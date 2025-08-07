#!/bin/bash

# DevGuard AI Copilot - Supabase-enabled Deployment Script
# Updated deployment script that uses Supabase instead of local database

set -e

# Configuration
APP_NAME="DevGuard AI Copilot"
APP_VERSION="1.0.0"
BUILD_DIR="build"
DEPLOY_DIR="deployment"
CONFIG_DIR="config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS=Linux;;
        Darwin*)    OS=macOS;;
        CYGWIN*|MINGW*|MSYS*) OS=Windows;;
        *)          OS="Unknown";;
    esac
    log "Detected OS: $OS"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        error "Flutter is not installed or not in PATH"
    fi
    
    # Check Dart
    if ! command -v dart &> /dev/null; then
        error "Dart is not installed or not in PATH"
    fi
    
    # Check Docker (optional)
    if command -v docker &> /dev/null; then
        log "Docker found - container deployment available"
        DOCKER_AVAILABLE=true
    else
        warn "Docker not found - container deployment not available"
        DOCKER_AVAILABLE=false
    fi
    
    # Check Git
    if ! command -v git &> /dev/null; then
        warn "Git not found - version info may be limited"
    fi
    
    # Check curl for Supabase connectivity
    if ! command -v curl &> /dev/null; then
        error "curl is required for Supabase connectivity verification"
    fi
    
    # Verify Flutter doctor
    log "Running Flutter doctor..."
    flutter doctor --verbose
    
    log "Prerequisites check completed"
}

# Verify Supabase connectivity
verify_supabase_connectivity() {
    log "Verifying Supabase connectivity..."
    
    # Check if environment variables are set
    if [[ -z "$SUPABASE_URL" ]]; then
        error "SUPABASE_URL environment variable is not set"
    fi
    
    if [[ -z "$SUPABASE_ANON_KEY" ]]; then
        error "SUPABASE_ANON_KEY environment variable is not set"
    fi
    
    # Test Supabase connection
    log "Testing Supabase connection to: $SUPABASE_URL"
    
    if curl -s --max-time 10 -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/" > /dev/null; then
        log "✅ Supabase connection successful"
    else
        error "❌ Failed to connect to Supabase. Please check your SUPABASE_URL and SUPABASE_ANON_KEY"
    fi
    
    # Test authentication endpoint
    if curl -s --max-time 10 -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/auth/v1/settings" > /dev/null; then
        log "✅ Supabase Auth connection successful"
    else
        warn "⚠️ Supabase Auth connection failed - authentication features may not work"
    fi
    
    log "Supabase connectivity verification completed"
}

# Setup environment
setup_environment() {
    log "Setting up deployment environment..."
    
    # Create deployment directories (no database directory needed)
    mkdir -p "$DEPLOY_DIR"/{linux,macos,windows,web,docker}
    mkdir -p "$CONFIG_DIR"/{production,staging,development}
    mkdir -p logs backups
    
    # Set proper permissions
    chmod 755 "$DEPLOY_DIR"
    chmod 755 logs backups
    
    log "Environment setup completed"
}

