# KeyFlow — Intelligent Local-First Typing History & Assistant

[![CI](https://github.com/tramakrishna3012/KeyFlow/actions/workflows/ci.yml/badge.svg)](https://github.com/tramakrishna3012/KeyFlow/actions/workflows/ci.yml)
[![Release Android](https://github.com/tramakrishna3012/KeyFlow/actions/workflows/release-android.yml/badge.svg)](https://github.com/tramakrishna3012/KeyFlow/actions/workflows/release-android.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.7-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-blue)](https://github.com/tramakrishna3012/KeyFlow)

**KeyFlow** is a modern, privacy-first, local-first typing history tracker and intelligent desktop/mobile assistant built with Flutter. It captures, organizes, encrypts, and indexes keystrokes and text snippets across all applications with zero external telemetry, instant search, smart app exclusions, and a native system-wide floating assistant.

---

## ✨ Key Features

### 🛡️ Privacy & Local-First Encryption
- **Zero-Knowledge Architecture**: All typing logs are processed entirely on-device by default.
- **SQLCipher AES-256 Encryption**: Data at rest is encrypted using database-level keys stored securely in the hardware keystore via `FlutterSecureStorage`.
- **Configurable Retention Purge**: Automated background retention policies (24 hours, 7 days, 30 days, 90 days, or indefinite) with secure cascading data shredding.
- **Optional E2E Cloud Sync**: Encrypted synchronization backed by Supabase with client-side key derivation.

### 🕒 Redesigned Snippet History (2-Level Grouping)
- **Hierarchical Layout**: Grouped by date sections (*Today*, *Yesterday*, *Mon, 24 Aug*) with entry count pill badges.
- **Per-App Cards**: Dynamic application header cards featuring package icons, bold app names, package identifiers, and chronological timestamps.
- **Touch-Friendly Copy Affordance**: One-tap copy button and long-press selection with haptic feedback and confirmation toasts.
- **Debounce & Deduplication Engine**: 800ms debounce pipeline and 10-second deduplication cache preventing duplicate database records.

### 🤖 System-Wide Floating Assistant Bot
- **Native Draggable Overlay**: WindowManager-based overlay bubble (`SYSTEM_ALERT_WINDOW`) that hovers above other applications.
- **Expandable Quick Control Panel**:
  - Live capture status indicator (*Active* / *Paused*).
  - Instant *"Pause Typing Capture"* toggle for momentary privacy during sensitive input.
  - *"Accessibility Access"* status switch with deep-linking to Android Accessibility Settings and automatic app lifecycle resume refreshing.
  - Quick action launcher for instant navigation back into KeyFlow.

### 🚫 Installed App Exclusion Manager
- **Interactive App Discovery**: Enumerates installed applications on the device with icons, names, and package IDs.
- **Instant Search & Filter**: Real-time filtering across installed packages with immediate toggle state reflection.
- **Sensitive App Auto-Detection**: Built-in recommendations for banking, payment, and authenticator applications.
- **Direct Native Sync**: Immediately syncs exclusion lists with `KeyflowAccessibilityService`.

### 🔔 Discreet Background Synchronization
- **Generic Notification Labels**: Foreground accessibility service runs discreetly under the neutral *"System Sync Service"* title with minimal status text (*"Active"* / *"Paused"*).
- **Clean Channel Management**: Automatically migrates and cleans legacy notification channels.

### 🔄 Semantic Auto-Update Engine
- **Accurate SemVer Comparison**: Compares releases using numeric semantic versioning (`major.minor.patch`).
- **Encrypted Persistent Dismissal**: Remembers dismissed update versions without recurring prompt spam.
- **Process Guard**: Prevents flickering dialogs and duplicate update checks on view rebuilds.

---

## 🏗️ Architecture & Technology Stack

| Component | Technology / Library |
| :--- | :--- |
| **Framework** | [Flutter 3.44.7](https://flutter.dev) (Dart 3.x) |
| **State Management** | [Flutter Riverpod 2.x](https://riverpod.dev) (`StateNotifierProvider`, `FutureProvider`) |
| **Routing & Navigation** | [GoRouter](https://pub.dev/packages/go_router) with responsive Adaptive Navigation (Rail & Bottom Bar) |
| **Local Database** | [sqflite_sqlcipher](https://pub.dev/packages/sqflite_sqlcipher) (AES-256 encrypted SQLite) |
| **Key Storage** | [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) (Android Keystore / iOS Keychain) |
| **Native Android** | Kotlin, `AccessibilityService`, `WindowManager` Overlay, Custom Broadcast Channels |
| **Backend & Sync** | [Supabase](https://supabase.com) (E2E encrypted payload relay) |
| **Design System** | Clean Light Theme with custom semantic token system ([`AppColors`](file:///d:/Freelance/KeyFlow/app/lib/core/theme/app_colors.dart)) |

---

## 📂 Project Structure

```
KeyFlow/
├── app/                                 # Main Flutter application
│   ├── android/                         # Android platform implementation
│   │   └── app/src/main/kotlin/.../     # Kotlin Accessibility & Overlay Services
│   │       ├── KeyflowAccessibilityService.kt
│   │       ├── KeyflowOverlayService.kt
│   │       └── MainActivity.kt
│   ├── lib/                             # Core Dart/Flutter codebase
│   │   ├── core/                        # Design tokens, theme, router, utilities
│   │   │   ├── router/app_router.dart
│   │   │   ├── services/auto_update_service.dart
│   │   │   ├── theme/app_colors.dart
│   │   │   └── theme/app_theme.dart
│   │   ├── data/                        # Repositories, models, and providers
│   │   │   ├── history_repository.dart
│   │   │   ├── providers.dart
│   │   │   └── sync_service.dart
│   │   └── features/                    # Feature modules
│   │       ├── auth/                    # Sign In / Sign Up light theme modals
│   │       ├── capture/                 # CaptureService & platform channel bridges
│   │       ├── history/                 # Grouped snippet history & detail views
│   │       ├── home/                    # Dashboard & live stats
│   │       ├── profile/                 # Profile & security settings
│   │       └── settings/                # Excluded apps & accessibility controls
│   └── test/                            # 108 automated unit, widget, and security tests
├── web/                                 # HTML5 interactive prototype & web distribution
├── .github/workflows/                   # GitHub Actions CI/CD pipelines
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.44.7`)
- [Android SDK](https://developer.android.com/studio) (API level 26 minimum, API 35 target)
- [Xcode](https://developer.apple.com/xcode/) (macOS only, for iOS builds)

### Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/tramakrishna3012/KeyFlow.git
   cd KeyFlow/app
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Run Static Analysis & Automated Tests**:
   ```bash
   flutter analyze
   flutter test
   ```

4. **Launch the application**:
   ```bash
   # Run on connected Android device / emulator
   flutter run
   ```

---

## 📱 Permissions Setup (Android)

For typing history and the floating assistant to operate:
1. **Accessibility Service**:
   - Go to **Settings → Accessibility → KeyFlow** and toggle **ON**.
2. **Display Over Other Apps** (Optional for Floating Bubble):
   - Go to **Settings → Apps → KeyFlow → Display over other apps** and allow permission.

---

## 📦 Building & Releases

### Android APK & Bundle
```bash
cd app

# Build Release APK
flutter build apk --release

# Build Android App Bundle (Play Store)
flutter build appbundle --release
```
Binaries are output to `app/build/app/outputs/flutter-apk/app-release.apk`.

### iOS (.ipa — macOS required)
```bash
cd app
flutter build ipa --release
```

### Web
```bash
cd app
flutter build web --release
```

---

## 🧪 Testing & Quality Assurance

KeyFlow maintains a strict zero-lint and high-coverage test suite:

- **Static Analysis**: `flutter analyze` returns `0 issues` with zero warnings or info-level lints.
- **Formatting**: `dart format --set-exit-if-changed .` enforced across all Dart files.
- **Automated Tests**: 108/108 passing automated tests covering:
  - Database encryption & SQLCipher contracts
  - Retention purge lifecycle
  - Search performance (< 200ms benchmark)
  - Accessibility toggle synchronization
  - History deduplication & debouncing
  - Semantic version checking

Run the complete test suite:
```bash
cd app
flutter test
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).