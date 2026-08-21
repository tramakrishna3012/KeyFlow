# Look System Application: Database & Security Controls

## 1. Cryptographic Standards

* **Encryption in Transit**: TLS 1.3 enforced for all client-to-backend and web dashboard communications.
* **Encryption at Rest**:
  - Desktop client local buffer encrypted via platform Keystore (Android EncryptedSharedPreferences, macOS Keychain, Windows DPAPI / SQLCipher AES-256).
  - Production database volumes encrypted with AES-256 block-level encryption.
* **Password Hashing**: Bcrypt with work factor 12 (or Argon2id) preventing rainbow table attacks.
* **Session Security**: Cryptographically signed JWT tokens with 24-hour expiration, stored exclusively in memory and secure on-device storage.

---

## 2. Row-Level Security (RLS) & Multi-Tenancy

Every activity log and session record is tagged with `user_id` and `organization_id`. PostgreSQL Row-Level Security policies ensure:
1. Standard members can **only** query and delete rows where `user_id == auth.uid()`.
2. Cross-organization access is blocked at the database engine level.
3. Administrative reads require explicit role membership verified in signed JWT claims.

---

## 3. Threat Model & Countermeasures

| Threat Vector | Mitigation Strategy |
| :--- | :--- |
| **Covert Spyware / Antivirus Flagging** | Transparent process naming, live system tray status icon, code signing certificates, zero hook injection. |
| **Credential & Secret Leakage** | Window title regex sanitizer redacting URLs, query parameters, API keys, and email addresses. |
| **Brute Force & Credential Stuffing** | IP and account-based rate limiter; account lockout for 15 minutes after 5 consecutive failed attempts. |
| **Unauthorized Data Access** | Multi-tier RBAC (`admin`, `manager`, `member`) and Row-Level Security isolation. |
| **Stale Data Accumulation** | Automated daily cryptographic retention purge deleting activity older than the configured organization threshold. |
