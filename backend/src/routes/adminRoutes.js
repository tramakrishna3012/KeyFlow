const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { authenticateToken, requireRole } = require('../middleware/auth');
const { run, get, all } = require('../services/db');
const { logAudit } = require('../services/auditService');
const { runRetentionPurgeJob } = require('../services/retentionService');

router.use(authenticateToken);
router.use(requireRole(['admin', 'manager']));

// List organization members
router.get('/users', async (req, res, next) => {
  try {
    const users = await all(
      `SELECT id, email, full_name as fullName, role, is_active as isActive, last_login_at as lastLoginAt, created_at as createdAt
       FROM users 
       WHERE organization_id = ?
       ORDER BY created_at DESC`,
      [req.user.organization_id]
    );

    res.json({ success: true, users });
  } catch (err) {
    next(err);
  }
});

// Admin-only endpoints below
router.use(requireRole(['admin']));

// Provision new user
router.post('/users', async (req, res, next) => {
  try {
    const { email, password, fullName, role } = req.body;
    if (!email || !password || !fullName) {
      return res.status(400).json({ error: 'email, password, and fullName are required' });
    }

    const existing = await get('SELECT id FROM users WHERE email = ?', [email.toLowerCase()]);
    if (existing) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    const salt = await bcrypt.genSalt(12);
    const passwordHash = await bcrypt.hash(password, salt);
    const userId = crypto.randomUUID();

    await run(
      `INSERT INTO users (id, organization_id, email, password_hash, full_name, role, is_active, failed_login_attempts, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 1, 0, datetime('now'), datetime('now'))`,
      [userId, req.user.organization_id, email.toLowerCase(), passwordHash, fullName, role || 'member']
    );

    await logAudit({
      organizationId: req.user.organization_id,
      actorUserId: req.user.id,
      action: 'ADMIN_CREATED_USER',
      resourceType: 'user',
      resourceId: userId,
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.status(201).json({
      success: true,
      user: { id: userId, email: email.toLowerCase(), fullName, role: role || 'member' }
    });
  } catch (err) {
    next(err);
  }
});

// Get retention policy
router.get('/retention', async (req, res, next) => {
  try {
    let policy = await get('SELECT * FROM retention_policies WHERE organization_id = ?', [req.user.organization_id]);
    if (!policy) {
      policy = { retention_days: 90, auto_purge_enabled: 1 };
    }
    res.json({ success: true, policy });
  } catch (err) {
    next(err);
  }
});

// Update retention policy
router.put('/retention', async (req, res, next) => {
  try {
    const { retentionDays, autoPurgeEnabled } = req.body;
    const days = parseInt(retentionDays, 10);

    if (isNaN(days) || days < 7 || days > 730) {
      return res.status(400).json({ error: 'retentionDays must be between 7 and 730 days' });
    }

    await run(
      `INSERT INTO retention_policies (id, organization_id, retention_days, auto_purge_enabled, updated_by, updated_at)
       VALUES (?, ?, ?, ?, ?, datetime('now'))
       ON CONFLICT(organization_id) DO UPDATE SET
         retention_days = excluded.retention_days,
         auto_purge_enabled = excluded.auto_purge_enabled,
         updated_by = excluded.updated_by,
         updated_at = datetime('now')`,
      [crypto.randomUUID(), req.user.organization_id, days, autoPurgeEnabled ? 1 : 0, req.user.id]
    );

    await logAudit({
      organizationId: req.user.organization_id,
      actorUserId: req.user.id,
      action: 'RETENTION_POLICY_UPDATED',
      resourceType: 'retention_policy',
      metadata: { retentionDays: days, autoPurgeEnabled }
    });

    res.json({ success: true, message: 'Retention policy updated' });
  } catch (err) {
    next(err);
  }
});

// Manually trigger retention purge
router.post('/retention/purge-now', async (req, res, next) => {
  try {
    const results = await runRetentionPurgeJob();
    res.json({ success: true, results });
  } catch (err) {
    next(err);
  }
});

// View audit logs
router.get('/audit-logs', async (req, res, next) => {
  try {
    const logs = await all(
      `SELECT a.id, a.action, a.resource_type as resourceType, a.resource_id as resourceId, 
              a.ip_address as ipAddress, a.metadata, a.created_at as createdAt,
              u.email as actorEmail, u.full_name as actorName
       FROM audit_logs a
       LEFT JOIN users u ON a.actor_user_id = u.id
       WHERE a.organization_id = ?
       ORDER BY a.created_at DESC
       LIMIT 100`,
      [req.user.organization_id]
    );

    const parsedLogs = logs.map(l => ({
      ...l,
      metadata: typeof l.metadata === 'string' ? JSON.parse(l.metadata || '{}') : l.metadata
    }));

    res.json({ success: true, auditLogs: parsedLogs });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
