# KeyFlow & Look System: 100% Free-Tier Deployment Plan

This document outlines the step-by-step production deployment strategy for KeyFlow and Look System using generous, production-grade **100% free-tier** services.

---

## 1. Free-Tier Architecture Overview

| Component | Recommended Free Provider | Free Tier Limits | Purpose |
| :--- | :--- | :--- | :--- |
| **Backend API** | **[Fly.io](https://fly.io/)** or **[Render.com](https://render.com/)** | 3 shared-cpu-1x VMs, 3GB persistent volume | Hosts Node.js Express REST API with SQLite disk |
| **Web Dashboard** | **[Cloudflare Pages](https://pages.cloudflare.com/)** or **[Vercel](https://vercel.com/)** | Unlimited bandwidth, 100 custom domains | Global CDN hosting for static HTML/CSS/JS |
| **Encrypted Database** | **Fly.io Persistent Volume (SQLite)** / **[Neon.tech](https://neon.tech/)** | 3 GB Free Volume / 0.5 GB Postgres | Relational storage for sessions & encrypted logs |
| **App Binaries & Releases** | **[GitHub Releases](https://github.com/)** | Unlimited public release asset hosting | Distributes Windows `.exe`, macOS `.dmg`, Linux `.AppImage`, Android `.apk` |

---

## 2. Step-by-Step Fly.io Deployment (Backend + Persistent SQLite Storage)

[Fly.io](https://fly.io/) is the ideal free-tier host for KeyFlow because it gives you **3GB of free persistent SSD volume storage**, allowing your encrypted SQLite database (`look_system.db`) to persist across restarts and deploys without needing an external database.

### Step 2.1: Install Fly CLI (`flyctl`)

* **Windows (PowerShell)**:
  ```powershell
  pwsh -Command "iwr https://fly.io/install.ps1 -useb | iex"
  ```
* **macOS / Linux**:
  ```bash
  curl -L https://fly.io/install.sh | sh
  ```

### Step 2.2: Sign In / Register
```bash
fly auth signup
# or if you already have an account:
fly auth login
```

---

### Step 2.3: Prepare `fly.toml` Configuration

Inside the `backend/` directory, create a `fly.toml` file (or let Fly generate one):

```toml
# backend/fly.toml
app = "keyflow-api"
primary_region = "iad" # Choose closest region: e.g. iad, sin, fra, lhr, sjc

[build]
  dockerfile = "../Dockerfile.backend"

[env]
  NODE_ENV = "production"
  PORT = "4000"
  DB_PATH = "/data/look_system.db"
  DEFAULT_RETENTION_DAYS = "90"

[mounts]
  source = "keyflow_data"
  destination = "/data"

[http_service]
  internal_port = 4000
  force_https = true
  auto_stop_machines = 'stop'
  auto_start_machines = true
  min_machines_running = 1
  processes = ['app']

[[vm]]
  size = "shared-cpu-1x"
  memory = "256mb"
```

---

### Step 2.4: Create Free 1GB Persistent Volume for SQLite

Run this command to create a persistent disk in your chosen region (e.g. `iad` for US East, `sin` for Singapore, `fra` for Europe):

```bash
fly volumes create keyflow_data --size 1 --region iad
```

---

### Step 2.5: Set Production Secrets

Set your cryptographic keys and JWT secrets securely on Fly:

```bash
fly secrets set JWT_SECRET="your_secure_random_32_character_jwt_secret_key!"
```

---

### Step 2.6: Deploy the Backend API

From the root project folder:

```bash
fly deploy --config backend/fly.toml --dockerfile Dockerfile.backend
```

Once deployment completes, Fly will output your live URL:
`https://keyflow-api.fly.dev`

You can verify health by navigating to:
`https://keyflow-api.fly.dev/api/v1/health`

---

### Step 2.7: Useful Fly Management Commands

* **View live server logs**:
  ```bash
  fly logs --app keyflow-api
  ```
* **Check VM & Volume status**:
  ```bash
  fly status --app keyflow-api
  ```
* **SSH into your running backend machine**:
  ```bash
  fly ssh console --app keyflow-api
  ```

---

## 3. Step 3: Deploy Web Dashboard to Cloudflare Pages (100% Free)

1. Sign up at [Cloudflare](https://dash.cloudflare.com/) → Navigate to **Workers & Pages**.
2. Click **Create Application** → **Pages** → **Connect to Git**.
3. Select `tramakrishna3012/KeyFlow`.
4. Configure Build settings:
   * **Build command**: *(None - static)*
   * **Build output directory**: `web`
   * **Root directory**: `web`
5. Click **Save and Deploy**. Your dashboard will be live at:
   `https://keyflow-web.pages.dev`
6. In `web/app.js`, set your Fly.io API URL:
   ```javascript
   const API_BASE = 'https://keyflow-api.fly.dev/api/v1';
   ```

---

## 4. Step 4: Automate Desktop & Mobile Builds (GitHub Actions Releases)

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

## 5. Free Tier Cost & Limits Summary

| Service | Cost | Constraints | Mitigation |
| :--- | :--- | :--- | :--- |
| **Fly.io VM + Volume** | **$0 / month** | 3 shared-cpu-1x VMs, 3GB volume free | `auto_start_machines = true` handles auto-wake on request |
| **Cloudflare Pages** | **$0 / month** | Unlimited requests & bandwidth | Always fast via 300+ global edge data centers |
| **GitHub Releases** | **$0 / month** | 2 GB per file limit | Application binaries are ~35-50 MB |
