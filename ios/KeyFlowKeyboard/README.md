# KeyFlow — iOS Custom Keyboard Extension

> **Status:** Placeholder — no implementation yet

## Purpose

This is a native Swift **Custom Keyboard Extension** — a separate Xcode target in the same project, **not** embedded inside the Flutter app.

## Why a Separate Target? (from Architecture §4)

- Apple imposes strict memory limits on keyboard extensions that make embedding a full Flutter engine impractical
- A lightweight native UIKit/SwiftUI keyboard is the reliable approach
- Only text typed while the user has **actively selected** the KeyFlow keyboard is captured — this is a hard iOS platform limit, not a design gap

## Responsibilities

- Capture text typed through the KeyFlow keyboard extension
- Share data with the main Flutter container app via an **App Group** shared container (encrypted at rest per TRD S-1)
- The container app (Flutter) reads from the shared store for History/Search/Settings UI

## Platform Requirements

- **Minimum**: iOS 16+ (TRD §3); consider iOS 17.4+ for Apple's on-device Translation framework
- **Distribution**: Apple Developer Program Ad Hoc or TestFlight Internal Testing (TRD §7)
- **User must**: actively select KeyFlow keyboard in Settings → General → Keyboard and enable "Allow Full Access"

## Related Docs

- [Architecture §4 — iOS](../docs/KeyFlow_04_Architecture.md)
- [TRD §2 — Platform Capture Matrix](../docs/KeyFlow_03_TRD.md)
- [PRD §7 — iOS Assumption](../docs/KeyFlow_01_PRD.md)
