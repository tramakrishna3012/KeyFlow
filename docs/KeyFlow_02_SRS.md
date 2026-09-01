# KeyFlow — Software Requirements Specification (SRS)

**Document Version:** 3.0  
**Format Basis:** IEEE 830 Standard (Functional & Non-Functional Requirements)  
**System Scope:** KeyFlow Mobile (Flutter/Kotlin), Backend Relay (Node/Express), Web Console (Cloudflare Workers SPA & React)  

---

## 1. Introduction & System Context

### 1.1 Purpose
This document specifies the complete software requirements for the **KeyFlow System**, covering the local-first mobile client, the native accessibility capture daemon, the client-side session aggregation and debouncing engine, the multi-device synchronized clipboard manager, the interactive draft replay module, the cloud telemetry relay, and the web-based cross-device dashboard.

### 1.2 System Scope
- **Mobile Subsystem**: Flutter client running on Android 8.0+ (API 26–35), iOS, and Windows Desktop.
- **Native Android Engine**: Kotlin `AccessibilityService`, `WindowManager` Overlay Bot, `ClipboardManager` Listener.
- **Session Aggregation Engine**: Cross-platform debouncing buffer (2.5s) and session boundary terminator (60s).
- **Clipboard Sync Subsystem**: Content-type classifier (`code`, `url`, `text`) and cross-device sync relay.
- **Local Storage Engine**: SQLCipher AES-256 encrypted SQLite database with hardware Keystore binding.
- **Cloud Relay Engine**: Supabase PostgreSQL & Node.js/Express REST API with tenant isolation via Row Level Security (RLS).
- **Web Dashboard**: Cloudflare Workers SPA & React Dashboard with WebCrypto client-side decryption.

---

## 2. Functional Requirements (FR)

### Group 1: Capture & Session Aggregation Engine (FR-1 .. FR-8)
- **FR-1 [Consent Gate]**: The system shall not capture keystrokes or text until the user completes the onboarding flow and grants explicit Accessibility and Notification permissions.
- **FR-2 [Universal Accessibility Hook]**: On Android, the system shall intercept accessibility events to construct text buffers per application and window title.
- **FR-3 [2.5s Inactivity Debounce Buffer]**: The session aggregation engine shall buffer keystrokes locally and only upsert an updated session snapshot after 2.5 seconds of typing silence.
- **FR-4 [60s Session Boundary Terminator]**: The system shall automatically finalize the active session container and spawn a new paragraph record when the user switches applications or pauses typing for greater than 60 seconds.
- **FR-5 [Composite Key Grouping]**: The system shall group typing streams by composite key `appName.toLowerCase()::windowTitle.toLowerCase()::deviceName.toLowerCase()`.
- **FR-6 [Password & Sensitive Field Masking]**: The system shall automatically discard inputs originating from password fields (`isPasswordField == true`) or containing credit card / OTP patterns.
- **FR-7 [Calculator & Math Exemption]**: The system shall explicitly exempt Calculator and mathematical utilities from privacy filtering, recording numeric formulas and calculation results accurately.
- **FR-8 [Discreet Service Notification]**: The active background service shall run under the neutral title *"System Sync Service"* with minimal non-intrusive status indicators.

### Group 2: Multi-Device Clipboard Synchronization (FR-9 .. FR-13)
- **FR-9 [Native Clipboard Hook]**: The system shall monitor primary clipboard changes via `ClipboardManager` and immediately ingest copied text.
- **FR-10 [Content-Type Classification]**: The system shall classify clipboard entries into `code`, `url`, or `text` based on structural syntax and URL patterns.
- **FR-11 [Syntax-Highlighted Code Blocks]**: Copied code blocks shall render with line-numbered code containers and monospace typography.
- **FR-12 [Rich URL Preview Cards]**: Copied URLs shall render with domain badges and direct external link actions.
- **FR-13 [Pinning & 1-Click Copy]**: Users shall be able to pin/unpin favorite clipboard entries and copy any item to the device clipboard in 1-click with toast confirmation.

