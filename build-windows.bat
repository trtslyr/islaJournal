@echo off
echo 🏗️  Building Windows Release...
echo.

rem Build the Flutter Windows app
flutter build windows --release

echo.
echo ✅ Build complete!
echo.

rem Automatically copy VC++ Runtime DLLs
echo 🔄 Copying Visual C++ Runtime DLLs...

set BUILD_DIR=build\windows\runner\Release
set SYSTEM32=C:\Windows\System32

rem Copy required DLLs if they exist in System32
if exist "%SYSTEM32%\msvcp140.dll" (
    copy "%SYSTEM32%\msvcp140.dll" "%BUILD_DIR%\"
    echo ✅ Copied msvcp140.dll
) else (
    echo ⚠️  msvcp140.dll not found in System32
)

if exist "%SYSTEM32%\vcruntime140.dll" (
    copy "%SYSTEM32%\vcruntime140.dll" "%BUILD_DIR%\"
    echo ✅ Copied vcruntime140.dll
) else (
    echo ⚠️  vcruntime140.dll not found in System32
)

if exist "%SYSTEM32%\vcruntime140_1.dll" (
    copy "%SYSTEM32%\vcruntime140_1.dll" "%BUILD_DIR%\"
    echo ✅ Copied vcruntime140_1.dll
) else (
    echo ⚠️  vcruntime140_1.dll not found in System32
)

echo.
echo 📁 Executable location: %BUILD_DIR%\
echo.

rem Check if DLLs were copied successfully
if exist "%BUILD_DIR%\msvcp140.dll" if exist "%BUILD_DIR%\vcruntime140.dll" (
    echo ✅ Runtime DLLs bundled successfully!
    echo 🚀 Your app should now run on machines without VC++ Redistributable installed
) else (
    echo ⚠️  Some DLLs missing. Manual steps required:
    echo.
    echo 📋 Manual DLL Copy Instructions:
    echo    1. Download VC++ Redistributable: https://aka.ms/vs/17/release/vc_redist.x64.exe
    echo    2. Install it on your build machine
    echo    3. Copy these files from C:\Windows\System32\ to %BUILD_DIR%\:
    echo       - msvcp140.dll
    echo       - vcruntime140.dll  
    echo       - vcruntime140_1.dll
    echo.
    echo 🔄 Alternative: Have users install VC++ Redistributable:
    echo    Download: https://aka.ms/vs/17/release/vc_redist.x64.exe
)

echo.
echo ✅ Ready for distribution!
pause 