# Look System Application: REST API Specification

**Base URL**: `http://localhost:4000/api/v1`

---

## 1. Authentication Endpoints

### `POST /auth/register`
* **Description**: Register a new user and organization.
* **Request Body**:
```json
{
  "email": "user@company.com",
  "password": "SecurePassword123!",
  "fullName": "Jane Doe",
  "role": "admin",
  "organizationName": "Acme Corp"
}
```
* **Response `(201 Created)`**:
```json
{
  "user": {
    "id": "uuid-v4",
    "email": "user@company.com",
    "fullName": "Jane Doe",
    "role": "admin",
    "organizationId": "uuid-v4"
  },
  "token": "jwt-token-string"
}
```

### `POST /auth/login`
* **Description**: Authenticate with email and password. Includes account lockout defense.
* **Request Body**:
```json
{
  "email": "user@company.com",
  "password": "SecurePassword123!"
}
```
* **Response `(200 OK)`**: Returns user profile and signed JWT token.
* **Error `(423 Locked)`**: Account temporarily locked if 5 consecutive failed attempts occur.

---

## 2. Activity & Telemetry Endpoints

### `POST /activity/batch`
* **Headers**: `Authorization: Bearer <token>`
* **Description**: Ingest telemetry batch from authorized desktop workstation.
* **Request Body**:
```json
{
  "deviceName": "Workstation-01",
  "osInfo": "Windows 11 / macOS Sonoma",
  "agentVersion": "1.0.0",
  "entries": [
    {
      "appName": "Visual Studio Code",
      "windowTitle": "main.dart — Project Overview",
      "durationSeconds": 1800,
      "idleSeconds": 60,
      "isIdle": false,
      "startedAt": "2026-08-21T09:00:00Z",
      "endedAt": "2026-08-21T09:30:00Z"
    }
  ]
}
```
* **Response `(200 OK)`**: `{ "success": true, "deviceId": "uuid", "ingestedCount": 1 }`

### `GET /activity/summary`
* **Headers**: `Authorization: Bearer <token>`
* **Query Params**: `startDate`, `endDate`, `targetUserId` (admin only)
* **Response `(200 OK)`**: Returns total active seconds, idle seconds, productivity score, top applications, and category distributions.

---

## 3. Administration & Governance Endpoints

### `GET /admin/users`
* **Role**: `admin`, `manager`
* **Response `(200 OK)`**: Returns all enrolled users and their workstation statuses.

### `PUT /admin/retention`
* **Role**: `admin`
* **Request Body**: `{ "retentionDays": 90, "autoPurgeEnabled": true }`
* **Response `(200 OK)`**: `{ "success": true, "message": "Retention policy updated" }`

### `GET /admin/audit-logs`
* **Role**: `admin`
* **Response `(200 OK)`**: Searchable immutable audit trail of administrative actions.

---

## 4. Privacy & Compliance (DSAR) Endpoints

### `GET /compliance/status`
* **Response `(200 OK)`**: Current user consent status, policy version, and grant timestamp.

### `GET /compliance/export?format=json|csv`
* **Description**: Download complete user activity data archive (GDPR Article 15 DSAR).

### `POST /compliance/delete-my-data`
* **Description**: Permanently erase all personal telemetry records (GDPR Article 17 Right to be Forgotten).
