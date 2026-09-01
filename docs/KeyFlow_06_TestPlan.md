# KeyFlow Master End-to-End Test Plan: Mobile, Web & Multi-App Cross-Device Sync

**Document Version:** 4.0  
**Test Objective:** Comprehensive Visual & Functional Verification of KeyFlow Client Mobile App (Android/iOS), Cloudflare Web Console, Real-World Multi-App Typing Capture, Clipboard Synchronization, and Interactive Draft Replay.  
**Audience:** QA Engineers, Product Managers, Developers, Clients & End-Users.  

---

## 1. Test Architecture & Verification Standards

### 1.1 Scope & Prerequisites
* **Physical Device**: Motorola Edge 40 (Android 14 / API 34, $1080\times2400$ display).
* **Web Dashboard**: Cloudflare Workers Edge Application (`https://keyflow.tramakrishna3012.workers.dev`).
* **Backend Relay**: Node.js v18 REST API (`http://localhost:4000/api/v1` / Render Cloud Relay) & Supabase PostgreSQL with AES-256-GCM encryption.
* **Test Applications**:
  1. Google Chrome (`com.android.chrome`)
  2. Google Keep Notes (`com.google.android.keep`)
  3. Google Calculator (`com.google.android.calculator`)
  4. Native System Clipboard (`ClipboardManager`)

### 1.2 Quality & Visual Criteria
1. **Visual Clarity**: Every screen transition, card render, syntax highlight block, white ball switch knob, floating overlay bot, and draft replay animation must be visually distinct and rendered without layout shifts or overflow errors.
2. **Functional Integrity**:
   - Real-time debouncing ($2.5\text{s}$) must group continuous typing into a single paragraph container without single-keystroke database clutter.
   - Session termination ($60\text{s}$ pause or app switch) must finalize the active session and start a new container.
   - Clipboard events must capture immediately without debounce delay, auto-classifying into `code`, `url`, or `text`.
   - Web console must decrypt cloud payloads client-side using WebCrypto and render the exact same text typed on the mobile phone.
3. **Demo Video Standard**: The full test execution must be recorded into a $100\%$ valid, playable MP4 file with complete `ftyp`, `moov`, and `mdat` atom headers.

---

## 2. End-to-End Test Execution Flow (Scenario-by-Scenario)

```mermaid
flowchart TD
    subgraph "Phase 1: Setup & Onboarding"
        A1[Launch KeyFlow App] --> A2[Verify Onboarding Slides 1, 2, 3]
        A2 --> A3[Grant Accessibility & Notification Permissions]
        A3 --> A4[Sign In / Authenticate User Account]
    end

    subgraph "Phase 2: Multi-App Real-World Typing"
        B1[Open Google Keep Notes] --> B2[Type Project Roadmap Paragraph]
        B3[Open Google Chrome Browser] --> B4[Type Web Dashboard URL]
        B5[Open Google Calculator] --> B6[Type Mathematical Formula 75000 + 25000]
    end

    subgraph "Phase 3: Multi-Device Clipboard Capture"
        C1[Copy Web URL to Clipboard] --> C2[Copy JavaScript Code Snippet]
        C3[Copy Plain Text Meeting Note]
    end

    subgraph "Phase 4: Mobile App Visual & Functional Verification"
        D1[Open KeyFlow Home Dashboard] --> D2[Inspect Real-Time KPI Cards & Histogram]
        D2 --> D3[Inspect Session Typing Feed & Date Groups]
        D3 --> D4[Test 1-Click Copy with Toast Alert]
        D4 --> D5[Test App Filter Chips & Sub-20ms Search]
        D5 --> D6[Test White Ball Switches & Floating Assistant Bot]
        D6 --> D7[Test Responsive Landscape Orientation]
    end

    subgraph "Phase 5: Web Console Verification & Live Sync"
        E1[Open Web Console on Cloudflare] --> E2[Verify Synced Typing Sessions from Phone]
        E2 --> E3[Open Replay Draft Modal & Test Scrubber/Playback]
        E3 --> E4[Inspect Clipboard Feed: Syntax Code, URL Cards & Pinning]
        E4 --> E5[Verify Search, Analytics & Privacy DSAR Controls]
    end

    Phase 1 --> Phase 2 --> Phase 3 --> Phase 4 --> Phase 5
```