### Group 3: Interactive Replay Draft Modal (FR-14 .. FR-16)
- **FR-14 [Draft History Snapshots]**: The session aggregator shall store delta draft snapshots (every ~5 characters) in the session record.
- **FR-15 [Interactive Timeline Scrubber]**: The web console and mobile app shall provide a slider scrubber allowing users to drag and inspect typing progression step-by-step.
- **FR-16 [Animated Playback Engine]**: The replay modal shall support 1x, 2x, and 4x speed multipliers with Play/Pause and Step Copy actions.

### Group 4: Local Storage, Security & Cryptography (FR-17 .. FR-22)
- **FR-17 [SQLCipher AES-256 Storage]**: All cleartext history records, timestamps, and application identifiers shall be stored in an AES-256 encrypted SQLite database (`sqflite_sqlcipher`).
- **FR-18 [Hardware Key Management]**: The database master key shall be generated via cryptographically secure random bytes and stored inside `FlutterSecureStorage` (Android Keystore / iOS Keychain).
- **FR-19 [Automated Retention Purge]**: The system shall execute a scheduled background retention purge job enforcing user-selected policies (24 Hours, 7 Days, 30 Days, 90 Days, or Never).
- **FR-20 [1-Click Data Export]**: The system shall allow the user to export all stored history entries as an encrypted or decrypted standard JSON archive.
- **FR-21 [Cascading Data Shredding]**: When the user requests history deletion or account reset, all SQLite tables shall be truncated and overwritten immediately.
- **FR-22 [Tenant Isolation RLS]**: Cloud database tables (`typing_sessions`, `clipboard_entries`) shall enforce PostgreSQL Row Level Security restricting access strictly to `auth.uid() = user_id`.

### Group 5: Mobile User Experience & Navigation (FR-23 .. FR-27)
- **FR-23 [Session Typing Feed]**: The History screen shall organize entries by date and app, displaying word count, character count, duration, favorite star, and copy triggers.
- **FR-24 [Sub-20ms Search]**: The History screen shall provide real-time search filtering across all applications with response time < 20ms.
- **FR-25 [High-Contrast White Ball Switches]**: All settings switches shall render prominent white ball thumb knobs (`thumbColor: Colors.white`) with high-contrast active track gradients.
- **FR-26 [Adaptive Navigation]**: For wide viewports (width > 600px, landscape mode, desktop), the application shall adapt from bottom navigation to a scrollable `NavigationRail` sidebar without vertical overflow.
- **FR-27 [Floating Assistant Bot]**: The application shall provide a toggleable system overlay bot (`SYSTEM_ALERT_WINDOW`) with quick capture pause/resume controls.

### Group 6: Web Dashboard & Cloud Telemetry (FR-28 .. FR-30)
- **FR-28 [Dual Feed Navigation]**: The web console shall provide dual tabs for `Session Typing Stream` and `Clipboard History Feed` alongside Executive Overview, Search, App Breakdown, Admin, and Privacy tabs.
- **FR-29 [Hardware Device Badging]**: Synced records shall display authorized device badges (e.g. `📱 Motorola Edge 40` or `💻 Desktop`).
- **FR-30 [Real-Time Refresh & Decryption]**: The web dashboard shall pull, decrypt via WebCrypto, and render new records in real time.

---

## 3. Non-Functional Requirements (NFR)

| ID | Category | Requirement Description | Target Metric | Status |
| :--- | :--- | :--- | :--- | :---: |
| **NFR-1** | **Performance** | History search query execution time across 10,000 records | < 20 ms | **PASS** |
| **NFR-2** | **Resource Footprint**| Sustained background CPU usage on Android | < 1.5% CPU | **PASS** |
| **NFR-3** | **Memory Usage** | Background RAM footprint for accessibility service | < 120 MB RAM | **PASS** |
| **NFR-4** | **Security** | Database encryption standard for data at rest | AES-256-GCM / SQLCipher | **PASS** |
| **NFR-5** | **Availability** | Web Dashboard static asset edge delivery | 99.99% uptime via Cloudflare | **PASS** |
| **NFR-6** | **Compatibility** | Android OS version support | Android 8.0 to Android 15 (API 26–35) | **PASS** |
| **NFR-7** | **Quality Gate** | SonarQube static code quality & security compliance | Grade A Security, Grade A Reliability, Duplication < 3% | **PASS** |
| **NFR-8** | **Video Codec** | Playability of recorded screen demos across standard media players | 100% Playable (Valid `moov` atom header) | **PASS** |
