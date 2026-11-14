const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const app = require('../src/app');
const { initDB, get } = require('../src/services/db');
const { randomUUID } = require('node:crypto');
const { runMigrations } = require('../src/services/migrations');
const { SessionAggregator } = require('./helpers/SessionAggregator');

let server;
let baseUrl;
let userToken = '';
const testEmail = `session_user_${Date.now()}@keyflow.dev`;
const testPassword = 'TestPassword123!';

function request(path, options = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, baseUrl);
    const headers = options.headers || {};
    let body = options.body;

    if (body && typeof body === 'object') {
      body = JSON.stringify(body);
      headers['Content-Type'] = 'application/json';
    }

    const req = http.request(url, {
      method: options.method || 'GET',
      headers
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        let parsed = data;
        try {
          parsed = JSON.parse(data);
        } catch (_) {}
        resolve({ status: res.statusCode, headers: res.headers, body: parsed });
      });
    });

    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

test.before(async () => {
  await initDB();
  await runMigrations();
  server = http.createServer(app);
  await new Promise((resolve) => {
    server.listen(0, () => {
      const port = server.address().port;
      baseUrl = `http://localhost:${port}`;
      resolve();
    });
  });

  // Register a test user
  const regRes = await request('/api/v1/auth/register', {
    method: 'POST',
    body: {
      email: testEmail,
      password: testPassword,
      fullName: 'Session Tester',
      orgName: 'KeyFlow Session QA'
    }
  });

  if (regRes.status === 201) {
    userToken = regRes.body.token;
  } else {
    const logRes = await request('/api/v1/auth/login', {
      method: 'POST',
      body: { email: testEmail, password: testPassword }
    });
    userToken = logRes.body.token;
  }
});

test.after(async () => {
  if (server) {
    await new Promise(resolve => server.close(resolve));
  }
});

test('Approved typing sync encrypts text, retries safely, and isolates accounts', async () => {
  const id = randomUUID();
  const path = `/api/v1/sessions/manual/${id}`;
  const history = '/api/v1/sessions/manual';
  const owner = { Authorization: `Bearer ${userToken}` };
  const body = {
    content: '  A multiline snippet\nwith Unicode 👋  ',
    capturedAt: new Date().toISOString(),
    platform: 'iOS'
  };
  const write = (headers, content = body.content) => request(path, {
    method: 'PUT',
    headers: { ...headers },
    body: { ...body, content }
  });

  assert.equal((await write({})).status, 401);
  assert.equal((await write(owner, 'password: test-only')).status, 422);
  assert.deepEqual((await get('SELECT id FROM manual_typing_snippets WHERE id = ?', [id])), undefined);
  const retries = await Promise.all([write(owner), write(owner)]);
  assert.deepEqual(retries.map(response => response.status), [204, 204]);
  const stored = await get('SELECT encrypted_content FROM manual_typing_snippets WHERE id = ?', [id]);
  assert.ok(stored.encrypted_content);
  assert.notEqual(stored.encrypted_content, body.content);

  const second = await request('/api/v1/auth/register', {
    method: 'POST',
    body: { email: `other_${id}@example.test`, password: testPassword, fullName: 'Second Account' }
  });
  assert.equal(second.status, 201);
  const other = { Authorization: `Bearer ${second.body.token}` };
  assert.equal((await write(other, 'Cannot overwrite')).status, 404);
  assert.equal((await request(history, { headers: other })).body.snippets.length, 0);
  const result = await request(history, { headers: owner });
  assert.equal(result.status, 200);
  assert.deepEqual(result.body.snippets.filter(item => item.id === id), [{ id, ...body }]);
});

test('SessionAggregator (Client Engine): Inactivity Debounce and Upsert Paradigm', async (t) => {
  let updateCalls = 0;
  let finalizedCalls = 0;
  let lastUpdatedSession = null;

  const aggregator = new SessionAggregator({
    inactivityDebounceMs: 50, // Short for testing
    sessionTimeoutMs: 200,
    onSessionUpdate: (s) => {
      updateCalls++;
      lastUpdatedSession = s;
    },
    onSessionFinalize: () => {
      finalizedCalls++;
    }
  });

  // Step 1: Rapid keystrokes (simulating user typing "Hello World")
  aggregator.handleTypingInput({
    appName: 'VS Code',
    windowTitle: 'SessionAggregator.ts — KeyFlow',
    deviceName: 'MacBook Pro',
    text: 'H'
  });
  aggregator.handleTypingInput({
    appName: 'VS Code',
    windowTitle: 'SessionAggregator.ts — KeyFlow',
    deviceName: 'MacBook Pro',
    text: 'Hello'
  });
  aggregator.handleTypingInput({
    appName: 'VS Code',
    windowTitle: 'SessionAggregator.ts — KeyFlow',
    deviceName: 'MacBook Pro',
    text: 'Hello World'
  });

  // Verify single session created in memory with correct counts
  const active = aggregator.getActiveSessions();
  assert.equal(active.length, 1);
  assert.equal(active[0].content, 'Hello World');
  assert.equal(active[0].characterCount, 11);
  assert.equal(active[0].wordCount, 2);
  assert.equal(active[0].appName, 'VS Code');

  // Wait for debounce (configured as 50ms)
  await new Promise((r) => setTimeout(r, 80));
  assert.equal(updateCalls, 1);
  assert.equal(lastUpdatedSession.content, 'Hello World');

  // Step 2: Privacy sensitive field rejection
  const passwordResult = aggregator.handleTypingInput({
    appName: 'Chrome',
    windowTitle: 'Login - KeyFlow',
    deviceName: 'MacBook Pro',
    text: 'SuperSecret123',
    isPasswordField: true
  });
  assert.equal(passwordResult, null, 'Password fields must be ignored');

  // Step 3: Calculator exemption
  const calcResult = aggregator.handleTypingInput({
    appName: 'Calculator',
    windowTitle: 'Calculator',
    deviceName: 'MacBook Pro',
    text: '5000 * 2 = 10000'
  });
  assert.notEqual(calcResult, null, 'Calculator should be exempted');

  // Step 4: Wait for session timeout (configured as 200ms) to trigger finalize
  await new Promise((r) => setTimeout(r, 220));
  assert.equal(finalizedCalls >= 1, true);
});

