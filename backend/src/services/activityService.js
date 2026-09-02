const crypto = require('node:crypto');
const { run, get, all, encryptRecord, decryptRecord } = require('./db');

const CATEGORY_MAP = {
  // Development
  'code': 'Development',
  'vscode': 'Development',
  'visual studio': 'Development',
  'android studio': 'Development',
  'xcode': 'Development',
  'cursor': 'Development',
  'terminal': 'Development',
  'powershell': 'Development',
  'cmd': 'Development',
  'git': 'Development',
  'github desktop': 'Development',
  'intellij': 'Development',
  'pycharm': 'Development',
  'postman': 'Development',

  // Communication
  'slack': 'Communication',
  'teams': 'Communication',
  'microsoft teams': 'Communication',
  'discord': 'Communication',
  'zoom': 'Communication',
  'telegram': 'Communication',
  'whatsapp': 'Communication',
  'outlook': 'Communication',
  'thunderbird': 'Communication',
  'mail': 'Communication',

  // Productivity & Office
  'excel': 'Productivity',
  'word': 'Productivity',
  'powerpoint': 'Productivity',
  'notion': 'Productivity',
  'obsidian': 'Productivity',
  'linear': 'Productivity',
  'jira': 'Productivity',
  'google docs': 'Productivity',
  'google sheets': 'Productivity',
  'trello': 'Productivity',

  // Design
  'figma': 'Design',
  'photoshop': 'Design',
  'illustrator': 'Design',
  'blender': 'Design',
  'canva': 'Design',

  // Browsers
  'chrome': 'Browsing',
  'msedge': 'Browsing',
  'edge': 'Browsing',
  'firefox': 'Browsing',
  'safari': 'Browsing',
  'brave': 'Browsing'
};

// Sensitive patterns: credit cards, SSN, passwords, auth secrets
const SENSITIVE_PATTERNS = [
  /\b\d{4}[ -]?\d{4}[ -]?\d{4}[ -]?\d{1,4}\b/g, // Credit card numbers
  /\b\d{3}-\d{2}-\d{4}\b/g, // SSN
  /\b(?:cvv|cvc|exp|pin|otp|passcode|token|bearer|secret)\s*[:=]\s*[^\s,;]+/gi,
];

// Banking & payment app identifiers where text capture is automatically excluded
const PAYMENT_BANKING_APPS = [
  'paytm', 'gpay', 'phonepe', 'banking', 'paypal', 'wallet', 'venmo', 'chase',
  'wellsfargo', 'bank', 'cred', 'bhim', 'mobikwik', 'freecharge'
];

function isSensitiveFieldOrText(appName = '', text = '') {
  if (!text) return false;
  const cleanApp = String(appName || '').toLowerCase();

  // Calculator and utility apps never contain financial secrets
  if (cleanApp.includes('calculator') || cleanApp.includes('calc')) {
    return false;
  }

  // Check if app is an explicit banking/payment app
  for (const pApp of PAYMENT_BANKING_APPS) {
    if (cleanApp.includes(pApp)) return true;
  }

  for (const pattern of SENSITIVE_PATTERNS) {
    if (pattern.test(text)) return true;
  }
  return false;
}

function inferCategory(appName = '', windowTitle = '') {
  const cleanApp = (appName || '').toLowerCase();
  for (const [key, category] of Object.entries(CATEGORY_MAP)) {
    if (cleanApp.includes(key)) {
      return category;
    }
  }
  return 'General';
}

function sanitizeWindowTitle(rawTitle = '') {
  if (!rawTitle) return '';
  let sanitized = String(rawTitle).trim();

  // Strip query parameters and potential bearer tokens / URLs with secrets
  sanitized = sanitized.replace(/https?:\/\/[^\s]+/gi, (url) => {
    try {
      const parsed = new URL(url);
      return `${parsed.protocol}//${parsed.hostname}${parsed.pathname}`;
    } catch {
      return '[Web URL]';
    }
  });

  // Strip emails
  sanitized = sanitized.replace(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g, '[Redacted Email]');

  // Strip credit cards & sensitive patterns
  for (const pattern of SENSITIVE_PATTERNS) {
    sanitized = sanitized.replace(pattern, '[Redacted Sensitive]');
  }

  // Strip token-like alphanumeric strings (> 24 hex/b64 chars)
  sanitized = sanitized.replace(/\b[A-Za-z0-9-_]{24,}\b/g, '[Redacted Token]');

  // Limit length
  return sanitized.length > 100 ? sanitized.substring(0, 97) + '...' : sanitized;
}

