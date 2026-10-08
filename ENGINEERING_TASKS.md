# Technical Specification & Verification Plan: KeyFlow Multi-Platform Ecosystem

Act as a Principal Software Engineer, Mobile Architect, and QA Automation Lead. Execute the web platform audit, resolve the mobile App Info launchability issue without altering core synchronization or privacy logic, run end-to-end device verification on Motorola Edge 40 (Device: ZD222GYVTF), and generate dual demonstration video artifacts.

STRICT CONSTRAINT: Do NOT alter or remove any existing encryption (SQLCipher), session aggregation debounce timers, privacy field masking, or background service persistence. Retain all existing core business logic intact.

================================================================================
PHASE 1: WEB APPLICATION PLATFORM AUDIT & RESOLUTION (FIRST PRIORITY)
================================================================================
Perform a complete diagnostic audit on the Web Application (/web and backend at keyflow.tramakrishna3012.workers.dev / local server):

1. Platform Health & Network Connectivity:
   - Test GET /api/health and verify HTTP 200 response with valid JSON payload.
   - Confirm CORS headers permit requests from web dashboard origins.
2. Authentication & Account Routing:
   - Audit web/app.js authentication flows. Verify new user registration (Sign Up) and user login (Sign In) function reliably without 404s, unhandled promise rejections, or infinite loaders.
   - Verify JWT session token persistence in localStorage across page refreshes.
   - Ensure UI cards and navigation headers are free of any legacy prototype branding or mislabeled backend references.
3. Real-Time Data Streams:
   - Inspect TypingStreamFeed and ClipboardHistoryFeed components. Confirm dynamic polling (1.5s interval) or WebSocket updates render incoming data records promptly.
   - Audit light-theme contrast ratios and resolve any layout clipping or responsive flex overflows.

================================================================================
PHASE 2: MOBILE "APP INFO OPEN" BUTTON & DIRECT LAUNCH INTEGRATION
================================================================================
Resolve the issue where Android Settings -> App Info has the "Open" button disabled or greyed out:

1. AndroidManifest.xml (app/android/app/src/main/AndroidManifest.xml):
   - Verify MainActivity declares android:exported="true".
   - Add category.INFO inside MainActivity intent-filter under action.MAIN:
     ```xml
     <intent-filter>
         <action android:name="android.intent.action.MAIN" />
         <category android:name="android.intent.category.INFO" />
     </intent-filter>
     ```
     (Note: category.INFO instructs the Android Package Manager that the application can be launched directly from OS Settings without requiring a default home-screen launcher icon).
   - Register the deep-link intent filter:
     ```xml
     <intent-filter>
         <action android:name="android.intent.action.VIEW" />
         <category android:name="android.intent.category.DEFAULT" />
         <category android:name="android.intent.category.BROWSABLE" />
         <data android:scheme="keyflow" android:host="open" />
     </intent-filter>
     ```
   - Keep existing KeyflowTileService (Quick Settings Tile) intact.
2. Web Portal Launch Bridge (web/index.html or download page):
   - Add a direct launch action for mobile browsers:
     `<a href="keyflow://open" class="btn-open-app">Open Installed App</a>`
   - Enables users to launch directly into the registration view immediately after APK installation.

================================================================================
PHASE 3: VERIFICATION RUNBOOK ON MOTOROLA EDGE 40 (ZD222GYVTF)
================================================================================
Execute automated verification on the connected device:

1. Build & Deploy:
   - Compile debug APK: cd app && flutter build apk --debug
   - Install to device: adb -s ZD222GYVTF install -r build/app/outputs/flutter-apk/app-debug.apk
2. Launch Verification:
   - Test launch via deep link: adb -s ZD222GYVTF shell am start -a android.intent.action.VIEW -d "keyflow://open"
   - Confirm MainActivity gains foreground focus via dumpsys window displays.
3. Functional Acceptance Criteria:
   - [PASS/FAIL] Mobile App launches into Sign Up view via App Info and deep link.
   - [PASS/FAIL] Complete account registration with test credentials (client.test@keyflow.io / Password#2026).
   - [PASS/FAIL] Enable accessibility helper service in Android Settings; confirm status changes to Active.
   - [PASS/FAIL] Input sample sentence in Keep Notes; confirm 1 consolidated paragraph card is created.
   - [PASS/FAIL] Log in to Web Dashboard using identical credentials; confirm the synchronized card renders in real time.

================================================================================
PHASE 4: DUAL INDEPENDENT DEMONSTRATION VIDEOS
================================================================================
Produce TWO separate, fully playable, high-definition (1080p @ 30fps) videos in demo_recordings/:

VIDEO 1: Mobile Client Onboarding & Launch Tutorial
- Artifact: demo_recordings/01_mobile_install_and_signup.mp4
- Content:
  1. Demonstration of APK installation completion.
  2. Launching the application via:
     - Method A: Android Settings -> Apps -> KeyFlow -> Tapping the active "Open" button.
     - Method B: Tapping the "Open Installed App" browser bridge.
  3. Client Registration: Filling the Sign Up form (Email, Password) and submitting.
  4. Permissions Onboarding: Navigating to Android Accessibility settings, enabling the helper service, and returning to the active dashboard.

VIDEO 2: Web Console Credential Access & Cross-Device Sync
- Artifact: demo_recordings/02_web_cross_device_sync.mp4
- Content:
  1. Opening keyflow.tramakrishna3012.workers.dev in the browser.
  2. Signing in to the web console using the exact same mobile test credentials.
  3. Live Cross-Device Sync:
     - Mobile user inputs a note block in Google Keep.
     - Web Dashboard Typing Stream receives and renders the aggregated card after the 2.5s debounce.
     - Mobile copies a URL -> Web Clipboard tab displays the URL card with 1-click copy.
  4. Privacy Safeguards: Demonstrating that secure password fields are strictly omitted from sync streams.

================================================================================
PHASE 5: DELIVERABLE INTEGRITY
================================================================================
1. Verify both MP4 files are valid, playable containers with proper moov atom placement (libx264, yuv420p, +faststart).
2. Update CLIENT_SETUP_GUIDE.md detailing exact launch steps and web verification for client review.