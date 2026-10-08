const test = require('node:test');
const assert = require('node:assert');
const http = require('http');
const app = require('../src/app');
const { initDB, run } = require('../src/services/db');
const { registerUser } = require('../src/services/authService');

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

test('Web-to-Mobile Pairing Handshake Protocol', async (t) => {
  // 1. Setup authenticated user
  const email = `pairing_test_${Date.now()}@keyflow.dev`;
  const regResult = await registerUser({
    email,
    password: 'Password123!@#',
    fullName: 'Pairing Test User',
    role: 'admin',
    organizationName: 'KeyFlow Pairing Org'
  });
  const userJwt = regResult.token;

  await t.test('POST /api/auth/pairing-token requires authentication', async () => {
    const res = await request('/api/auth/pairing-token', { method: 'POST' });
    assert.strictEqual(res.status, 401);
  });

  let pairingToken;
  let pairingUrl;

  await t.test('POST /api/auth/pairing-token creates single-use 10-minute token', async () => {
    const res = await request('/api/auth/pairing-token', {
      method: 'POST',
      headers: { Authorization: `Bearer ${userJwt}` }
    });

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.success, true);
    assert.ok(res.body.pairing_token);
    assert.ok(res.body.expires_at);
    assert.ok(res.body.pairing_url.startsWith('keyflow://pair?token='));

    pairingToken = res.body.pairing_token;
    pairingUrl = res.body.pairing_url;
  });

  await t.test('POST /api/auth/verify-pairing exchanges pairing_token for user JWT & encryption seed', async () => {
    const res = await request('/api/auth/verify-pairing', {
      method: 'POST',
      body: { pairing_token: pairingToken }
    });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);
    assert.ok(res.body.token, 'Must return session JWT');
    assert.strictEqual(res.body.user.email, email);
    assert.ok(res.body.encryption_seed, 'Must return hardware encryption seed');
    assert.strictEqual(res.body.encryptionSeed, res.body.encryption_seed);
  });

  await t.test('POST /api/auth/verify-pairing immediately rejects already consumed token (single-use)', async () => {
    const res = await request('/api/auth/verify-pairing', {
      method: 'POST',
      body: { pairing_token: pairingToken }
    });

    assert.strictEqual(res.status, 410);
    assert.strictEqual(res.body.error, 'Pairing token has already been used');
  });

  await t.test('POST /api/auth/verify-pairing rejects non-existent token with 404', async () => {
    const res = await request('/api/auth/verify-pairing', {
      method: 'POST',
      body: { pairing_token: 'non_existent_token_12345' }
    });

    assert.strictEqual(res.status, 404);
  });
});
