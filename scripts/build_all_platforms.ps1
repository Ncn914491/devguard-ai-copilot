# Cross-platform build script for DevGuard AI Copilot
# Satisfies Requirements: 13.1, 13.2, 13.3 (Cross-platform builds and packaging)

param(
    [string]$Version = "1.0.0",
    [string]$BuildMode = "release",
    [switch]$SkipTests = $false,
    [switch]$CreateInstallers = $true
)

Write-Host "DevGuard AI Copilot - Cross-Platform Build Script" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Build Mode: $BuildMode" -ForegroundColor Yellow

# Set error handling
$ErrorActionPreference = "Stop"

# Create build directory
$BuildDir = "build/releases/$Version"
if (Test-Path $BuildDir) {
    Remove-Item -Recurse -Force $BuildDir
}
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

# Function to log build steps
function Write-BuildLog {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Verify Flutter installation
Write-BuildLog "Verifying Flutter installation..." "Cyan"
if (-not (Test-Command "flutter")) {
    Write-Error "Flutter is not installed or not in PATH"
    exit 1
}

$flutterVersion = flutter --version | Select-String "Flutter" | ForEach-Object { $_.ToString() }
Write-BuildLog "Flutter Version: $flutterVersion" "Green"

# Clean previous builds
Write-BuildLog "Cleaning previous builds..." "Cyan"
flutter clean

# Get dependencies
Write-BuildLog "Getting Flutter dependencies..." "Cyan"
flutter pub get

# Run tests (unless skipped)
if (-not $SkipTests) {
    Write-BuildLog "Running tests..." "Cyan"
    flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Tests failed. Build aborted."
        exit 1
    }
    Write-BuildLog "All tests passed!" "Green"
}

# Build for Windows
Write-BuildLog "Building for Windows..." "Cyan"
try {
    flutter build windows --$BuildMode --build-name=$Version
    
    # Copy Windows build
    $WindowsSource = "build/windows/x64/runner/$BuildMode"
    $WindowsDest = "$BuildDir/windows"
    Copy-Item -Recurse $WindowsSource $WindowsDest
    
    Write-BuildLog "Windows build completed successfully" "Green"
} catch {
    Write-BuildLog "Windows build failed: $_" "Red"
}

# Build for macOS (if on macOS or with cross-compilation support)
if ($IsMacOS -or (Test-Command "flutter config --enable-macos-desktop")) {
    Write-BuildLog "Building for macOS..." "Cyan"
    try {
        flutter build macos --$BuildMode --build-name=$Version
        
        # Copy macOS build
        $MacOSSource = "build/macos/Build/Products/$([char]::ToUpper($BuildMode[0]) + $BuildMode.Substring(1))"
        $MacOSDest = "$BuildDir/macos"
        Copy-Item -Recurse $MacOSSource $MacOSDest
        
        Write-BuildLog "macOS build completed successfully" "Green"
    } catch {
        Write-BuildLog "macOS build failed: $_" "Red"
    }
} else {
    Write-BuildLog "Skipping macOS build (not supported on this platform)" "Yellow"
}

# Build for Linux (if on Linux or with cross-compilation support)
if ($IsLinux -or (Test-Command "flutter config --enable-linux-desktop")) {
    Write-BuildLog "Building for Linux..." "Cyan"
    try {
        flutter build linux --$BuildMode --build-name=$Version
        
        # Copy Linux build
        $LinuxSource = "build/linux/x64/$BuildMode/bundle"
        $LinuxDest = "$BuildDir/linux"
        Copy-Item -Recurse $LinuxSource $LinuxDest
        
        Write-BuildLog "Linux build completed successfully" "Green"
    } catch {
        Write-BuildLog "Linux build failed: $_" "Red"
    }
} else {
    Write-BuildLog "Skipping Linux build (not supported on this platform)" "Yellow"
}

