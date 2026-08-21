# Look System Application: Deployment & Operational Runbook

## 1. Quickstart Deployment (Docker Compose)

To start the Look System backend API and Web Dashboard locally or on a production host:

```bash
# Clone and navigate to repository
cd KeyFlow

# Build and start all services
docker-compose up --build -d

# Verify health status
curl http://localhost:4000/api/health
```

The Web Dashboard will be available at `http://localhost:3000` and the Backend API at `http://localhost:4000`.

---

## 2. Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `PORT` | `4000` | Port for the Backend API. |
| `NODE_ENV` | `production` | Environment mode (`development` / `production`). |
| `JWT_SECRET` | Required | 256-bit cryptographic secret for signing user tokens. |
| `JWT_EXPIRES_IN` | `24h` | Token validity lifetime. |
| `DB_PATH` | `./look_system.db` | Path to SQLite / PostgreSQL database connection. |
| `DEFAULT_RETENTION_DAYS` | `90` | Default data retention limit before auto-purging. |

---

## 3. Disaster Recovery & Database Maintenance

### Automated Backups
```bash
# Backup SQLite database
sqlite3 /app/data/look_system.db ".backup '/app/data/backup_$(date +%Y%m%d_%H%M%S).db'"
```

### Manual Retention Purge Execution
```bash
curl -X POST http://localhost:4000/api/v1/admin/retention/purge-now \
  -H "Authorization: Bearer <ADMIN_JWT_TOKEN>"
```
