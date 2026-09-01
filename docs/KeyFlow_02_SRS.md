# KeyFlow — Software Requirements Specification (SRS)

**Document Version:** 2.0  
**Format Basis:** IEEE 830 Standard (Functional & Non-Functional Requirements)  
**System Scope:** KeyFlow Mobile (Flutter/Kotlin), Backend Relay (Node/Express), Web Console (Cloudflare Workers)  

---

## 1. Introduction & System Context

### 1.1 Purpose
This document specifies the software requirements for the **KeyFlow System**, covering the local-first mobile client, the native accessibility capture daemon, the clipboard monitoring subsystem, the encrypted local database, the cloud telemetry relay, and the web-based cross-device dashboard.

### 1.2 System Scope
- **Mobile Subsystem**: Flutter client running on Android 8.0+ (API 26–35), iOS, and Windows Desktop.
- **Native Android Engine**: Kotlin `AccessibilityService`, `WindowManager` Overlay Bot, `ClipboardManager` Listener.
- **Local Storage Engine**: SQLCipher AES-256 encrypted SQLite database with hardware Keystore binding.
- **Cloud Relay Engine**: Supabase E2E encrypted payload synchronization.
- **Backend Services**: Node.js/Express telemetry ingestion, JWT authentication, RBAC, and automated purge jobs.
- **Web Dashboard**: Cloudflare Workers SPA with WebCrypto client-side decryption.

---

## 2. Functional Requirements (FR)

### Group 1: Capture & Privacy Engine (FR-1 .. FR-8)
- **FR-1 [Consent Gate]**: The system shall not capture keystrokes or text until the user completes the onboarding flow and grants explicit Accessibility and Notification permissions.
- **FR-2 [Universal Keystroke Hook]**: On Android, the system shall intercept `TYPE_VIEW_TEXT_CHANGED`, `TYPE_VIEW_FOCUSED`, and `TYPE_WINDOW_CONTENT_CHANGED` events to construct text buffers.
- **FR-3 [Debounce & Ingestion]**: The capture pipeline shall debounce user typing with an 800ms quiet window and deduplicate entries within a 10-second sliding cache window.
- **FR-4 [Clipboard Capture]**: The system shall monitor primary clipboard changes via `ClipboardManager.OnPrimaryClipChangedListener` and immediately ingest copied text under `sourceApp: "Clipboard"` without debounce delay.
- **FR-5 [Password & Sensitive Field Masking]**: The system shall automatically discard inputs originating from fields flagged as `TYPE_TEXT_VARIATION_PASSWORD`, `TYPE_TEXT_VARIATION_WEB_PASSWORD`, or containing credit card / SSN patterns.
- **FR-6 [Calculator & General Math Exemption]**: The system shall explicitly exempt Calculator and mathematical utilities from privacy filtering, recording numeric formulas and calculation results accurately.
- **FR-7 [App Exclusion Blacklist]**: The system shall allow users to blacklist any installed application, immediately discarding events from the blacklisted package at the native accessibility layer.
- **FR-8 [Discreet Service Notification]**: The active background service shall run under the neutral title *"System Sync Service"* with minimal non-intrusive status indicators.

### Group 2: Local Storage & Cryptography (FR-9 .. FR-14)
- **FR-9 [SQLCipher AES-256 Storage]**: All cleartext history records, timestamps, and application identifiers shall be stored in an AES-256 encrypted SQLite database (`sqflite_sqlcipher`).
- **FR-10 [Hardware Key Management]**: The database master key shall be generated via cryptographically secure random bytes on first initialization and stored inside `FlutterSecureStorage` (Android Keystore / iOS Keychain).
- **FR-11 [Automated Retention Purge]**: The system shall execute a scheduled background retention purge job enforcing user-selected policies (24 Hours, 7 Days, 30 Days, 90 Days, or Never).
- **FR-12 [1-Click Data Export]**: The system shall allow the user to export all stored history entries as an encrypted or decrypted standard JSON archive.
- **FR-13 [Cascading Data Shredding]**: When the user requests history deletion or account reset, all SQLite tables shall be truncated and overwritten immediately.

