# KeyFlow — Comprehensive End-to-End Test Plan (Button-by-Button & Feature-by-Feature)

**Document Version:** 2.0  
**Test Scope:** 100% Surface Coverage across Mobile Application (Flutter/Android) and Web Dashboard (Cloudflare Workers / Express / Supabase)  
**Execution Type:** Manual QA Test Specification & Automated Test Matrix  

---

## 1. Test Strategy & Quality Standards

This test plan defines the step-by-step verification procedures for **every single button, input field, toggle switch, dropdown, modal, and interactive feature** in the KeyFlow ecosystem.

### Severity Classifications
- **Blocker (S1)**: Crashes, complete capture failure, encryption failure, or sensitive credential leak.
- **Major (S2)**: Button/Feature unresponsive, sync failure, false-positive privacy masking, or navigation trap.
- **Minor (S3)**: UI misalignment, incorrect badge count, missing animation, or delayed toast feedback.
- **Cosmetic (S4)**: Typo, font size inconsistency, or slight color deviation.

---

## 2. Mobile Application Test Suite (Flutter / Android)

### Module 1: Application Splash & Onboarding Flow

| Test ID | Screen / Component | Button / Control Under Test | Action & Input Steps | Expected Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **MOB-ONB-01** | Splash Screen | Initial Cold Launch | Launch app with clean app data (`pm clear`) | Displays KeyFlow animated logo, initializes secure storage, navigates to Onboarding Slide 1. |
| **MOB-ONB-02** | Onboarding Slide 1 | `Next` Button | Tap "Next" button at bottom of Slide 1 (What KeyFlow Does) | Smoothly transitions to Slide 2; progress indicator advances to step 2/3. |
| **MOB-ONB-03** | Onboarding Slide 1 | `Skip` Button | Tap "Skip" link in upper right | Bypasses slides and directly displays Onboarding Slide 3 (Permissions). |
| **MOB-ONB-04** | Onboarding Slide 2 | `Next` Button | Tap "Next" button on Slide 2 (Privacy & Encryption) | Smoothly transitions to Slide 3; progress indicator advances to step 3/3. |
| **MOB-ONB-05** | Onboarding Slide 2 | Back Swipe Gesture | Swipe right from left edge | Returns smoothly to Slide 1 without state reset. |
| **MOB-ONB-06** | Onboarding Slide 3 | `Get Started` Button | Tap "Get Started" primary action button | Navigates to Authentication screen; sets onboarding completed flag in `SharedPreferences`. |
| **MOB-ONB-07** | Onboarding Screen | Landscape Orientation | Rotate device to landscape (1080x600) | Content is wrapped in `SingleChildScrollView`, form fits within 440dp width, zero render overflow errors. |

---

### Module 2: Authentication & Account Binding

| Test ID | Screen / Component | Button / Control Under Test | Action & Input Steps | Expected Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **MOB-AUT-01** | Auth Screen | `Sign Up` Mode Toggle | Tap "Don't have an account? Sign Up" | Switches form to Sign Up mode; reveals "Full Name" and "Organization" inputs. |
| **MOB-AUT-02** | Auth Screen | Full Name Field | Input "Rama Krishna" | Accepts unicode characters; clears validation error state. |
| **MOB-AUT-03** | Auth Screen | Email Field (Validation) | Input "invalid-email" and tap outside | Displays inline validation error: *"Please enter a valid email address"*. |
| **MOB-AUT-04** | Auth Screen | Email Field (Valid) | Input `tramakrishna3012@gmail.com` | Accepts email; error state disappears. |
| **MOB-AUT-05** | Auth Screen | Password Obscure Toggle | Tap eye icon inside Password field | Toggles password visibility between bullet masking and clear text. |
| **MOB-AUT-06** | Auth Screen | Password Field (Short) | Input "123" | Displays error: *"Password must be at least 8 characters"*. |
| **MOB-AUT-07** | Auth Screen | `Create Account` Button | Tap "Create Account" with valid registration details | Shows loading spinner; registers user in backend/Supabase; redirects to Home Dashboard. |
| **MOB-AUT-08** | Auth Screen | `Sign In` Button | Tap "Sign In" with `tramakrishna3012@gmail.com` / `#TRama1230` | Authenticates user; derives encryption keys; redirects to Home Dashboard. |
| **MOB-AUT-09** | Auth Screen | `Continue in Offline Mode` | Tap "Continue in Offline Mode" button | Bypasses cloud login; initializes local SQLCipher DB in zero-knowledge offline mode. |

