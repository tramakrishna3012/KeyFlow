# KeyFlow — macOS Native Capture Module

> **Status:** Implemented (`MacOSCaptureEngine`, `MacOSStatusItem`, `KeyflowMacOSCapturePlugin`)

## Purpose

This module will contain the macOS-specific text capture engine using:
- **`CGEventTap`** under the Accessibility permission

Written in Swift.

## Responsibilities (from Architecture §4)

- Capture keystrokes via `CGEventTap`, gated behind the Accessibility permission
- Communicate with Flutter via the macOS platform channel
- Display a **menu-bar icon** mirroring the Windows tray-icon requirement (TRD §2)
- Enforce the **Exclusion List** at the native layer before forwarding text to Flutter
- Detect and skip secure/password fields where the OS exposes that signal

## Platform Requirements

- **Minimum**: macOS 13 (Ventura)+ (TRD §3)
- **Signing**: Apple Developer ID + Notarization (TRD §6)
- **Distribution**: Signed + notarized `.dmg`/`.pkg` (TRD §7)

## Related Docs

- [Architecture §4 — macOS](../docs/KeyFlow_04_Architecture.md)
- [TRD §2 — Platform Capture Matrix](../docs/KeyFlow_03_TRD.md)
