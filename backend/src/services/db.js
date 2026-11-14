const { DB_PATH, DATABASE_URL, DATABASE_SSL, JWT_SECRET } = require('../config/env');
const crypto = require('node:crypto');

// ---------------------------------------------------------------------------
// Driver selection
//
// If DATABASE_URL is set (e.g. a Supabase/Neon Postgres connection string),
// the backend talks to real Postgres via `pg`. Otherwise it falls back to a
// local SQLite file — the zero-config default used in dev and in tests.
//
// Every call site in this codebase (routes/*, services/*) only ever uses the
// run/get/all helpers exported below with SQLite-flavored SQL (`?` positional
// placeholders, `datetime('now')`, `PRAGMA table_info`, `INTEGER PRIMARY KEY
// AUTOINCREMENT`). Rather than hand-porting ~2000 lines of SQL spread across
// a dozen files, the Postgres branch below translates that same SQL on the
// fly. This keeps a single source of truth for the SQL and means callers
// never need to know which driver is active.
// ---------------------------------------------------------------------------

const usePostgres = Boolean(DATABASE_URL);

let run;
let get;
let all;
let db;
let closeDb;

if (usePostgres) {
  const { Pool, types } = require('pg');

  // Postgres's SUM()/COUNT() over integer columns returns `bigint`, which `pg` parses as a
  // JS string by default (OID 20) rather than a number, to avoid silent precision loss above
  // 2^53. Every call site in this codebase (durations, counts, byte sizes) stays well within
  // safe-integer range and already treats these as plain numbers (Math.round, arithmetic,
  // comparisons), matching what the SQLite driver has always returned. Parsing bigint as a
  // number here keeps that behavior identical across both drivers instead of special-casing
  // every aggregate query call site.
  types.setTypeParser(20, (value) => parseInt(value, 10));

  const pool = new Pool({
    connectionString: DATABASE_URL,
    ssl: DATABASE_SSL ? { rejectUnauthorized: false } : false
  });

  // Translates the SQLite-flavored SQL used throughout this codebase into
  // Postgres-compatible SQL:
  //   - datetime('now') / datetime("now")      -> keyflow_now()  (defined in initDB)
  //   - INTEGER PRIMARY KEY AUTOINCREMENT       -> SERIAL PRIMARY KEY
  //   - LIKE                                    -> ILIKE  (SQLite's LIKE is case-insensitive
  //                                                by default; Postgres's is not)
  //   - `AS camelCaseAlias`                     -> `AS "camelCaseAlias"`  (Postgres folds
  //                                                unquoted identifiers to lowercase; SQLite
  //                                                preserves them as written. Without this,
  //                                                every camelCase SELECT alias this codebase
  //                                                relies on, e.g. `is_excluded as isExcluded`,
  //                                                comes back as `isexcluded` and silently
  //                                                reads as `undefined` in the JS result row)
  //   - positional `?` placeholders             -> $1, $2, ... (skipping `?` inside
  //                                                single-quoted string literals)
  function translateSql(sql) {
    let text = sql
      .replace(/datetime\(\s*["']now["']\s*\)/gi, 'keyflow_now()')
      .replace(/INTEGER\s+PRIMARY\s+KEY\s+AUTOINCREMENT/gi, 'SERIAL PRIMARY KEY')
      .replace(/\bLIKE\b/gi, 'ILIKE')
      .replace(/\bAS\s+([A-Za-z_][A-Za-z0-9_]*)\b/gi, (match, alias) =>
        /[A-Z]/.test(alias) ? `AS "${alias}"` : match
      );

    let out = '';
    let paramIndex = 0;
    let inString = false;
    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if (ch === "'") {
        inString = !inString;
        out += ch;
        continue;
      }
      if (ch === '?' && !inString) {
        paramIndex += 1;
        out += `$${paramIndex}`;
      } else {
        out += ch;
      }
    }
    return out;
  }

  // `PRAGMA table_info(table)` has no Postgres equivalent; it's only used (in
  // migrations.js) to check whether a column already exists before adding
  // it. Intercepted here and answered from information_schema, returning the
  // same `{ name }` shape the SQLite PRAGMA result rows have.
  const pragmaTableInfoPattern = /^\s*PRAGMA\s+table_info\(\s*["'`]?([A-Za-z0-9_]+)["'`]?\s*\)/i;

  async function pgAll(sql, params = []) {
    const pragmaMatch = sql.match(pragmaTableInfoPattern);
    if (pragmaMatch) {
      const result = await pool.query(
        'SELECT column_name AS name FROM information_schema.columns WHERE table_name = $1',
        [pragmaMatch[1]]
      );
      return result.rows;
    }
    const result = await pool.query(translateSql(sql), params);
    return result.rows;
  }

  run = async (sql, params = []) => {
    const result = await pool.query(translateSql(sql), params);
    return { id: null, changes: result.rowCount };
  };

  get = async (sql, params = []) => {
    const rows = await pgAll(sql, params);
    return rows[0];
  };

  all = pgAll;

  db = pool;
  closeDb = () => pool.end();
} else {
  const sqlite3 = require('sqlite3').verbose();
  const sqliteDb = new sqlite3.Database(DB_PATH);

  run = (sql, params = []) =>
    new Promise((resolve, reject) => {
      sqliteDb.run(sql, params, function (err) {
        if (err) return reject(err);
        resolve({ id: this.lastID, changes: this.changes });
      });
    });

  get = (sql, params = []) =>
    new Promise((resolve, reject) => {
      sqliteDb.get(sql, params, (err, row) => {
        if (err) return reject(err);
        resolve(row);
      });
    });

  all = (sql, params = []) =>
    new Promise((resolve, reject) => {
      sqliteDb.all(sql, params, (err, rows) => {
        if (err) return reject(err);
        resolve(rows);
      });
    });

  db = sqliteDb;
  closeDb = () => new Promise((resolve) => sqliteDb.close(() => resolve()));
}

function getDriverName() {
  return usePostgres ? 'postgres' : 'sqlite';
}

// Lightweight connectivity check for the health endpoint. Never throws.
async function pingDatabase() {
  const startedAt = Date.now();
  try {
    await get('SELECT 1 AS ok');
    return { driver: getDriverName(), connected: true, latencyMs: Date.now() - startedAt };
  } catch (err) {
    return { driver: getDriverName(), connected: false, error: err.message };
  }
}

// AES-256-GCM record-level encryption helpers
const ENCRYPTION_MASTER_KEY = crypto.createHash('sha256').update(JWT_SECRET).digest();

function encryptRecord(plaintext) {
  if (!plaintext) return { ciphertext: '', iv: '', authTag: '' };
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', ENCRYPTION_MASTER_KEY, iv);
  let encrypted = cipher.update(plaintext, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag().toString('hex');
  return {
    ciphertext: encrypted,
    iv: iv.toString('hex'),
    authTag
  };
}

function decryptRecord(ciphertext, ivHex, authTagHex) {
  if (!ciphertext || !ivHex || !authTagHex) return '';
  try {
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    const decipher = crypto.createDecipheriv('aes-256-gcm', ENCRYPTION_MASTER_KEY, iv);
    decipher.setAuthTag(authTag);
    let decrypted = decipher.update(ciphertext, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch {
    return '[Encrypted content unavailable]';
  }
}

async function initDB() {
  if (usePostgres) {
    // Backs the translated `keyflow_now()` calls used as column defaults below,
    // producing the same ISO-8601 shape the rest of the app already expects
    // from `datetime('now')` / `new Date().toISOString()`.
    await run(`
      CREATE OR REPLACE FUNCTION keyflow_now() RETURNS text AS $KEYFLOW$
        SELECT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
      $KEYFLOW$ LANGUAGE SQL;
    `);
  }

  await run(`
    CREATE TABLE IF NOT EXISTS organizations (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      domain TEXT UNIQUE,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      organization_id TEXT REFERENCES organizations(id),
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      full_name TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'member',
      is_active INTEGER NOT NULL DEFAULT 1,
      mfa_enabled INTEGER NOT NULL DEFAULT 0,
      failed_login_attempts INTEGER NOT NULL DEFAULT 0,
      locked_until TEXT,
      last_login_at TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      device_name TEXT NOT NULL,
      os_info TEXT NOT NULL,
      agent_version TEXT NOT NULL,
      is_authorized INTEGER NOT NULL DEFAULT 1,
      consent_granted_at TEXT NOT NULL DEFAULT (datetime('now')),
      last_sync_at TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      device_id TEXT NOT NULL REFERENCES devices(id),
      started_at TEXT NOT NULL,
      ended_at TEXT,
      total_active_seconds INTEGER NOT NULL DEFAULT 0,
      total_idle_seconds INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS applications (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
      app_name TEXT NOT NULL,
      app_category TEXT NOT NULL DEFAULT 'General',
      total_duration_seconds INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS activity_events (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
      application_id TEXT REFERENCES applications(id) ON DELETE CASCADE,
      event_type TEXT NOT NULL DEFAULT 'active',
      started_at TEXT NOT NULL,
      ended_at TEXT NOT NULL,
      duration_seconds INTEGER NOT NULL DEFAULT 0,
      is_idle INTEGER NOT NULL DEFAULT 0,
      window_title_sanitized TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS text_records (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
      application_id TEXT REFERENCES applications(id) ON DELETE CASCADE,
      encrypted_content TEXT NOT NULL,
      iv TEXT NOT NULL,
      auth_tag TEXT NOT NULL,
      sanitized_preview TEXT,
      captured_at TEXT NOT NULL,
      is_excluded INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS privacy_exclusions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      excluded_app_name TEXT,
      excluded_field_type TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS activity_logs (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      device_id TEXT NOT NULL REFERENCES devices(id),
      app_name TEXT NOT NULL,
      app_category TEXT NOT NULL DEFAULT 'General',
      window_title_sanitized TEXT,
      duration_seconds INTEGER NOT NULL,
      idle_seconds INTEGER NOT NULL DEFAULT 0,
      is_idle INTEGER NOT NULL DEFAULT 0,
      started_at TEXT NOT NULL,
      ended_at TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS retention_policies (
      id TEXT PRIMARY KEY,
      organization_id TEXT UNIQUE NOT NULL REFERENCES organizations(id),
      retention_days INTEGER NOT NULL DEFAULT 90,
      auto_purge_enabled INTEGER NOT NULL DEFAULT 1,
      last_purged_at TEXT,
      updated_by TEXT REFERENCES users(id),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS audit_logs (
      id TEXT PRIMARY KEY,
      organization_id TEXT REFERENCES organizations(id),
      actor_user_id TEXT REFERENCES users(id),
      action TEXT NOT NULL,
      resource_type TEXT NOT NULL,
      resource_id TEXT,
      ip_address TEXT,
      user_agent TEXT,
      metadata TEXT DEFAULT '{}',
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS consent_records (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      policy_version TEXT NOT NULL,
      consent_type TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'granted',
      consented_at TEXT NOT NULL DEFAULT (datetime('now')),
      revoked_at TEXT
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS typing_sessions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_name TEXT NOT NULL,
      app_name TEXT NOT NULL,
      window_title TEXT,
      content TEXT NOT NULL,
      character_count INTEGER NOT NULL DEFAULT 0,
      word_count INTEGER NOT NULL DEFAULT 0,
      started_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      draft_history TEXT DEFAULT '[]',
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS manual_typing_snippets (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      platform TEXT NOT NULL,
      encrypted_content TEXT NOT NULL,
      iv TEXT NOT NULL,
      auth_tag TEXT NOT NULL,
      captured_at TEXT NOT NULL
    );
  `);

  if (usePostgres) {
    // The API connection owns this table. Deny direct reads by other roles,
    // including Supabase Data API roles that may receive default table grants.
    await run('ALTER TABLE manual_typing_snippets ENABLE ROW LEVEL SECURITY');
  }

  await run(`
    CREATE TABLE IF NOT EXISTS clipboard_entries (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_name TEXT NOT NULL,
      source_app TEXT,
      content TEXT NOT NULL,
      encrypted_content TEXT,
      iv TEXT,
      auth_tag TEXT,
      content_type TEXT NOT NULL DEFAULT 'text',
      is_pinned INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS pairing_tokens (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token TEXT UNIQUE NOT NULL,
      expires_at TEXT NOT NULL,
      used INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  // Create Indices
  await run(`CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id, started_at);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_applications_session ON applications(session_id, app_name);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_activity_events_session ON activity_events(session_id, application_id);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_text_records_session ON text_records(session_id, application_id);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_privacy_exclusions_user ON privacy_exclusions(user_id);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_activity_logs_user ON activity_logs(user_id, started_at);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_activity_logs_app ON activity_logs(app_name, app_category);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_audit_logs_org ON audit_logs(organization_id, created_at);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_typing_sessions_user ON typing_sessions(user_id, updated_at DESC);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_typing_sessions_app ON typing_sessions(user_id, app_name);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_manual_typing_snippets_user ON manual_typing_snippets(user_id, captured_at DESC, id);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_clipboard_entries_user ON clipboard_entries(user_id, is_pinned DESC, created_at DESC);`);
  await run(`CREATE INDEX IF NOT EXISTS idx_pairing_tokens ON pairing_tokens(token);`);
}

module.exports = {
  db,
  run,
  get,
  all,
  initDB,
  encryptRecord,
  decryptRecord,
  getDriverName,
  pingDatabase,
  closeDb
};
