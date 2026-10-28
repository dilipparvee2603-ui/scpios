#!/bin/bash
set -e

echo "--------------------------------------------------"
echo "[CFX STUDIOS] iOS IPA BUILD CONTROLLER (macOS)"
echo "--------------------------------------------------"
echo ""

cd "$(dirname "$0")"

# 1. Update dependencies
echo "[1/4] Resolving Flutter dependencies..."
flutter pub get

# 2. Build iOS Release Application
echo "[2/4] Building iOS Release App (No Code Signing Required)..."
flutter build ios --release --no-codesign

# 3. Package IPA
echo "[3/4] Packaging .ipa file..."
mkdir -p build/ios/ipa/Payload
cp -r build/ios/iphoneos/Runner.app build/ios/ipa/Payload/
cd build/ios/ipa
zip -r -q ScenePack-Pro.ipa Payload
rm -rf Payload
cd ../../..

echo ""
echo "--------------------------------------------------"
echo "[SUCCESS] IPA GENERATED!"
echo "LOCATION: build/ios/ipa/ScenePack-Pro.ipa"
echo "You can sideload this IPA via Sideloadly, AltStore, or Scarlet."
echo "--------------------------------------------------"
