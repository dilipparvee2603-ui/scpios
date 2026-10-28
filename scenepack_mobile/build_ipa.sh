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

# 2. CocoaPods setup
echo "[2/4] Installing CocoaPods..."
cd ios
pod install
cd ..

# 3. Build IPA
echo "[3/4] Building iOS Release Archive..."
flutter build ipa --release --no-codesign

# 4. Package IPA
echo "[4/4] Packaging .ipa file..."
mkdir -p build/ios/ipa/Payload
cp -r build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app build/ios/ipa/Payload/
cd build/ios/ipa
zip -r -q ScenePack-Pro.ipa Payload
rm -rf Payload
cd ../../..

echo ""
echo "--------------------------------------------------"
echo "[SUCCESS] IPA GENERATED!"
echo "LOCATION: build/ios/ipa/ScenePack-Pro.ipa"
echo "You can sideload this IPA via AltStore, Sideloadly, or Scarlet."
echo "--------------------------------------------------"
