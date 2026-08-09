# CI/CD Workflows for KeyFlow

This project uses GitHub Actions for continuous integration and deployment. Below are the available workflows:

## Workflows

### 1. CI (`ci.yml`)
**Triggered on:** push to main/develop branches or pull requests
**Purpose:** Run tests, linting, and code analysis
**Jobs:**
- `analyze-and-test`: Runs Flutter analyze and tests on Ubuntu
- `build-android`: Builds Android APK on main branch pushes
- `build-web`: Builds web version on main branch pushes

### 2. Release Android (`release-android.yml`)
**Triggered on:** GitHub Release creation or manual dispatch
**Purpose:** Build signed Android App Bundle (AAB) and APKs for release
**Requirements:** Android signing secrets configured in repository secrets

### 3. Build iOS (`build-ios.yml`)
**Triggered on:** push to main branch (iOS-related changes) or manual dispatch
**Purpose:** Build iOS IPA (requires macOS runner)
**Jobs:**
- `build-ios`: Builds iOS IPA without code signing
- `test-ios`: Runs tests on iOS environment

### 4. Build Windows (`build-windows.yml`)
**Triggered on:** push to main branch (Windows-related changes) or manual dispatch
**Purpose:** Build Windows executable and create installer package

## Required Secrets

For the Android release workflow, you need to configure these repository secrets:

1. **ANDROID_KEYSTORE**: Base64-encoded Android keystore file
2. **ANDROID_KEYSTORE_PASSWORD**: Keystore password
3. **ANDROID_KEY_PASSWORD**: Key password
4. **ANDROID_KEY_ALIAS**: Key alias

To encode your keystore:
```bash
base64 -i your-keystore.jks
```

## Local Development Setup

### Prerequisites
- Flutter 3.44.7 or later
- Android SDK
- iOS development tools (for iOS builds)
- Windows development tools (for Windows builds)

### Local Testing
Run the same commands locally that the CI runs:
```bash
cd app
flutter pub get
flutter analyze
flutter test --coverage
flutter build apk --release
```

## Cache Configuration

The workflows use Flutter dependency caching to speed up builds. Cache keys are based on Flutter version to ensure compatibility.

## Artifact Retention

- Test artifacts: 7 days
- Build artifacts: 30 days
- Release artifacts: Attached to GitHub Releases indefinitely

## Troubleshooting

### Common Issues

1. **Flutter version mismatch**: Ensure local Flutter version matches `FLUTTER_VERSION` in workflows
2. **Dependency issues**: Run `flutter pub get` locally to verify dependencies
3. **Android signing**: Ensure keystore secrets are properly base64 encoded
4. **iOS build**: Requires macOS runner and proper CocoaPods setup