const express = require('express');
const router = express.Router();
const crypto = require('node:crypto');
const { authenticateToken } = require('../middleware/auth');
const { run, get, all } = require('../services/db');

function calculateWordCount(text) {
  if (!text || !text.trim()) return 0;
  return text.trim().split(/\s+/).filter(Boolean).length;
}

// ----------------------------------------------------------------------------
// POST /api/v1/sessions/upsert
// Upserts an aggregated typing session paragraph
// ----------------------------------------------------------------------------
router.post('/upsert', authenticateToken, async (req, res, next) => {
  try {
    const userId = req.user.id;
    let {
      id,
      deviceName,
      appName,
      windowTitle,
      content,
      startedAt,
      updatedAt,
      isFavorite,
      draftHistory
    } = req.body;

    if (!appName || typeof content !== 'string') {
      return res.status(400).json({ error: 'appName and content string are required' });
    }

    id = id || crypto.randomUUID();
    deviceName = deviceName || 'Desktop';
    windowTitle = windowTitle || '';
    const nowIso = new Date().toISOString();
    startedAt = startedAt || nowIso;
    updatedAt = updatedAt || nowIso;
    const favoriteInt = isFavorite ? 1 : 0;
    const draftJson = Array.isArray(draftHistory) ? JSON.stringify(draftHistory) : (draftHistory || '[]');

    const characterCount = content.length;
    const wordCount = calculateWordCount(content);

    // Check if session already exists
    const existing = await get(
      `SELECT id, user_id FROM typing_sessions WHERE id = ?`,
      [id]
    );

    if (existing) {
      if (existing.user_id !== userId) {
        return res.status(403).json({ error: 'Access denied to this session' });
      }

      await run(
        `UPDATE typing_sessions 
         SET content = ?, character_count = ?, word_count = ?, updated_at = ?, draft_history = ?
         WHERE id = ? AND user_id = ?`,
        [content, characterCount, wordCount, updatedAt, draftJson, id, userId]
      );
    } else {
      await run(
        `INSERT INTO typing_sessions 
         (id, user_id, device_name, app_name, window_title, content, character_count, word_count, started_at, updated_at, is_favorite, draft_history)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [id, userId, deviceName, appName, windowTitle, content, characterCount, wordCount, startedAt, updatedAt, favoriteInt, draftJson]
      );
    }

    const saved = await get(
      `SELECT id, user_id, device_name, app_name, window_title, content, character_count, word_count, started_at, updated_at, is_favorite, draft_history, created_at
       FROM typing_sessions WHERE id = ?`,
      [id]
    );

    res.status(200).json({
      success: true,
      session: {
        ...saved,
        is_favorite: Boolean(saved.is_favorite),
        draft_history: JSON.parse(saved.draft_history || '[]')
      }
    });
  } catch (err) {
    next(err);
  }
});

// ----------------------------------------------------------------------------
// GET /api/v1/sessions
// List aggregated typing sessions with multi-parameter filtering
// ----------------------------------------------------------------------------
router.get('/', authenticateToken, async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { appName, deviceName, q, isFavorite, limit = 50, offset = 0 } = req.query;

    let query = `SELECT id, user_id, device_name, app_name, window_title, content, character_count, word_count, started_at, updated_at, is_favorite, draft_history, created_at
                 FROM typing_sessions WHERE user_id = ?`;
    const params = [userId];

    if (appName) {
      query += ` AND LOWER(app_name) = LOWER(?)`;
      params.push(appName);
    }

    if (deviceName) {
      query += ` AND LOWER(device_name) = LOWER(?)`;
      params.push(deviceName);
    }

    if (isFavorite === 'true' || isFavorite === '1') {
      query += ` AND is_favorite = 1`;
    }

    if (q && q.trim()) {
      query += ` AND (content LIKE ? OR window_title LIKE ? OR app_name LIKE ?)`;
      const term = `%${q.trim()}%`;
      params.push(term, term, term);
    }

    query += ` ORDER BY updated_at DESC LIMIT ? OFFSET ?`;
    params.push(parseInt(limit, 10) || 50, parseInt(offset, 10) || 0);

    const rows = await all(query, params);

    const sessions = rows.map((r) => ({
      ...r,
      is_favorite: Boolean(r.is_favorite),
      draft_history: JSON.parse(r.draft_history || '[]')
    }));

    // Get stats
    const countRow = await get(
      `SELECT COUNT(*) as total, SUM(character_count) as total_chars, SUM(word_count) as total_words 
       FROM typing_sessions WHERE user_id = ?`,
      [userId]
    );

    res.status(200).json({
      success: true,
      total: countRow ? countRow.total : 0,
      total_chars: countRow ? (countRow.total_chars || 0) : 0,
      total_words: countRow ? (countRow.total_words || 0) : 0,
      sessions
    });
  } catch (err) {
    next(err);
  }
});

// ----------------------------------------------------------------------------
// PATCH /api/v1/sessions/:id/favorite
// Toggle favorite status
// ----------------------------------------------------------------------------
router.patch('/:id/favorite', authenticateToken, async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const existing = await get(
      `SELECT id, is_favorite FROM typing_sessions WHERE id = ? AND user_id = ?`,
      [id, userId]
    );

    if (!existing) {
      return res.status(404).json({ error: 'Session not found' });
    }

    const newFav = existing.is_favorite ? 0 : 1;
    await run(
      `UPDATE typing_sessions SET is_favorite = ? WHERE id = ? AND user_id = ?`,
      [newFav, id, userId]
    );

    res.status(200).json({
      success: true,
      id,
      is_favorite: Boolean(newFav)
    });
  } catch (err) {
    next(err);
  }
});

// ----------------------------------------------------------------------------
// DELETE /api/v1/sessions/:id
// Delete a session
// ----------------------------------------------------------------------------
router.delete('/:id', authenticateToken, async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const result = await run(
      `DELETE FROM typing_sessions WHERE id = ? AND user_id = ?`,
      [id, userId]
    );

    if (result.changes === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }

    res.status(200).json({ success: true, id });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
