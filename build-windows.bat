@echo off
echo 🏗️  Building Windows Release...
echo.

rem Build the Flutter Windows app
flutter build windows --release

echo.
echo ✅ Build complete!
echo.
echo 📁 Executable location: build\windows\runner\Release\
echo.
echo ⚠️  IMPORTANT: Copy Visual C++ Runtime DLLs for distribution:
echo    Copy these 3 files to build\windows\runner\Release\:
echo    - msvcp140.dll
echo    - vcruntime140.dll  
echo    - vcruntime140_1.dll
echo.
echo    Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
echo    Or find in: C:\Windows\System32\
echo.
echo 🚀 Alternative: Users can install VC++ Redistributable instead
echo    Download: https://aka.ms/vs/17/release/vc_redist.x64.exe
echo.
echo ✅ Ready for distribution!
pause 