# Create installers if requested
if ($CreateInstallers) {
    Write-BuildLog "Creating installers..." "Cyan"
    
    # Windows installer (using Inno Setup if available)
    if (Test-Path "$BuildDir/windows" -and (Test-Command "iscc")) {
        Write-BuildLog "Creating Windows installer..." "Cyan"
        $InnoScript = @"
[Setup]
AppName=DevGuard AI Copilot
AppVersion=$Version
DefaultDirName={pf}\DevGuard AI Copilot
DefaultGroupName=DevGuard AI Copilot
OutputDir=$BuildDir\installers
OutputBaseFilename=DevGuard-AI-Copilot-$Version-Windows-Setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "$BuildDir\windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\DevGuard AI Copilot"; Filename: "{app}\devguard_ai_copilot.exe"
Name: "{commondesktop}\DevGuard AI Copilot"; Filename: "{app}\devguard_ai_copilot.exe"

[Run]
Filename: "{app}\devguard_ai_copilot.exe"; Description: "{cm:LaunchProgram,DevGuard AI Copilot}"; Flags: nowait postinstall skipifsilent
"@
        
        $InnoScriptPath = "$BuildDir/installer.iss"
        $InnoScript | Out-File -FilePath $InnoScriptPath -Encoding UTF8
        
        New-Item -ItemType Directory -Path "$BuildDir/installers" -Force | Out-Null
        iscc $InnoScriptPath
        
        Write-BuildLog "Windows installer created" "Green"
    } else {
        Write-BuildLog "Skipping Windows installer (Inno Setup not available or Windows build missing)" "Yellow"
    }
    
    # macOS installer (create DMG if on macOS)
    if (Test-Path "$BuildDir/macos" -and $IsMacOS) {
        Write-BuildLog "Creating macOS installer..." "Cyan"
        $DmgPath = "$BuildDir/installers/DevGuard-AI-Copilot-$Version-macOS.dmg"
        New-Item -ItemType Directory -Path "$BuildDir/installers" -Force | Out-Null
        
        # This would use hdiutil to create DMG
        # hdiutil create -volname "DevGuard AI Copilot" -srcfolder "$BuildDir/macos" -ov -format UDZO "$DmgPath"
        
        Write-BuildLog "macOS installer would be created here (requires macOS tools)" "Yellow"
    }
    
    # Linux installer (create AppImage or DEB package)
    if (Test-Path "$BuildDir/linux") {
        Write-BuildLog "Creating Linux installer..." "Cyan"
        
        # Create a simple tar.gz package
        $LinuxPackage = "$BuildDir/installers/DevGuard-AI-Copilot-$Version-Linux.tar.gz"
        New-Item -ItemType Directory -Path "$BuildDir/installers" -Force | Out-Null
        
        if (Test-Command "tar") {
            tar -czf $LinuxPackage -C "$BuildDir" linux/
            Write-BuildLog "Linux package created: $LinuxPackage" "Green"
        } else {
            Write-BuildLog "Skipping Linux package (tar not available)" "Yellow"
        }
    }
}

# Generate build report
Write-BuildLog "Generating build report..." "Cyan"
$BuildReport = @"
DevGuard AI Copilot Build Report
================================
Version: $Version
Build Mode: $BuildMode
Build Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Flutter Version: $flutterVersion

Build Results:
"@

$platforms = @("windows", "macos", "linux")
foreach ($platform in $platforms) {
    if (Test-Path "$BuildDir/$platform") {
        $size = (Get-ChildItem -Recurse "$BuildDir/$platform" | Measure-Object -Property Length -Sum).Sum
        $sizeInMB = [math]::Round($size / 1MB, 2)
        $BuildReport += "`n✓ $platform - $sizeInMB MB"
    } else {
        $BuildReport += "`n✗ $platform - Not built"
    }
}

if ($CreateInstallers -and (Test-Path "$BuildDir/installers")) {
    $BuildReport += "`n`nInstallers:"
    Get-ChildItem "$BuildDir/installers" | ForEach-Object {
        $sizeInMB = [math]::Round($_.Length / 1MB, 2)
        $BuildReport += "`n✓ $($_.Name) - $sizeInMB MB"
    }
}

$BuildReport += "`n`nBuild completed successfully!"
$BuildReport | Out-File -FilePath "$BuildDir/build-report.txt" -Encoding UTF8

Write-Host $BuildReport -ForegroundColor Green

Write-BuildLog "Build process completed!" "Green"
Write-BuildLog "Build artifacts available in: $BuildDir" "Cyan"

# Create checksums for security
Write-BuildLog "Creating checksums..." "Cyan"
$ChecksumFile = "$BuildDir/checksums.txt"
"DevGuard AI Copilot v$Version - File Checksums" | Out-File -FilePath $ChecksumFile -Encoding UTF8
"Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $ChecksumFile -Append -Encoding UTF8
"" | Out-File -FilePath $ChecksumFile -Append -Encoding UTF8

Get-ChildItem -Recurse $BuildDir -File | Where-Object { $_.Name -ne "checksums.txt" } | ForEach-Object {
    $hash = Get-FileHash $_.FullName -Algorithm SHA256
    $relativePath = $_.FullName.Replace("$BuildDir\", "")
    "$($hash.Hash)  $relativePath" | Out-File -FilePath $ChecksumFile -Append -Encoding UTF8
}

Write-BuildLog "Checksums created: $ChecksumFile" "Green"

Write-Host "`nBuild Summary:" -ForegroundColor Magenta
Write-Host "- Version: $Version" -ForegroundColor White
Write-Host "- Build Directory: $BuildDir" -ForegroundColor White
Write-Host "- Platforms: $(($platforms | Where-Object { Test-Path "$BuildDir/$_" }) -join ', ')" -ForegroundColor White
if ($CreateInstallers) {
    $installerCount = (Get-ChildItem "$BuildDir/installers" -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "- Installers: $installerCount created" -ForegroundColor White
}
Write-Host "- Build Report: $BuildDir/build-report.txt" -ForegroundColor White
Write-Host "- Checksums: $BuildDir/checksums.txt" -ForegroundColor White