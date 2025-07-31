@echo off
echo.
echo ===============================================
echo    Starting Isla Journal...
echo ===============================================
echo.

REM Check if the executable exists
if not exist "build\windows\x64\runner\Release\isla_journal.exe" (
    echo ERROR: Isla Journal executable not found!
    echo.
    echo Please build the Windows app first by running:
    echo   flutter build windows --release
    echo.
    pause
    exit /b 1
)

REM Launch the application
echo Launching Isla Journal...
start "" "build\windows\x64\runner\Release\isla_journal.exe"

REM Optional: Keep window open for a moment to show launch status
timeout /t 2 /nobreak >nul

echo Isla Journal launched successfully!
echo You can close this window.
echo.
pause 