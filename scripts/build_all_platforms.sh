#!/bin/bash

# Cross-platform build script for DevGuard AI Copilot (Unix/Linux/macOS)
# Satisfies Requirements: 13.1, 13.2, 13.3 (Cross-platform builds and packaging)

set -e  # Exit on any error

# Default values
VERSION="1.0.0"
BUILD_MODE="release"
SKIP_TESTS=false
CREATE_INSTALLERS=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --build-mode)
            BUILD_MODE="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --no-installers)
            CREATE_INSTALLERS=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --version VERSION      Set build version (default: 1.0.0)"
            echo "  --build-mode MODE      Set build mode: debug|release (default: release)"
            echo "  --skip-tests          Skip running tests"
            echo "  --no-installers       Skip creating installers"
            echo "  -h, --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to log build steps
log_build() {
    local message="$1"
    local color="${2:-$NC}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${color}[$timestamp] $message${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect platform
PLATFORM=$(uname -s)
case $PLATFORM in
    Linux*)     PLATFORM=Linux;;
    Darwin*)    PLATFORM=macOS;;
    CYGWIN*)    PLATFORM=Windows;;
    MINGW*)     PLATFORM=Windows;;
    *)          PLATFORM="Unknown";;
esac

echo -e "${GREEN}DevGuard AI Copilot - Cross-Platform Build Script${NC}"
echo -e "${YELLOW}Version: $VERSION${NC}"
echo -e "${YELLOW}Build Mode: $BUILD_MODE${NC}"
echo -e "${YELLOW}Platform: $PLATFORM${NC}"

# Create build directory
BUILD_DIR="build/releases/$VERSION"
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"

# Verify Flutter installation
log_build "Verifying Flutter installation..." "$CYAN"
if ! command_exists flutter; then
    echo -e "${RED}Error: Flutter is not installed or not in PATH${NC}"
    exit 1
fi

FLUTTER_VERSION=$(flutter --version | head -n 1)
log_build "Flutter Version: $FLUTTER_VERSION" "$GREEN"

# Clean previous builds
log_build "Cleaning previous builds..." "$CYAN"
flutter clean

# Get dependencies
log_build "Getting Flutter dependencies..." "$CYAN"
flutter pub get

# Run tests (unless skipped)
if [ "$SKIP_TESTS" = false ]; then
    log_build "Running tests..." "$CYAN"
    if ! flutter test; then
        echo -e "${RED}Error: Tests failed. Build aborted.${NC}"
        exit 1
    fi
    log_build "All tests passed!" "$GREEN"
fi

# Build for current platform and cross-compile if possible
BUILD_SUCCESS=()
BUILD_FAILED=()

# Build for Windows (if supported)
if command_exists flutter && flutter config --list | grep -q "enable-windows-desktop: true"; then
    log_build "Building for Windows..." "$CYAN"
    if flutter build windows --$BUILD_MODE --build-name=$VERSION; then
        # Copy Windows build
        WINDOWS_SOURCE="build/windows/x64/runner/$BUILD_MODE"
        WINDOWS_DEST="$BUILD_DIR/windows"
        if [ -d "$WINDOWS_SOURCE" ]; then
            cp -r "$WINDOWS_SOURCE" "$WINDOWS_DEST"
            BUILD_SUCCESS+=("Windows")
            log_build "Windows build completed successfully" "$GREEN"
        else
            BUILD_FAILED+=("Windows")
            log_build "Windows build directory not found" "$RED"
        fi
    else
        BUILD_FAILED+=("Windows")
        log_build "Windows build failed" "$RED"
    fi
else
    log_build "Skipping Windows build (not supported on this platform)" "$YELLOW"
fi

# Build for macOS (if on macOS)
if [ "$PLATFORM" = "macOS" ] && command_exists flutter; then
    log_build "Building for macOS..." "$CYAN"
    if flutter build macos --$BUILD_MODE --build-name=$VERSION; then
        # Copy macOS build
        BUILD_MODE_CAPITALIZED="$(tr '[:lower:]' '[:upper:]' <<< ${BUILD_MODE:0:1})${BUILD_MODE:1}"
        MACOS_SOURCE="build/macos/Build/Products/$BUILD_MODE_CAPITALIZED"
        MACOS_DEST="$BUILD_DIR/macos"
        if [ -d "$MACOS_SOURCE" ]; then
            cp -r "$MACOS_SOURCE" "$MACOS_DEST"
            BUILD_SUCCESS+=("macOS")
            log_build "macOS build completed successfully" "$GREEN"
        else
            BUILD_FAILED+=("macOS")
            log_build "macOS build directory not found" "$RED"
        fi
    else
        BUILD_FAILED+=("macOS")
        log_build "macOS build failed" "$RED"
    fi
else
    log_build "Skipping macOS build (not on macOS platform)" "$YELLOW"
fi

