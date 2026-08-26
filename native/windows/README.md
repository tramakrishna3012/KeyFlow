# KeyFlow — Windows Native Capture Module

> **Status:** Implemented (`windows_capture_engine`, `windows_tray_icon`, `windows_startup_manager`, `keyflow_capture_plugin`)

## Purpose

This module will contain the Windows-specific text capture engine using either:
- **Low-level keyboard hook** (`WH_KEYBOARD_LL`) via Win32 API
- **Text Services Framework** integration

Written in C++ or C#.

## Responsibilities (from Architecture §4)

- Capture keystrokes via the native hook, assembling them into text entries
- Expose captured text events to the Flutter layer via `MethodChannel`/`EventChannel`
- Run a **visible system-tray icon** at all times capture is active (TRD §2 non-negotiable rule)
- Enforce the **Exclusion List** at the native layer before forwarding text to Flutter
- Detect and skip secure/password fields where the OS exposes that signal

## Platform Requirements

- **Minimum**: Windows 10 21H2+ (TRD §3)
- **Signing**: Windows Authenticode certificate (EV preferred for SmartScreen reputation)
- **Distribution**: Signed MSIX or EXE installer (TRD §7)

## Related Docs

- [Architecture §4 — Windows](../docs/KeyFlow_04_Architecture.md)
- [TRD §2 — Platform Capture Matrix](../docs/KeyFlow_03_TRD.md)
- [TRD §6 — AV/OS Warning Strategy](../docs/KeyFlow_03_TRD.md)
