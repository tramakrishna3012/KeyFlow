const app = require('./app');
const { PORT } = require('./config/env');
const { initDB } = require('./services/db');
const { runRetentionPurgeJob } = require('./services/retentionService');

async function startServer() {
  try {
    await initDB();
    console.log('[Look System DB] Database tables & indices initialized.');

    // Schedule daily retention purge
    setInterval(async () => {
      try {
        console.log('[Look Retention Worker] Running automated retention purge...');
        const results = await runRetentionPurgeJob();
        console.log('[Look Retention Worker] Purge complete:', results);
      } catch (err) {
        console.error('[Look Retention Worker Error]', err);
      }
    }, 24 * 60 * 60 * 1000);

    const port = Number(PORT) || 4000;
    app.listen(port, '0.0.0.0', () => {
      console.log(`[Look System API] Server running on port ${port} (0.0.0.0)`);
    });
  } catch (err) {
    console.error('[Look System Startup Error]', err);
    process.exit(1);
  }
}

if (require.main === module) {
  startServer();
}

module.exports = { startServer };
