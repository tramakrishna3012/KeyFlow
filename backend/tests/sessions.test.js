const test = require('node:test');
const assert = require('node:assert');
const http = require('http');
const app = require('../src/app');
const { initDB, run } = require('../src/services/db');

let server;
let baseUrl;

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
  server = http.createServer(app);
  await new Promise((resolve) => {
    server.listen(0, () => {
      const port = server.address().port;
      baseUrl = `http://localhost:${port}`;
      resolve();
    });
  });
});

test.after(async () => {
  if (server) {
    await new Promise(resolve => server.close(resolve));
  }
});

test('Look System: Full Session Lifecycle & Application Hierarchy', async () => {
  const userEmail = `session_owner_${Date.now()}@looksystem.com`;
  const reg = await request('/api/v1/auth/register', {
    method: 'POST',
    body: {
      email: userEmail,
      password: 'OwnerPassword123!',
      fullName: 'Session Owner',
      role: 'member'
    }
  });
  const token = reg.body.token;

  // 1. Start Session
  const startRes = await request('/api/v1/activity/sessions/start', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: { deviceName: 'MacBook Pro M3' }
  });
  assert.strictEqual(startRes.status, 201);
  assert.ok(startRes.body.sessionId);
  assert.strictEqual(startRes.body.status, 'active');

  const sessionId = startRes.body.sessionId;

  // 2. Pause Session
  const pauseRes = await request('/api/v1/activity/sessions/pause', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: { sessionId }
  });
  assert.strictEqual(pauseRes.status, 200);
  assert.strictEqual(pauseRes.body.status, 'paused');

  // 3. Resume Session
  const resumeRes = await request('/api/v1/activity/sessions/resume', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: { sessionId }
  });
  assert.strictEqual(resumeRes.status, 200);
  assert.strictEqual(resumeRes.body.status, 'active');

  // 4. Ingest batch activity with text records under this session
  const eventId1 = `evt-unique-${Date.now()}-001`;
  const eventId2 = `evt-unique-${Date.now()}-002`;
  const eventId3 = `evt-unique-${Date.now()}-003`;
  const batchRes = await request('/api/v1/activity/batch', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: {
      deviceName: 'MacBook Pro M3',
      osInfo: 'macOS Sonoma 14.5',
      sessionId,
      entries: [
        {
          id: eventId1,
          appName: 'Google Chrome',
          windowTitle: 'KeyFlow Architecture Document',
          textRecord: 'Reviewing session-based monitoring architecture specifications.',
          durationSeconds: 300,
          startedAt: new Date(Date.now() - 300000).toISOString(),
          endedAt: new Date().toISOString()
        },
        {
          id: eventId2,
          appName: 'Visual Studio Code',
          windowTitle: 'LookSystemCore.dart',
          textRecord: 'Implementing event-driven low CPU background monitor.',
          durationSeconds: 600,
          startedAt: new Date(Date.now() - 600000).toISOString(),
          endedAt: new Date().toISOString()
        },
        {
          id: eventId3,
          appName: 'Notes',
          windowTitle: 'Banking Password & OTP secret',
          textRecord: 'pin=1234 otp=892314 4111-2222-3333-4444 credit card',
          durationSeconds: 120,
          startedAt: new Date(Date.now() - 120000).toISOString(),
          endedAt: new Date().toISOString()
        }
      ]
    }
  });
  assert.strictEqual(batchRes.status, 200);
  assert.strictEqual(batchRes.body.ingestedCount, 3);

  // 5. Test Deduplication (Resending the same eventId should not duplicate)
  const dupRes = await request('/api/v1/activity/batch', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: {
      deviceName: 'MacBook Pro M3',
      sessionId,
      entries: [
        {
          id: eventId1,
          appName: 'Google Chrome',
          windowTitle: 'KeyFlow Architecture Document',
          textRecord: 'Duplicate submission attempt',
          durationSeconds: 300
        }
      ]
    }
  });
  assert.strictEqual(dupRes.status, 200);
  assert.strictEqual(dupRes.body.ingestedCount, 0);

  // 6. Stop Session
  const stopRes = await request('/api/v1/activity/sessions/stop', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: { sessionId }
  });
  assert.strictEqual(stopRes.status, 200);
  assert.strictEqual(stopRes.body.status, 'completed');

  // 7. Fetch Hierarchical Session Tree: Session -> Applications -> Activity / Text
  const treeRes = await request(`/api/v1/activity/sessions/${sessionId}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  assert.strictEqual(treeRes.status, 200);
  assert.ok(treeRes.body.session);
  assert.strictEqual(treeRes.body.session.id, sessionId);
  assert.ok(Array.isArray(treeRes.body.applications));
  assert.strictEqual(treeRes.body.applications.length, 3);

  const chromeApp = treeRes.body.applications.find(a => a.app_name === 'Google Chrome');
  assert.ok(chromeApp);
  assert.ok(chromeApp.activityTimeline.length >= 1);
  assert.ok(chromeApp.textRecords.length >= 1);
  assert.match(chromeApp.textRecords[0].content, /Reviewing session-based monitoring/);

  // Verify sensitive pattern redaction in Notes app text
  const notesApp = treeRes.body.applications.find(a => a.app_name === 'Notes');
  assert.ok(notesApp);
  assert.strictEqual(notesApp.textRecords[0].isExcluded, true);

  // 8. Search & Filtering Endpoint
  const searchRes = await request('/api/v1/activity/search?q=architecture', {
    headers: { Authorization: `Bearer ${token}` }
  });
  assert.strictEqual(searchRes.status, 200);
  assert.ok(searchRes.body.results.length >= 1);
  assert.strictEqual(searchRes.body.results[0].appName, 'Google Chrome');

  // 9. Configure Privacy Exclusions
  const exclRes = await request('/api/v1/activity/privacy/exclusions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: { appName: '1Password' }
  });
  assert.strictEqual(exclRes.status, 201);

  const getExclRes = await request('/api/v1/activity/privacy/exclusions', {
    headers: { Authorization: `Bearer ${token}` }
  });
  assert.strictEqual(getExclRes.status, 200);
  assert.ok(getExclRes.body.exclusions.some(e => e.appName === '1Password'));

  // 10. Cross-Device Typing History Retrieval
  const typingRes = await request('/api/v1/activity/typing-history?appName=Visual', {
    headers: { Authorization: `Bearer ${token}` }
  });
  assert.strictEqual(typingRes.status, 200);
  assert.ok(typingRes.body.history.length >= 1);
  assert.strictEqual(typingRes.body.history[0].appName, 'Visual Studio Code');
  assert.match(typingRes.body.history[0].content, /Implementing event-driven low CPU/);
});
