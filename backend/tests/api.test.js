const test = require('node:test');
const assert = require('node:assert');
const http = require('http');
const app = require('../src/app');
const { initDB, run } = require('../src/services/db');
const { runRetentionPurgeJob } = require('../src/services/retentionService');

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

test('1. Health Check Endpoint', async () => {
  const res = await request('/api/health');
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.status, 'healthy');
  assert.strictEqual(res.body.service, 'Look System API');
});

test('2. User Registration & Authentication Flow', async () => {
  // Register Admin User
  const adminEmail = `admin_${Date.now()}@looksystem.com`;
  const regAdmin = await request('/api/v1/auth/register', {
    method: 'POST',
    body: {
      email: adminEmail,
      password: 'SecureAdminPassword123!',
      fullName: 'Chief Admin',
      role: 'admin',
      organizationName: 'Look Tech Corp'
    }
  });

  assert.strictEqual(regAdmin.status, 201);
  assert.ok(regAdmin.body.token);
  assert.strictEqual(regAdmin.body.user.role, 'admin');

  // Duplicate email prevention
  const duplicate = await request('/api/v1/auth/register', {
    method: 'POST',
    body: {
      email: adminEmail,
      password: 'SomeOtherPassword123!',
      fullName: 'Imposter'
    }
  });
  assert.strictEqual(duplicate.status, 409);

  // Successful Login
  const loginRes = await request('/api/v1/auth/login', {
    method: 'POST',
    body: {
      email: adminEmail,
      password: 'SecureAdminPassword123!'
    }
  });
  assert.strictEqual(loginRes.status, 200);
  assert.ok(loginRes.body.token);
  assert.strictEqual(loginRes.body.user.email, adminEmail);

  // Authenticated /me endpoint
  const meRes = await request('/api/v1/auth/me', {
    headers: { Authorization: `Bearer ${loginRes.body.token}` }
  });
  assert.strictEqual(meRes.status, 200);
  assert.strictEqual(meRes.body.user.email, adminEmail);
});

test('3. Account Lockout on Consecutive Failed Logins', async () => {
  const victimEmail = `victim_${Date.now()}@looksystem.com`;
  await request('/api/v1/auth/register', {
    method: 'POST',
    body: {
      email: victimEmail,
      password: 'ValidPassword123!',
      fullName: 'Security Target'
    }
  });

  // Attempt 5 incorrect logins
  for (let i = 0; i < 5; i++) {
    const failedRes = await request('/api/v1/auth/login', {
      method: 'POST',
      body: { email: victimEmail, password: 'WrongPassword!' }
    });
    assert.strictEqual(failedRes.status, 401);
  }

  // 6th attempt should return 423 Locked
  const lockedRes = await request('/api/v1/auth/login', {
    method: 'POST',
    body: { email: victimEmail, password: 'WrongPassword!' }
  });
  assert.strictEqual(lockedRes.status, 423);
  assert.match(lockedRes.body.error, /Account temporarily locked/i);
});

test('4. Telemetry Ingestion, Sanitization & Analytics Aggregation', async () => {
  const memberEmail = `employee_${Date.now()}@looksystem.com`;
  const reg = await request('/api/v1/auth/register', {
    method: 'POST',
    body: {
      email: memberEmail,
      password: 'EmployeePassword123!',
      fullName: 'Productive Employee',
      role: 'member'
    }
  });

  const token = reg.body.token;

  // Ingest batch activity with titles containing emails & tokens to test sanitization
  const now = new Date();
  const startTime = new Date(now.getTime() - 3600 * 1000).toISOString();
  const endTime = now.toISOString();

  const batchRes = await request('/api/v1/activity/batch', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: {
      deviceName: 'Engineering-MacBook-Pro',
      osInfo: 'macOS Sonoma 14.5',
      agentVersion: '1.0.0',
      entries: [
        {
          appName: 'Visual Studio Code',
          windowTitle: 'look_system_core.js — secret=abc1234567890abcdef1234567890',
          durationSeconds: 1800,
          idleSeconds: 60,
          isIdle: false,
          startedAt: startTime,
          endedAt: endTime
        },
        {
          appName: 'Slack',
          windowTitle: 'Chat with john.doe@company.com in #general',
          durationSeconds: 900,
          idleSeconds: 300,
          isIdle: false,
          startedAt: startTime,
          endedAt: endTime
        },
        {
          appName: 'Google Chrome',
          windowTitle: 'https://github.com/org/repo?token=supersecret12345678901234567890',
          durationSeconds: 600,
          idleSeconds: 0,
          isIdle: false,
          startedAt: startTime,
          endedAt: endTime
        }
      ]
    }
  });

  assert.strictEqual(batchRes.status, 200);
  assert.strictEqual(batchRes.body.ingestedCount, 3);

  // Fetch Activity Summary
  const summaryRes = await request('/api/v1/activity/summary', {
    headers: { Authorization: `Bearer ${token}` }
  });

  assert.strictEqual(summaryRes.status, 200);
  assert.strictEqual(summaryRes.body.metrics.totalDurationSeconds, 3300);
  assert.strictEqual(summaryRes.body.metrics.totalIdleSeconds, 360);
  assert.strictEqual(summaryRes.body.metrics.totalActiveSeconds, 2940);
  assert.strictEqual(summaryRes.body.metrics.uniqueApps, 3);
  assert.ok(summaryRes.body.metrics.productivityScore >= 80);

  // Verify categories inferred automatically
  const categories = summaryRes.body.categories.map(c => c.category);
  assert.ok(categories.includes('Development'));
  assert.ok(categories.includes('Communication'));
  assert.ok(categories.includes('Browsing'));

  // Verify sanitized titles in recent logs
  for (const log of summaryRes.body.recentLogs) {
    assert.doesNotMatch(log.windowTitle, /john\.doe@company\.com/);
    assert.doesNotMatch(log.windowTitle, /token=supersecret/);
  }
});

