#!/usr/bin/env bash
# KeyFlow Android APK & AAB Release Build Script
# Requirements: Android SDK, Java 17, Flutter SDK

set -e

echo "=========================================="
echo " Building KeyFlow Android Release APK/AAB "
echo "=========================================="

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../app"

echo "Running flutter pub get..."
flutter pub get

echo "Building Release APK..."
flutter build apk --release

echo "Building Release App Bundle (AAB)..."
flutter build appbundle --release

APK_PATH="$SCRIPT_DIR/../app/build/app/outputs/flutter-apk/app-release.apk"
AAB_PATH="$SCRIPT_DIR/../app/build/app/outputs/bundle/release/app-release.aab"

if [ -f "$APK_PATH" ]; then
  echo "[SUCCESS] Android Release APK generated at: $APK_PATH"
  echo "[SUCCESS] Android Release AAB generated at: $AAB_PATH"
else
  echo "[ERROR] Android release build failed."
  exit 1
fi