# Generate production configuration for Supabase
generate_production_config() {
    log "Generating production configuration for Supabase..."
    
    # Production environment file
    cat > "$CONFIG_DIR/production/.env.production" <<EOF
# DevGuard AI Copilot - Production Configuration (Supabase)
APP_NAME=DevGuard AI Copilot
APP_VERSION=$APP_VERSION
APP_ENVIRONMENT=production
APP_DEBUG=false
APP_PORT=8080

# Supabase Configuration
SUPABASE_URL=\${SUPABASE_URL}
SUPABASE_ANON_KEY=\${SUPABASE_ANON_KEY}
SUPABASE_SERVICE_ROLE_KEY=\${SUPABASE_SERVICE_ROLE_KEY}

# Security Configuration
JWT_SECRET=\${JWT_SECRET:-$(openssl rand -base64 32)}
JWT_EXPIRY_HOURS=24
JWT_REFRESH_EXPIRY_DAYS=30
ENCRYPTION_KEY=\${ENCRYPTION_KEY:-$(openssl rand -base64 32)}
SESSION_TIMEOUT=3600

# AI Integration
GEMINI_API_KEY=\${GEMINI_API_KEY}
GEMINI_MODEL=gemini-pro
AI_RATE_LIMIT=100
AI_TIMEOUT=30

# GitHub Integration
GITHUB_CLIENT_ID=\${GITHUB_CLIENT_ID}
GITHUB_CLIENT_SECRET=\${GITHUB_CLIENT_SECRET}
GITHUB_WEBHOOK_SECRET=\${GITHUB_WEBHOOK_SECRET}
GITHUB_OAUTH_REDIRECT_URI=\${GITHUB_OAUTH_REDIRECT_URI}

# Email Configuration
SMTP_HOST=\${SMTP_HOST:-smtp.gmail.com}
SMTP_PORT=\${SMTP_PORT:-587}
SMTP_USERNAME=\${SMTP_USERNAME}
SMTP_PASSWORD=\${SMTP_PASSWORD}
SMTP_FROM_ADDRESS=\${SMTP_FROM_ADDRESS:-noreply@devguard.com}
SMTP_TLS=true

# WebSocket Configuration
WEBSOCKET_PORT=8081
WEBSOCKET_MAX_CONNECTIONS=1000
WEBSOCKET_HEARTBEAT_INTERVAL=30

# Security Monitoring
SECURITY_MONITORING_ENABLED=true
HONEYTOKEN_COUNT=20
ALERT_WEBHOOK_URL=\${ALERT_WEBHOOK_URL}
SECURITY_SCAN_INTERVAL=300

# Logging Configuration
LOG_LEVEL=info
LOG_FILE_PATH=./logs/devguard_production.log
LOG_MAX_SIZE=100MB
LOG_MAX_FILES=10
LOG_FORMAT=json

# Performance Configuration
CACHE_ENABLED=true
CACHE_TTL_SECONDS=3600
MAX_CONCURRENT_OPERATIONS=50
REQUEST_TIMEOUT=30
RATE_LIMIT_ENABLED=true

# Monitoring
METRICS_ENABLED=true
METRICS_PORT=9090
HEALTH_CHECK_INTERVAL=30

# Backup Configuration (for logs and config only)
BACKUP_ENABLED=true
BACKUP_INTERVAL=3600
BACKUP_RETENTION_DAYS=30
BACKUP_COMPRESSION=true

# Real-time Features
REALTIME_ENABLED=true
REALTIME_MAX_CONNECTIONS=500
REALTIME_HEARTBEAT_INTERVAL=30

# Storage Configuration
STORAGE_ENABLED=true
STORAGE_MAX_FILE_SIZE=100MB
STORAGE_ALLOWED_TYPES=pdf,doc,docx,txt,md,png,jpg,jpeg,gif
EOF

    # Staging configuration
    cat > "$CONFIG_DIR/staging/.env.staging" <<EOF
# DevGuard AI Copilot - Staging Configuration (Supabase)
APP_NAME=DevGuard AI Copilot (Staging)
APP_VERSION=$APP_VERSION
APP_ENVIRONMENT=staging
APP_DEBUG=true
APP_PORT=8080

# Supabase Configuration
SUPABASE_URL=\${SUPABASE_STAGING_URL}
SUPABASE_ANON_KEY=\${SUPABASE_STAGING_ANON_KEY}
SUPABASE_SERVICE_ROLE_KEY=\${SUPABASE_STAGING_SERVICE_ROLE_KEY}

# Security Configuration (Use weaker settings for staging)
JWT_SECRET=staging_jwt_secret_key_for_testing_only
JWT_EXPIRY_HOURS=8
ENCRYPTION_KEY=staging_encryption_key_32_chars

# Reduced security for testing
SECURITY_MONITORING_ENABLED=false
HONEYTOKEN_COUNT=5

# Logging
LOG_LEVEL=debug
LOG_FILE_PATH=./logs/devguard_staging.log

# Performance (Reduced for staging)
CACHE_TTL_SECONDS=1800
MAX_CONCURRENT_OPERATIONS=25

# Real-time Features
REALTIME_ENABLED=true
REALTIME_MAX_CONNECTIONS=100
EOF

    # Development configuration
    cat > "$CONFIG_DIR/development/.env.development" <<EOF
# DevGuard AI Copilot - Development Configuration (Supabase)
APP_NAME=DevGuard AI Copilot (Dev)
APP_VERSION=$APP_VERSION-dev
APP_ENVIRONMENT=development
APP_DEBUG=true
APP_PORT=8080

# Supabase Configuration
SUPABASE_URL=\${SUPABASE_DEV_URL}
SUPABASE_ANON_KEY=\${SUPABASE_DEV_ANON_KEY}
SUPABASE_SERVICE_ROLE_KEY=\${SUPABASE_DEV_SERVICE_ROLE_KEY}

# Security Configuration (Minimal for development)
JWT_SECRET=dev_jwt_secret_key_for_development_only
JWT_EXPIRY_HOURS=24
ENCRYPTION_KEY=dev_encryption_key_32_characters

# Disable security features for development
SECURITY_MONITORING_ENABLED=false
HONEYTOKEN_COUNT=0

# Logging
LOG_LEVEL=debug
LOG_FILE_PATH=./logs/devguard_dev.log

# Performance (Minimal for development)
CACHE_ENABLED=false
MAX_CONCURRENT_OPERATIONS=10

# Real-time Features
REALTIME_ENABLED=true
REALTIME_MAX_CONNECTIONS=50
EOF

    log "Production configuration for Supabase generated"
}

