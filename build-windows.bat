@echo off
echo.
echo ===============================================
echo    Building Isla Journal for Windows...
echo ===============================================
echo.

REM Check if Flutter is available
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Flutter not found in PATH!
    echo Please install Flutter or add it to your PATH.
    echo.
    pause
    exit /b 1
)

echo Building Windows release version...
echo This may take a few minutes...
echo.

REM Build the Windows app
flutter build windows --release

if %errorlevel% equ 0 (
    echo.
    echo ===============================================
    echo    Build completed successfully!
    echo ===============================================
    echo.
    echo You can now run IslaJournal.bat to launch the app
    echo.
) else (
    echo.
    echo ===============================================
    echo    Build failed!
    echo ===============================================
    echo.
    echo Please check the error messages above.
    echo.
)

pause 