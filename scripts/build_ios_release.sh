#!/usr/bin/env bash
# KeyFlow iOS App & Keyboard Extension Release Build Script
# Requirements: macOS, Xcode, CocoaPods, Apple Developer Provisioning Profiles

set -e

echo "========================================================="
echo " Building KeyFlow iOS App & Keyboard Extension Target   "
echo "========================================================="

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../app"

echo "Running flutter pub get..."
flutter pub get

echo "Building iOS Release Archive (without signing for export)..."
flutter build ios --release --no-codesign

IPA_DIR="$SCRIPT_DIR/../app/build/ios/archive"
echo "[SUCCESS] iOS container build completed. Open ios/Runner.xcworkspace in Xcode to archive and export the KeyFlowKeyboard custom extension target."