async function registerOrGetDevice({ userId, deviceName, osInfo, agentVersion }) {
  let device = await get('SELECT id FROM devices WHERE user_id = ? AND device_name = ?', [userId, deviceName]);
  if (!device) {
    const id = crypto.randomUUID();
    await run(
      `INSERT INTO devices (id, user_id, device_name, os_info, agent_version, is_authorized, consent_granted_at, last_sync_at, created_at)
       VALUES (?, ?, ?, ?, ?, 1, datetime('now'), datetime('now'), datetime('now'))`,
      [id, userId, deviceName, osInfo || 'Unknown OS', agentVersion || '1.0.0']
    );
    return id;
  }

  await run('UPDATE devices SET last_sync_at = datetime("now"), agent_version = ? WHERE id = ?', [agentVersion || '1.0.0', device.id]);
  return device.id;
}

async function checkUserExclusions(userId, appName) {
  const exclusions = await all(
    'SELECT excluded_app_name, excluded_field_type FROM privacy_exclusions WHERE user_id = ? AND is_active = 1',
    [userId]
  );
  const cleanApp = (appName || '').toLowerCase();
  for (const item of exclusions) {
    if (item.excluded_app_name && cleanApp.includes(item.excluded_app_name.toLowerCase())) {
      return true;
    }
  }
  return false;
}

async function startSession({ userId, deviceId, deviceName }) {
  const finalDeviceId = deviceId || await registerOrGetDevice({ userId, deviceName: deviceName || 'Default Workstation' });
  const sessionId = crypto.randomUUID();
  await run(
    `INSERT INTO sessions (id, user_id, device_id, started_at, status, created_at)
     VALUES (?, ?, ?, datetime('now'), 'active', datetime('now'))`,
    [sessionId, userId, finalDeviceId]
  );
  return { sessionId, deviceId: finalDeviceId, status: 'active' };
}

async function pauseSession({ sessionId, userId }) {
  await run('UPDATE sessions SET status = "paused" WHERE id = ? AND user_id = ?', [sessionId, userId]);
  return { sessionId, status: 'paused' };
}

async function resumeSession({ sessionId, userId }) {
  await run('UPDATE sessions SET status = "active" WHERE id = ? AND user_id = ?', [sessionId, userId]);
  return { sessionId, status: 'active' };
}

async function stopSession({ sessionId, userId }) {
  const session = await get('SELECT started_at FROM sessions WHERE id = ? AND user_id = ?', [sessionId, userId]);
  if (!session) throw new Error('Session not found');

  const now = new Date();
  const startTime = new Date(session.started_at);
  const durationSec = Math.max(0, Math.round((now.getTime() - startTime.getTime()) / 1000));

  await run(
    `UPDATE sessions 
     SET status = "completed", ended_at = datetime('now'), total_active_seconds = ?
     WHERE id = ? AND user_id = ?`,
    [durationSec, sessionId, userId]
  );

  return { sessionId, status: 'completed', durationSeconds: durationSec };
}

async function listSessions({ userId, limit = 20, offset = 0, status, startDate, endDate }) {
  let query = 'SELECT s.*, d.device_name, d.os_info FROM sessions s JOIN devices d ON s.device_id = d.id WHERE s.user_id = ?';
  const params = [userId];

  if (status) {
    query += ' AND s.status = ?';
    params.push(status);
  }
  if (startDate) {
    query += ' AND s.started_at >= ?';
    params.push(startDate);
  }
  if (endDate) {
    query += ' AND s.started_at <= ?';
    params.push(endDate);
  }

  query += ' ORDER BY s.started_at DESC LIMIT ? OFFSET ?';
  params.push(Number(limit), Number(offset));

  const sessions = await all(query, params);
  return sessions;
}

