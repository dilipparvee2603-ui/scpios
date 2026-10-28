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
echo "[2/4] Building iOS Release App (Unsigned)..."
flutter build ios --release --no-codesign

# 3. Package IPA
echo "[3/4] Packaging .ipa file..."
mkdir -p build/ios/ipa/Payload
if [ -d "build/ios/iphoneos/Runner.app" ]; then
  cp -r build/ios/iphoneos/Runner.app build/ios/ipa/Payload/
elif [ -d "build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app" ]; then
  cp -r build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app build/ios/ipa/Payload/
else
  APP_PATH=$(find build -name "Runner.app" -type d | head -n 1)
  echo "Found Runner.app at: $APP_PATH"
  cp -r "$APP_PATH" build/ios/ipa/Payload/
fi
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