# Build for Linux (if on Linux or supported)
if [ "$PLATFORM" = "Linux" ] && command_exists flutter; then
    log_build "Building for Linux..." "$CYAN"
    if flutter build linux --$BUILD_MODE --build-name=$VERSION; then
        # Copy Linux build
        LINUX_SOURCE="build/linux/x64/$BUILD_MODE/bundle"
        LINUX_DEST="$BUILD_DIR/linux"
        if [ -d "$LINUX_SOURCE" ]; then
            cp -r "$LINUX_SOURCE" "$LINUX_DEST"
            BUILD_SUCCESS+=("Linux")
            log_build "Linux build completed successfully" "$GREEN"
        else
            BUILD_FAILED+=("Linux")
            log_build "Linux build directory not found" "$RED"
        fi
    else
        BUILD_FAILED+=("Linux")
        log_build "Linux build failed" "$RED"
    fi
else
    log_build "Skipping Linux build (not on Linux platform)" "$YELLOW"
fi

# Create installers if requested
if [ "$CREATE_INSTALLERS" = true ]; then
    log_build "Creating installers..." "$CYAN"
    mkdir -p "$BUILD_DIR/installers"
    
    # macOS installer (create DMG if on macOS)
    if [ -d "$BUILD_DIR/macos" ] && [ "$PLATFORM" = "macOS" ] && command_exists hdiutil; then
        log_build "Creating macOS installer..." "$CYAN"
        DMG_PATH="$BUILD_DIR/installers/DevGuard-AI-Copilot-$VERSION-macOS.dmg"
        
        if hdiutil create -volname "DevGuard AI Copilot" -srcfolder "$BUILD_DIR/macos" -ov -format UDZO "$DMG_PATH"; then
            log_build "macOS installer created: $DMG_PATH" "$GREEN"
        else
            log_build "Failed to create macOS installer" "$RED"
        fi
    fi
    
    # Linux installer (create tar.gz and AppImage if possible)
    if [ -d "$BUILD_DIR/linux" ]; then
        log_build "Creating Linux installer..." "$CYAN"
        
        # Create tar.gz package
        LINUX_PACKAGE="$BUILD_DIR/installers/DevGuard-AI-Copilot-$VERSION-Linux.tar.gz"
        if tar -czf "$LINUX_PACKAGE" -C "$BUILD_DIR" linux/; then
            log_build "Linux package created: $LINUX_PACKAGE" "$GREEN"
        else
            log_build "Failed to create Linux package" "$RED"
        fi
        
        # Create .deb package if dpkg-deb is available
        if command_exists dpkg-deb; then
            log_build "Creating Debian package..." "$CYAN"
            
            DEB_DIR="$BUILD_DIR/deb-package"
            mkdir -p "$DEB_DIR/DEBIAN"
            mkdir -p "$DEB_DIR/usr/bin"
            mkdir -p "$DEB_DIR/usr/share/applications"
            mkdir -p "$DEB_DIR/usr/share/pixmaps"
            
            # Create control file
            cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: devguard-ai-copilot
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Maintainer: DevGuard Team <team@devguard.ai>
Description: AI-powered development security and productivity copilot
 DevGuard AI Copilot provides automated git workflows, security monitoring,
 deployment management, and team collaboration features for development teams.
EOF
            
            # Copy application files
            cp -r "$BUILD_DIR/linux/"* "$DEB_DIR/usr/bin/"
            
            # Create desktop entry
            cat > "$DEB_DIR/usr/share/applications/devguard-ai-copilot.desktop" << EOF
[Desktop Entry]
Name=DevGuard AI Copilot
Comment=AI-powered development security and productivity copilot
Exec=/usr/bin/devguard_ai_copilot
Icon=devguard-ai-copilot
Terminal=false
Type=Application
Categories=Development;
EOF
            
            # Build .deb package
            DEB_PACKAGE="$BUILD_DIR/installers/devguard-ai-copilot_${VERSION}_amd64.deb"
            if dpkg-deb --build "$DEB_DIR" "$DEB_PACKAGE"; then
                log_build "Debian package created: $DEB_PACKAGE" "$GREEN"
            else
                log_build "Failed to create Debian package" "$RED"
            fi
            
            # Clean up
            rm -rf "$DEB_DIR"
        fi
    fi
    
    # Windows installer (create NSIS installer if available)
    if [ -d "$BUILD_DIR/windows" ] && command_exists makensis; then
        log_build "Creating Windows installer..." "$CYAN"
        
        NSIS_SCRIPT="$BUILD_DIR/installer.nsi"
        cat > "$NSIS_SCRIPT" << EOF
!define APPNAME "DevGuard AI Copilot"
!define COMPANYNAME "DevGuard"
!define DESCRIPTION "AI-powered development security and productivity copilot"
!define VERSIONMAJOR 1
!define VERSIONMINOR 0
!define VERSIONBUILD 0

