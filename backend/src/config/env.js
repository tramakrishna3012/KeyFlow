const dotenv = require('dotenv');
dotenv.config();

const crypto = require('node:crypto');

// Validate JWT_SECRET in production
if (process.env.NODE_ENV === 'production' && !process.env.JWT_SECRET) {
  console.error('[FATAL] JWT_SECRET environment variable is required in production mode');
  console.error('[FATAL] Set JWT_SECRET to a strong random value (minimum 32 characters)');
  console.error('[FATAL] Generate with: openssl rand -hex 32');
  process.exit(1);
}

// Warn if using default in development
const jwtSecret = process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex');
if (!process.env.JWT_SECRET && process.env.NODE_ENV !== 'production') {
  console.warn('[WARNING] JWT_SECRET not set. Using random value (tokens will invalidate on restart)');
  console.warn('[WARNING] Set JWT_SECRET in .env file for token persistence');
}

module.exports = {
  PORT: process.env.PORT || 4000,
  JWT_SECRET: jwtSecret,
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '24h',
  MAX_FAILED_LOGIN_ATTEMPTS: 5,
  LOCKOUT_DURATION_MINUTES: 15,
  DEFAULT_RETENTION_DAYS: 90,
  DB_PATH: process.env.DB_PATH || './look_system.db'
};
