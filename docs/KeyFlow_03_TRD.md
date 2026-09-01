# KeyFlow — Technical Requirements Document (TRD)

**Document Version:** 2.0  
**Status:** Implemented & Verified  
**Technical Scope:** Platform Capture Engines, Cryptography, Backend Relay, Edge Web Dashboard  

---

## 1. System Platform Matrix

| Platform | Capture / Ingestion Mechanism | Permissions & Visibility | Technical Engine |
| :--- | :--- | :--- | :--- |
| **Android (Mobile)** | `AccessibilityService` + `ClipboardManager` | `BIND_ACCESSIBILITY_SERVICE`, `SYSTEM_ALERT_WINDOW`, `POST_NOTIFICATIONS` | Kotlin native plugin, EventChannel, MethodChannel |
| **Web Dashboard** | WebCrypto API + Fetch REST Sync | HTTPS Session Auth / JWT Bearer Token | Cloudflare Workers Edge CDN, Vanilla ES6+ SPA |
| **Backend Relay** | Express REST API / SQLite3 / D1 | Bearer JWT, TLS 1.3, Rate-Limited Ingestion | Node.js v18+, SQLite3, Supabase PostgreSQL Relay |
| **Windows Desktop** | Low-Level Hook / Flutter Desktop | Standard user privileges; System Tray presence | Flutter Desktop Windows C++ Runner |

---

## 2. Technical Ingestion & Debounce Pipeline

```
[User Typing Event] ──► [Native AccessibilityService] 
                             │
                             ├─► [Exclusion Filter & Password Check] 
                             │
                             ▼ (MethodChannel Emit)
                      [CaptureService (Dart)]
                             │
                             ├─► Is Clipboard Event? ──► [Instant SQLCipher Persist & Cloud Sync]
                             │
                             └─► Is Typing Event? 
                                       │
                                       ▼
                             [800ms Debounce Timer & 10s Deduplication Hash]
                                       │
                                       ▼
                             [SQLCipher AES-256 Write] ──► [Queue Cloud Relay Sync]
```

---

## 3. Cryptographic & Security Specifications

### 3.1 Local Storage (SQLCipher AES-256)
- **Database Engine**: SQLite 3.x compiled with SQLCipher.
- **Key Generation**: 256-bit entropy generated using `SecureRandom` on first application execution.
- **Key Storage**: Android Keystore / iOS Keychain via `FlutterSecureStorage` with hardware backing (`masterKey`).

### 3.2 Cloud Telemetry & End-to-End Encryption
- **Key Derivation Function**: HKDF (`HMAC-SHA256`).
  - **Salt**: `kf_` + `user_id`
  - **Info Tag**: `keyflow-history-encryption`
  - **Derived Key**: AES-GCM 256-bit symmetric cipher key.
- **Web Dashboard Decryption**: In-browser client-side decryption via standard `window.crypto.subtle` API.

### 3.3 Privacy Masking & Redaction Rules
- **Password Masking**: Discard any event matching `TYPE_TEXT_VARIATION_PASSWORD` or `TYPE_TEXT_VARIATION_WEB_PASSWORD`.
- **Payment & Banking Blacklist**: Automatic exclusion of packages matching `PAYMENT_BANKING_APPS` (`com.google.android.apps.nbu.paisa.user`, `net.one97.paytm`, `com.phonepe.app`, etc.).
- **Calculator Exemption**: Explicit whitelist for mathematical utilities (`com.google.android.calculator`, `calculator`, `calc`). Numeric formulas and results are never redacted.

---

## 4. Screen Recording & Video Artifact Standards

To guarantee that demo videos, test recordings, and visual artifacts are universally playable:
- **Process Termination**: The recording daemon must be terminated cleanly using `adb shell pkill -2 screenrecord` (SIGINT) followed by a 3.0s buffer before pulling the file.
- **Atom Structure**: The MP4 container must contain complete `ftyp`, `moov`, and `mdat` atom headers.
- **Encoding Parameters**: Standard H.264 / `mp4v` codec, 1080x2400 resolution, 20.0–30.0 FPS.

---

## 5. Automated CI/CD & Quality Gate Baseline

- **Flutter Analysis**: `flutter analyze` must return 0 issues.
- **Dart Formatter**: `dart format --set-exit-if-changed .` must pass with 0 unformatted files.
- **Flutter Test Suite**: 108 / 108 automated unit and widget tests must pass.
- **Backend Test Suite**: 8 / 8 integration and RBAC tests must pass.
- **SonarCloud Quality Gate**:
  - Security Rating: **A** (0 vulnerabilities)
  - Reliability Rating: **A** (0 bugs)
  - Maintainability Rating: **A** (0 code smells)
  - Duplication Rate: **< 3.0%**