---

## 3. Detailed Test Cases Matrix

### Phase 1: Application Setup, Permissions & Onboarding
| Test ID | Module / Feature | Step-by-Step User Action | Expected Visual & Functional Outcome | Status |
| :--- | :--- | :--- | :--- | :---: |
| **SET-01** | First Launch & Setup | Launch KeyFlow on Android device. | Renders onboarding Slide 1 with high-contrast graphic explaining automatic text recovery and clipboard synchronization. | **PASS** |
| **SET-02** | Onboarding Navigation | Tap "Next" on Slide 1 $\rightarrow$ Slide 2 $\rightarrow$ Slide 3. | Carousel transitions smoothly with animated indicator dots; explains zero-knowledge local encryption and permission requirements. | **PASS** |
| **SET-03** | Permission Gate | Tap "Enable Accessibility" & "Allow Notifications". | Deep-links to Android Accessibility Settings; enables `KeyflowAccessibilityService`; grants `POST_NOTIFICATIONS` runtime permission. | **PASS** |
| **SET-04** | User Authentication | Enter `tramakrishna3012@gmail.com` / `#TRama1230` $\rightarrow$ Tap "Sign In". | Authenticates with backend; derives local HKDF cryptographic keys; stores master token in Android Keystore; redirects to Home Dashboard. | **PASS** |

---

### Phase 2: Multi-App Real-World Typing Capture
| Test ID | Application Tested | User Typing Action | Expected Aggregation & Privacy Behavior | Status |
| :--- | :--- | :--- | :--- | :---: |
| **TYP-01** | **Google Keep Notes**<br>(`com.google.android.keep`) | Open Keep $\rightarrow$ Create note $\rightarrow$ Type:<br>`"KeyFlow Project Roadmap: Intelligent paragraph session debouncing and multi-device clipboard synchronization."` | Intercepted by accessibility hook; aggregated with $2.5\text{s}$ debounce; packaged into a single paragraph session card under app name `Google Keep`. | **PASS** |
| **TYP-02** | **Google Chrome**<br>(`com.android.chrome`) | Open Chrome $\rightarrow$ Tap URL bar $\rightarrow$ Type:<br>`"https://keyflow.tramakrishna3012.workers.dev/dashboard"` | Intercepted; debounced; stored under `Chrome` with window title context. | **PASS** |
| **TYP-03** | **Google Calculator**<br>(`com.google.android.calculator`) | Open Calculator $\rightarrow$ Type numeric formula:<br>`"75000 + 25000 = 100000"` | **ZERO FALSE REDACTION**: Smart privacy filter recognizes calculator package and permits complete numeric formulas without masking. | **PASS** |

---

### Phase 3: Multi-Device Clipboard Capture & Classification
| Test ID | Content Type | Content Copied to Clipboard | Expected Classification & Storage Behavior | Status |
| :--- | :--- | :--- | :--- | :---: |
| **CLP-01** | **Web URL** | `"https://keyflow.tramakrishna3012.workers.dev"` | Hooked immediately by `ClipboardManager` listener; auto-classified as `url`; stored with domain metadata. | **PASS** |
| **CLP-02** | **Code Snippet** | `"const aggregator = new SessionAggregator({ debounceMs: 2500 });"` | Hooked instantly; auto-classified as `code`; preserved with indentation and language tokens. | **PASS** |
| **CLP-03** | **Plain Text** | `"Client Meeting Notes: Cross-platform synchronization verified 100%."` | Hooked instantly; auto-classified as `text`; persisted without debounce delay. | **PASS** |

---

