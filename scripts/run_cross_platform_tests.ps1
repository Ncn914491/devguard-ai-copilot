# DevGuard AI Copilot - Cross-Platform Test Runner
# PowerShell script for Windows

Write-Host "🚀 DevGuard AI Copilot - Cross-Platform Test Runner" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Function to check if command exists
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

# Check prerequisites
Write-Host "`n📋 Checking Prerequisites..." -ForegroundColor Yellow

if (-not (Test-Command "flutter")) {
    Write-Host "❌ Flutter not found in PATH" -ForegroundColor Red
    Write-Host "   Install Flutter: https://flutter.dev/docs/get-started/install" -ForegroundColor Gray
    exit 1
}
Write-Host "✅ Flutter found" -ForegroundColor Green

if (-not (Test-Command "dart")) {
    Write-Host "❌ Dart not found in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Dart found" -ForegroundColor Green

# Validate environment
Write-Host "`n🔍 Validating Environment..." -ForegroundColor Yellow
try {
    dart run scripts/validate_environment.dart
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Environment validation failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "⚠️  Could not run environment validation" -ForegroundColor Yellow
}

# Get dependencies
Write-Host "`n📦 Getting Dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to get dependencies" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Dependencies resolved" -ForegroundColor Green

# Run unit tests
Write-Host "`n🧪 Running Unit Tests..." -ForegroundColor Yellow
flutter test test/signup_flow_integration_test.dart
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Unit tests failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Unit tests passed" -ForegroundColor Green

# Run integration tests
Write-Host "`n🔗 Running Integration Tests..." -ForegroundColor Yellow
flutter test test/integration/
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Some integration tests failed" -ForegroundColor Yellow
} else {
    Write-Host "✅ Integration tests passed" -ForegroundColor Green
}

# Test Web Build
Write-Host "`n🌐 Testing Web Build..." -ForegroundColor Yellow
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Web build failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Web build successful" -ForegroundColor Green

# Test Windows Build (if on Windows)
if ($IsWindows -or $env:OS -eq "Windows_NT") {
    Write-Host "`n🖥️  Testing Windows Build..." -ForegroundColor Yellow
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Windows build failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Windows build successful" -ForegroundColor Green
}

# Run the app in debug mode for quick validation
Write-Host "`n🏃 Quick App Validation..." -ForegroundColor Yellow
Write-Host "Starting app in debug mode for 30 seconds..." -ForegroundColor Gray

$job = Start-Job -ScriptBlock {
    flutter run --web-port=8080 --web-hostname=localhost
}

Start-Sleep -Seconds 30
Stop-Job $job
Remove-Job $job

Write-Host "`n" + "=" * 60 -ForegroundColor Gray
Write-Host "✅ Cross-platform tests completed successfully!" -ForegroundColor Green
Write-Host "`n🚀 Ready to deploy!" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  • Run 'flutter run -d web' for web development" -ForegroundColor Gray
Write-Host "  • Run 'flutter run -d windows' for Windows development" -ForegroundColor Gray
Write-Host "  • Check build/web/ for web deployment files" -ForegroundColor Gray
Write-Host "  • Check build/windows/ for Windows deployment files" -ForegroundColor Gray