# KeyFlow

**Local-first typing history & assist** — capture what you type, search and reuse it, with autocorrect, translation, and emoji suggestions built in.

A cross-platform app for a small internal user group, built with Flutter for the shared UI/business logic and native modules per platform for system capture.

---

## Module Layout

| Directory | Purpose | Status |
|---|---|---|
| [`/app`](app/) | Flutter shared app — UI, state management (Riverpod), HistoryRepository | ✅ Scaffolded |
| [`/native/windows`](native/windows/) | Windows native capture module (C++/C# `WH_KEYBOARD_LL` hook) | 📋 Placeholder |
| [`/native/macos`](native/macos/) | macOS native capture module (Swift `CGEventTap`) | 📋 Placeholder |
| [`/native/android`](native/android/) | Android `AccessibilityService` module (Kotlin) | 📋 Placeholder |
| [`/ios/KeyFlowKeyboard`](ios/KeyFlowKeyboard/) | iOS Custom Keyboard Extension (Swift, separate Xcode target) | 📋 Placeholder |
| [`/relay`](relay/) | Stateless translation relay service | 📋 Placeholder |
| [`/docs`](docs/) | Product specs (PRD, SRS, TRD, Architecture, UI/UX, TestPlan) | 📄 Complete |

---

## Documentation

All specification documents live in [`/docs`](docs/):

| Doc | Description |
|---|---|
| [PRD](docs/KeyFlow_01_PRD.md) | Product Requirements — vision, goals, scope |
| [SRS](docs/KeyFlow_02_SRS.md) | Software Requirements — functional & non-functional |
| [TRD](docs/KeyFlow_03_TRD.md) | Technical Requirements — platform constraints, security |
| [Architecture](docs/KeyFlow_04_Architecture.md) | System architecture — layer diagram, data schema |
| [UI/UX](docs/KeyFlow_05_UIUX.md) | Design spec — screens, flows, accessibility |
| [Test Plan](docs/KeyFlow_06_TestPlan.md) | Testing strategy — UAT scenarios, AV verification |

---

## Quick Start

```bash
# Prerequisites: Flutter 3.44+ installed
cd app
flutter pub get
flutter run
```

### Run checks

```bash
cd app
flutter analyze      # static analysis
flutter test         # unit & widget tests
```

---

## CI/CD

GitHub Actions workflow (`.github/workflows/flutter_ci.yml`) runs on push/PR to `main`:
- `flutter analyze --fatal-infos`
- `flutter test --coverage`

Scoped to `/app` only.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     Flutter Shared Layer                 │
│   UI screens · Riverpod state · HistoryRepository       │
│   Search & reinsert · Settings · Consent flow           │
└───────────────┬─────────────┬─────────────┬─────────────┘
                │ Platform     │ Platform     │ Platform
                │ Channel      │ Channel      │ Channel
       ┌────────▼────────┐ ┌───▼──────────┐ ┌▼──────────────┐ ┌──────────────────┐
       │ Windows native  │ │ macOS native │ │ Android        │ │ iOS Custom       │
       │ capture module  │ │ capture      │ │ Accessibility  │ │ Keyboard         │
       │ (C++/C#)        │ │ module       │ │ Service        │ │ Extension        │
       │                 │ │ (Swift)      │ │ (Kotlin)       │ │ (Swift)          │
       └─────────────────┘ └──────────────┘ └────────────────┘ └──────────────────┘
```

---

## License

Internal use only — not for public distribution.
