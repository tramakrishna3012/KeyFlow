# KeyFlow - Local-first Typing History & Assist App

[![CI](https://github.com/tramakrishna3012/KeyFlow/actions/workflows/ci.yml/badge.svg)](https://github.com/tramakrishna3012/KeyFlow/actions/workflows/ci.yml)
[![Release Android](https://github.com/tramakrishna3012/KeyFlow/actions/workflows/release-android.yml/badge.svg)](https://github.com/tramakrishna3012/KeyFlow/actions/workflows/release-android.yml)

KeyFlow is a local-first typing history and assist application built with Flutter. It provides autocorrect, emoji search, translation, and secure local storage with optional cloud sync.

## Features

- **Local-first storage**: All data stored securely on device with SQLCipher encryption
- **Cross-platform**: Android, iOS, Windows, and Web support
- **Autocorrect engine**: Smart word suggestions with learning capability
- **Emoji search**: Fast emoji search and insertion
- **Translation**: Built-in translation functionality
- **Secure sync**: Optional Supabase cloud sync with end-to-end encryption
- **Privacy focused**: All processing happens locally by default

## Architecture

- **Framework**: Flutter 3.44.7 with Riverpod for state management
- **Navigation**: GoRouter for declarative routing
- **Database**: SQLite with SQLCipher encryption
- **Cloud Sync**: Supabase with encrypted sync
- **UI**: Material Design with custom theming

## Development Setup

### Prerequisites

- Flutter 3.44.7 or later
- Android SDK (for Android builds)
- Xcode (for iOS builds - macOS only)
- Visual Studio (for Windows builds)

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/tramakrishna3012/KeyFlow.git
   cd KeyFlow
   ```

2. Install dependencies:
   ```bash
   cd app
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## CI/CD & Releases

This project uses GitHub Actions for automated continuous integration, testing, and multi-platform release distribution.

### Workflows

1. **CI** (`ci.yml`) - Runs automatically on every push/PR to `main`:
   - Static analysis (`flutter analyze`)
   - Unit, integration & security test suites
   - Code formatting validation (`dart format`)
   - Automated Android APK & Web artifact compilation

2. **Release Android** (`release-android.yml`) - Triggered on GitHub Release creation, tag push (`v*`), or manual dispatch:
   - Builds production Android App Bundle (`app-release.aab`)
   - Builds optimized architecture APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`)
   - Automatically publishes APK binaries to the GitHub Release page

### How to Release Version v1.0.0

#### Option A: Via GitHub Web UI (Recommended)
1. Go to your GitHub repository: [tramakrishna3012/KeyFlow/releases](https://github.com/tramakrishna3012/KeyFlow/releases).
2. Click **"Draft a new release"**.
3. In **Choose a tag**, enter `v1.0.0` and click **"Create new tag: v1.0.0 on publish"**.
4. Set the Release title to `KeyFlow v1.0.0 - Production Release`.
5. Click **"Generate release notes"** or describe the changes.
6. Click **"Publish release"**.
7. The **Release Android** GitHub Action will automatically trigger, compile the APKs, and attach them directly to the release page.

#### Option B: Via Git Command Line
```bash
# 1. Create and push the release tag
git tag -a v1.0.0 -m "Release v1.0.0: Look System & Typing History"
git push origin v1.0.0
```

#### Option C: Manual Workflow Dispatch in GitHub Actions
1. Go to [Actions → Release Android](https://github.com/tramakrishna3012/KeyFlow/actions/workflows/release-android.yml).
2. Click **Run workflow** dropdown → Choose `main` branch → Click **Run workflow**.

## Testing

Run tests locally:
```bash
cd app
flutter test
```

Run specific test files:
```bash
flutter test test/widget_test.dart
```

Generate coverage report:
```bash
flutter test --coverage
```

## Building

### Android
```bash
flutter build apk --release
```

### iOS (macOS only)
```bash
flutter build ipa --release
```

### Windows
```bash
flutter build windows --release
```

### Web
```bash
flutter build web --release
```

## Project Structure

```
keyflow/
├── app/                    # Flutter application
│   ├── lib/               # Application source code
│   ├── test/              # Unit and widget tests
│   ├── android/           # Android platform code
│   ├── ios/               # iOS platform code
│   ├── windows/           # Windows platform code
│   └── web/               # Web platform code
├── .github/workflows/     # CI/CD workflows
├── scripts/               # Build and utility scripts
└── docs/                  # Documentation
```

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]