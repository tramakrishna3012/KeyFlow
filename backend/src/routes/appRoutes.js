const express = require('express');
const router = express.Router();

router.get('/version', (req, res) => {
  res.json({
    latestVersion: '1.0.0',
    versionCode: 6,
    downloadUrl: 'https://github.com/tramakrishna3012/KeyFlow/releases/download/v1.0.0/app-arm64-v8a-release.apk',
    releaseNotes: '• Android R8 full-mode code obfuscation and resource shrinking\n• In-app auto-update via secure FileProvider\n• Unified authentication with KeyFlow Express backend\n• Sensitive input filtering for OTPs and passwords\n• Offline-first encrypted SQLite storage',
    publishedAt: '2026-08-23T23:30:00Z',
    minSupportedVersion: '0.1.0'
  });
});

module.exports = router;
