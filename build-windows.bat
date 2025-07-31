@echo off
echo Building Isla Journal for Windows (Release)...

REM Clean previous builds
flutter clean
flutter pub get

REM Build Windows release
flutter build windows --release

REM Check if build was successful
if %ERRORLEVEL% neq 0 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo ✅ Build completed successfully!
echo 📁 Output location: build\windows\x64\runner\Release\
echo.
echo ⚠️  IMPORTANT: If you get "flutter_secure_storage_windows_plugin.dll not found" error:
echo    1. Copy the DLL from: build\windows\x64\plugins\flutter_secure_storage_windows\
echo    2. To: build\windows\x64\runner\Release\
echo.
echo 🚀 You can now run isla_journal.exe from the Release folder
pause 