test('SessionAggregator (Client Engine): Content Type Classification for Clipboard', (t) => {
  // URL Classification
  assert.equal(
    SessionAggregator.classifyContentType('https://keyflow.tramakrishna3012.workers.dev/docs'),
    'url'
  );
  assert.equal(
    SessionAggregator.classifyContentType('http://localhost:3000/api/v1/health'),
    'url'
  );

  // Code Classification
  const jsCode = `const aggregator = new SessionAggregator();\nreturn aggregator.generateUUID();`;
  assert.equal(SessionAggregator.classifyContentType(jsCode), 'code');

  const sqlCode = `SELECT id, content FROM typing_sessions WHERE is_favorite = true;`;
  assert.equal(SessionAggregator.classifyContentType(sqlCode), 'code');

  // Text Classification
  assert.equal(
    SessionAggregator.classifyContentType('Just a standard paragraph note about productivity.'),
    'text'
  );
});

test('API: POST /api/v1/sessions/upsert and GET /api/v1/sessions', async () => {
  const sessionId = `test-session-uuid-${Date.now()}`;

  // 1. Initial Upsert
  const res1 = await request('/api/v1/sessions/upsert', {
    method: 'POST',
    headers: { Authorization: `Bearer ${userToken}` },
    body: {
      id: sessionId,
      deviceName: 'Motorola Edge 40',
      appName: 'Slack',
      windowTitle: '#general — KeyFlow Team',
      content: 'Hey team, the new session debouncing is live!',
      isFavorite: true,
      draftHistory: [
        { timestamp: new Date().toISOString(), text: 'Hey team', charCount: 8 },
        { timestamp: new Date().toISOString(), text: 'Hey team, the new session debouncing is live!', charCount: 46 }
      ]
    }
  });

  assert.equal(res1.status, 200);
  assert.equal(res1.body.success, true);
  assert.equal(res1.body.session.id, sessionId);
  assert.equal(res1.body.session.character_count, 45);
  assert.equal(res1.body.session.word_count, 8);
  assert.equal(res1.body.session.is_favorite, true);

  // 2. Second Upsert (same id - updates content without duplicate row)
  const res2 = await request('/api/v1/sessions/upsert', {
    method: 'POST',
    headers: { Authorization: `Bearer ${userToken}` },
    body: {
      id: sessionId,
      deviceName: 'Motorola Edge 40',
      appName: 'Slack',
      windowTitle: '#general — KeyFlow Team',
      content: 'Hey team, the new session debouncing is live and tested!',
      isFavorite: true
    }
  });

  assert.equal(res2.status, 200);
  assert.equal(res2.body.session.character_count, 56);
  assert.equal(res2.body.session.word_count, 10);

  // 3. Query Sessions
  const getRes = await request('/api/v1/sessions?appName=Slack', {
    method: 'GET',
    headers: { Authorization: `Bearer ${userToken}` }
  });

  assert.equal(getRes.status, 200);
  assert.equal(getRes.body.success, true);
  assert.equal(getRes.body.sessions.length >= 1, true);
  const found = getRes.body.sessions.find((s) => s.id === sessionId);
  assert.notEqual(found, undefined);
  assert.equal(found.content, 'Hey team, the new session debouncing is live and tested!');
});

test('API: POST /api/v1/clipboard/insert and GET /api/v1/clipboard with Pinning', async () => {
  // 1. Insert URL entry
  const res1 = await request('/api/v1/clipboard/insert', {
    method: 'POST',
    headers: { Authorization: `Bearer ${userToken}` },
    body: {
      deviceName: 'Motorola Edge 40',
      sourceApp: 'Chrome',
      content: 'https://github.com/tramakrishna3012/KeyFlow',
      isPinned: true
    }
  });

  assert.equal(res1.status, 201);
  assert.equal(res1.body.success, true);
  assert.equal(res1.body.entry.content_type, 'url');
  assert.equal(res1.body.entry.is_pinned, true);

  const clipId = res1.body.entry.id;

  // 2. Insert Code entry
  const res2 = await request('/api/v1/clipboard/insert', {
    method: 'POST',
    headers: { Authorization: `Bearer ${userToken}` },
    body: {
      deviceName: 'Motorola Edge 40',
      sourceApp: 'VS Code',
      content: 'function calculateWordCount(text) {\n  return text.split(/\\s+/).length;\n}'
    }
  });

  assert.equal(res2.status, 201);
  assert.equal(res2.body.entry.content_type, 'code');

  // 3. Query clipboard (pinned items should be sorted first)
  const listRes = await request('/api/v1/clipboard', {
    method: 'GET',
    headers: { Authorization: `Bearer ${userToken}` }
  });

  assert.equal(listRes.status, 200);
  assert.equal(listRes.body.entries.length >= 2, true);
  assert.equal(listRes.body.entries[0].is_pinned, true);

  // 4. Toggle Pin
  const pinRes = await request(`/api/v1/clipboard/${clipId}/pin`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${userToken}` }
  });

  assert.equal(pinRes.status, 200);
  assert.equal(pinRes.body.is_pinned, false);
});
