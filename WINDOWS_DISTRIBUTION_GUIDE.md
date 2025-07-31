# Windows Distribution Guide for Isla Journal

## The Problem

When running Isla Journal on older Windows machines, users may encounter these errors:
- `msvcp140.dll not found`
- `vcruntime140.dll not found`
- `vcruntime140_1.dll not found`

These are **Microsoft Visual C++ Redistributable** libraries required by Flutter Windows apps.

## Solutions

### Option 1: Bundle DLLs (Recommended)

**Pros:**
- ✅ Works immediately on any Windows machine
- ✅ No user installation required
- ✅ Larger app size but guaranteed compatibility

**Steps:**
1. Run `build-windows.bat` (now auto-copies DLLs)
2. Distribute the entire `build\windows\runner\Release\` folder
3. Users run `isla_journal.exe` directly

### Option 2: User Installs Redistributable

**Pros:**
- ✅ Smaller app distribution size
- ✅ Benefits other apps on user's machine
- ❌ Requires user to install dependency

**Steps:**
1. Build with: `flutter build windows --release`
2. Provide users with these instructions:

```
Before running Isla Journal:
1. Download: https://aka.ms/vs/17/release/vc_redist.x64.exe
2. Install the Microsoft Visual C++ Redistributable
3. Run isla_journal.exe
```

### Option 3: Installer Package (Advanced)

Create a proper Windows installer using tools like:
- **Inno Setup** (Free, popular)
- **NSIS** (Free, powerful)
- **WiX Toolset** (Free, professional)

The installer can:
- Install the app
- Check for and install VC++ Redistributable if missing
- Create Start Menu shortcuts
- Handle uninstallation

## Required DLL Files

If bundling manually, ensure these files are in the same directory as `isla_journal.exe`:

```
📁 Release/
├── isla_journal.exe          # Your app
├── flutter_windows.dll       # Flutter engine (auto-included)
├── msvcp140.dll              # Visual C++ Runtime
├── vcruntime140.dll          # Visual C++ Runtime  
├── vcruntime140_1.dll        # Visual C++ Runtime (newer versions)
├── data/                     # Flutter assets
└── ...other Flutter files
```

## Testing Distribution

**Before distributing:**
1. Test on a clean Windows VM without Visual Studio/VC++ installed
2. Try Windows 10 (older versions) and Windows 11
3. Test both x64 and x86 architectures if supporting both

## Target Windows Versions

Your app currently targets:
- **Architecture:** x64 (64-bit)
- **Minimum Windows:** Windows 10 1903 or later
- **Recommended:** Windows 10 21H2+ or Windows 11

## Distribution Checklist

- [ ] Built with `build-windows.bat`
- [ ] Verified DLLs are bundled
- [ ] Tested on clean Windows machine
- [ ] Created user documentation
- [ ] Zip/package the Release folder
- [ ] Include version info and system requirements

## Potential Issues & Solutions

### **Build Machine Issues**

**Problem:** DLLs not found during build
- **Cause:** Build machine doesn't have VC++ Redistributable installed
- **Solution:** Install https://aka.ms/vs/17/release/vc_redist.x64.exe on build machine

**Problem:** Permission denied copying DLLs
- **Cause:** Restricted environment or antivirus blocking
- **Solution:** Run build script as administrator or manually copy DLLs

**Problem:** Wrong architecture DLLs copied
- **Cause:** x86 DLLs copied instead of x64
- **Solution:** Ensure you're building on 64-bit Windows and check System32 (not SysWOW64)

### **User Issues**

**Problem:** Still getting DLL errors after bundling
1. **Check architecture:** Ensure user has 64-bit Windows
2. **Check DLL versions:** Different VC++ versions have different DLLs
3. **Check all DLLs:** Verify both `msvcp140.dll` AND `vcruntime140.dll` are present
4. **Antivirus interference:** Some antivirus software blocks unknown DLLs

**Emergency Solution:** Have users install VC++ Redistributable directly:
```
https://aka.ms/vs/17/release/vc_redist.x64.exe
```

## Testing Strategy

### **Critical Testing Steps:**
1. **Test on clean Windows VM** without Visual Studio
2. **Test on older Windows 10** machines  
3. **Test on Windows 11** 
4. **Test with antivirus software** running
5. **Test user account without admin rights**

### **Verification Tools:**

**Check dependencies:**
```cmd
dumpbin /dependents isla_journal.exe
```

**Check DLL versions:**
```cmd
powershell "Get-ItemProperty 'msvcp140.dll' | Select-Object VersionInfo"
```

## Troubleshooting

**If users still get DLL errors:**
1. Ensure they're running the correct architecture (x64)
2. Check Windows version compatibility (Windows 10 1903+ required)
3. Try installing VC++ Redistributable manually
4. Run Windows Update to get latest system libraries
5. Check antivirus isn't blocking the DLLs
6. Verify all required DLLs are in the same folder as the .exe

**For developers:**
- Build on Windows machine with latest Visual Studio redistributables
- Use `build-windows-robust.bat` for better error checking
- Test distribution package on various Windows versions
- Keep both bundled and non-bundled versions for different distribution needs 