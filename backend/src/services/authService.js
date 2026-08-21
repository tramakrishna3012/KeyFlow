const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { run, get } = require('./db');
const { JWT_SECRET, JWT_EXPIRES_IN, MAX_FAILED_LOGIN_ATTEMPTS, LOCKOUT_DURATION_MINUTES } = require('../config/env');
const { logAudit } = require('./auditService');

async function registerUser({ email, password, fullName, role = 'member', organizationName = 'Default Organization', ipAddress, userAgent }) {
  const existingUser = await get('SELECT id FROM users WHERE email = ?', [email.toLowerCase()]);
  if (existingUser) {
    const error = new Error('Email already registered');
    error.statusCode = 409;
    throw error;
  }

  // Create organization if doesn't exist
  let org = await get('SELECT id FROM organizations WHERE name = ?', [organizationName]);
  let orgId;
  if (!org) {
    orgId = crypto.randomUUID();
    await run('INSERT INTO organizations (id, name, created_at, updated_at) VALUES (?, ?, datetime("now"), datetime("now"))', [orgId, organizationName]);
    // Create default retention policy for org
    await run('INSERT INTO retention_policies (id, organization_id, retention_days, auto_purge_enabled, updated_at) VALUES (?, ?, 90, 1, datetime("now"))', [crypto.randomUUID(), orgId]);
  } else {
    orgId = org.id;
  }

  const salt = await bcrypt.genSalt(12);
  const passwordHash = await bcrypt.hash(password, salt);
  const userId = crypto.randomUUID();

  await run(
    `INSERT INTO users (id, organization_id, email, password_hash, full_name, role, is_active, failed_login_attempts, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, 1, 0, datetime('now'), datetime('now'))`,
    [userId, orgId, email.toLowerCase(), passwordHash, fullName, role]
  );

  // Auto record consent for account registration
  await run(
    `INSERT INTO consent_records (id, user_id, policy_version, consent_type, status, consented_at)
     VALUES (?, ?, '1.0.0', 'activity_monitoring_consent', 'granted', datetime('now'))`,
    [crypto.randomUUID(), userId]
  );

  await logAudit({
    organizationId: orgId,
    actorUserId: userId,
    action: 'USER_REGISTERED',
    resourceType: 'user',
    resourceId: userId,
    ipAddress,
    userAgent
  });

  const token = jwt.sign(
    { userId, email: email.toLowerCase(), role, organizationId: orgId },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );

  return {
    user: {
      id: userId,
      email: email.toLowerCase(),
      fullName,
      role,
      organizationId: orgId
    },
    token
  };
}

async function loginUser({ email, password, ipAddress, userAgent }) {
  const user = await get('SELECT * FROM users WHERE email = ?', [email.toLowerCase()]);
  if (!user) {
    const error = new Error('Invalid email or password');
    error.statusCode = 401;
    throw error;
  }

  // Check account lockout
  if (user.locked_until) {
    const lockTime = new Date(user.locked_until).getTime();
    if (Date.now() < lockTime) {
      const remainingMinutes = Math.ceil((lockTime - Date.now()) / (60 * 1000));
      const error = new Error(`Account temporarily locked due to failed attempts. Try again in ${remainingMinutes} minute(s).`);
      error.statusCode = 423; // Locked
      throw error;
    } else {
      // Lock expired, reset
      await run('UPDATE users SET locked_until = NULL, failed_login_attempts = 0 WHERE id = ?', [user.id]);
    }
  }

  const isMatch = await bcrypt.compare(password, user.password_hash);
  if (!isMatch) {
    const attempts = (user.failed_login_attempts || 0) + 1;
    let lockedUntil = null;
    if (attempts >= MAX_FAILED_LOGIN_ATTEMPTS) {
      lockedUntil = new Date(Date.now() + LOCKOUT_DURATION_MINUTES * 60 * 1000).toISOString();
    }

    await run('UPDATE users SET failed_login_attempts = ?, locked_until = ? WHERE id = ?', [attempts, lockedUntil, user.id]);

    await logAudit({
      organizationId: user.organization_id,
      actorUserId: user.id,
      action: 'LOGIN_FAILED',
      resourceType: 'auth',
      resourceId: user.id,
      ipAddress,
      userAgent,
      metadata: { attempts }
    });

    const error = new Error(lockedUntil ? 'Account locked due to excessive failed attempts.' : 'Invalid email or password');
    error.statusCode = 401;
    throw error;
  }

  // Reset failed attempts on success
  await run('UPDATE users SET failed_login_attempts = 0, locked_until = NULL, last_login_at = datetime("now") WHERE id = ?', [user.id]);

  await logAudit({
    organizationId: user.organization_id,
    actorUserId: user.id,
    action: 'LOGIN_SUCCESS',
    resourceType: 'auth',
    resourceId: user.id,
    ipAddress,
    userAgent
  });

  const token = jwt.sign(
    { userId: user.id, email: user.email, role: user.role, organizationId: user.organization_id },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );

  return {
    user: {
      id: user.id,
      email: user.email,
      fullName: user.full_name,
      role: user.role,
      organizationId: user.organization_id,
      mfaEnabled: Boolean(user.mfa_enabled)
    },
    token
  };
}

module.exports = {
  registerUser,
  loginUser
};
