const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const { authenticateToken } = require('../middleware/auth');
const { registerOrGetDevice, ingestBatchActivity, getActivitySummary } = require('../services/activityService');
const { run, get, all } = require('../services/db');

// Ingest telemetry batch from desktop agent
router.post('/batch', authenticateToken, async (req, res, next) => {
  try {
    const { deviceName, osInfo, agentVersion, entries } = req.body;

    if (!deviceName || !Array.isArray(entries)) {
      return res.status(400).json({ error: 'deviceName and entries array are required' });
    }

    const deviceId = await registerOrGetDevice({
      userId: req.user.id,
      deviceName,
      osInfo,
      agentVersion
    });

    const result = await ingestBatchActivity({
      userId: req.user.id,
      deviceId,
      entries
    });

    res.status(200).json({
      success: true,
      deviceId,
      ingestedCount: result.ingestedCount
    });
  } catch (err) {
    next(err);
  }
});

// Get user activity summary & analytics
router.get('/summary', authenticateToken, async (req, res, next) => {
  try {
    const { startDate, endDate, targetUserId } = req.query;

    // Managers/Admins can view team members; members only see themselves
    let queryUserId = req.user.id;
    if (targetUserId && (req.user.role === 'admin' || req.user.role === 'manager')) {
      queryUserId = targetUserId;
    }

    const summary = await getActivitySummary({
      userId: queryUserId,
      startDate,
      endDate
    });

    res.json({ success: true, ...summary });
  } catch (err) {
    next(err);
  }
});

// Session control endpoints
router.post('/sessions/start', authenticateToken, async (req, res, next) => {
  try {
    const { deviceName } = req.body;
    const deviceId = await registerOrGetDevice({
      userId: req.user.id,
      deviceName: deviceName || 'Default Workstation'
    });

    const sessionId = crypto.randomUUID();
    await run(
      `INSERT INTO sessions (id, user_id, device_id, started_at, status, created_at)
       VALUES (?, ?, ?, datetime('now'), 'active', datetime('now'))`,
      [sessionId, req.user.id, deviceId]
    );

    res.status(201).json({ success: true, sessionId, status: 'active' });
  } catch (err) {
    next(err);
  }
});

router.post('/sessions/pause', authenticateToken, async (req, res, next) => {
  try {
    const { sessionId } = req.body;
    if (!sessionId) return res.status(400).json({ error: 'sessionId required' });

    await run('UPDATE sessions SET status = "paused" WHERE id = ? AND user_id = ?', [sessionId, req.user.id]);
    res.json({ success: true, status: 'paused' });
  } catch (err) {
    next(err);
  }
});

router.post('/sessions/stop', authenticateToken, async (req, res, next) => {
  try {
    const { sessionId } = req.body;
    if (!sessionId) return res.status(400).json({ error: 'sessionId required' });

    await run('UPDATE sessions SET status = "completed", ended_at = datetime("now") WHERE id = ? AND user_id = ?', [sessionId, req.user.id]);
    res.json({ success: true, status: 'completed' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
