# KeyFlow REST API Specification (v1)

**Base URL**: `https://keyflow-dnsd.onrender.com/api/v1` or `http://localhost:4000/api/v1`

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
    "token": "<JWT_TOKEN>",
    "user": { "id": "...", "email": "...", "role": "admin" }
  }
  ```

### `POST /auth/login`
* **Request**: `{ "email": "...", "password": "..." }`
* **Response `200 OK`**: `{ "token": "<JWT_TOKEN>", "user": { ... } }`

---

## 2. Real-Time Session Aggregation Endpoints

### `POST /sessions/upsert`
* **Headers**: `Authorization: Bearer <JWT>`, `Content-Type: application/json`
* **Request**:
  ```json
  {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "appName": "Chrome",
    "windowTitle": "Google Docs — Project Plan",
    "deviceName": "Motorola Edge 40",
    "content": "KeyFlow intelligent text recovery session.",
    "characterCount": 42,
    "wordCount": 5,
    "startedAt": "2026-09-01T12:00:00.000Z",
    "updatedAt": "2026-09-01T12:02:30.000Z",
    "isFavorite": false,
    "draftHistory": [
      { "timestamp": "2026-09-01T12:00:00.000Z", "text": "KeyFlow intelligent", "charCount": 19 },
      { "timestamp": "2026-09-01T12:02:30.000Z", "text": "KeyFlow intelligent text recovery session.", "charCount": 42 }
    ]
  }
  ```
* **Response `200 OK`**: `{ "success": true, "session": { ... } }`

### `GET /sessions`
* **Headers**: `Authorization: Bearer <JWT>`
* **Query Params**: `appName`, `search`, `limit`, `offset`, `onlyFavorites`
* **Response `200 OK`**:
  ```json
  {
    "success": true,
    "count": 1,
    "sessions": [
      {
        "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "app_name": "Chrome",
        "window_title": "Google Docs — Project Plan",
        "device_name": "Motorola Edge 40",
        "content": "KeyFlow intelligent text recovery session.",
        "character_count": 42,
        "word_count": 5,
        "is_favorite": 0,
        "started_at": "2026-09-01T12:00:00.000Z",
        "updated_at": "2026-09-01T12:02:30.000Z"
      }
    ]
  }
  ```

### `PATCH /sessions/:id/favorite`
* **Headers**: `Authorization: Bearer <JWT>`
* **Request**: `{ "isFavorite": true }`
* **Response `200 OK`**: `{ "success": true, "isFavorite": true }`

### `DELETE /sessions/:id`
* **Headers**: `Authorization: Bearer <JWT>`
* **Response `200 OK`**: `{ "success": true, "message": "Session deleted" }`

---

## 3. Synchronized Multi-Device Clipboard Endpoints

### `POST /clipboard/insert`
* **Headers**: `Authorization: Bearer <JWT>`, `Content-Type: application/json`
* **Request**:
  ```json
  {
    "id": "clip-uuid-9876",
    "sourceApp": "VS Code",
    "deviceName": "Desktop",
    "content": "const token = jwt.sign(payload, SECRET);",
    "contentType": "code",
    "isPinned": false,
    "createdAt": "2026-09-01T12:05:00.000Z"
  }
  ```
* **Response `201 Created`**: `{ "success": true, "entry": { ... } }`

### `GET /clipboard`
* **Headers**: `Authorization: Bearer <JWT>`
* **Query Params**: `contentType` (`code` | `url` | `text`), `limit`, `offset`, `onlyPinned`
* **Response `200 OK`**:
  ```json
  {
    "success": true,
    "count": 1,
    "entries": [
      {
        "id": "clip-uuid-9876",
        "source_app": "VS Code",
        "device_name": "Desktop",
        "content": "const token = jwt.sign(payload, SECRET);",
        "content_type": "code",
        "is_pinned": 0,
        "created_at": "2026-09-01T12:05:00.000Z"
      }
    ]
  }
  ```

### `PATCH /clipboard/:id/pin`
* **Headers**: `Authorization: Bearer <JWT>`
* **Request**: `{ "isPinned": true }`
* **Response `200 OK`**: `{ "success": true, "isPinned": true }`

### `DELETE /clipboard/:id`
* **Headers**: `Authorization: Bearer <JWT>`
* **Response `200 OK`**: `{ "success": true, "message": "Clipboard entry removed" }`

---

## 4. Privacy & Compliance Controls

### `POST /privacy/exclusions`
* **Headers**: `Authorization: Bearer <JWT>`
* **Request**: `{ "appName": "1Password", "reason": "Password Manager Exclusion" }`
* **Response `201 Created`**: `{ "success": true }`

### `POST /compliance/dsar/delete` (1-Click Data Shredding)
* **Headers**: `Authorization: Bearer <JWT>`
* **Response `200 OK`**: `{ "success": true, "purgedRecords": 184 }`