async function getSessionTree({ sessionId, userId }) {
  const session = await get(
    `SELECT s.*, d.device_name, d.os_info 
     FROM sessions s 
     JOIN devices d ON s.device_id = d.id 
     WHERE s.id = ? AND s.user_id = ?`,
    [sessionId, userId]
  );
  if (!session) return null;

  const apps = await all(
    'SELECT * FROM applications WHERE session_id = ? ORDER BY total_duration_seconds DESC',
    [sessionId]
  );

  for (const app of apps) {
    app.activityTimeline = await all(
      `SELECT id, event_type as eventType, started_at as startedAt, ended_at as endedAt,
              duration_seconds as durationSeconds, is_idle as isIdle, window_title_sanitized as windowTitle
       FROM activity_events
       WHERE application_id = ?
       ORDER BY started_at ASC`,
      [app.id]
    );

    const textRecords = await all(
      `SELECT id, encrypted_content, iv, auth_tag, sanitized_preview, captured_at as capturedAt, is_excluded as isExcluded
       FROM text_records
       WHERE application_id = ?
       ORDER BY captured_at ASC`,
      [app.id]
    );

    app.textRecords = textRecords.map((rec) => {
      const decrypted = rec.isExcluded ? '[Excluded by privacy rule]' : decryptRecord(rec.encrypted_content, rec.iv, rec.auth_tag);
      return {
        id: rec.id,
        capturedAt: rec.capturedAt,
        sanitizedPreview: rec.sanitized_preview,
        content: decrypted,
        isExcluded: Boolean(rec.isExcluded)
      };
    });
  }

  return {
    session,
    applications: apps
  };
}

async function ingestBatchActivity({ userId, deviceId, sessionId, entries }) {
  if (!Array.isArray(entries) || entries.length === 0) {
    return { ingestedCount: 0 };
  }

  // Ensure active session exists or create/reuse
  let activeSessionId = sessionId;
  if (!activeSessionId) {
    const active = await get('SELECT id FROM sessions WHERE user_id = ? AND status = "active" ORDER BY started_at DESC LIMIT 1', [userId]);
    if (active) {
      activeSessionId = active.id;
    } else {
      const created = await startSession({ userId, deviceId });
      activeSessionId = created.sessionId;
    }
  }

  let count = 0;
  for (const entry of entries) {
    const {
      id: clientEventId,
      appName,
      windowTitle,
      textRecord,
      textRecords,
      durationSeconds = 0,
      idleSeconds = 0,
      isIdle = false,
      startedAt = new Date().toISOString(),
      endedAt = new Date().toISOString()
    } = entry;

    if (!appName) continue;

    // Deduplication check if client passed UUID
    if (clientEventId) {
      const existing = await get('SELECT id FROM activity_events WHERE id = ?', [clientEventId]);
      if (existing) continue;
    }

    const isExcluded = await checkUserExclusions(userId, appName);
    const category = inferCategory(appName, windowTitle);
    const sanitizedTitle = sanitizeWindowTitle(windowTitle);

    // Get or create application node under session
    let appRecord = await get(
      'SELECT id, total_duration_seconds FROM applications WHERE session_id = ? AND app_name = ?',
      [activeSessionId, appName]
    );

    let appId;
    if (!appRecord) {
      appId = crypto.randomUUID();
      await run(
        `INSERT INTO applications (id, session_id, app_name, app_category, total_duration_seconds, created_at)
         VALUES (?, ?, ?, ?, ?, datetime('now'))`,
        [appId, activeSessionId, appName, category, Math.max(0, Number(durationSeconds) || 0)]
      );
    } else {
      appId = appRecord.id;
      await run(
        'UPDATE applications SET total_duration_seconds = total_duration_seconds + ? WHERE id = ?',
        [Math.max(0, Number(durationSeconds) || 0), appId]
      );
    }

    // Insert activity event
    const eventId = clientEventId || crypto.randomUUID();
    await run(
      `INSERT INTO activity_events (id, session_id, application_id, event_type, started_at, ended_at, duration_seconds, is_idle, window_title_sanitized, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))`,
      [
        eventId,
        activeSessionId,
        appId,
        isIdle ? 'idle' : 'active',
        startedAt,
        endedAt,
        Math.max(0, Number(durationSeconds) || 0),
        isIdle ? 1 : 0,
        sanitizedTitle
      ]
    );

    // Extract text strings to record
    const textsToProcess = [];
    if (typeof textRecord === 'string' && textRecord.trim().length > 0) {
      textsToProcess.push(textRecord);
    } else if (textRecord && typeof textRecord === 'object' && textRecord.content) {
      textsToProcess.push(String(textRecord.content));
    }
    if (Array.isArray(textRecords)) {
      for (const tr of textRecords) {
        if (typeof tr === 'string' && tr.trim().length > 0) {
          textsToProcess.push(tr);
        } else if (tr && typeof tr === 'object' && (tr.text || tr.content)) {
          textsToProcess.push(String(tr.text || tr.content));
        }
      }
    }

    // If text records are included and not excluded/sensitive, encrypt at rest
    for (const rawText of textsToProcess) {
      const isSensitive = isSensitiveFieldOrText(appName, rawText);
      const markExcluded = isExcluded || isSensitive;
      const sanitizedPreview = markExcluded ? '[Redacted Privacy Record]' : sanitizeWindowTitle(rawText.substring(0, 60));
      const encrypted = encryptRecord(markExcluded ? '[Redacted Content]' : rawText);

      await run(
        `INSERT INTO text_records (id, session_id, application_id, encrypted_content, iv, auth_tag, sanitized_preview, captured_at, is_excluded, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))`,
        [
          crypto.randomUUID(),
          activeSessionId,
          appId,
          encrypted.ciphertext,
          encrypted.iv,
          encrypted.authTag,
          sanitizedPreview,
          startedAt,
          markExcluded ? 1 : 0
        ]
      );
    }

    // Also populate legacy activity_logs for backward compatibility
    await run(
      `INSERT INTO activity_logs (id, user_id, device_id, app_name, app_category, window_title_sanitized, duration_seconds, idle_seconds, is_idle, started_at, ended_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))`,
      [
        crypto.randomUUID(),
        userId,
        deviceId,
        appName,
        category,
        sanitizedTitle,
        Math.max(0, Number(durationSeconds) || 0),
        Math.max(0, Number(idleSeconds) || 0),
        isIdle ? 1 : 0,
        startedAt,
        endedAt
      ]
    );

    count++;
  }

  return { ingestedCount: count, sessionId: activeSessionId };
}

