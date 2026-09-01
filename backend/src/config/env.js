const dotenv = require('dotenv');
dotenv.config();

const crypto = require('node:crypto');

module.exports = {
  PORT: process.env.PORT || 4000,
  JWT_SECRET: process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex'),
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '24h',
  MAX_FAILED_LOGIN_ATTEMPTS: 5,
  LOCKOUT_DURATION_MINUTES: 15,
  DEFAULT_RETENTION_DAYS: 90,
  DB_PATH: process.env.DB_PATH || './look_system.db'
};
