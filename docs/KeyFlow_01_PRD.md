# KeyFlow — Product Requirements Document (PRD)

**Document Version:** 2.0  
**Status:** Approved & Implemented  
**Classification:** Enterprise Internal / Single-Tenant Telemetry & Local Productivity Platform  

---

## 1. Product Purpose & Vision

**KeyFlow** is an intelligent, local-first typing history manager, real-time clipboard monitor, and productivity telemetry platform. It captures, indexes, encrypts, and organizes text inputs and copied snippets across all applications on Android, Desktop, and Web. 

KeyFlow bridges on-device zero-knowledge security with an optional enterprise-grade Cloudflare Workers web telemetry dashboard, giving users full sovereign ownership over their typed history while providing productivity insights, fast search, translation assistance, and instant 1-click text reuse.

### Core Principles
1. **User Consent & Transparency**: Explicit onboarding walkthroughs, discreet notifications, and zero stealth monitoring.
2. **Local-First Zero Knowledge**: Data at rest is encrypted via SQLCipher AES-256 with hardware keystore keys. Text is never sent to external servers without explicit encrypted cloud sync consent.
3. **Frictionless Text Recovery**: 1-click clipboard copy, instant full-text search (<20ms), and 2-level hierarchical snippet grouping.
4. **Intelligent Privacy Guard**: Universal automatic redaction for password inputs and banking applications, with strict exemptions for calculators and utility software.

---

## 2. Target Personas & Use Cases

### Persona A: High-Volume Office & Support Operator
- **Context**: Types hundreds of emails, customer tickets, and documentation paragraphs daily across multiple applications.
- **Needs**: Instant retrieval of previously typed responses ("What was the exact formula or boilerplate I sent yesterday?").
- **Solution**: 2-level grouped history (Date → App), real-time search, and 1-click copy.

### Persona B: Cross-Device Professional
- **Context**: Switches between an Android mobile device and a desktop/web environment.
- **Needs**: Seamless synchronization of typed snippets and clipboard history across platforms.
- **Solution**: Encrypted Cloud Sync relay via Supabase and Cloudflare Workers Web Dashboard with real-time telemetry refreshing.

### Persona C: Privacy-Conscious Executive
- **Context**: Requires strict data sovereignty, compliance with GDPR/CCPA, and protection against unauthorized credential harvesting.
- **Needs**: Absolute assurance that passwords, OTPs, and credit card numbers are never logged.
- **Solution**: Automated password field exclusion, smart banking app blacklists, configurable retention auto-purge, and 1-click cryptographic data shredding.

---

## 3. Product Goals & Key Performance Indicators (KPIs)

| Objective | Metric / KPI | Target Standard |
| :--- | :--- | :--- |
| **Typing Capture Reliability** | Keystroke & Debounce Ingestion Rate | > 99.8% capture fidelity without missing characters |
| **Search Latency** | Full-text query across 5,000+ records | < 20ms response time on mobile and web |
| **Privacy Compliance** | False-positive leak of passwords/cards | 0 security leaks; 100% masking on sensitive fields |
| **System Overhead** | Background memory & CPU footprint | < 1.5% sustained CPU; < 120MB RAM on Android |
| **Video Playability** | Screen recording integrity & codec | 100% valid MP4 atom structure (`moov` present) |
| **Code Quality & CI** | Automated test pass rate & SonarQube | 100% test pass rate (108/108 Flutter, 8/8 Backend); Quality Gate Passed |

---

## 4. Scope & Feature Hierarchy

### 4.1 Mobile Application (Flutter & Kotlin)
- **Onboarding Experience**: 3-step informative walkthrough explaining capture scope, security safeguards, and system permissions.
- **Authentication**: Email/Password authentication, offline mode fallback, and biometric/token binding.
- **Home Dashboard**: Dynamic daily statistics (Snippets count, characters typed, time saved, active applications, and weekly activity chart).
- **Typing History**: Grouped under Date headers (*Today*, *Yesterday*, *Date*) with per-app cards, package badges, relative timestamps, and 1-click copy affordances.
- **Clipboard Monitoring**: Native `ClipboardManager` hook capturing copied text snippets instantly.
- **Floating Assistant Bot**: Draggable system overlay (`SYSTEM_ALERT_WINDOW`) with quick capture pause/resume toggle and accessibility diagnostic shortcuts.
- **Settings & Exclusion Manager**: Installed app discovery, individual app blacklisting, high-contrast white ball switch toggles, retention purge configuration, and JSON export/delete actions.
- **Assist Modules**: Contextual emoji assistance and offline/online translation tools.

### 4.2 Web Telemetry Dashboard (Cloudflare Workers & Express)
- **Executive Overview**: Enterprise dashboard with active duration KPIs, log volume counters, productivity scores, and authorized device tallies.
- **Cross-Device Typing History**: Pure typing logs with device tags (`📱 Motorola Edge 40`), app headers, and decrypted snippet previews.
- **Search & Filtering**: Multi-parameter search across dates, apps, and text content.
- **App Usage Breakdown**: Visual breakdown of productive vs. non-productive app usage.
- **Admin & Org Controls**: User management, device de-authorization, and audit logging.
- **Privacy & Exclusions**: Global exclusion rules management and DSAR compliance controls.

---

## 5. Non-Functional Requirements & Security Guarantees

1. **Cryptographic Standards**: Local SQLite encrypted with SQLCipher AES-256; cloud payloads encrypted with client-side HKDF derived AES-GCM keys.
2. **Discreet Background Execution**: Background service operates under the neutral notification title *"System Sync Service"* with minimal status text.
3. **Memory & Battery Optimization**: Low-overhead event listening with aggressive debounce buffers to avoid wake-locks or battery drain.
4. **Adaptive UI Layout**: Responsive layouts for mobile portrait, horizontal/landscape, tablet, and desktop viewports.
