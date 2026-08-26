#!/usr/bin/env bash
# KeyFlow macOS Release Build, Signing & Notarization Script
# Requirements: Xcode, Flutter SDK, Developer ID Application Certificate, Apple Notarytool CLI

set -e

echo "=========================================="
echo " Building KeyFlow macOS Release Bundle   "
echo "=========================================="

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../app"

echo "Running flutter pub get..."
flutter pub get

echo "Building Flutter macOS Release..."
flutter build macos --release

APP_PATH="$SCRIPT_DIR/../app/build/macos/Build/Products/Release/keyflow_app.app"

if [ -d "$APP_PATH" ]; then
  echo "[SUCCESS] macOS app bundle created at: $APP_PATH"

  # Signing step if Developer ID is provided
  if [ -n "$DEVELOPER_ID_APP" ]; then
    echo "Signing app bundle with Developer ID: $DEVELOPER_ID_APP..."
    codesign --deep --force --options runtime --sign "$DEVELOPER_ID_APP" "$APP_PATH"

    # Notarization step
    if [ -n "$APPLE_ID" ] && [ -n "$APPLE_TEAM_ID" ] && [ -n "$APPLE_APP_SPECIFIC_PASSWORD" ]; then
      echo "Submitting app bundle to Apple Notarization service..."
      ZIP_PATH="$SCRIPT_DIR/../app/build/macos/Build/Products/Release/keyflow_app.zip"
      ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

      xcrun notarytool submit "$ZIP_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --wait

      xcrun stapler staple "$APP_PATH"
      echo "[SUCCESS] macOS App successfully signed and notarized!"
    fi
  else
    echo "[NOTE] Signing skipped (DEVELOPER_ID_APP environment variable not set)."
  fi
else
  echo "[ERROR] macOS release build failed: Output bundle not found."
  exit 1
fi
