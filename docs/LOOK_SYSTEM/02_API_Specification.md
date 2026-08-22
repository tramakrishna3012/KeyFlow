# Look System Application: REST API Specification (v1)

**Base URL**: `https://api.looksystem.enterprise/api/v1` or `http://localhost:4000/api/v1`

---

## 1. Authentication & Identity

### `POST /auth/register`
* **Request**:
  ```json
  {
    "email": "owner@company.com",
    "password": "SecurePassword123!",
    "fullName": "Jane Doe",
    "role": "admin",
    "organizationName": "Acme Corp"
  }
  ```
* **Response `201 Created`**:
  ```json
  {
    "message": "User registered successfully",
    "token": "eyJhbGciOi...",
    "user": { "id": "...", "email": "...", "role": "admin" }
  }
  ```

### `POST /auth/login`
* **Request**: `{ "email": "...", "password": "..." }`
* **Response `200 OK`**: `{ "token": "...", "user": { ... } }`

---

## 2. Session Lifecycle & Batch Activity Management

### `POST /activity/sessions/start`
* **Headers**: `Authorization: Bearer <JWT>`
* **Request**: `{ "deviceName": "MacBook Pro M3", "osInfo": "macOS 14.5" }`
* **Response `200 OK`**: `{ "sessionId": "sess-...", "status": "active" }`

### `POST /activity/sessions/pause`
* **Request**: `{ "sessionId": "sess-..." }`
* **Response `200 OK`**: `{ "sessionId": "sess-...", "status": "paused" }`

### `POST /activity/sessions/resume`
* **Request**: `{ "sessionId": "sess-..." }`
* **Response `200 OK`**: `{ "sessionId": "sess-...", "status": "active" }`

### `POST /activity/sessions/stop`
* **Request**: `{ "sessionId": "sess-..." }`
* **Response `200 OK`**: `{ "sessionId": "sess-...", "status": "completed", "durationSeconds": 1820 }`

### `GET /activity/sessions`
* **Query Params**: `limit`, `offset`, `status`, `startDate`, `endDate`
* **Response `200 OK`**:
  ```json
  {
    "sessions": [
      {
        "id": "sess-...",
        "device_name": "MacBook Pro",
        "started_at": "2026-08-22T08:00:00.000Z",
        "ended_at": "2026-08-22T12:00:00.000Z",
        "status": "completed",
        "total_active_seconds": 14400
      }
    ]
  }
  ```

### `GET /activity/sessions/:sessionId`
* **Response `200 OK`**: Returns hierarchical tree (`Session -> Applications -> ActivityEvents & TextRecords`).

### `POST /activity/batch` (Offline Queue Sync & Deduplication)
* **Headers**: `Authorization: Bearer <JWT>`
* **Request**:
  ```json
  {
    "deviceName": "MacBook Pro M3",
    "sessionId": "sess-...",
    "entries": [
      {
        "id": "evt-client-uuid-1",
        "appName": "Visual Studio Code",
        "windowTitle": "LookSystemCore.dart",
        "textRecord": "Implementing offline encrypted sync queue",
        "durationSeconds": 300,
        "isIdle": false,
        "startedAt": "2026-08-22T09:00:00.000Z",
        "endedAt": "2026-08-22T09:05:00.000Z"
      }
    ]
  }
  ```
* **Response `200 OK`**: `{ "ingestedCount": 1, "sessionId": "sess-..." }`

---

## 3. Search & Privacy Exclusions

### `GET /activity/search`
* **Query Params**: `q` (keyword search), `appName`, `sessionId`, `startDate`, `endDate`, `limit`, `offset`
* **Response `200 OK`**:
  ```json
  {
    "results": [
      {
        "id": "evt-...",
        "sessionId": "sess-...",
        "deviceName": "MacBook Pro",
        "appName": "Visual Studio Code",
        "windowTitle": "LookSystemCore.dart",
        "textPreview": "Implementing offline encrypted sync queue",
        "durationSeconds": 300,
        "timestamp": "2026-08-22T09:00:00.000Z"
      }
    ]
  }
  ```

### `GET /activity/privacy/exclusions`
* **Response `200 OK`**: `{ "exclusions": [{ "appName": "1Password", "fieldType": null }] }`

### `POST /activity/privacy/exclusions`
* **Request**: `{ "appName": "Bitwarden", "fieldType": "password" }`
* **Response `201 Created`**: `{ "message": "Exclusion rule added" }`