# Build application for all platforms
build_all_platforms() {
    log "Building application for all platforms..."
    
    # Clean previous builds
    flutter clean
    flutter pub get
    
    # Run code generation
    log "Running code generation..."
    dart run build_runner build --delete-conflicting-outputs
    
    # Run tests
    log "Running tests..."
    flutter test --coverage
    
    # Build for Web
    if [[ "$1" == "all" || "$1" == "web" ]]; then
        log "Building for Web..."
        flutter build web --release --web-renderer html --base-href /
        cp -r build/web "$DEPLOY_DIR/"
        log "Web build completed"
    fi
    
    # Build for Linux
    if [[ "$OS" == "Linux" && ("$1" == "all" || "$1" == "linux") ]]; then
        log "Building for Linux..."
        flutter build linux --release
        cp -r build/linux "$DEPLOY_DIR/"
        log "Linux build completed"
    fi
    
    # Build for macOS
    if [[ "$OS" == "macOS" && ("$1" == "all" || "$1" == "macos") ]]; then
        log "Building for macOS..."
        flutter build macos --release
        cp -r build/macos "$DEPLOY_DIR/"
        log "macOS build completed"
    fi
    
    # Build for Windows
    if [[ "$OS" == "Windows" && ("$1" == "all" || "$1" == "windows") ]]; then
        log "Building for Windows..."
        flutter build windows --release
        cp -r build/windows "$DEPLOY_DIR/"
        log "Windows build completed"
    fi
    
    log "All platform builds completed"
}

