const express = require('express');
const router = express.Router();
const crypto = require('node:crypto');
const { authenticateToken } = require('../middleware/auth');
const {
  registerOrGetDevice,
  startSession,
  pauseSession,
  resumeSession,
  stopSession,
  listSessions,
  getSessionTree,
  ingestBatchActivity,
  searchActivityRecords,
  getTypingHistory,
  getActivitySummary
} = require('../services/activityService');
const { run, all } = require('../services/db');

// Ingest telemetry batch from desktop agent (offline queue or live sync)
router.post('/batch', authenticateToken, async (req, res, next) => {
  try {
    const { deviceName, osInfo, agentVersion, sessionId, entries } = req.body;

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
      sessionId,
      entries
    });

    res.status(200).json({
      success: true,
      deviceId,
      sessionId: result.sessionId,
      ingestedCount: result.ingestedCount
    });
  } catch (err) {
    next(err);
  }
});

// Search and filter across permitted stored records
router.get('/search', authenticateToken, async (req, res, next) => {
  try {
    const { q, appName, startDate, endDate, sessionId, limit } = req.query;
    const results = await searchActivityRecords({
      userId: req.user.id,
      query: q,
      appName,
      startDate,
      endDate,
      sessionId,
      limit: limit ? Number.parseInt(limit, 10) : 50
    });

    res.json({ success: true, count: results.length, results });
  } catch (err) {
    next(err);
  }
});

// Cross-device typing history retrieval (decrypted permitted records)
router.get('/typing-history', authenticateToken, async (req, res, next) => {
  try {
    const { q, appName, startDate, endDate, limit, offset } = req.query;
    const history = await getTypingHistory({
      userId: req.user.id,
      q,
      appName,
      startDate,
      endDate,
      limit: limit ? Number.parseInt(limit, 10) : 50,
      offset: offset ? Number.parseInt(offset, 10) : 0
    });

    res.json({ success: true, count: history.length, history });
  } catch (err) {
    next(err);
  }
});

// Activity Summary & Analytics
router.get('/summary', authenticateToken, async (req, res, next) => {
  try {
    const { startDate, endDate, targetUserId } = req.query;

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

// Session Lifecycle Routes
router.post('/sessions/start', authenticateToken, async (req, res, next) => {
  try {
    const { deviceName, deviceId } = req.body;
    const session = await startSession({
      userId: req.user.id,
      deviceId,
      deviceName
    });
    res.status(201).json({ success: true, ...session });
  } catch (err) {
    next(err);
  }
});

router.post('/sessions/pause', authenticateToken, async (req, res, next) => {
  try {
    const { sessionId } = req.body;
    if (!sessionId) return res.status(400).json({ error: 'sessionId required' });

    const result = await pauseSession({ sessionId, userId: req.user.id });
    res.json({ success: true, ...result });
  } catch (err) {
    next(err);
  }
});

router.post('/sessions/resume', authenticateToken, async (req, res, next) => {
  try {
    const { sessionId } = req.body;
    if (!sessionId) return res.status(400).json({ error: 'sessionId required' });

    const result = await resumeSession({ sessionId, userId: req.user.id });
    res.json({ success: true, ...result });
  } catch (err) {
    next(err);
  }
});

router.post('/sessions/stop', authenticateToken, async (req, res, next) => {
  try {
    const { sessionId } = req.body;
    if (!sessionId) return res.status(400).json({ error: 'sessionId required' });

    const result = await stopSession({ sessionId, userId: req.user.id });
    res.json({ success: true, ...result });
  } catch (err) {
    next(err);
  }
});

router.get('/sessions', authenticateToken, async (req, res, next) => {
  try {
    const { limit, offset, status, startDate, endDate } = req.query;
    const sessions = await listSessions({
      userId: req.user.id,
      limit: limit ? Number.parseInt(limit, 10) : 20,
      offset: offset ? Number.parseInt(offset, 10) : 0,
      status,
      startDate,
      endDate
    });
    res.json({ success: true, count: sessions.length, sessions });
  } catch (err) {
    next(err);
  }
});

router.get('/sessions/:id', authenticateToken, async (req, res, next) => {
  try {
    const sessionTree = await getSessionTree({
      sessionId: req.params.id,
      userId: req.user.id
    });
    if (!sessionTree) {
      return res.status(404).json({ error: 'Session not found' });
    }
    res.json({ success: true, ...sessionTree });
  } catch (err) {
    next(err);
  }
});

// Privacy Exclusions Configuration
router.get('/privacy/exclusions', authenticateToken, async (req, res, next) => {
  try {
    const exclusions = await all(
      'SELECT id, excluded_app_name as appName, excluded_field_type as fieldType, is_active as isActive, created_at as createdAt FROM privacy_exclusions WHERE user_id = ?',
      [req.user.id]
    );
    res.json({ success: true, exclusions });
  } catch (err) {
    next(err);
  }
});

router.post('/privacy/exclusions', authenticateToken, async (req, res, next) => {
  try {
    const { appName, fieldType } = req.body;
    if (!appName && !fieldType) {
      return res.status(400).json({ error: 'appName or fieldType required' });
    }
    const id = crypto.randomUUID();
    await run(
      `INSERT INTO privacy_exclusions (id, user_id, excluded_app_name, excluded_field_type, is_active, created_at)
       VALUES (?, ?, ?, ?, 1, datetime('now'))`,
      [id, req.user.id, appName || null, fieldType || null]
    );
    res.status(201).json({ success: true, id, appName, fieldType });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