test('5. Role-Based Access Control (RBAC) Enforcement', async () => {
  // Member token
  const member = await request('/api/v1/auth/register', {
    method: 'POST',
    body: { email: `member_${Date.now()}@test.com`, password: 'Password123!', fullName: 'Regular User', role: 'member' }
  });

  // Admin token
  const admin = await request('/api/v1/auth/register', {
    method: 'POST',
    body: { email: `admin_${Date.now()}@test.com`, password: 'Password123!', fullName: 'Super Admin', role: 'admin' }
  });

  // Member hitting admin users list -> 403 Forbidden
  const memberForbidden = await request('/api/v1/admin/users', {
    headers: { Authorization: `Bearer ${member.body.token}` }
  });
  assert.strictEqual(memberForbidden.status, 403);

  // Admin hitting admin users list -> 200 OK
  const adminAllowed = await request('/api/v1/admin/users', {
    headers: { Authorization: `Bearer ${admin.body.token}` }
  });
  assert.strictEqual(adminAllowed.status, 200);
  assert.ok(Array.isArray(adminAllowed.body.users));
});

test('6. Privacy, Consent & GDPR Data Subject Rights (DSAR)', async () => {
  const user = await request('/api/v1/auth/register', {
    method: 'POST',
    body: { email: `privacy_${Date.now()}@test.com`, password: 'Password123!', fullName: 'Privacy User' }
  });
  const token = user.body.token;

  // View initial consent
  const consentStatus = await request('/api/v1/compliance/status', {
    headers: { Authorization: `Bearer ${token}` }
  });
  assert.strictEqual(consentStatus.status, 200);
  assert.strictEqual(consentStatus.body.consentStatus, 'granted');

  // Update consent to revoked
  const revokeRes = await request('/api/v1/compliance/consent', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: { status: 'revoked', policyVersion: '1.1.0' }
  });
  assert.strictEqual(revokeRes.status, 200);
  assert.strictEqual(revokeRes.body.status, 'revoked');

  // Export Data Archive (JSON)
  const exportJson = await request('/api/v1/compliance/export?format=json', {
    headers: { Authorization: `Bearer ${token}` }
  });
  assert.strictEqual(exportJson.status, 200);
  assert.ok(exportJson.body.exportTimestamp);
  assert.ok(exportJson.body.user);

  // Export Data Archive (CSV)
  const exportCsv = await request('/api/v1/compliance/export?format=csv', {
    headers: { Authorization: `Bearer ${token}` }
  });
  assert.strictEqual(exportCsv.status, 200);
  assert.match(exportCsv.headers['content-type'], /text\/csv/);

  // Delete My Data (Right to be Forgotten)
  const deleteRes = await request('/api/v1/compliance/delete-my-data', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` }
  });
  assert.strictEqual(deleteRes.status, 200);
  assert.ok(deleteRes.body.message.includes('erased'));
});

test('7. Automated Retention Policy Purge Job', async () => {
  const purgeResults = await runRetentionPurgeJob();
  assert.ok(Array.isArray(purgeResults));
});