---

### Module 3: Home Screen & Telemetry Dashboard

| Test ID | Screen / Component | Button / Control Under Test | Action & Input Steps | Expected Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **MOB-HOM-01** | Home AppBar | Profile Avatar Button | Tap user initials avatar (e.g. `K`) in top right | Opens Profile & Cloud Sync Modal smoothly. |
| **MOB-HOM-02** | Metric Grid | `Snippets` KPI Card | Inspect total snippets count card | Displays current total count of saved entries with blue indicator dot. |
| **MOB-HOM-03** | Metric Grid | `Chars today` KPI Card | Inspect characters count card | Displays sum of characters typed today with emerald green dot. |
| **MOB-HOM-04** | Metric Grid | `Time saved` KPI Card | Inspect time saved card | Calculates productivity metrics (e.g. `1m`, `15m`) with amber dot. |
| **MOB-HOM-05** | Metric Grid | `Active apps` KPI Card | Inspect active applications card | Displays count of unique applications tracked today with rose dot. |
| **MOB-HOM-06** | Activity Section | Histogram Bar Chart | Inspect 7-day typing histogram | Renders bar heights proportional to keystroke volume for M, T, W, T, F, S, S. |
| **MOB-HOM-07** | Recent Snippets | `See all` Action Button | Tap "See all" link in section header | Navigates directly to History Tab (bottom nav index 1). |
| **MOB-HOM-08** | Recent Snippets | Quick Copy Icon Button | Tap copy icon on any recent snippet card | Copies snippet to clipboard; triggers haptic feedback and toast: *"Copied to clipboard"*. |

---

### Module 4: Typing History & Snippet Management

| Test ID | Screen / Component | Button / Control Under Test | Action & Input Steps | Expected Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **MOB-HIS-01** | History Screen | Search Input Field | Type search query (e.g. `"75000"`) | Executes real-time search (<20ms); updates list to matching entries instantly. |
| **MOB-HIS-02** | History Screen | Clear Search Button (`X`) | Tap `X` clear icon in search bar | Clears search text field; restores full unfiltered history list. |
| **MOB-HIS-03** | History Screen | `All Apps` Filter Chip | Tap "All Apps" chip | Sets active filter to All; displays all application groups. |
| **MOB-HIS-04** | History Screen | App Filter Chip (e.g. `Chrome`) | Tap "Chrome" filter chip | Highlights chip; filters list to show only entries from `com.android.chrome`. |
| **MOB-HIS-05** | History Screen | Date Header Pill Badge | Inspect Date group header (e.g. `TODAY`) | Displays sticky date header with total count badge (e.g. `3 entries`). |
| **MOB-HIS-06** | History Screen | App Header Card | Inspect App header inside date section | Displays app package icon, bold app name (*Chrome*), package ID (`com.android.chrome`). |
| **MOB-HIS-07** | History Screen | 1-Click Copy Icon Button | Tap copy button on snippet row | Copies text to clipboard; displays toast *"Copied to clipboard"*. |
| **MOB-HIS-08** | History Screen | Snippet Row Tap | Tap on snippet text body | Navigates to Snippet Detail Screen with full expanded content. |
| **MOB-HIS-09** | Snippet Detail | Copy Action Button | Tap "Copy Text" in detail view | Copies full un-truncated text to clipboard. |
| **MOB-HIS-10** | Snippet Detail | Delete Action Button | Tap "Delete Snippet" in detail view | Prompts confirmation; deletes record from local SQLCipher DB; pops view. |
| **MOB-HIS-11** | Snippet Detail | Back Button | Tap back arrow in detail AppBar | Returns to History list without losing search/filter scroll position. |

---

### Module 5: Real-Time Capture & Privacy Filtering

| Test ID | Scenario | Steps to Execute | Expected Behavior |
| :--- | :--- | :--- | :--- |
| **MOB-CAP-01** | Chrome Typing Capture | Open Chrome, type `https://keyflow.dev/sync-test`, press Enter | Captured via `AccessibilityService`; debounced (800ms); stored in SQLCipher; visible in History. |
| **MOB-CAP-02** | Calculator Typing | Open Calculator, type `75000 + 25000 = 100000` | **NO REDACTION**: Captured accurately as clear text formula/number `2500175000`. |
| **MOB-CAP-03** | Copied Text Capture | Copy text anywhere on device (`"KeyFlow Demo"`) | `ClipboardManager` listener captures copied text immediately under `sourceApp: "Clipboard"`. |
| **MOB-CAP-04** | Password Field Masking | Type into any OS password field (`TYPE_TEXT_VARIATION_PASSWORD`) | Input is discarded completely at native accessibility layer; 0 records stored. |
| **MOB-CAP-05** | Banking App Exclusion | Open banking app (e.g. Paytm / GPay) | Package is detected in `PAYMENT_BANKING_APPS`; capture is automatically suppressed. |

