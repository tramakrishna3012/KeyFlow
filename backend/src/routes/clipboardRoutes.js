const express = require('express');
const router = express.Router();
const crypto = require('node:crypto');
const { authenticateToken } = require('../middleware/auth');
const { run, get, all, encryptRecord, decryptRecord } = require('../services/db');

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
// Ingests copied item with automatic content-type classification and encryption
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

    // Encrypt clipboard content for security (may contain passwords, tokens, etc.)
    const encrypted = encryptRecord(content);

    await run(
      `INSERT INTO clipboard_entries (id, user_id, device_name, source_app, content, encrypted_content, iv, auth_tag, content_type, is_pinned, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, userId, deviceName, sourceApp, '[Encrypted Clipboard Data]', encrypted.ciphertext, encrypted.iv, encrypted.authTag, contentType, pinnedInt, nowIso]
    );

    const saved = await get(
      `SELECT id, user_id, device_name, source_app, encrypted_content, iv, auth_tag, content_type, is_pinned, created_at
       FROM clipboard_entries WHERE id = ? AND user_id = ?`,
      [id, userId]
    );

    if (!saved) {
      return res.status(404).json({ error: 'Failed to save clipboard entry' });
    }

    // Decrypt for response
    const decryptedContent = decryptRecord(saved.encrypted_content, saved.iv, saved.auth_tag);

    res.status(201).json({
      success: true,
      entry: {
        id: saved.id,
        user_id: saved.user_id,
        device_name: saved.device_name,
        source_app: saved.source_app,
        content: decryptedContent,
        content_type: saved.content_type,
        is_pinned: Boolean(saved.is_pinned),
        created_at: saved.created_at
      }
    });
  } catch (err) {
    next(err);
  }
});

// ----------------------------------------------------------------------------
// GET /api/v1/clipboard
// List clipboard entries with pinned items first (decrypted)
// ----------------------------------------------------------------------------
router.get('/', authenticateToken, async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { q, contentType, isPinned, limit = 50, offset = 0 } = req.query;

    let query = `SELECT id, user_id, device_name, source_app, encrypted_content, iv, auth_tag, content_type, is_pinned, created_at
                 FROM clipboard_entries WHERE user_id = ?`;
    const params = [userId];

    if (contentType) {
      query += ` AND content_type = ?`;
      params.push(contentType);
    }

    if (isPinned === 'true' || isPinned === '1') {
      query += ` AND is_pinned = 1`;
    }

    query += ` ORDER BY is_pinned DESC, created_at DESC`;

    const rows = await all(query, params);
    
    // Decrypt content for each entry
    let entries = rows.map((r) => {
      const decryptedContent = decryptRecord(r.encrypted_content, r.iv, r.auth_tag);
      return {
        id: r.id,
        user_id: r.user_id,
        device_name: r.device_name,
        source_app: r.source_app,
        content: decryptedContent,
        content_type: r.content_type,
        is_pinned: Boolean(r.is_pinned),
        created_at: r.created_at
      };
    });

    if (q && q.trim()) {
      const term = q.trim().toLowerCase();
      entries = entries.filter((e) => 
        (e.content && e.content.toLowerCase().includes(term)) ||
        (e.source_app && e.source_app.toLowerCase().includes(term))
      );
    }

    const total = entries.length;
    const paginated = entries.slice(parseInt(offset, 10) || 0, (parseInt(offset, 10) || 0) + (parseInt(limit, 10) || 50));

    res.status(200).json({
      success: true,
      total,
      entries: paginated
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
