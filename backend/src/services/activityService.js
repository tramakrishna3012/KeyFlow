const crypto = require('node:crypto');
const { run, get, all } = require('./db');

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

function inferCategory(appName = '', windowTitle = '') {
  const cleanApp = appName.toLowerCase();
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

async function ingestBatchActivity({ userId, deviceId, entries }) {
  if (!Array.isArray(entries) || entries.length === 0) {
    return { ingestedCount: 0 };
  }

  let count = 0;
  for (const entry of entries) {
    const {
      appName,
      windowTitle,
      durationSeconds = 0,
      idleSeconds = 0,
      isIdle = false,
      startedAt,
      endedAt
    } = entry;

    if (!appName || !startedAt || !endedAt) continue;

    const id = crypto.randomUUID();
    const category = inferCategory(appName, windowTitle);
    const sanitizedTitle = sanitizeWindowTitle(windowTitle);

    await run(
      `INSERT INTO activity_logs (id, user_id, device_id, app_name, app_category, window_title_sanitized, duration_seconds, idle_seconds, is_idle, started_at, ended_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))`,
      [
        id,
        userId,
        deviceId,
        appName,
        category,
        sanitizedTitle,
        Math.max(0, Number.parseInt(durationSeconds, 10) || 0),
        Math.max(0, Number.parseInt(idleSeconds, 10) || 0),
        isIdle ? 1 : 0,
        startedAt,
        endedAt
      ]
    );
    count++;
  }

  return { ingestedCount: count };
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

module.exports = {
  inferCategory,
  sanitizeWindowTitle,
  registerOrGetDevice,
  ingestBatchActivity,
  getActivitySummary
};
