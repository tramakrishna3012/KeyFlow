# KeyFlow & Look System: 100% Free-Tier Deployment Plan

This document outlines the step-by-step production deployment strategy for KeyFlow and Look System using generous, production-grade **100% free-tier** services.

---

## 1. Free-Tier Architecture Overview

| Component | Recommended Free Provider | Free Tier Limits | Purpose |
| :--- | :--- | :--- | :--- |
| **Backend API** | **[Render.com](https://render.com/)** or **[Fly.io](https://fly.io/)** | 750 free hrs/mo, 512MB RAM | Hosts Node.js Express REST API & WebSockets |
| **Web Dashboard** | **[Cloudflare Pages](https://pages.cloudflare.com/)** or **[Vercel](https://vercel.com/)** | Unlimited bandwidth, 100 custom domains | Global CDN hosting for static HTML/CSS/JS |
| **Encrypted Database** | **[Neon.tech](https://neon.tech/)** / **[Supabase](https://supabase.com/)** / Persistent Volume | 0.5 GB Free Postgres / SQLite volume | Relational storage for sessions & encrypted logs |
| **App Binaries & Releases** | **[GitHub Releases](https://github.com/)** | Unlimited public release asset hosting | Distributes Windows `.exe`, macOS `.dmg`, Linux `.AppImage`, Android `.apk` |

---

## 2. Step 1: Deploy Encrypted Database (Free Tier)

### Option A: Free Serverless PostgreSQL (Recommended: Neon.tech / Supabase)
1. Create a free account on [Neon.tech](https://neon.tech/) or [Supabase.com](https://supabase.com/).
2. Create a new database project named `keyflow-production`.
3. Copy your Postgres connection string:
   ```env
   DATABASE_URL=postgres://user:password@ep-cool-cloud.neon.tech/keyflow_production?sslmode=require
   ```

### Option B: Zero-Config SQLite (Embedded)
If using the bundled SQLite database (`look_system.db`):
* Deploy the backend to a host with persistent disk storage (e.g. **Fly.io** free volume: 3GB free persistent storage).

---

## 3. Step 2: Deploy Backend API to Render (100% Free)

1. Sign up at [Render.com](https://render.com/) using your GitHub account.
2. Click **New +** → **Web Service** → Connect your repository: `tramakrishna3012/KeyFlow`.
3. Configure the service:
   * **Root Directory**: `backend`
   * **Environment**: `Node`
   * **Build Command**: `npm install --omit=dev`
   * **Start Command**: `node src/server.js`
   * **Instance Type**: `Free`
4. Add **Environment Variables** under Settings:
   ```env
   NODE_ENV=production
   PORT=10000
   JWT_SECRET=your_super_secret_32_character_key_here!
   JWT_EXPIRES_IN=24h
   DEFAULT_RETENTION_DAYS=90
   ```
5. Click **Create Web Service**. Your API will be live at:
   `https://keyflow-backend.onrender.com`

---

## 4. Step 3: Deploy Web Dashboard to Cloudflare Pages / Vercel (100% Free)

### Deploying via Cloudflare Pages:
1. Sign up at [Cloudflare](https://dash.cloudflare.com/) → Navigate to **Workers & Pages**.
2. Click **Create Application** → **Pages** → **Connect to Git**.
3. Select `tramakrishna3012/KeyFlow`.
4. Configure Build settings:
   * **Build command**: *(None - static)*
   * **Build output directory**: `web`
   * **Root directory**: `web`
5. Click **Save and Deploy**. Your dashboard will be live at:
   `https://keyflow-web.pages.dev`
6. Update `web/app.js` with your production API URL:
   ```javascript
   const API_BASE = 'https://keyflow-backend.onrender.com/api/v1';
   ```

---

## 5. Step 4: Automate Desktop & Mobile Builds (GitHub Actions Releases)

The existing GitHub Actions workflows in `.github/workflows/` automatically package and upload releases:

1. Create and push a version tag:
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0 - Look System Production"
   git push origin v1.0.0
   ```
2. GitHub Actions will build:
   * **Windows**: `KeyFlow-Setup.exe`
   * **macOS**: `KeyFlow-macOS.dmg`
   * **Linux**: `KeyFlow-Linux.tar.gz`
   * **Android**: `app-release.apk`
3. Downloadable for free by end-users directly from your GitHub repository under `Releases`.

---

## 6. Free Tier Cost & Limits Summary

| Service | Cost | Constraints | Mitigation |
| :--- | :--- | :--- | :--- |
| **Render Web Service** | **$0 / month** | Spins down after 15 mins of inactivity | Desktop client ping / free uptime monitor (e.g. UptimeRobot) keeps it active |
| **Cloudflare Pages** | **$0 / month** | Unlimited requests & bandwidth | Always fast via 300+ global edge data centers |
| **Neon / Supabase Postgres** | **$0 / month** | 0.5 GB storage | Automatic 90-day retention purge job keeps DB lean |
| **GitHub Releases** | **$0 / month** | 2 GB per file limit | Application binaries are ~35-50 MB |
