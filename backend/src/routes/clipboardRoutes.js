const express = require('express');
const router = express.Router();
const crypto = require('node:crypto');
const { authenticateToken } = require('../middleware/auth');
const { run, get, all } = require('../services/db');

function classifyContentType(content) {
  if (!content || !content.trim()) return 'text';
  const trimmed = content.trim();

  const urlPattern = /^(https?:\/\/|ftp:\/\/|www\.)[^\s/$.?#].[^\s]*$/i;
  if (urlPattern.test(trimmed)) {
    return 'url';
  }

  const codeIndicators = [
    /\b(const|let|var|function|return|import|export|class|interface|type|async|await)\b/g,
    /\b(def|class|lambda|import|from|elif|print)\b/g,
    /\b(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE|JOIN|CREATE|DROP|ALTER)\b/gi,
    /\b(public|private|protected|void|static|final|struct|impl|fn)\b/g,
    /[{}();=>]{2,}/g,
    /^<(!DOCTYPE|html|div|span|p|a|ul|li|template|script|style)[\s>]/i,
    /^[a-zA-Z0-9_-]+\s*:\s*[a-zA-Z0-9#_-]+;$/,
    /{\s*"\w+"\s*:/
  ];

  let matchCount = 0;
  for (const regex of codeIndicators) {
    const matches = trimmed.match(regex);
    if (matches) {
      matchCount += matches.length;
    }
  }

  if (matchCount >= 2 || (trimmed.includes('\n') && matchCount >= 1)) {
    return 'code';
  }

  return 'text';
}

// ----------------------------------------------------------------------------
// POST /api/v1/clipboard/insert
// Ingests copied item with automatic content-type classification
// ----------------------------------------------------------------------------
router.post('/insert', authenticateToken, async (req, res, next) => {
  try {
    const userId = req.user.id;
    let { id, deviceName, sourceApp, content, contentType, isPinned } = req.body;

    if (!content || typeof content !== 'string' || !content.trim()) {
      return res.status(400).json({ error: 'Valid content string is required' });
    }

    id = id || crypto.randomUUID();
    deviceName = deviceName || 'Desktop';
    sourceApp = sourceApp || 'System Clipboard';
    contentType = contentType || classifyContentType(content);
    const pinnedInt = isPinned ? 1 : 0;
    const nowIso = new Date().toISOString();

    await run(
      `INSERT INTO clipboard_entries (id, user_id, device_name, source_app, content, content_type, is_pinned, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, userId, deviceName, sourceApp, content, contentType, pinnedInt, nowIso]
    );

    const saved = await get(
      `SELECT id, user_id, device_name, source_app, content, content_type, is_pinned, created_at
       FROM clipboard_entries WHERE id = ?`,
      [id]
    );

    res.status(201).json({
      success: true,
      entry: {
        ...saved,
        is_pinned: Boolean(saved.is_pinned)
      }
    });
  } catch (err) {
    next(err);
  }
});

// ----------------------------------------------------------------------------
// GET /api/v1/clipboard
// List clipboard entries with pinned items first
// ----------------------------------------------------------------------------
router.get('/', authenticateToken, async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { q, contentType, isPinned, limit = 50, offset = 0 } = req.query;

    let query = `SELECT id, user_id, device_name, source_app, content, content_type, is_pinned, created_at
                 FROM clipboard_entries WHERE user_id = ?`;
    const params = [userId];

    if (contentType) {
      query += ` AND content_type = ?`;
      params.push(contentType);
    }

    if (isPinned === 'true' || isPinned === '1') {
      query += ` AND is_pinned = 1`;
    }

    if (q && q.trim()) {
      query += ` AND (content LIKE ? OR source_app LIKE ?)`;
      const term = `%${q.trim()}%`;
      params.push(term, term);
    }

    query += ` ORDER BY is_pinned DESC, created_at DESC LIMIT ? OFFSET ?`;
    params.push(parseInt(limit, 10) || 50, parseInt(offset, 10) || 0);

    const rows = await all(query, params);
    const entries = rows.map((r) => ({
      ...r,
      is_pinned: Boolean(r.is_pinned)
    }));

    const countRow = await get(
      `SELECT COUNT(*) as total FROM clipboard_entries WHERE user_id = ?`,
      [userId]
    );

    res.status(200).json({
      success: true,
      total: countRow ? countRow.total : 0,
      entries
    });
  } catch (err) {
    next(err);
  }
});

// ----------------------------------------------------------------------------
// PATCH /api/v1/clipboard/:id/pin
// Toggle pinned status
// ----------------------------------------------------------------------------
router.patch('/:id/pin', authenticateToken, async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const existing = await get(
      `SELECT id, is_pinned FROM clipboard_entries WHERE id = ? AND user_id = ?`,
      [id, userId]
    );

    if (!existing) {
      return res.status(404).json({ error: 'Clipboard entry not found' });
    }

    const newPin = existing.is_pinned ? 0 : 1;
    await run(
      `UPDATE clipboard_entries SET is_pinned = ? WHERE id = ? AND user_id = ?`,
      [newPin, id, userId]
    );

    res.status(200).json({
      success: true,
      id,
      is_pinned: Boolean(newPin)
    });
  } catch (err) {
    next(err);
  }
});

// ----------------------------------------------------------------------------
// DELETE /api/v1/clipboard/:id
// Delete clipboard entry
// ----------------------------------------------------------------------------
router.delete('/:id', authenticateToken, async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const result = await run(
      `DELETE FROM clipboard_entries WHERE id = ? AND user_id = ?`,
      [id, userId]
    );

    if (result.changes === 0) {
      return res.status(404).json({ error: 'Clipboard entry not found' });
    }

    res.status(200).json({ success: true, id });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
