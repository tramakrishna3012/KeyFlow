# KeyFlow — Product Requirements Document (PRD)

**Document Version:** 3.0  
**Status:** Approved & Production-Ready  
**Classification:** Cross-Platform Session Recovery & Enterprise Multi-Device Clipboard Platform  

---

## 1. Product Purpose & Vision

**KeyFlow** is an intelligent, local-first typing recovery manager, real-time session aggregator, and multi-device clipboard synchronization platform. Built to eliminate the friction of lost text and repetitive typing across all user applications, KeyFlow replaces naive character-by-character keylogging with clean, paragraph-level session streams and intelligent clipboard organization.

KeyFlow bridges on-device zero-knowledge security with an enterprise-grade web telemetry dashboard hosted on Cloudflare Workers and a dedicated Node.js backend. It provides users sovereign ownership over their typed history with instant text recovery, draft replay animation, and multi-device synchronization.

### Core Architecture Principles
1. **Intelligent Session Aggregation (No Keystroke Spam)**: Buffers text with a 2.5s inactivity debounce and a 60s termination boundary, transforming disjointed character events into coherent paragraph session cards.
2. **Local-First Zero Knowledge**: Data at rest is encrypted via AES-256-GCM with hardware keystore keys. Text is transmitted only with explicit encrypted cloud sync consent.
3. **Multi-Device Clipboard Synchronization**: Ingests copied snippets, automatically classifies them into Code Blocks, URLs, or Plain Text, and synchronizes them across mobile and desktop.
4. **Draft Timeline Replay**: Step-by-step scrubber and animated playback engine allowing users to reconstruct lost drafts.
5. **Intelligent Privacy Guard**: Universal automatic redaction for password inputs, OTPs, and banking applications, with strict exemptions for calculators and utility software.

---

## 2. Target Personas & Use Cases

### Persona A: Software Engineer & Technical Writer
- **Context**: Writes technical documents, drafts code snippets, and switches frequently between IDEs, browsers, and terminal apps.
- **Needs**: Instant retrieval of previously typed code blocks or clipboard URLs without database noise.
- **Solution**: Auto-classified clipboard cards with monospace syntax formatting and 1-click copy.

### Persona B: Cross-Platform Professional
- **Context**: Works across an Android phone (Motorola Edge 40) and desktop/web dashboards.
- **Needs**: Seamless synchronization of typed paragraphs, session history, and copied snippets.
- **Solution**: Encrypted Cloud Sync relay via Supabase/Node.js API and Cloudflare Workers Web Dashboard with real-time telemetry updates.

### Persona C: Privacy-Conscious Executive
- **Context**: Requires strict data sovereignty, compliance with GDPR/CCPA, and protection against credential leaks.
- **Needs**: Absolute assurance that passwords, OTPs, and credit card numbers are never logged.
- **Solution**: Automated password field exclusion, smart banking app blacklists, configurable retention auto-purge, and 1-click cryptographic data shredding.

---

## 3. Product Goals & Key Performance Indicators (KPIs)

| Objective | Metric / KPI | Target Standard | Status |
| :--- | :--- | :--- | :---: |
| **Session Capture Fidelity** | Inactivity Debounce & Ingestion Rate | 2.5s buffer with 0% dropped paragraphs | **PASS** |
| **Search Latency** | Full-text query across 10,000+ records | < 20ms response time on mobile and web | **PASS** |
| **Privacy Compliance** | False-positive leak of passwords/cards | 0 security leaks; 100% masking on sensitive fields | **PASS** |
| **System Overhead** | Background memory & CPU footprint | < 1.5% sustained CPU; < 120MB RAM on Android | **PASS** |
| **Video Playability** | Screen recording integrity & codec | 100% valid MP4 atom structure (`moov` present) | **PASS** |
| **Code Quality & CI** | Automated test pass rate & SonarQube | 100% test pass rate (110/110 Flutter, 12/12 Backend); Quality Gate Grade A | **PASS** |

---

## 4. Scope & Feature Hierarchy

### 4.1 Client-Side Session Aggregation Engine
- **Composite Key Grouping**: `appName.toLowerCase()::windowTitle.toLowerCase()::deviceName.toLowerCase()`.
- **2.5s Inactivity Debounce**: Dispatches update events only after 2.5 seconds of typing silence.
- **60s Session Boundary Terminator**: Finalizes active sessions and spawns new paragraph containers when changing apps or pausing >60s.
- **Draft Snapshots**: Captures delta checkpoints (every ~5 characters) for interactive replay.

### 4.2 Multi-Device Clipboard Manager
- **Content Classification**: Regex classification into `code`, `url`, or `text`.
- **Visual Presentation**: Code syntax containers with line numbers, clickable URL cards with domain badges, and plain text cards.
- **Actions**: Pin/Unpin favorite toggles, 1-click copy with toast feedback, and direct external link launcher.

### 4.3 Interactive Replay Draft Modal
- **Scrubber Slider**: Step forward/backward through drafting history.
- **Speed Multipliers**: 1x, 2x, 4x animated playback.
- **Delta Counter**: Real-time character and word count tracking at each draft phase.

### 4.4 Mobile Application (Flutter & Kotlin)
- **Onboarding Experience**: 3-step walkthrough explaining capture scope, security safeguards, and system permissions.
- **Home Dashboard**: Daily statistics (Snippets count, characters typed, time saved, active applications, and weekly chart).
- **Typing Stream Feed**: Grouped session cards with word/character counts, duration, favorite star, and copy triggers.
- **Floating Assistant Bot**: Draggable system overlay (`SYSTEM_ALERT_WINDOW`) with quick capture pause/resume toggle.
- **Settings & Exclusion Manager**: Installed app discovery, individual app blacklisting, high-contrast white ball switch toggles, retention purge configuration, and JSON export/delete actions.

### 4.5 Web Telemetry Dashboard (Cloudflare Workers & Express)
- **Executive Overview**: Active duration KPIs, log volume counters, productivity scores, and authorized device tallies.
- **Typing Stream**: Paragraph-level session feed with app badge, device tag, word/char counts, 1-click copy, and Replay Draft modal.
- **Clipboard History**: Synchronized clipboard feed with type filtering tabs (All, Code, URLs, Text).
- **Search & Filtering**: Multi-parameter search across dates, apps, and text content.
- **App Usage Matrix**: Visual breakdown of productive vs. non-productive app usage.
- **Admin & Org Controls**: User management, device de-authorization, and audit logging.
- **Privacy & Exclusions**: Global exclusion rules management and DSAR compliance controls.

---

## 5. Non-Functional Requirements & Security Guarantees

1. **Cryptographic Standards**: Local SQLite encrypted with SQLCipher AES-256; cloud payloads encrypted with client-side HKDF derived AES-GCM keys.
2. **Discreet Background Execution**: Background service operates under the neutral notification title *"System Sync Service"* with minimal status text.
3. **Memory & Battery Optimization**: Low-overhead event listening with aggressive debounce buffers to avoid wake-locks or battery drain.
4. **Adaptive UI Layout**: Responsive layouts for mobile portrait, horizontal/landscape, tablet, and desktop viewports.
