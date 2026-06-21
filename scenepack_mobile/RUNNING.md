# Running ScenePack Pro (Flutter)

To run this native Flutter application on your mobile device, follow these clinical steps:

## 1. Prerequisites
Ensure you have the **Flutter SDK** installed and configured on your machine.
- Download: [flutter.dev/docs/get-started](https://flutter.dev/docs/get-started)
- Verify: Run `flutter doctor` in your terminal.

## 2. Dependency Acquisition
Navigate to the project root and pull the Forensic/Media libraries:
```powershell
cd d:\app\scenepack_mobile
flutter pub get
```

## 3. Launching on Device
Connect your Android or iOS device and run:
```powershell
flutter run
```

## 4. Platform Specifics (Critical)

### Android
- Ensure you have **NDK** installed in Android Studio (required by FFmpegKit).
- Minimum SDK version: **24** (Android 7.0).
- Location: `android/app/build.gradle` -> `minSdkVersion 24`.

### iOS
- Run `pod install` in the `ios/` directory.
- Minimum iOS version: **12.1**.
- Ensure `NSPhotoLibraryUsageDescription` is added to `Info.plist`.

## 5. Troubleshooting
If you encounter FFmpeg library conflicts, run:
```powershell
flutter clean
flutter pub get
```
