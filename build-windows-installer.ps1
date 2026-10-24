# =====================================================================
# Whisper: Windows Setup Wizard (.exe) Builder
# Builds Flutter Windows release and packages with Inno Setup
# =====================================================================

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🚀 Whisper: Building Windows Setup Wizard Installer (.exe)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check Flutter
Write-Host "`n>>> [1/4] Checking Flutter environment..." -ForegroundColor Yellow
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Host "❌ Flutter CLI was not found in PATH. Please install Flutter or add it to PATH." -ForegroundColor Red
    exit 1
}
Write-Host "✅ Flutter detected: $(flutter --version | Select-Object -First 1)" -ForegroundColor Green

# 2. Check or install Inno Setup Compiler (ISCC)
Write-Host "`n>>> [2/4] Locating Inno Setup Compiler (ISCC.exe)..." -ForegroundColor Yellow
$isccCandidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 5\ISCC.exe",
    (Get-Command iscc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
)

$isccPath = $isccCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $isccPath) {
    Write-Host "⚠️  Inno Setup Compiler not found. Attempting automatic installation via Chocolatey or Winget..." -ForegroundColor Yellow
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "Running: choco install innosetup -y..." -ForegroundColor Cyan
        Start-Process choco -ArgumentList "install", "innosetup", "-y" -Wait -Verb RunAs
    } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Running: winget install JRSoftware.InnoSetup -e --silent..." -ForegroundColor Cyan
        Start-Process winget -ArgumentList "install", "JRSoftware.InnoSetup", "-e", "--silent" -Wait
    }

    # Recheck
    $isccPath = $isccCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

if (-not $isccPath) {
    Write-Host "❌ Inno Setup Compiler (ISCC.exe) is required to build the 'Next > Next' installer." -ForegroundColor Red
    Write-Host "Please download and install Inno Setup 6 from: https://jrsoftware.org/isdl.php" -ForegroundColor White
    exit 1
}
Write-Host "✅ Found Inno Setup: $isccPath" -ForegroundColor Green

# 3. Build Flutter Windows Release
Write-Host "`n>>> [3/4] Building Flutter Windows release binary..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\frontend"
try {
    flutter config --enable-windows-desktop
    flutter pub get
    flutter build windows --release
} finally {
    Pop-Location
}

$releaseDir = "$PSScriptRoot\frontend\build\windows\x64\runner\Release"
if (-not (Test-Path "$releaseDir\whisper.exe") -and -not (Test-Path "$releaseDir\frontend.exe")) {
    Write-Host "❌ Flutter Windows build output not found at: $releaseDir" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Flutter Windows binary compiled successfully!" -ForegroundColor Green

# 4. Compile Inno Setup Script
Write-Host "`n>>> [4/4] Compiling Windows Setup Wizard (.exe)..." -ForegroundColor Yellow
$issPath = "$PSScriptRoot\frontend\windows\installer\inno_setup.iss"
$outputDir = "$PSScriptRoot\artifacts\windows"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

& $isccPath $issPath

$installerPath = "$outputDir\whisper-windows-setup.exe"
if (Test-Path $installerPath) {
    $fileSizeMB = [math]::Round((Get-Item $installerPath).Length / 1MB, 2)
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "🎉 SUCCESS! Windows Setup Wizard Installer generated:" -ForegroundColor Green
    Write-Host "📍 Path: $installerPath" -ForegroundColor White
    Write-Host "📊 Size: $fileSizeMB MB" -ForegroundColor White
    Write-Host "✨ Double-click the file to install through the Next > Next wizard!" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to generate installer at $installerPath" -ForegroundColor Red
    exit 1
}
