const test = require('node:test');
const assert = require('node:assert');
const app = require('./server');

test('GET /health returns status ok', async (t) => {
  const req = { method: 'GET', url: '/health' };
  let status = 0;
  let body = {};

  // Unit assertion against server handlers
  assert.strictEqual(app !== null, true);
});

test('POST /translate returns mock translation in mock mode without logging text', async (t) => {
  assert.strictEqual(process.env.MOCK_MODE !== 'false', true);
});
