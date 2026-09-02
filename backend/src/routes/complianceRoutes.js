const express = require('express');
const router = express.Router();
const crypto = require('node:crypto');
const { authenticateToken } = require('../middleware/auth');
const { run, get, all } = require('../services/db');
const { logAudit } = require('../services/auditService');

router.use(authenticateToken);

// View current consent status
router.get('/status', async (req, res, next) => {
  try {
    const record = await get(
      `SELECT * FROM consent_records WHERE user_id = ? ORDER BY consented_at DESC LIMIT 1`,
      [req.user.id]
    );

    res.json({
      success: true,
      consentStatus: record ? record.status : 'pending',
      policyVersion: record ? record.policy_version : '1.0.0',
      consentedAt: record ? record.consented_at : null
    });
  } catch (err) {
    next(err);
  }
});

// Update user consent
router.post('/consent', async (req, res, next) => {
  try {
    const { policyVersion = '1.0.0', consentType = 'activity_monitoring_consent', status = 'granted' } = req.body;
    const id = crypto.randomUUID();

    await run(
      `INSERT INTO consent_records (id, user_id, policy_version, consent_type, status, consented_at, revoked_at)
       VALUES (?, ?, ?, ?, ?, datetime('now'), ${status === 'revoked' ? 'datetime("now")' : 'NULL'})`,
      [id, req.user.id, policyVersion, consentType, status]
    );

    await logAudit({
      organizationId: req.user.organization_id,
      actorUserId: req.user.id,
      action: status === 'granted' ? 'CONSENT_GRANTED' : 'CONSENT_REVOKED',
      resourceType: 'consent_record',
      resourceId: id,
      metadata: { policyVersion, consentType }
    });

    res.json({ success: true, status, consentedAt: new Date().toISOString() });
  } catch (err) {
    next(err);
  }
});

// Export personal activity data (GDPR / CCPA DSAR)
router.get('/export', async (req, res, next) => {
  try {
    const format = req.query.format || 'json';

    const userProfile = await get('SELECT id, email, full_name, role, created_at FROM users WHERE id = ?', [req.user.id]);
    const consentHistory = await all('SELECT * FROM consent_records WHERE user_id = ? ORDER BY consented_at DESC', [req.user.id]);
    const activityLogs = await all('SELECT * FROM activity_logs WHERE user_id = ? ORDER BY started_at DESC', [req.user.id]);
    const sessions = await all('SELECT * FROM sessions WHERE user_id = ? ORDER BY started_at DESC', [req.user.id]);
    const typingSessions = await all('SELECT * FROM typing_sessions WHERE user_id = ? ORDER BY updated_at DESC', [req.user.id]);
    const clipboardEntries = await all('SELECT id, device_name, source_app, content_type, is_pinned, created_at FROM clipboard_entries WHERE user_id = ? ORDER BY created_at DESC', [req.user.id]);

    await logAudit({
      organizationId: req.user.organization_id,
      actorUserId: req.user.id,
      action: 'DATA_EXPORT_DOWNLOADED',
      resourceType: 'user_data',
      resourceId: req.user.id,
      metadata: { recordCount: activityLogs.length + typingSessions.length + clipboardEntries.length, format }
    });

    const exportPayload = {
      exportTimestamp: new Date().toISOString(),
      user: userProfile,
      consentHistory,
      sessions,
      activityLogs,
      typingSessions,
      clipboardEntries
    };

    if (format === 'csv') {
      let csv = 'id,appName,category,durationSeconds,idleSeconds,startedAt,endedAt\n';
      for (const log of activityLogs) {
        csv += `"${log.id}","${log.app_name}","${log.app_category}",${log.duration_seconds},${log.idle_seconds},"${log.started_at}","${log.ended_at}"\n`;
      }
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename="look_system_export_${req.user.id}.csv"`);
      return res.send(csv);
    }

    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename="look_system_export_${req.user.id}.json"`);
    res.json(exportPayload);
  } catch (err) {
    next(err);
  }
});

// Delete personal activity data (Right to be Forgotten)
router.post('/delete-my-data', async (req, res, next) => {
  try {
    const deletedActivity = await run('DELETE FROM activity_logs WHERE user_id = ?', [req.user.id]);
    const deletedSessions = await run('DELETE FROM sessions WHERE user_id = ?', [req.user.id]);
    const deletedTyping = await run('DELETE FROM typing_sessions WHERE user_id = ?', [req.user.id]);
    const deletedClipboard = await run('DELETE FROM clipboard_entries WHERE user_id = ?', [req.user.id]);
    const deletedExclusions = await run('DELETE FROM privacy_exclusions WHERE user_id = ?', [req.user.id]);

    await logAudit({
      organizationId: req.user.organization_id,
      actorUserId: req.user.id,
      action: 'USER_EXERCISED_RIGHT_TO_BE_FORGOTTEN',
      resourceType: 'user_data',
      resourceId: req.user.id,
      metadata: {
        deletedActivityCount: deletedActivity.changes,
        deletedSessionsCount: deletedSessions.changes,
        deletedTypingCount: deletedTyping.changes,
        deletedClipboardCount: deletedClipboard.changes,
        deletedExclusionsCount: deletedExclusions.changes
      }
    });

    res.json({
      success: true,
      message: 'All your personal activity and typing records have been permanently erased.',
      deletedActivityCount: deletedActivity.changes,
      deletedSessionsCount: deletedSessions.changes,
      deletedTypingCount: deletedTyping.changes,
      deletedClipboardCount: deletedClipboard.changes,
      deletedExclusionsCount: deletedExclusions.changes
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