RequestExecutionLevel admin
InstallDir "\$PROGRAMFILES64\\DevGuard AI Copilot"
Name "\${APPNAME}"
Icon "assets\\icon.ico"
outFile "$BUILD_DIR\\installers\\DevGuard-AI-Copilot-$VERSION-Windows-Setup.exe"

page directory
page instfiles

section "install"
    setOutPath \$INSTDIR
    file /r "$BUILD_DIR\\windows\\*"
    
    writeUninstaller "\$INSTDIR\\uninstall.exe"
    
    createDirectory "\$SMPROGRAMS\\\${COMPANYNAME}"
    createShortCut "\$SMPROGRAMS\\\${COMPANYNAME}\\\${APPNAME}.lnk" "\$INSTDIR\\devguard_ai_copilot.exe"
    createShortCut "\$DESKTOP\\\${APPNAME}.lnk" "\$INSTDIR\\devguard_ai_copilot.exe"
sectionEnd

section "uninstall"
    delete "\$INSTDIR\\uninstall.exe"
    rmDir /r "\$INSTDIR"
    
    delete "\$SMPROGRAMS\\\${COMPANYNAME}\\\${APPNAME}.lnk"
    delete "\$DESKTOP\\\${APPNAME}.lnk"
    rmDir "\$SMPROGRAMS\\\${COMPANYNAME}"
sectionEnd
EOF
        
        if makensis "$NSIS_SCRIPT"; then
            log_build "Windows installer created" "$GREEN"
        else
            log_build "Failed to create Windows installer" "$RED"
        fi
    fi
fi

# Generate build report
log_build "Generating build report..." "$CYAN"
BUILD_REPORT="$BUILD_DIR/build-report.txt"

cat > "$BUILD_REPORT" << EOF
DevGuard AI Copilot Build Report
================================
Version: $VERSION
Build Mode: $BUILD_MODE
Build Date: $(date '+%Y-%m-%d %H:%M:%S')
Platform: $PLATFORM
Flutter Version: $FLUTTER_VERSION

Build Results:
EOF

# Add build results
for platform in "${BUILD_SUCCESS[@]}"; do
    if [ -d "$BUILD_DIR/$(echo $platform | tr '[:upper:]' '[:lower:]')" ]; then
        SIZE=$(du -sh "$BUILD_DIR/$(echo $platform | tr '[:upper:]' '[:lower:]')" | cut -f1)
        echo "✓ $platform - $SIZE" >> "$BUILD_REPORT"
    fi
done

for platform in "${BUILD_FAILED[@]}"; do
    echo "✗ $platform - Build failed" >> "$BUILD_REPORT"
done

# Add installer information
if [ "$CREATE_INSTALLERS" = true ] && [ -d "$BUILD_DIR/installers" ]; then
    echo "" >> "$BUILD_REPORT"
    echo "Installers:" >> "$BUILD_REPORT"
    for installer in "$BUILD_DIR/installers"/*; do
        if [ -f "$installer" ]; then
            SIZE=$(du -sh "$installer" | cut -f1)
            FILENAME=$(basename "$installer")
            echo "✓ $FILENAME - $SIZE" >> "$BUILD_REPORT"
        fi
    done
fi

echo "" >> "$BUILD_REPORT"
echo "Build completed successfully!" >> "$BUILD_REPORT"

# Display build report
cat "$BUILD_REPORT"

log_build "Build process completed!" "$GREEN"
log_build "Build artifacts available in: $BUILD_DIR" "$CYAN"

# Create checksums for security
log_build "Creating checksums..." "$CYAN"
CHECKSUM_FILE="$BUILD_DIR/checksums.txt"

echo "DevGuard AI Copilot v$VERSION - File Checksums" > "$CHECKSUM_FILE"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$CHECKSUM_FILE"
echo "" >> "$CHECKSUM_FILE"

find "$BUILD_DIR" -type f ! -name "checksums.txt" -exec sha256sum {} \; | \
    sed "s|$BUILD_DIR/||g" >> "$CHECKSUM_FILE"

log_build "Checksums created: $CHECKSUM_FILE" "$GREEN"

# Build summary
echo -e "\n${MAGENTA}Build Summary:${NC}"
echo -e "${NC}- Version: $VERSION"
echo -e "${NC}- Build Directory: $BUILD_DIR"
echo -e "${NC}- Successful Builds: ${BUILD_SUCCESS[*]}"
if [ ${#BUILD_FAILED[@]} -gt 0 ]; then
    echo -e "${NC}- Failed Builds: ${BUILD_FAILED[*]}"
fi
if [ "$CREATE_INSTALLERS" = true ]; then
    INSTALLER_COUNT=$(find "$BUILD_DIR/installers" -type f 2>/dev/null | wc -l)
    echo -e "${NC}- Installers: $INSTALLER_COUNT created"
fi
echo -e "${NC}- Build Report: $BUILD_REPORT"
echo -e "${NC}- Checksums: $CHECKSUM_FILE"

log_build "All done! 🚀" "$GREEN"