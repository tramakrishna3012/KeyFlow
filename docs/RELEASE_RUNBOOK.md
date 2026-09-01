# KeyFlow — Release, Code Signing & Deployment Runbook

**Document Version:** 2.0  
**Target Platform Matrix:** Android (API 26–35), Cloudflare Workers (Web), Express (Node.js backend), Windows (x64)  
**CI/CD Workflows:** `.github/workflows/ci.yml`, `.github/workflows/release-android.yml`  

---

## 1. Release Gate Prerequisites

Before building a release distribution candidate:

1. **Automated Test Suite Gate**:
   - Flutter App: `flutter test` → **108 / 108 tests passing**.
   - Backend API: `npm test` → **8 / 8 tests passing**.
2. **Static Analysis & Formatting**:
   - `flutter analyze` → **0 issues found**.
   - `dart format --set-exit-if-changed .` → **0 unformatted files**.
3. **SonarCloud Quality Gate**:
   - Security Rating: **A** (0 vulnerabilities).
   - Reliability: **A** (0 bugs).
   - Duplication: **< 3.0%**.
4. **Video Recording Integrity**:
   - Demos cleanly finalized via `pkill -2 screenrecord` with valid MP4 `moov` atom headers.

---

## 2. Platform Build Instructions

### 📱 Android Release APK & AAB
```bash
# 1. Navigate to app directory
cd app

# 2. Build production signed APK
flutter build apk --release

# 3. Output artifact location:
# app/build/app/outputs/flutter-apk/app-release.apk

# 4. Sideload onto test device via ADB
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### 🌐 Cloudflare Workers Web Dashboard
```bash
# 1. Navigate to web directory
cd web

# 2. Deploy static SPA to Cloudflare Workers
npx wrangler deploy

# 3. Verify deployment at:
# https://keyflow.tramakrishna3012.workers.dev
```

### 🖥️ Express Telemetry Backend (Render / Docker)
```bash
# 1. Build backend container image
docker build -f Dockerfile.backend -t keyflow-backend:latest .

# 2. Run container locally or deploy to Render
docker run -d -p 4000:4000 --env-file backend/.env keyflow-backend:latest
```

---

## 3. Automated GitHub Actions Workflows

- **`.github/workflows/ci.yml`**: Automatically runs on every push and pull request to `main`. Executes `dart format`, `flutter analyze`, `flutter test`, `backend test`, and uploads coverage to SonarCloud.
- **`.github/workflows/release-android.yml`**: Automatically triggers on tag push (`v*`). Builds signed production APKs and attaches release binaries to GitHub Releases.