# Create Docker deployment for Supabase
create_docker_deployment() {
    if [[ "$DOCKER_AVAILABLE" != true ]]; then
        warn "Docker not available, skipping container deployment"
        return
    fi
    
    log "Creating Docker deployment for Supabase..."
    
    # Multi-stage Dockerfile for production with Supabase
    cat > "$DEPLOY_DIR/docker/Dockerfile.production" <<EOF
# Multi-stage build for DevGuard AI Copilot Production with Supabase
FROM ubuntu:22.04 AS build-env

# Install dependencies
RUN apt-get update && apt-get install -y \\
    curl \\
    git \\
    unzip \\
    xz-utils \\
    zip \\
    libglu1-mesa \\
    clang \\
    cmake \\
    ninja-build \\
    pkg-config \\
    libgtk-3-dev \\
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:\${PATH}"

# Configure Flutter
RUN flutter doctor -v
RUN flutter config --enable-web
RUN flutter config --enable-linux-desktop

# Set working directory
WORKDIR /app

# Copy dependency files
COPY pubspec.* ./
RUN flutter pub get

# Copy source code
COPY . .

# Run code generation
RUN dart run build_runner build --delete-conflicting-outputs

# Build applications
RUN flutter build web --release --web-renderer html
RUN flutter build linux --release

# Production stage
FROM ubuntu:22.04

# Install runtime dependencies (removed SQLite, added curl for Supabase)
RUN apt-get update && apt-get install -y \\
    nginx \\
    supervisor \\
    curl \\
    ca-certificates \\
    && rm -rf /var/lib/apt/lists/*

# Create application user
RUN useradd -r -s /bin/false devguard

# Create application directories (no database directory needed)
RUN mkdir -p /app/{logs,backups,config} \\
    && chown -R devguard:devguard /app

# Copy built applications
COPY --from=build-env /app/build/web /var/www/html
COPY --from=build-env /app/build/linux/x64/release/bundle /app/bin
COPY --from=build-env /app/lib /app/lib
COPY --from=build-env /app/pubspec.yaml /app/

# Copy configuration files
COPY config/production/.env.production /app/.env
COPY deployment/docker/nginx.conf /etc/nginx/nginx.conf
COPY deployment/docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set permissions
RUN chown -R devguard:devguard /app \\
    && chmod +x /app/bin/devguard_ai_copilot

# Expose ports
EXPOSE 80 8080 8081 9090

# Health check with Supabase connectivity verification
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
    CMD curl -f http://localhost/health && curl -f "\$SUPABASE_URL/rest/v1/" -H "apikey: \$SUPABASE_ANON_KEY" || exit 1

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
EOF

    log "Docker deployment configuration for Supabase created"
}

# Create platform-specific deployment scripts for Supabase
create_platform_scripts() {
    log "Creating platform-specific deployment scripts for Supabase..."
    
    # Linux deployment script
    cat > "$DEPLOY_DIR/linux/deploy_linux_supabase.sh" <<'EOF'
#!/bin/bash

set -e

echo "🐧 Deploying DevGuard AI Copilot on Linux with Supabase..."

# Configuration
APP_NAME="devguard-ai-copilot"
APP_USER="devguard"
INSTALL_DIR="/opt/devguard-ai-copilot"
SERVICE_FILE="/etc/systemd/system/devguard.service"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "This script should not be run as root. Please run as a regular user with sudo privileges."
    exit 1
fi

# Verify Supabase environment variables
if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
    echo "❌ Error: SUPABASE_URL and SUPABASE_ANON_KEY environment variables must be set"
    exit 1
fi

# Test Supabase connectivity
echo "🔗 Testing Supabase connectivity..."
if curl -s --max-time 10 -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/" > /dev/null; then
    echo "✅ Supabase connection successful"
else
    echo "❌ Failed to connect to Supabase. Please check your configuration."
    exit 1
fi

# Create application user
sudo useradd -r -s /bin/false $APP_USER 2>/dev/null || true

# Create installation directory (no database directory needed)
sudo mkdir -p $INSTALL_DIR
sudo cp -r ../linux/x64/release/bundle/* $INSTALL_DIR/
sudo cp -r ../../config $INSTALL_DIR/
sudo mkdir -p $INSTALL_DIR/{logs,backups}

# Set permissions
sudo chown -R $APP_USER:$APP_USER $INSTALL_DIR
sudo chmod +x $INSTALL_DIR/devguard_ai_copilot

# Create systemd service with Supabase environment
sudo tee $SERVICE_FILE > /dev/null <<EOSERVICE
[Unit]
Description=DevGuard AI Copilot (Supabase)
After=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/devguard_ai_copilot
Restart=always
RestartSec=10
Environment=PATH=/usr/bin:/usr/local/bin
Environment=HOME=$INSTALL_DIR
Environment=SUPABASE_URL=$SUPABASE_URL
Environment=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
Environment=SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY
EnvironmentFile=$INSTALL_DIR/config/production/.env.production

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR/logs $INSTALL_DIR/backups

[Install]
WantedBy=multi-user.target
EOSERVICE

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable devguard
sudo systemctl start devguard

# Setup log rotation
sudo tee /etc/logrotate.d/devguard > /dev/null <<EOLOGROTATE
$INSTALL_DIR/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $APP_USER $APP_USER
    postrotate
        systemctl reload devguard
    endscript
}
EOLOGROTATE

# Setup firewall (if ufw is available)
if command -v ufw &> /dev/null; then
    sudo ufw allow 8080/tcp
    sudo ufw allow 8081/tcp
fi

echo "✅ Linux deployment with Supabase completed!"
echo "Service status: sudo systemctl status devguard"
echo "Logs: sudo journalctl -u devguard -f"
echo "Application URL: http://localhost:8080"
echo "Supabase URL: $SUPABASE_URL"
EOF

    # Make scripts executable
    chmod +x "$DEPLOY_DIR/linux/deploy_linux_supabase.sh"
    
    log "Platform-specific deployment scripts for Supabase created"
}

# Create backup and maintenance scripts for Supabase
create_maintenance_scripts() {
    log "Creating maintenance scripts for Supabase..."
    
    # Backup script (no database backup needed, only logs and config)
    cat > "$DEPLOY_DIR/backup_system_supabase.sh" <<'EOF'
#!/bin/bash

set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="devguard_backup_$TIMESTAMP"

echo "💾 Starting system backup (Supabase mode - no database backup needed)..."

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# Backup configuration
cp -r config "$BACKUP_DIR/$BACKUP_NAME/"
cp .env* "$BACKUP_DIR/$BACKUP_NAME/" 2>/dev/null || true

# Backup logs (last 7 days)
find logs -name "*.log" -mtime -7 -exec cp {} "$BACKUP_DIR/$BACKUP_NAME/" \; 2>/dev/null || true

# Create archive
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

# Clean old backups (keep last 30)
find "$BACKUP_DIR" -name "devguard_backup_*.tar.gz" -mtime +30 -delete

echo "✅ Backup completed: $BACKUP_NAME.tar.gz"
echo "ℹ️  Note: Database is managed by Supabase - no local database backup needed"
EOF

    # Health check script with Supabase connectivity
    cat > "$DEPLOY_DIR/health_check_supabase.sh" <<'EOF'
#!/bin/bash

echo "🏥 DevGuard AI Copilot Health Check (Supabase)"
echo "=============================================="

# Check application status
if curl -s --max-time 5 http://localhost:8080/health > /dev/null; then
    echo "✅ Application: Responding"
else
    echo "❌ Application: Not responding"
fi

# Check WebSocket
if curl -s --max-time 5 -H "Upgrade: websocket" http://localhost:8081 > /dev/null; then
    echo "✅ WebSocket: Available"
else
    echo "❌ WebSocket: Not available"
fi

# Check Supabase connectivity
if [[ -n "$SUPABASE_URL" && -n "$SUPABASE_ANON_KEY" ]]; then
    if curl -s --max-time 10 -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/" > /dev/null; then
        echo "✅ Supabase: Connected"
    else
        echo "❌ Supabase: Connection failed"
    fi
    
    # Check Supabase Auth
    if curl -s --max-time 10 -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/auth/v1/settings" > /dev/null; then
        echo "✅ Supabase Auth: Available"
    else
        echo "❌ Supabase Auth: Not available"
    fi
else
    echo "⚠️  Supabase: Environment variables not set"
fi

# Check disk space
DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo "✅ Disk Space: $DISK_USAGE% used"
else
    echo "⚠️  Disk Space: $DISK_USAGE% used (Warning)"
fi

# Check memory usage
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
echo "📊 Memory Usage: $MEMORY_USAGE%"

echo "=============================================="
echo "Health check completed at $(date)"
echo "ℹ️  Database health is managed by Supabase"
EOF

    # Make scripts executable
    chmod +x "$DEPLOY_DIR/backup_system_supabase.sh"
    chmod +x "$DEPLOY_DIR/health_check_supabase.sh"
    
    log "Maintenance scripts for Supabase created"
}

# Main deployment function
main() {
    log "Starting DevGuard AI Copilot deployment with Supabase..."
    
    # Load environment variables
    if [[ -f ".env" ]]; then
        source .env
        log "Loaded environment variables from .env"
    else
        warn "No .env file found - using system environment variables"
    fi
    
    detect_os
    check_prerequisites
    verify_supabase_connectivity
    setup_environment
    generate_production_config
    
    # Build applications
    PLATFORM=${1:-all}
    build_all_platforms "$PLATFORM"
    
    # Create deployment artifacts
    create_docker_deployment
    create_platform_scripts
    create_maintenance_scripts
    
    log "✅ DevGuard AI Copilot deployment with Supabase completed successfully!"
    log "📁 Deployment artifacts available in: $DEPLOY_DIR"
    log "🔗 Supabase URL: $SUPABASE_URL"
    log "🚀 Ready for production deployment!"
}

# Run main function with all arguments
main "$@"