### Phase 4: Mobile App Visual & Functional Verification
| Test ID | Screen / Component | Interactive QA Action | Expected Visual & Functional Verification | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **MOB-01** | **Home Dashboard** | Inspect KPI Cards & Weekly Histogram. | Real-time counters reflect newly typed sessions, character count totals, and time saved estimate; weekly bar chart displays today's volume. | **PASS** |
| **MOB-02** | **Session Typing Feed** | Switch to History Tab $\rightarrow$ Inspect session list. | Hierarchical layout: Sticky `TODAY` header with total count pill; distinct paragraph cards for `Google Keep`, `Chrome`, and `Calculator` with word/character counts and timestamps. | **PASS** |
| **MOB-03** | **1-Click Copy** | Tap Copy icon button on any session card. | Copies decrypted paragraph to device clipboard; displays green toast alert: *"Copied to clipboard"*. | **PASS** |
| **MOB-04** | **Filter Chips** | Tap `All Apps`, `Chrome`, `Calculator`, `Keep` chips. | Real-time filter isolates session cards belonging exclusively to the selected application. | **PASS** |
| **MOB-05** | **Sub-20ms Search** | Type `"75000"` in search input bar. | Real-time query execution in $<20\text{ms}$; isolates matching Calculator session; tap `X` clears search instantly. | **PASS** |
| **MOB-06** | **Snippet Details** | Tap on session card body. | Opens Snippet Detail modal showing complete un-truncated text, character/word counters, Share, and Translate actions. | **PASS** |
| **MOB-07** | **White Ball Switches** | Navigate to Settings $\rightarrow$ Toggle "Pause Typing Capture". | Toggle knob renders a **prominent high-contrast white ball** (`Colors.white`); pauses capture and updates status badge to amber *"Paused"*. | **PASS** |
| **MOB-08** | **Floating Overlay Bot** | In Settings $\rightarrow$ Toggle "Floating Assistant Bubble". | Spawns a draggable semi-transparent $56\text{dp}$ circular bot on Android screen; dragging snaps smoothly to screen edges; single tap expands quick menu. | **PASS** |
| **MOB-09** | **Landscape Layout** | Rotate device to landscape orientation ($90^\circ$). | Layout adapts from bottom navigation to a scrollable `NavigationRail` sidebar with zero vertical overflow errors. | **PASS** |

---

### Phase 5: Web Console Verification & Real-Time Sync
| Test ID | Screen / Tab | Interactive QA Action | Expected Visual & Functional Verification | Status |
| :--- | :--- | :--- | :--- | :--- :---: |
| **WEB-01** | **Public Landing & Auth** | Open `https://keyflow.tramakrishna3012.workers.dev` $\rightarrow$ Click "Sign In / Register". | Opens glassmorphic Auth modal; submit `tramakrishna3012@gmail.com` $\rightarrow$ reveals full 7-tab sidebar navigation. | **PASS** |
| **WEB-02** | **Executive Overview** | Inspect Tab 1 (Overview). | Renders enterprise KPIs: Active Duration, Log Volumes, Productivity Score, and Authorized Device badge (`📱 Motorola Edge 40`). | **PASS** |
| **WEB-03** | **Typing Stream Feed** | Switch to Tab 2 (Typing Stream) $\rightarrow$ Click "Refresh Telemetry". | Pulls and decrypts (via WebCrypto) the exact sessions typed on Motorola Edge 40 (`Google Keep`, `Chrome`, `Calculator`). | **PASS** |
| **WEB-04** | **Replay Draft Modal** | Click "Replay Draft" on Keep session card $\rightarrow$ Drag scrubber slider $\rightarrow$ Click "Play". | Opens interactive modal; dragging scrubber reconstructs drafting steps; animated playback runs at `1x`, `2x`, and `4x` speeds with real-time character count. | **PASS** |
| **WEB-05** | **Clipboard Feed** | Switch to Tab 3 (Clipboard History). | Classified cards: Code snippet in monospace box with line numbers, URL card with domain badge and "Open Link" button, Plain text card. | **PASS** |
| **WEB-06** | **Search & Filtering** | Switch to Tab 4 (Search) $\rightarrow$ Execute query. | Returns structured tabular records with timestamps, device names, and copy buttons. | **PASS** |
| **WEB-07** | **Privacy & DSAR** | Switch to Tab 7 (Privacy & Exclusions). | Displays package blacklist management and 1-Click GDPR DSAR data shredding button. | **PASS** |

---

## 4. Verification & Recording Artifacts
* **Master Demo Video**: `demo_recordings/master_e2e_sync_demo.mp4` (100% Playable, H.264 MP4, valid `moov` atom header).
* **Manual QA Audit Report**: `MANUAL_TESTING_REPORT.md` (Detailed step-by-step logs and observations).