async function searchActivityRecords({ userId, query, appName, startDate, endDate, sessionId, limit = 50 }) {
  let sql = `
    SELECT 
      ae.id,
      ae.session_id as sessionId,
      s.started_at as sessionDate,
      d.device_name as deviceName,
      a.app_name as appName,
      a.app_category as category,
      ae.window_title_sanitized as windowTitle,
      ae.duration_seconds as durationSeconds,
      ae.started_at as timestamp,
      tr.sanitized_preview as textPreview,
      tr.is_excluded as isExcluded
    FROM activity_events ae
    JOIN sessions s ON ae.session_id = s.id
    JOIN devices d ON s.device_id = d.id
    JOIN applications a ON ae.application_id = a.id
    LEFT JOIN text_records tr ON tr.application_id = a.id AND tr.session_id = s.id
    WHERE s.user_id = ?
  `;
  const params = [userId];

  if (sessionId) {
    sql += ' AND s.id = ?';
    params.push(sessionId);
  }
  if (appName) {
    sql += ' AND a.app_name LIKE ?';
    params.push(`%${appName}%`);
  }
  if (startDate) {
    sql += ' AND ae.started_at >= ?';
    params.push(startDate);
  }
  if (endDate) {
    sql += ' AND ae.started_at <= ?';
    params.push(endDate);
  }
  if (query) {
    sql += ' AND (a.app_name LIKE ? OR ae.window_title_sanitized LIKE ? OR tr.sanitized_preview LIKE ?)';
    params.push(`%${query}%`, `%${query}%`, `%${query}%`);
  }

  sql += ' ORDER BY ae.started_at DESC LIMIT ?';
  params.push(Number(limit));

  const results = await all(sql, params);
  return results;
}

