const express = require('express');
const router = express.Router();
const crypto = require('node:crypto');
const jwt = require('jsonwebtoken');
const { registerUser, loginUser } = require('../services/authService');
const { authenticateToken } = require('../middleware/auth');
const { run, get } = require('../services/db');
const { JWT_SECRET, JWT_EXPIRES_IN } = require('../config/env');
const { logAudit } = require('../services/auditService');

router.post('/register', async (req, res, next) => {
  try {
    const { email, password, fullName, role, organizationName } = req.body;
    if (!email || !password || !fullName) {
      return res.status(400).json({ error: 'email, password, and fullName are required' });
    }

    // Enhanced password validation
    if (password.length < 12) {
      return res.status(400).json({ error: 'Password must be at least 12 characters long' });
    }

    // Check password complexity
    const hasUpperCase = /[A-Z]/.test(password);
    const hasLowerCase = /[a-z]/.test(password);
    const hasNumber = /[0-9]/.test(password);
    const hasSpecialChar = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password);

    if (!hasUpperCase || !hasLowerCase || !hasNumber || !hasSpecialChar) {
      return res.status(400).json({ 
        error: 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character' 
      });
    }

    const result = await registerUser({
      email,
      password,
      fullName,
      role: role || 'member',
      organizationName: organizationName || 'Look Enterprise Org',
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
});

router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'email and password are required' });
    }

    const result = await loginUser({
      email,
      password,
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.json(result);
  } catch (err) {
    next(err);
  }
});

router.get('/me', authenticateToken, async (req, res, next) => {
  try {
    const user = await get(
      `SELECT u.id, u.email, u.full_name, u.full_name as fullName, u.role, u.is_active, u.created_at, o.name as organizationName
       FROM users u
       LEFT JOIN organizations o ON u.organization_id = o.id
       WHERE u.id = ?`,
      [req.user.id]
    );

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user });
  } catch (err) {
    next(err);
  }
});

router.post('/pairing-token', authenticateToken, async (req, res, next) => {
  try {
    const pairingToken = crypto.randomBytes(32).toString('hex');
    const id = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    await run(
      `INSERT INTO pairing_tokens (id, user_id, token, expires_at, used, created_at)
       VALUES (?, ?, ?, ?, 0, datetime('now'))`,
      [id, req.user.id, pairingToken, expiresAt]
    );

    await logAudit({
      organizationId: req.user.organization_id,
      actorUserId: req.user.id,
      action: 'PAIRING_TOKEN_GENERATED',
      resourceType: 'auth',
      resourceId: id,
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.status(201).json({
      success: true,
      pairing_token: pairingToken,
      token: pairingToken,
      expires_at: expiresAt,
      expiresAt: expiresAt,
      pairing_url: `keyflow://pair?token=${pairingToken}`,
      pairingUrl: `keyflow://pair?token=${pairingToken}`
    });
  } catch (err) {
    next(err);
  }
});

router.post('/verify-pairing', async (req, res, next) => {
  try {
    const pairingToken = req.body?.pairing_token || req.body?.token;
    if (!pairingToken) {
      return res.status(400).json({ error: 'pairing_token is required' });
    }

    const record = await get('SELECT * FROM pairing_tokens WHERE token = ?', [pairingToken]);
    if (!record) {
      return res.status(404).json({ error: 'Invalid pairing token' });
    }

    if (record.used) {
      return res.status(410).json({ error: 'Pairing token has already been used' });
    }

    const expiresAtTime = new Date(record.expires_at).getTime();
    if (Date.now() > expiresAtTime) {
      return res.status(410).json({ error: 'Pairing token has expired' });
    }

    // Immediately invalidate the token upon consumption
    await run('UPDATE pairing_tokens SET used = 1 WHERE id = ?', [record.id]);

    const user = await get(
      'SELECT id, organization_id, email, full_name, role, is_active FROM users WHERE id = ?',
      [record.user_id]
    );

    if (!user || !user.is_active) {
      return res.status(403).json({ error: 'User account is inactive or not found' });
    }

    const sessionToken = jwt.sign(
      { userId: user.id, email: user.email, role: user.role, organizationId: user.organization_id },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    const encryptionSeed = crypto.createHmac('sha256', JWT_SECRET).update(`seed_${user.id}`).digest('hex');

    await logAudit({
      organizationId: user.organization_id,
      actorUserId: user.id,
      action: 'MOBILE_PAIRING_SUCCESS',
      resourceType: 'auth',
      resourceId: user.id,
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.json({
      success: true,
      token: sessionToken,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.full_name,
        role: user.role,
        organizationId: user.organization_id
      },
      encryption_seed: encryptionSeed,
      encryptionSeed: encryptionSeed
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
