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

# 2. Prepare iOS Config & CocoaPods
echo "[2/4] Preparing iOS configuration..."
flutter build ios --config-only --release

# 3. Build with Xcode directly
echo "[3/4] Building iOS Release App via Xcode..."
cd ios
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ../build/ios \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build
cd ..

# 4. Package IPA
echo "[4/4] Packaging .ipa file..."
mkdir -p build/ios/ipa/Payload
cp -r build/ios/Build/Products/Release-iphoneos/Runner.app build/ios/ipa/Payload/
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
