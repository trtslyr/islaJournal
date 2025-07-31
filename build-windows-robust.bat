@echo off
echo 🏗️  Building Windows Release (Robust Version)...
echo.

rem Build the Flutter Windows app
flutter build windows --release

if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter build failed!
    pause
    exit /b 1
)

echo.
echo ✅ Build complete!
echo.

rem Set up paths
set BUILD_DIR=build\windows\runner\Release
set SYSTEM32=C:\Windows\System32
set SYSWOW64=C:\Windows\SysWOW64

echo 🔍 Checking for Visual C++ Runtime DLLs...
echo.

rem Check multiple possible locations for DLLs
set "DLL_SOURCES[0]=%SYSTEM32%"
set "DLL_SOURCES[1]=%SYSWOW64%"
set "DLL_SOURCES[2]=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT"
set "DLL_SOURCES[3]=C:\Program Files (x86)\Microsoft Visual Studio\2019\*\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT"

rem Required DLLs
set DLL_COUNT=0
set DLLS_FOUND=0

rem Check for msvcp140.dll
echo 🔍 Looking for msvcp140.dll...
if exist "%SYSTEM32%\msvcp140.dll" (
    copy "%SYSTEM32%\msvcp140.dll" "%BUILD_DIR%\" >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo ✅ Copied msvcp140.dll from System32
        set /a DLLS_FOUND+=1
    ) else (
        echo ⚠️  Found but failed to copy msvcp140.dll from System32
    )
) else (
    echo ⚠️  msvcp140.dll not found in System32
)

rem Check for vcruntime140.dll
echo 🔍 Looking for vcruntime140.dll...
if exist "%SYSTEM32%\vcruntime140.dll" (
    copy "%SYSTEM32%\vcruntime140.dll" "%BUILD_DIR%\" >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo ✅ Copied vcruntime140.dll from System32
        set /a DLLS_FOUND+=1
    ) else (
        echo ⚠️  Found but failed to copy vcruntime140.dll from System32
    )
) else (
    echo ⚠️  vcruntime140.dll not found in System32
)

rem Check for vcruntime140_1.dll (optional, newer versions)
echo 🔍 Looking for vcruntime140_1.dll...
if exist "%SYSTEM32%\vcruntime140_1.dll" (
    copy "%SYSTEM32%\vcruntime140_1.dll" "%BUILD_DIR%\" >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo ✅ Copied vcruntime140_1.dll from System32
        set /a DLLS_FOUND+=1
    ) else (
        echo ⚠️  Found but failed to copy vcruntime140_1.dll from System32
    )
) else (
    echo ℹ️  vcruntime140_1.dll not found (this is optional)
)

echo.
echo 📊 DLL Copy Summary: %DLLS_FOUND% DLLs successfully copied
echo 📁 Executable location: %BUILD_DIR%\
echo.

rem Verify critical DLLs exist
if exist "%BUILD_DIR%\msvcp140.dll" if exist "%BUILD_DIR%\vcruntime140.dll" (
    echo ✅ GOOD: Critical runtime DLLs are bundled!
    echo 🚀 Your app should run on machines without VC++ Redistributable
    echo.
    goto :success
)

rem If we get here, critical DLLs are missing
echo.
echo ❌ WARNING: Missing critical DLLs!
echo.
echo 🔧 SOLUTIONS:
echo.
echo 1️⃣  INSTALL VC++ REDISTRIBUTABLE ON BUILD MACHINE:
echo    Download: https://aka.ms/vs/17/release/vc_redist.x64.exe
echo    Install it, then re-run this script
echo.
echo 2️⃣  MANUAL DLL COPY:
echo    After installing VC++ Redistributable above:
echo    Copy these files to %BUILD_DIR%\:
echo      - msvcp140.dll
echo      - vcruntime140.dll
echo      - vcruntime140_1.dll (if available)
echo.
echo 3️⃣  USER INSTALLATION (Alternative):
echo    Don't bundle DLLs - have users install VC++ Redistributable:
echo    https://aka.ms/vs/17/release/vc_redist.x64.exe
echo.
echo 4️⃣  TEST YOUR BUILD:
echo    Test on a clean Windows VM without Visual Studio to verify it works
echo.

:success
echo ✅ Build complete! Check the summary above for next steps.
echo.

rem Show file sizes for verification
if exist "%BUILD_DIR%\isla_journal.exe" (
    echo 📊 Build Information:
    dir "%BUILD_DIR%\isla_journal.exe" | find "isla_journal.exe"
    echo.
    echo 📦 Bundled DLLs:
    if exist "%BUILD_DIR%\msvcp140.dll" echo   ✅ msvcp140.dll
    if exist "%BUILD_DIR%\vcruntime140.dll" echo   ✅ vcruntime140.dll  
    if exist "%BUILD_DIR%\vcruntime140_1.dll" echo   ✅ vcruntime140_1.dll
    echo.
)

echo 🧪 TESTING RECOMMENDATION:
echo    Test your build on a clean Windows machine without Visual Studio
echo    to ensure the DLL bundling worked correctly.
echo.
pause 