async function getActivitySummary({ userId, startDate, endDate }) {
  let dateFilter = '';
  const params = [userId];

  if (startDate) {
    dateFilter += ' AND started_at >= ?';
    params.push(startDate);
  }
  if (endDate) {
    dateFilter += ' AND started_at <= ?';
    params.push(endDate);
  }

  const totals = await get(
    `SELECT 
       COALESCE(SUM(duration_seconds), 0) as totalDuration,
       COALESCE(SUM(idle_seconds), 0) as totalIdle,
       COALESCE(COUNT(DISTINCT app_name), 0) as uniqueApps,
       COUNT(*) as logCount
     FROM activity_logs 
     WHERE user_id = ? ${dateFilter}`,
    params
  );

  const totalActive = Math.max(0, (totals.totalDuration || 0) - (totals.totalIdle || 0));
  const productivityScore = totals.totalDuration > 0
    ? Math.min(100, Math.round((totalActive / totals.totalDuration) * 100))
    : 100;

  // Category breakdown
  const categories = await all(
    `SELECT app_category as category, SUM(duration_seconds) as duration, COUNT(*) as sessions
     FROM activity_logs
     WHERE user_id = ? ${dateFilter}
     GROUP BY app_category
     ORDER BY duration DESC`,
    params
  );

  // Top applications
  const topApps = await all(
    `SELECT app_name as appName, app_category as category, SUM(duration_seconds) as duration, SUM(idle_seconds) as idle
     FROM activity_logs
     WHERE user_id = ? ${dateFilter}
     GROUP BY app_name, app_category
     ORDER BY duration DESC
     LIMIT 10`,
    params
  );

  // Recent timeline logs
  const recentLogs = await all(
    `SELECT id, app_name as appName, app_category as category, window_title_sanitized as windowTitle,
            duration_seconds as durationSeconds, idle_seconds as idleSeconds, is_idle as isIdle,
            started_at as startedAt, ended_at as endedAt
     FROM activity_logs
     WHERE user_id = ? ${dateFilter}
     ORDER BY started_at DESC
     LIMIT 50`,
    params
  );

  return {
    metrics: {
      totalDurationSeconds: totals.totalDuration,
      totalActiveSeconds: totalActive,
      totalIdleSeconds: totals.totalIdle,
      uniqueApps: totals.uniqueApps,
      logCount: totals.logCount,
      productivityScore
    },
    categories,
    topApps,
    recentLogs
  };
}

async function getTypingHistory({ userId, limit = 50, offset = 0, appName, startDate, endDate, q }) {
  let sql = `
    SELECT tr.id, tr.encrypted_content, tr.iv, tr.auth_tag, tr.sanitized_preview, tr.captured_at, tr.is_excluded,
           a.app_name, a.app_category,
           s.id as session_id, s.started_at as session_started_at,
           d.device_name, d.os_info
    FROM text_records tr
    JOIN applications a ON tr.application_id = a.id
    JOIN sessions s ON a.session_id = s.id
    JOIN devices d ON s.device_id = d.id
    WHERE s.user_id = ?
  `;
  const params = [userId];

  if (appName) {
    sql += ' AND a.app_name LIKE ?';
    params.push(`%${appName}%`);
  }
  if (startDate) {
    sql += ' AND tr.captured_at >= ?';
    params.push(startDate);
  }
  if (endDate) {
    sql += ' AND tr.captured_at <= ?';
    params.push(endDate);
  }
  if (q) {
    sql += ' AND (a.app_name LIKE ? OR tr.sanitized_preview LIKE ?)';
    params.push(`%${q}%`, `%${q}%`);
  }

  sql += ' ORDER BY tr.captured_at DESC LIMIT ? OFFSET ?';
  params.push(Number(limit), Number(offset));

  const rows = await all(sql, params);

  return rows.map((r) => {
    let decryptedText = '';
    if (r.is_excluded) {
      decryptedText = '[Content Excluded by Privacy Filter]';
    } else {
      try {
        decryptedText = decryptRecord(r.encrypted_content, r.iv, r.auth_tag);
      } catch {
        decryptedText = r.sanitized_preview || '';
      }
    }

    return {
      id: r.id,
      sessionId: r.session_id,
      deviceName: r.device_name,
      osInfo: r.os_info,
      appName: r.app_name,
      appCategory: r.app_category,
      sanitizedPreview: r.sanitized_preview,
      content: decryptedText,
      isExcluded: Boolean(r.is_excluded),
      capturedAt: r.captured_at
    };
  });
}

module.exports = {
  inferCategory,
  sanitizeWindowTitle,
  isSensitiveFieldOrText,
  registerOrGetDevice,
  checkUserExclusions,
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
};
