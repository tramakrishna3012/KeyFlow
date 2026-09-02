const { db, all, run } = require('./db');

/**
 * Database migration system for KeyFlow
 * Handles schema updates and data migrations safely
 */

async function runMigrations() {
  console.log('[Migrations] Checking for pending migrations...');

  // Create migrations tracking table
  await run(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      migration_name TEXT UNIQUE NOT NULL,
      applied_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  // Migration 1: Add encryption columns to clipboard_entries
  await runMigration('add_clipboard_encryption', async () => {
    console.log('[Migration] Adding encryption columns to clipboard_entries...');
    
    // Check if columns already exist
    const tableInfo = await all(`PRAGMA table_info(clipboard_entries);`);
    const hasEncryptedContent = tableInfo.some(col => col.name === 'encrypted_content');
    
    if (!hasEncryptedContent) {
      await run(`ALTER TABLE clipboard_entries ADD COLUMN encrypted_content TEXT;`);
      await run(`ALTER TABLE clipboard_entries ADD COLUMN iv TEXT;`);
      await run(`ALTER TABLE clipboard_entries ADD COLUMN auth_tag TEXT;`);
      console.log('[Migration] Encryption columns added successfully');
    } else {
      console.log('[Migration] Encryption columns already exist, skipping');
    }
  });

  console.log('[Migrations] All migrations completed');
}

async function runMigration(name, migrationFunc) {
  const existing = await new Promise((resolve, reject) => {
    db.get('SELECT * FROM schema_migrations WHERE migration_name = ?', [name], (err, row) => {
      if (err) return reject(err);
      resolve(row);
    });
  });

  if (existing) {
    console.log(`[Migration] ${name} already applied, skipping`);
    return;
  }

  try {
    await migrationFunc();
    await run('INSERT INTO schema_migrations (migration_name) VALUES (?)', [name]);
    console.log(`[Migration] ${name} completed successfully`);
  } catch (err) {
    console.error(`[Migration Error] ${name} failed:`, err);
    throw err;
  }
}

module.exports = {
  runMigrations
};
