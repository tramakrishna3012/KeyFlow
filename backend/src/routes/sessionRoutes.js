const express = require('express');
const router = express.Router();
const crypto = require('node:crypto');
const { authenticateToken } = require('../middleware/auth');
const { run, get, all, encryptRecord, decryptRecord } = require('../services/db');
const { isSensitiveFieldOrText } = require('../services/activityService');

router.put('/manual/:id', authenticateToken, async (req, res, next) => {
  try {
    const { id } = req.params;
    const { content, capturedAt, platform } = req.body || {};
    const timestamp = typeof capturedAt === 'string' ? Date.parse(capturedAt) : NaN;
    if (!/^[\da-f]{8}(?:-[\da-f]{4}){3}-[\da-f]{12}$/i.test(id) ||
        typeof content !== 'string' || !content.trim() ||
        typeof platform !== 'string' || !/^[a-z]+$/i.test(platform) ||
        !Number.isFinite(timestamp)) {
      return res.status(400).json({ error: 'Valid snippet text and metadata are required' });
    }
    if (isSensitiveFieldOrText('Manual entry', content)) {
      return res.status(422).json({ error: 'Remove credentials or payment details before syncing' });
    }

    const encrypted = encryptRecord(content);
    const result = await run(
      `INSERT INTO manual_typing_snippets (id, user_id, platform, encrypted_content, iv, auth_tag, captured_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT (id) DO UPDATE SET platform = excluded.platform,
         encrypted_content = excluded.encrypted_content, iv = excluded.iv,
         auth_tag = excluded.auth_tag, captured_at = excluded.captured_at
       WHERE manual_typing_snippets.user_id = excluded.user_id`,
      [id, req.user.id, platform, encrypted.ciphertext, encrypted.iv, encrypted.authTag,
        new Date(timestamp).toISOString()]
    );
    if (result.changes !== 1) {
      return res.status(404).json({ error: 'Snippet not found' });
    }
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

router.get('/manual', authenticateToken, async (req, res, next) => {
  try {
    const limit = Number.parseInt(req.query.limit, 10);
    const offset = Number.parseInt(req.query.offset, 10);
    if (!Number.isSafeInteger(offset) && req.query.offset !== undefined) {
      return res.status(400).json({ error: 'Invalid offset' });
    }
    const rows = await all(
      `SELECT id, platform, encrypted_content, iv, auth_tag, captured_at
       FROM manual_typing_snippets WHERE user_id = ?
       ORDER BY captured_at DESC, id LIMIT ? OFFSET ?`,
      [req.user.id, limit > 0 ? Math.min(limit, 200) : 50, offset > 0 ? offset : 0]
    );
    const snippets = rows.map((row) => ({
      id: row.id,
      platform: row.platform,
      capturedAt: row.captured_at,
      content: decryptRecord(row.encrypted_content, row.iv, row.auth_tag)
    }));
    res.set('Cache-Control', 'no-store').json({ snippets });
  } catch (err) {
    next(err);
  }
});

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
       FROM typing_sessions WHERE id = ? AND user_id = ?`,
      [id, userId]
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