---

### Module 6: Settings Screen & White Ball Switch Knobs

| Test ID | Screen / Component | Button / Control Under Test | Action & Input Steps | Expected Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **MOB-SET-01** | Settings | `Pause Typing Capture` Switch | Toggle "Pause Typing Capture" switch | Switch thumb knob slides smoothly; renders **prominent white ball** (`Colors.white`); pauses capture service; updates notification text to *"Paused"*. |
| **MOB-SET-02** | Settings | `Accessibility Settings` Tile | Tap "Open Android Accessibility Settings" | Deep-links directly to Android OS Accessibility Settings screen; refreshes active status chip upon return. |
| **MOB-SET-03** | Settings | `Battery Optimization` Tile | Tap "Background Battery Optimization" | Deep-links to Android system battery optimization un-restriction dialog. |
| **MOB-SET-04** | Settings | `Floating Assistant` Switch | Toggle "Floating Assistant Bubble" switch | Requests `SYSTEM_ALERT_WINDOW` permission; launches draggable overlay bot bubble. |
| **MOB-SET-05** | Settings | `Excluded Applications` Tile | Tap "Excluded Applications" row | Navigates to Excluded Apps management screen. |
| **MOB-SET-06** | Settings | `Auto-exclude Passwords` Switch| Inspect password exclusion switch | Locked ON with green track and white ball knob; cannot be disabled. |
| **MOB-SET-07** | Settings | `Retention Period` Dropdown | Tap Retention Period picker (e.g. select `7 Days`) | Updates retention setting; triggers immediate local purge of entries older than 7 days. |
| **MOB-SET-08** | Settings | `Autocorrect Suggestions` Switch| Toggle Autocorrect switch | Toggles inline autocorrection engine; switch displays white ball knob. |
| **MOB-SET-09** | Settings | `Export History Data` Button | Tap "Export History Data" | Generates standard JSON export file; triggers system share sheet. |
| **MOB-SET-10** | Settings | `Clear All History` Button | Tap "Clear All History" | Displays destructive confirmation modal; on confirm, shreds all local records. |

---

### Module 7: Excluded Applications & Profile Modal

| Test ID | Screen / Component | Button / Control Under Test | Action & Input Steps | Expected Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **MOB-EXC-01** | Excluded Apps | Search App Field | Type `"Chrome"` in search field | Filters installed applications list to match package `com.android.chrome`. |
| **MOB-EXC-02** | Excluded Apps | App Toggle Switch | Toggle switch next to Chrome | Toggles exclusion state; renders white ball thumb knob; updates native exclusion blacklist immediately. |
| **MOB-EXC-03** | Excluded Apps | Back Button | Tap back arrow in AppBar | Returns to Settings screen; updates excluded apps count (e.g. `1 Excluded`). |
| **MOB-PRF-01** | Profile Modal | `Encrypted Cloud Sync` Switch | Toggle "Encrypted Cloud Sync" switch | Renders white ball knob; derives HKDF client key; enables Supabase synchronization. |
| **MOB-PRF-02** | Profile Modal | `Close` / Outside Tap | Tap outside modal or swipe down | Dismisses profile modal cleanly. |

---

## 3. Web Application Test Suite (`https://keyflow.tramakrishna3012.workers.dev`)

### Module 8: Public Header, Navigation & Authentication Modal

| Test ID | Screen / Component | Button / Control Under Test | Action & Input Steps | Expected Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **WEB-NAV-01** | Header | KeyFlow Brand Logo | Click KeyFlow logo in top-left | Refreshes dashboard state or navigates to Executive Overview. |
| **WEB-NAV-02** | Header | `Sign In / Register` Button | Click "Sign In / Register" in header | Opens Authentication Modal with smooth backdrop blur. |
| **WEB-AUT-01** | Auth Modal | `Create Account` Tab | Click "Create Account" tab header | Switches to registration tab; displays Name, Org, Email, Password inputs. |
| **WEB-AUT-02** | Auth Modal | `Sign In` Tab | Click "Sign In" tab header | Switches to login tab; displays Email and Password inputs. |
| **WEB-AUT-03** | Auth Modal | Form Inputs & Submit | Input `tramakrishna3012@gmail.com` / `#TRama1230` and click "Sign In" | Authenticates via backend; sets session token in `localStorage`; reveals full sidebar tabs. |
| **WEB-AUT-04** | Auth Modal | Close Modal Button (`X`) | Click `X` icon in modal header | Dismisses modal without logging in. |

