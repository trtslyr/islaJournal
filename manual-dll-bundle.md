# Manual Windows DLL Bundling Guide

If GitHub Actions isn't working yet, here's how to manually create a Windows build that works on older machines:

## Quick Manual Solution

### Step 1: Get the Required DLLs

**Download these DLLs manually:**
1. Go to: https://aka.ms/vs/17/release/vc_redist.x64.exe
2. Download and run the installer on a Windows machine
3. After installation, copy these files from `C:\Windows\System32\`:
   - `msvcp140.dll`
   - `vcruntime140.dll` 
   - `vcruntime140_1.dll`

### Step 2: Build Your Flutter App

**On Windows machine:**
```cmd
flutter build windows --release
```

### Step 3: Bundle the DLLs

**Copy the DLLs to your build output:**
```cmd
copy "C:\Windows\System32\msvcp140.dll" "build\windows\runner\Release\"
copy "C:\Windows\System32\vcruntime140.dll" "build\windows\runner\Release\"
copy "C:\Windows\System32\vcruntime140_1.dll" "build\windows\runner\Release\"
```

### Step 4: Verify and Package

**Check your build directory contains:**
```
📁 build\windows\runner\Release\
├── isla_journal.exe          ✅ Your app
├── flutter_windows.dll       ✅ Flutter runtime
├── msvcp140.dll              ✅ VC++ runtime
├── vcruntime140.dll          ✅ VC++ runtime  
├── vcruntime140_1.dll        ✅ VC++ runtime
├── data\                     ✅ Flutter assets
└── ...other files
```

**Create distribution package:**
```cmd
cd build\windows\runner\Release
tar -czf isla-journal-windows-manual.tar.gz *
```

## Alternative: Pre-bundled DLLs

If you don't have access to a Windows machine with VC++ installed, I can provide the DLLs directly in the repo:

1. Create a `windows-dlls/` folder in your repo
2. Add the required DLLs there  
3. Modify build scripts to copy from that folder instead

## Testing Your Build

**Critical test:** Run the bundled executable on a "clean" Windows machine (one without Visual Studio or VC++ Redistributable installed) to verify it works.

## Success Criteria

✅ **isla_journal.exe runs immediately** on any Windows 10/11 machine  
✅ **No "DLL not found" errors**  
✅ **No user installation required** 