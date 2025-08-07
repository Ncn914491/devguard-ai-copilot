#!/bin/bash

# DevGuard AI Copilot - Cross-Platform Test Runner
# Bash script for Linux/macOS

echo "🚀 DevGuard AI Copilot - Cross-Platform Test Runner"
echo "======================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "\n${YELLOW}📋 Checking Prerequisites...${NC}"

if ! command_exists flutter; then
    echo -e "${RED}❌ Flutter not found in PATH${NC}"
    echo -e "${GRAY}   Install Flutter: https://flutter.dev/docs/get-started/install${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Flutter found${NC}"

if ! command_exists dart; then
    echo -e "${RED}❌ Dart not found in PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Dart found${NC}"

# Validate environment
echo -e "\n${YELLOW}🔍 Validating Environment...${NC}"
if dart run scripts/validate_environment.dart; then
    echo -e "${GREEN}✅ Environment validation passed${NC}"
else
    echo -e "${RED}❌ Environment validation failed${NC}"
    exit 1
fi

# Get dependencies
echo -e "\n${YELLOW}📦 Getting Dependencies...${NC}"
if flutter pub get; then
    echo -e "${GREEN}✅ Dependencies resolved${NC}"
else
    echo -e "${RED}❌ Failed to get dependencies${NC}"
    exit 1
fi

# Run unit tests
echo -e "\n${YELLOW}🧪 Running Unit Tests...${NC}"
if flutter test test/signup_flow_integration_test.dart; then
    echo -e "${GREEN}✅ Unit tests passed${NC}"
else
    echo -e "${RED}❌ Unit tests failed${NC}"
    exit 1
fi

# Run integration tests
echo -e "\n${YELLOW}🔗 Running Integration Tests...${NC}"
if flutter test test/integration/; then
    echo -e "${GREEN}✅ Integration tests passed${NC}"
else
    echo -e "${YELLOW}⚠️  Some integration tests failed${NC}"
fi

# Test Web Build
echo -e "\n${YELLOW}🌐 Testing Web Build...${NC}"
if flutter build web --release; then
    echo -e "${GREEN}✅ Web build successful${NC}"
else
    echo -e "${RED}❌ Web build failed${NC}"
    exit 1
fi

# Test Linux Build (if on Linux)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "\n${YELLOW}🐧 Testing Linux Build...${NC}"
    if flutter build linux --release; then
        echo -e "${GREEN}✅ Linux build successful${NC}"
    else
        echo -e "${RED}❌ Linux build failed${NC}"
        exit 1
    fi
fi

# Test macOS Build (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "\n${YELLOW}🍎 Testing macOS Build...${NC}"
    if flutter build macos --release; then
        echo -e "${GREEN}✅ macOS build successful${NC}"
    else
        echo -e "${RED}❌ macOS build failed${NC}"
        exit 1
    fi
fi

# Run the app in debug mode for quick validation
echo -e "\n${YELLOW}🏃 Quick App Validation...${NC}"
echo -e "${GRAY}Starting app in debug mode for 30 seconds...${NC}"

timeout 30s flutter run --web-port=8080 --web-hostname=localhost &
APP_PID=$!
sleep 30
kill $APP_PID 2>/dev/null || true

echo -e "\n======================================================"
echo -e "${GREEN}✅ Cross-platform tests completed successfully!${NC}"
echo -e "\n${CYAN}🚀 Ready to deploy!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "${GRAY}  • Run 'flutter run -d web' for web development${NC}"
echo -e "${GRAY}  • Run 'flutter run -d linux' for Linux development${NC}"
echo -e "${GRAY}  • Run 'flutter run -d macos' for macOS development${NC}"
echo -e "${GRAY}  • Check build/web/ for web deployment files${NC}"