---

### Module 9: Executive Overview & Cross-Device Typing History

| Test ID | Screen / Component | Button / Control Under Test | Action & Input Steps | Expected Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **WEB-EXE-01** | Executive Tab | Metric Cards | Inspect 4 KPI cards | Displays Active Duration, Total Activity Logs, Focus Score, Authorized Devices. |
| **WEB-EXE-02** | Executive Tab | Activity Charts | Inspect activity bar chart | Visualizes hourly/daily typing volume accurately. |
| **WEB-HIS-01** | Typing History Tab | `Refresh Telemetry` Button | Click "Refresh Telemetry" primary button | Triggers loading spinner; fetches new encrypted records from Supabase; decrypts client-side via WebCrypto; updates entry count. |
| **WEB-HIS-02** | Typing History Tab | Search Input Field | Type `"2500175000"` in search input | Real-time filter isolates matching Calculator typing entry. |
| **WEB-HIS-03** | Typing History Tab | App Filter Dropdown | Select "Chrome" from app filter dropdown | Filters view to display only Chrome typing entries. |
| **WEB-HIS-04** | Typing History Tab | Filter Badge Chips | Click "All 18" or "Chrome 18" badge chips | Instantly sets active filter to selected badge. |
| **WEB-HIS-05** | Typing History Tab | Device Badge | Inspect application card header | Displays hardware badge (e.g. `📱 Motorola Edge 40`). |
| **WEB-HIS-06** | Typing History Tab | 1-Click Copy Button | Click "Copy" button on any snippet row | Copies decrypted text to browser clipboard; displays copy confirmation feedback. |

---

### Module 10: Deep Search, Admin & Privacy Controls

| Test ID | Screen / Component | Button / Control Under Test | Action & Input Steps | Expected Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **WEB-SCH-01** | Search & Filtering | `Search History` Button | Enter query, select date range, click "Search History" | Queries database; renders paginated results table with timestamps and app names. |
| **WEB-SCH-02** | Search & Filtering | `Export Results` Button | Click "Export CSV" / "Export JSON" | Downloads filtered result records as standard CSV/JSON file. |
| **WEB-ADM-01** | Admin Controls | User Management Table | Inspect users table | Displays user name, email, assigned role (`Admin`), last active timestamp. |
| **WEB-ADM-02** | Admin Controls | Role Change Dropdown | Change user role dropdown | Updates role permissions in database; logs event in audit table. |
| **WEB-PRV-01** | Privacy Tab | `Add Exclusion` Button | Input package `com.example.test` and click "Add Exclusion" | Adds package to global exclusion table; syncs to connected devices. |
| **WEB-PRV-02** | Privacy Tab | GDPR `Export My Data` | Click "Export My Data" button | Generates full DSAR encrypted JSON archive for the authenticated user. |
| **WEB-SGO-01** | Sidebar Footer | `Sign Out` Button | Click "Sign Out" button in bottom left sidebar | Clears authentication token; resets state; returns to public landing view. |

---

## 4. End-to-End Cross-Platform Synchronization Matrix

| Test ID | Cross-Platform Scenario | Verification Steps | Pass Criteria |
| :--- | :--- | :--- | :--- |
| **SYNC-01** | Mobile Typing to Web Sync | Type equation in Calculator on Motorola Edge 40 -> Tap Refresh on Web | Equation `2500175000` appears on Web with `📱 Motorola Edge 40` badge in < 3s. |
| **SYNC-02** | Mobile Clipboard to Web Sync | Copy URL in Chrome on Motorola Edge 40 -> Refresh Web | URL appears under `Clipboard` header on Web Dashboard. |
| **SYNC-03** | End-to-End Cryptography | Inspect network payload transmitted to Supabase | Payload is ciphertext (`gSQVN...`) with IV; zero cleartext readable over wire. |
| **SYNC-04** | Web Client Decryption | Inspect decrypted DOM element in Web Dashboard | Plaintext is reconstructed in memory via `window.crypto.subtle.deriveKey`. |
