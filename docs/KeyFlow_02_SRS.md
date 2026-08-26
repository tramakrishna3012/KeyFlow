# KeyFlow — Software Requirements Specification (SRS)

**Version:** 1.0
**Format basis:** IEEE 830-style, adapted for a small-team internal release

---

## 1. Introduction

### 1.1 Purpose
This SRS defines the functional and non-functional requirements for KeyFlow v1, a cross-platform local typing-history, autocorrection, translation, and emoji-assist tool for a small internal user group.

### 1.2 Scope
Covers client applications for Windows, macOS, Android, and iOS, the local data layer on each device, and the optional translation relay service. Excludes any centralized monitoring, admin dashboard, or multi-user account system — each install is independent and single-user.

### 1.3 Definitions & Acronyms
- **Capture Engine** — the platform-specific module that observes typed text on a device.
- **History Store** — the encrypted local database holding captured text and snippets.
- **Consent Flow** — the mandatory onboarding sequence a user completes before capture begins.
- **Exclusion List** — user- and system-defined apps/fields KeyFlow never captures from.
- **Relay** — the thin backend service that forwards translation requests without storing content.

### 1.4 References
KeyFlow PRD v1.0, KeyFlow TRD v1.0, KeyFlow Architecture v1.0.

---

## 2. Overall Description

### 2.1 Product Perspective
KeyFlow is a standalone client application per platform, sharing a common Flutter-based UI/business-logic layer, with native per-platform modules for capture and secure storage (see Architecture doc for the platform-channel boundary). There is no central server for core functionality; the only network-dependent feature is optional cloud translation fallback.

### 2.2 Product Functions (Summary)
FR groups: Capture, History & Search, Autocorrect, Translation, Emoji, Consent & Visibility, Data Lifecycle, Settings.

### 2.3 User Characteristics
Small group of trusted, technically-comfortable office users. No assumption of admin/IT support beyond initial install.

### 2.4 Constraints
- iOS capture is limited to KeyFlow's own custom keyboard extension (platform sandboxing; not a design choice).
- No feature may transmit captured text off-device without an explicit, per-use user action (translation opt-in).
- All persistent typed content must be encrypted at rest.

### 2.5 Assumptions & Dependencies
- Users have local admin rights to install and grant OS permissions on their own machines.
- Devices meet minimum OS versions (see TRD §3).

---

## 3. Specific Requirements

### 3.1 Functional Requirements

**Capture**
- **FR-1**: The system shall capture typed text only after the user completes the Consent Flow and grants the platform-required permission.
- **FR-2**: The system shall display a persistent, unambiguous visual indicator whenever capture is active (tray icon, menu bar icon, or system notification depending on platform).
- **FR-3**: The system shall exclude capture from any app/field on the Exclusion List, and from any field the OS marks as a secure/password field where that signal is exposed.
- **FR-4**: The system shall allow the user to add or remove apps from the Exclusion List at any time, taking effect immediately.
- **FR-5**: On iOS, capture shall occur only while the user has actively selected the KeyFlow keyboard as their active input method.

**History & Search**
- **FR-6**: The system shall store captured text entries locally, encrypted at rest, each tagged with source app, timestamp, and device.
- **FR-7**: The system shall provide a quick-access search (global hotkey on desktop, in-app on mobile) returning matching history entries ranked by recency and relevance.
- **FR-8**: The system shall allow one-action reinsertion of a selected history entry at the current cursor position.
- **FR-9**: The system shall allow the user to manually delete individual history entries or clear all history.
- **FR-10**: The system shall enforce a configurable retention period (default 30 days), automatically purging entries older than the configured window.

**Autocorrection**
- **FR-11**: The system shall suggest corrections for likely typographical errors as the user types, using a local dictionary/model.
- **FR-12**: The user shall be able to accept, dismiss, or permanently ignore a given suggestion.
- **FR-13**: Autocorrection shall be toggleable on/off globally and per-app.

**Translation**
- **FR-14**: The system shall allow the user to select text (live or from history) and request translation to a chosen target language.
- **FR-15**: Translation shall default to an on-device engine; any cloud-based fallback shall require explicit per-use confirmation and shall not persist the source text on the server side beyond the request lifecycle.
- **FR-16**: The system shall display which engine (on-device vs. cloud) handled a given translation.

**Emoji**
- **FR-17**: The system shall suggest contextually relevant emoji based on the text being typed.
- **FR-18**: The system shall provide a searchable emoji picker accessible via hotkey or UI control.

**Consent, Visibility & Control**
- **FR-19**: The Consent Flow shall, in plain language, disclose what is captured, where it's stored, retention defaults, and how to review/delete it, before requesting the OS permission prompt.
- **FR-20**: The system shall provide an in-app view of exactly what has been captured, at any time.
- **FR-21**: The system shall provide a one-click "export my data" and "delete all my data" action.
- **FR-22**: Uninstalling the application shall remove the local History Store and revoke any OS permissions the app can programmatically release.

### 3.2 Non-Functional Requirements

| Category | Requirement |
|---|---|
| Performance | Suggestion/autocorrect latency < 50ms perceived; search results < 200ms for 100k entries |
| Resource usage | Background capture service: < 1% sustained CPU, < 150MB RAM |
| Security | AES-256 encryption at rest; encryption key stored in OS-native secure storage (Keychain/Keystore/Credential Manager) |
| Reliability | Capture engine shall auto-restart after a crash without data loss of already-committed entries |
| Portability | Shared business logic/UI in Flutter; platform-specific capture modules isolated behind a common interface |
| Usability | First-run consent flow completable in under 2 minutes; no capture occurs before consent is given |
| Auditability | Every permission grant/revoke and exclusion-list change is logged locally with a timestamp, viewable by the user |

### 3.3 External Interface Requirements
- **UI**: Native look-and-feel per platform (system tray/menu bar on desktop, notification + settings screen on Android, keyboard extension + container app on iOS).
- **Hardware**: No special hardware; standard desktop/mobile input devices.
- **Software interfaces**: OS Accessibility/Input Monitoring APIs, OS secure keychain/keystore APIs, optional translation API.
- **Communications**: HTTPS only, for translation relay traffic exclusively; no other network traffic by default.

---

## 4. Data Requirements

- Local encrypted database per device (no cross-device sync in v1).
- Data fields: entry text, source app identifier, timestamp, language (if translated), exclusion-list state at time of capture.
- Retention: configurable, default 30 days, hard cap enforced by scheduled local purge job.
- No entry is ever transmitted off-device except the specific selected text for an explicit, user-initiated cloud translation request.

## 5. Appendix — Traceability

Each FR above maps to a corresponding acceptance test in the Test Plan (§4) and a corresponding module in the Architecture document (§3-4).
