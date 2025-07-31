#!/usr/bin/env pwsh

Write-Host "🏗️  Building Windows Release..." -ForegroundColor Cyan
Write-Host ""

# Build the Flutter Windows app
Write-Host "Building Flutter app..." -ForegroundColor Yellow
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter build failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Build complete!" -ForegroundColor Green
Write-Host ""

# Automatically copy VC++ Runtime DLLs
Write-Host "🔄 Copying Visual C++ Runtime DLLs..." -ForegroundColor Yellow

$BuildDir = "build\windows\runner\Release"
$System32 = "$env:WINDIR\System32"
$RequiredDlls = @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")
$CopiedDlls = @()

foreach ($dll in $RequiredDlls) {
    $sourcePath = Join-Path $System32 $dll
    $destPath = Join-Path $BuildDir $dll
    
    if (Test-Path $sourcePath) {
        try {
            Copy-Item $sourcePath $destPath -Force
            Write-Host "✅ Copied $dll" -ForegroundColor Green
            $CopiedDlls += $dll
        }
        catch {
            Write-Host "⚠️  Failed to copy $dll : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⚠️  $dll not found in System32" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "📁 Executable location: $BuildDir\" -ForegroundColor Cyan
Write-Host ""

# Check if critical DLLs were copied successfully  
$criticalDlls = @("msvcp140.dll", "vcruntime140.dll")
$allCriticalCopied = $true

foreach ($dll in $criticalDlls) {
    if (-not (Test-Path (Join-Path $BuildDir $dll))) {
        $allCriticalCopied = $false
        break
    }
}

if ($allCriticalCopied) {
    Write-Host "✅ Runtime DLLs bundled successfully!" -ForegroundColor Green
    Write-Host "🚀 Your app should now run on machines without VC++ Redistributable installed" -ForegroundColor Green
} else {
    Write-Host "⚠️  Some DLLs missing. Manual steps required:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📋 Manual DLL Copy Instructions:" -ForegroundColor Cyan
    Write-Host "   1. Download VC++ Redistributable: https://aka.ms/vs/17/release/vc_redist.x64.exe"
    Write-Host "   2. Install it on your build machine"
    Write-Host "   3. Copy these files from C:\Windows\System32\ to $BuildDir\:"
    Write-Host "      - msvcp140.dll"
    Write-Host "      - vcruntime140.dll"
    Write-Host "      - vcruntime140_1.dll"
    Write-Host ""
    Write-Host "🔄 Alternative: Have users install VC++ Redistributable:" -ForegroundColor Cyan
    Write-Host "   Download: https://aka.ms/vs/17/release/vc_redist.x64.exe"
}

Write-Host ""
Write-Host "✅ Ready for distribution!" -ForegroundColor Green

# Get build info
$exePath = Join-Path $BuildDir "isla_journal.exe"
if (Test-Path $exePath) {
    $fileInfo = Get-ItemProperty $exePath
    Write-Host ""
    Write-Host "📊 Build Information:" -ForegroundColor Cyan
    Write-Host "   Executable: $($fileInfo.Name)"
    Write-Host "   Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB"
    Write-Host "   Modified: $($fileInfo.LastWriteTime)"
    
    # Show bundled DLLs
    Write-Host "   Bundled DLLs: $($CopiedDlls.Count) of $($RequiredDlls.Count)"
    if ($CopiedDlls.Count -gt 0) {
        Write-Host "      - $($CopiedDlls -join ', ')"
    }
}

Write-Host ""
Read-Host "Press Enter to continue" 