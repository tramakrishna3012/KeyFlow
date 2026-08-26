# KeyFlow — Technical Requirements Document (TRD)

**Version:** 1.0

---

## 1. Purpose

This document defines the platform-level technical constraints, security requirements, and distribution requirements that the PRD/SRS must be built within. Read this before designing any capture-related feature — several requirements below are *hard platform limits*, not preferences.

## 2. Platform Capture Matrix (authoritative)

| Platform | Capture mechanism | Visibility to device user | Notes |
|---|---|---|---|
| **iOS** | Custom keyboard extension only | User must actively select KeyFlow as their keyboard (Settings → General → Keyboard); "Allow Full Access" toggle is user-controlled | No third-party app can observe keystrokes in other apps or the system keyboard — this is enforced by iOS sandboxing and cannot be worked around. Design the product around this ceiling, don't fight it. |
| **Android** | AccessibilityService | Mandatory persistent notification while active; must be enabled manually in Settings → Accessibility | Google Play policy requires clear disclosure of accessibility-service use in the store listing if distributed there; internal/sideloaded distribution (§7) is recommended for this deployment |
| **macOS** | CGEventTap under the Accessibility permission | User must grant Accessibility permission in System Settings → Privacy & Security; macOS shows the app in that list persistently | Same mechanism used by legitimate utilities (e.g., window managers, text expanders) |
| **Windows** | Low-level keyboard hook (`WH_KEYBOARD_LL`) or Text Services Framework | No OS permission prompt by default — visibility must be built in deliberately (tray icon, Task Manager process name, Startup Apps entry) | Because this pattern has no forced OS prompt, it is exactly what AV heuristics scrutinize; see §6 |

**Non-negotiable rule:** on every platform, KeyFlow must never suppress, hide, or work around the OS's own disclosure mechanism (Android's notification, macOS's Accessibility list entry, etc.). On Windows, where the OS provides no forced disclosure, KeyFlow must supply its own (visible tray icon at minimum) as a substitute. A build that hides its presence is out of scope for this project, full stop.

## 3. Minimum Supported OS Versions

| Platform | Minimum version | Rationale |
|---|---|---|
| Windows | Windows 10 21H2+ | MSIX packaging + modern Credential Manager APIs |
| macOS | macOS 13 (Ventura)+ | Stable Accessibility API + Notarization tooling |
| Android | Android 10 (API 29)+ | AccessibilityService capability set; ML Kit on-device translation support |
| iOS | iOS 16+ | Custom keyboard extension APIs; consider iOS 17.4+ if using Apple's on-device Translation framework |

## 4. Security Requirements

- **S-1**: All captured text at rest shall be encrypted with AES-256; the encryption key shall live in the OS-native secure store (Keychain / Android Keystore / Windows Credential Manager / DPAPI), never in application code or a plain file.
- **S-2**: KeyFlow shall never capture text from a field the OS identifies as a secure/password field, where that signal is exposed by the platform's accessibility APIs.
- **S-3**: The Exclusion List shall ship with sensible defaults (password managers, common banking domains/apps) and be user-editable.
- **S-4**: No captured text shall leave the device over the network, except the specific span of text a user explicitly submits for cloud-based translation (opt-in per use, not a persistent setting).
- **S-5**: Crash/diagnostic logs shall never contain captured text content.
- **S-6**: The application binary shall be code-signed (all platforms) and notarized (macOS) before any distribution, including internal testing builds where the platform supports it.
- **S-7**: Uninstall shall wipe the local encrypted store and any cached keys.

## 5. Compliance & Deployment Note

KeyFlow is designed so each install is single-user and consented: the person using the device is the person who enabled it. If any of these installs will run on an employer-owned or employer-managed machine, confirm with the relevant IT/HR policy owner that a locally-installed accessibility/input-monitoring tool is permitted — this varies by organization and jurisdiction, and it's a policy question for the deploying team rather than something the software itself can determine. This note is informational, not legal advice.

## 6. Antivirus / OS Warning Strategy (the legitimate path)

"No harmful warnings" is achieved through transparency and process, not concealment:

1. **Code signing** — Windows Authenticode certificate (EV preferred for faster SmartScreen reputation), Apple Developer ID + Notarization for macOS.
2. **Visible presence** — tray/menu-bar icon, clear process name matching the signed publisher, visible entry in startup-app lists.
3. **No covert networking** — no telemetry or exfiltration beyond the explicit translation opt-in; this alone rules out most heuristics that flag keyloggers.
4. **Reputation building** — Windows SmartScreen reputation improves with signed-build install volume over time; for a small internal rollout, pre-empt this by submitting the signed binary to Microsoft's and major AV vendors' false-positive review portals before wide internal rollout (tracked as a release-gate task in the Test Plan).
5. **Store disclosure where applicable** — if ever distributed via Google Play, the listing must disclose accessibility-service use per policy.

A build that attempts to hide its own process, suppress the OS's permission UI, or exfiltrate data covertly is not in scope for this TRD and should not be requested of the agentic IDE (see Prompts doc, guardrail note).

## 7. Distribution Strategy (small trusted group)

| Platform | Recommended channel | Why |
|---|---|---|
| Windows | Signed MSIX or EXE installer, shared directly with the small user group | No store review needed; signing handles trust |
| macOS | Signed + notarized `.dmg`/`.pkg`, shared directly | Gatekeeper accepts notarized builds without store distribution |
| Android | Signed APK, sideloaded ("install from unknown sources"), or Play Console **Internal Testing** track | Internal Testing track avoids full public review while still using Play's delivery/update mechanism |
| iOS | Apple Developer Program **Internal/Ad Hoc distribution** or **TestFlight Internal Testing** (up to 100 named testers, no App Review needed for internal testers) | Ideal fit for "a few known people" — avoids public App Store review entirely |

## 8. Third-Party Dependencies

- **Translation**: prefer on-device (Apple's Translation framework on iOS/macOS 17.4+/14.4+, Android ML Kit Translation on-device models). Cloud fallback (e.g., DeepL/Google Translate API) only for unsupported language pairs, called through a thin relay (see Architecture §5) so no API key ships in the client binary.
- **Local database**: SQLite with SQLCipher (or platform-equivalent encrypted store) for the History Store.
- **Autocorrect**: local dictionary + lightweight on-device language model; no cloud dependency required.

## 9. Non-Functional Requirements Recap

See SRS §3.2 for the full table (performance, resource usage, reliability, portability, usability, auditability). This TRD adds no exceptions to those.
