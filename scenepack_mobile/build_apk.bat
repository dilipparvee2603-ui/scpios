@echo off
setlocal enabledelayedexpansion
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"
cd /d "%~dp0"

echo --------------------------------------------------
echo [CFX STUDIOS] BUILD CONTROLLER v2.2 (DEBUG MODE)
echo --------------------------------------------------
echo.

set /p NEW_VER="ENTER VERSION NAME (e.g. 2.20): "
set /p NEW_BUILD="ENTER BUILD NUMBER (e.g. 2100): "

echo.
echo [1/3] UPDATING PUBSPEC.YAML...
powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content pubspec.yaml) -replace 'version: .*', 'version: %NEW_VER%.0+%NEW_BUILD%' | Set-Content pubspec.yaml -Encoding ASCII" || goto :error

echo [2/3] UPDATING APP STATE ENGINE...
powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content lib/main.dart) -replace 'final String appVersion = \".*\"', 'final String appVersion = \"v%NEW_VER%.0\"' | Set-Content lib/main.dart -Encoding UTF8" || goto :error

echo [3/3] INITIATING PRODUCTION BUILD...
echo --------------------------------------------------

call "%~dp0src\flutter\bin\flutter.bat" build apk --split-per-abi

if %ERRORLEVEL% EQU 0 (
    echo.
    echo --------------------------------------------------
    echo [SUCCESS] BUILD v%NEW_VER% (Build %NEW_BUILD%) COMPLETE!
    echo APK LOCATION: build\app\outputs\flutter-apk\
    echo --------------------------------------------------
    pause
    exit /b 0
) else (
    goto :error
)

:error
echo.
echo --------------------------------------------------
echo [CRITICAL ERROR] BUILD FAILED OR INTERRUPTED.
echo CHECK THE LOGS ABOVE FOR DETAILS.
echo --------------------------------------------------
echo.
pause
exit /b 1