### Group 3: Mobile User Experience & Navigation (FR-14 .. FR-22)
- **FR-14 [2-Level Grouped History]**: The History screen shall organize entries hierarchically: Level 1 by Date sections (*Today*, *Yesterday*, *Date*) with pill badges; Level 2 by Application Cards with package icons, timestamps, and snippet cards.
- **FR-15 [1-Click Copy Affordance]**: Each snippet card shall feature a dedicated copy icon that instantly copies text to clipboard and displays a visual toast confirmation.
- **FR-16 [Sub-20ms History Search]**: The History screen shall provide a real-time search field that filters entries across all applications with response time < 20ms.
- **FR-17 [App Filter Chips]**: The History screen shall display dynamic application filter chips allowing single-tap filtering by specific apps (*All Apps*, *Chrome*, *Calculator*, *WhatsApp*).
- **FR-18 [High-Contrast White Ball Switches]**: All settings switches shall render prominent white ball thumb knobs (`thumbColor: Colors.white`) with high-contrast active track gradients.
- **FR-19 [Adaptive Navigation]**: For wide viewports (width > 600px, landscape/horizontal mode, desktop), the application shall adapt from bottom navigation to a scrollable `NavigationRail` sidebar without vertical overflow.
- **FR-20 [Floating Assistant Bot]**: The application shall provide a toggleable system overlay bot (`SYSTEM_ALERT_WINDOW`) with quick capture pause/resume controls and accessibility diagnostic shortcuts.
- **FR-21 [Assist Tools]**: The application shall provide built-in Emoji search/favorite grids and offline/online translation tools.
- **FR-22 [Semantic Auto-Update]**: The application shall check GitHub releases using semantic versioning (`major.minor.patch`) and allow persistent dismissal.

### Group 4: Web Dashboard & Telemetry Sync (FR-23 .. FR-30)
- **FR-23 [Cloud Telemetry Ingestion]**: The backend shall accept debounced activity batches over HTTPS, applying JWT verification, rate limiting, and RBAC authorization.
- **FR-24 [End-to-End Encryption]**: Cloud-synchronized payloads stored in Supabase shall be encrypted client-side using HKDF (`SHA-256`) derived AES-GCM keys.
- **FR-25 [Web Dashboard UI]**: The web console at `https://keyflow.tramakrishna3012.workers.dev` shall provide 6 main tabs: Executive Overview, Typing History, Search & Filtering, App Usage Breakdown, Admin & Org Controls, and Privacy & Exclusions.
- **FR-26 [Hardware Device Badging]**: Synced web records shall display authorized device badges (e.g. `📱 Motorola Edge 40`).
- **FR-27 [Real-Time Refresh]**: The web dashboard shall feature a "Refresh Telemetry" button that pulls, decrypts, and renders new records in real time.
- **FR-28 [Admin Controls & DSAR]**: Administrators shall be able to inspect active sessions, manage roles, de-authorize devices, and execute GDPR DSAR subject deletion requests.

---

## 3. Non-Functional Requirements (NFR)

| ID | Category | Requirement Description | Target Metric |
| :--- | :--- | :--- | :--- |
| **NFR-1** | **Performance** | History search query execution time across 10,000 records | < 20 ms |
| **NFR-2** | **Resource Footprint**| Sustained background CPU usage on Android | < 1.5% CPU |
| **NFR-3** | **Memory Usage** | Background RAM footprint for accessibility service | < 120 MB RAM |
| **NFR-4** | **Security** | Database encryption standard for data at rest | AES-256-GCM / SQLCipher |
| **NFR-5** | **Availability** | Web Dashboard static asset edge delivery | 99.99% uptime via Cloudflare |
| **NFR-6** | **Compatibility** | Android OS version support | Android 8.0 to Android 15 (API 26–35) |
| **NFR-7** | **Quality Gate** | SonarQube static code quality & security compliance | Passed (Security A, Reliability A, Duplication < 3%) |
| **NFR-8** | **Video Codec** | Playability of recorded screen demos across standard media players | 100% Playable (Valid `moov` atom header) |
