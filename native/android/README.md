# KeyFlow — Android Native Capture Module

> **Status:** Placeholder — no implementation yet

## Purpose

This module will contain the Android-specific text capture engine using:
- **`AccessibilityService`** — Android's accessibility framework

Written in Kotlin, packaged as a Flutter plugin.

## Responsibilities (from Architecture §4)

- Implement a native Kotlin `AccessibilityService` that observes text input events
- Bridge captured text to the Flutter engine via a Flutter plugin (`MethodChannel`)
- Android automatically enforces a **persistent notification** while the service runs (TRD §2)
- Enforce the **Exclusion List** at the native layer before any text reaches shared code
- Detect and skip secure/password fields

## Platform Requirements

- **Minimum**: Android 10 (API 29)+ (TRD §3)
- **Distribution**: Signed APK sideloaded, or Play Console Internal Testing track (TRD §7)
- **Play Policy**: Accessibility-service disclosure required if distributed via Play Store

## Related Docs

- [Architecture §4 — Android](../docs/KeyFlow_04_Architecture.md)
- [TRD §2 — Platform Capture Matrix](../docs/KeyFlow_03_TRD.md)
