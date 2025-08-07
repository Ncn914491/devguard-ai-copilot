#!/bin/bash

# DevGuard AI Copilot - Cross-Platform Deployment Script
# Supports Linux, macOS, and Windows deployment with production configuration

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
    
    # Verify Flutter doctor
    log "Running Flutter doctor..."
    flutter doctor --verbose
    
    log "Prerequisites check completed"
}

# Setup environment
setup_environment() {
    log "Setting up deployment environment..."
    
    # Create deployment directories
    mkdir -p "$DEPLOY_DIR"/{linux,macos,windows,web,docker}
    mkdir -p "$CONFIG_DIR"/{production,staging,development}
    mkdir -p logs backups data
    
    # Set proper permissions
    chmod 755 "$DEPLOY_DIR"
    chmod 755 logs backups data
    
    log "Environment setup completed"
}

# Generate production configuration
generate_production_config() {
    log "Generating production configuration..."
    
    # Production environment file
    cat > "$CONFIG_DIR/production/.env.production" <<EOF
# DevGuard AI Copilot - Production Configuration
APP_NAME=DevGuard AI Copilot
APP_VERSION=$APP_VERSION
APP_ENVIRONMENT=production
APP_DEBUG=false
APP_PORT=8080

# Supabase Configuration
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
DATABASE_TYPE=supabase
DATABASE_TIMEOUT=30

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

# Backup Configuration
BACKUP_ENABLED=true
BACKUP_INTERVAL=3600
BACKUP_RETENTION_DAYS=30
BACKUP_COMPRESSION=true
EOF

    # Staging configuration
    cat > "$CONFIG_DIR/staging/.env.staging" <<EOF
# DevGuard AI Copilot - Staging Configuration
APP_NAME=DevGuard AI Copilot (Staging)
APP_VERSION=$APP_VERSION
APP_ENVIRONMENT=staging
APP_DEBUG=true
APP_PORT=8080

# Supabase Configuration (Staging)
SUPABASE_URL=${SUPABASE_STAGING_URL}
SUPABASE_ANON_KEY=${SUPABASE_STAGING_ANON_KEY}
SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_STAGING_SERVICE_ROLE_KEY}
DATABASE_TYPE=supabase

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
EOF

    # Development configuration
    cat > "$CONFIG_DIR/development/.env.development" <<EOF
# DevGuard AI Copilot - Development Configuration
APP_NAME=DevGuard AI Copilot (Dev)
APP_VERSION=$APP_VERSION-dev
APP_ENVIRONMENT=development
APP_DEBUG=true
APP_PORT=8080

# Supabase Configuration (Development)
SUPABASE_URL=${SUPABASE_DEV_URL}
SUPABASE_ANON_KEY=${SUPABASE_DEV_ANON_KEY}
SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_DEV_SERVICE_ROLE_KEY}
DATABASE_TYPE=supabase

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
EOF

    log "Production configuration generated"
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

# Create Docker deployment
create_docker_deployment() {
    if [[ "$DOCKER_AVAILABLE" != true ]]; then
        warn "Docker not available, skipping container deployment"
        return
    fi
    
    log "Creating Docker deployment..."
    
    # Multi-stage Dockerfile for production
    cat > "$DEPLOY_DIR/docker/Dockerfile.production" <<EOF
# Multi-stage build for DevGuard AI Copilot Production
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

# Install runtime dependencies (removed SQLite, using Supabase)
RUN apt-get update && apt-get install -y \\
    nginx \\
    supervisor \\
    curl \\
    ca-certificates \\
    && rm -rf /var/lib/apt/lists/*

# Create application user
RUN useradd -r -s /bin/false devguard

# Create application directories (no data directory needed with Supabase)
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
    CMD curl -f http://localhost/health && \\
        if [ -n "\$SUPABASE_URL" ] && [ -n "\$SUPABASE_ANON_KEY" ]; then \\
            curl -f "\$SUPABASE_URL/rest/v1/" -H "apikey: \$SUPABASE_ANON_KEY"; \\
        else \\
            echo "Supabase environment variables not set"; \\
        fi || exit 1

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
EOF

    # Docker Compose for production
    cat > "$DEPLOY_DIR/docker/docker-compose.production.yml" <<EOF
version: '3.8'

services:
  devguard-app:
    build:
      context: ../..
      dockerfile: deployment/docker/Dockerfile.production
    container_name: devguard-ai-copilot-prod
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
      - "8081:8081"
      - "9090:9090"
    volumes:
      - app-logs:/app/logs
      - app-backups:/app/backups
      - ./ssl:/app/config/ssl:ro
    environment:
      - APP_ENVIRONMENT=production
    networks:
      - devguard-network
    depends_on:
      - devguard-redis
      - devguard-prometheus
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  devguard-redis:
    image: redis:7-alpine
    container_name: devguard-redis-prod
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    networks:
      - devguard-network
    command: redis-server --appendonly yes --requirepass \${REDIS_PASSWORD}
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "\${REDIS_PASSWORD}", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  devguard-prometheus:
    image: prom/prometheus:latest
    container_name: devguard-prometheus
    restart: unless-stopped
    ports:
      - "9091:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    networks:
      - devguard-network
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'

  devguard-grafana:
    image: grafana/grafana:latest
    container_name: devguard-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./grafana/datasources:/etc/grafana/provisioning/datasources:ro
    networks:
      - devguard-network
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_ADMIN_PASSWORD}

volumes:
  app-data:
  app-logs:
  app-backups:
  redis-data:
  prometheus-data:
  grafana-data:

networks:
  devguard-network:
    driver: bridge
EOF

    # Nginx configuration for production
    cat > "$DEPLOY_DIR/docker/nginx.conf" <<EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=login:10m rate=1r/s;

    # Upstream servers
    upstream devguard_app {
        server 127.0.0.1:8080;
        keepalive 32;
    }

    upstream devguard_websocket {
        server 127.0.0.1:8081;
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name _;
        return 301 https://\$server_name\$request_uri;
    }

    # Main server block
    server {
        listen 443 ssl http2;
        server_name _;

        # SSL Configuration
        ssl_certificate /app/config/ssl/devguard.crt;
        ssl_certificate_key /app/config/ssl/devguard.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security headers
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' wss:;" always;

        # Static files (Flutter web app)
        location / {
            root /var/www/html;
            try_files \$uri \$uri/ /index.html;
            
            # Cache static assets
            location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
                expires 1y;
                add_header Cache-Control "public, immutable";
                access_log off;
            }
        }

        # API endpoints
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            
            proxy_pass http://devguard_app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # Authentication endpoints (stricter rate limiting)
        location /api/auth/ {
            limit_req zone=login burst=5 nodelay;
            
            proxy_pass http://devguard_app;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # WebSocket endpoints
        location /ws {
            proxy_pass http://devguard_websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # WebSocket timeouts
            proxy_read_timeout 86400;
            proxy_send_timeout 86400;
        }

        # Health check endpoint
        location /health {
            proxy_pass http://devguard_app/health;
            access_log off;
        }

        # Metrics endpoint (restrict access)
        location /metrics {
            allow 127.0.0.1;
            allow 10.0.0.0/8;
            allow 172.16.0.0/12;
            allow 192.168.0.0/16;
            deny all;
            
            proxy_pass http://devguard_app/metrics;
        }
    }
}
EOF

    # Supervisor configuration
    cat > "$DEPLOY_DIR/docker/supervisord.conf" <<EOF
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:devguard-app]
command=/app/bin/devguard_ai_copilot
directory=/app
user=devguard
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/devguard-app.err.log
stdout_logfile=/var/log/supervisor/devguard-app.out.log
environment=HOME="/app",USER="devguard"

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/nginx.err.log
stdout_logfile=/var/log/supervisor/nginx.out.log

[unix_http_server]
file=/var/run/supervisor.sock
chmod=0700

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
EOF

    log "Docker deployment configuration created"
}

# Create platform-specific deployment scripts
create_platform_scripts() {
    log "Creating platform-specific deployment scripts..."
    
    # Linux deployment script
    cat > "$DEPLOY_DIR/linux/deploy_linux.sh" <<'EOF'
#!/bin/bash

set -e

echo "🐧 Deploying DevGuard AI Copilot on Linux..."

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

# Create application user
sudo useradd -r -s /bin/false $APP_USER 2>/dev/null || true

# Create installation directory
sudo mkdir -p $INSTALL_DIR
sudo cp -r ../linux/x64/release/bundle/* $INSTALL_DIR/
sudo cp -r ../../config $INSTALL_DIR/
sudo cp -r ../../data $INSTALL_DIR/
sudo mkdir -p $INSTALL_DIR/{logs,backups}

# Set permissions
sudo chown -R $APP_USER:$APP_USER $INSTALL_DIR
sudo chmod +x $INSTALL_DIR/devguard_ai_copilot

# Create systemd service
sudo tee $SERVICE_FILE > /dev/null <<EOSERVICE
[Unit]
Description=DevGuard AI Copilot
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
EnvironmentFile=$INSTALL_DIR/config/production/.env.production

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR/data $INSTALL_DIR/logs $INSTALL_DIR/backups

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

echo "✅ Linux deployment completed!"
echo "Service status: sudo systemctl status devguard"
echo "Logs: sudo journalctl -u devguard -f"
echo "Application URL: http://localhost:8080"
EOF

    # macOS deployment script
    cat > "$DEPLOY_DIR/macos/deploy_macos.sh" <<'EOF'
#!/bin/bash

set -e

echo "🍎 Deploying DevGuard AI Copilot on macOS..."

# Configuration
APP_NAME="DevGuard AI Copilot"
INSTALL_DIR="/Applications/$APP_NAME.app"
PLIST_FILE="/Library/LaunchDaemons/com.devguard.ai-copilot.plist"

# Copy application
sudo cp -r "Build/Products/Release/devguard_ai_copilot.app" "$INSTALL_DIR"
sudo cp -r ../../config "$INSTALL_DIR/Contents/Resources/"
sudo cp -r ../../data "$INSTALL_DIR/Contents/Resources/"
sudo mkdir -p "$INSTALL_DIR/Contents/Resources"/{logs,backups}

# Create launch daemon
sudo tee $PLIST_FILE > /dev/null <<EOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.devguard.ai-copilot</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/Contents/MacOS/devguard_ai_copilot</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR/Contents/Resources</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin</string>
    </dict>
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/Contents/Resources/logs/devguard.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/Contents/Resources/logs/devguard.error.log</string>
</dict>
</plist>
EOPLIST

# Set permissions
sudo chown -R root:wheel "$INSTALL_DIR"
sudo chmod 644 $PLIST_FILE

# Load launch daemon
sudo launchctl load $PLIST_FILE

echo "✅ macOS deployment completed!"
echo "Application installed in: $INSTALL_DIR"
echo "Service status: sudo launchctl list | grep devguard"
echo "Application URL: http://localhost:8080"
EOF

    # Windows deployment script
    cat > "$DEPLOY_DIR/windows/deploy_windows.ps1" <<'EOF'
# DevGuard AI Copilot - Windows Deployment Script

param(
    [string]$InstallPath = "C:\Program Files\DevGuard AI Copilot",
    [string]$ServiceName = "DevGuardAICopilot"
)

Write-Host "🪟 Deploying DevGuard AI Copilot on Windows..." -ForegroundColor Green

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Create installation directory
New-Item -ItemType Directory -Force -Path $InstallPath
New-Item -ItemType Directory -Force -Path "$InstallPath\logs"
New-Item -ItemType Directory -Force -Path "$InstallPath\backups"
New-Item -ItemType Directory -Force -Path "$InstallPath\data"

# Copy application files
Copy-Item -Recurse -Force "runner\Release\*" $InstallPath
Copy-Item -Recurse -Force "..\..\config" $InstallPath
Copy-Item -Recurse -Force "..\..\data\*" "$InstallPath\data"

# Create Windows service wrapper script
$ServiceScript = @"
@echo off
cd /d "$InstallPath"
set PATH=%PATH%;$InstallPath
devguard_ai_copilot.exe
"@

$ServiceScript | Out-File -FilePath "$InstallPath\service_wrapper.bat" -Encoding ASCII

# Install Windows service
$ServiceDisplayName = "DevGuard AI Copilot"
$ServiceDescription = "AI-powered development copilot with security monitoring"
$ServicePath = "$InstallPath\service_wrapper.bat"

# Remove existing service if it exists
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Stop-Service -Name $ServiceName -Force
    & sc.exe delete $ServiceName
    Start-Sleep -Seconds 2
}

# Create new service
& sc.exe create $ServiceName binPath= $ServicePath DisplayName= $ServiceDisplayName start= auto
& sc.exe description $ServiceName $ServiceDescription

# Configure service recovery
& sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/5000/restart/5000

# Start service
& sc.exe start $ServiceName

# Configure Windows Firewall
New-NetFirewallRule -DisplayName "DevGuard AI Copilot HTTP" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
New-NetFirewallRule -DisplayName "DevGuard AI Copilot WebSocket" -Direction Inbound -Protocol TCP -LocalPort 8081 -Action Allow

Write-Host "✅ Windows deployment completed!" -ForegroundColor Green
Write-Host "Service installed: $ServiceDisplayName"
Write-Host "Service status: sc query $ServiceName"
Write-Host "Application URL: http://localhost:8080"
EOF

    # Make scripts executable
    chmod +x "$DEPLOY_DIR/linux/deploy_linux.sh"
    chmod +x "$DEPLOY_DIR/macos/deploy_macos.sh"
    
    log "Platform-specific deployment scripts created"
}

# Create monitoring configuration
create_monitoring_config() {
    log "Creating monitoring configuration..."
    
    # Prometheus configuration
    cat > "$DEPLOY_DIR/docker/prometheus.yml" <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'devguard-app'
    static_configs:
      - targets: ['devguard-app:9090']
    scrape_interval: 30s
    metrics_path: '/metrics'

  - job_name: 'redis'
    static_configs:
      - targets: ['devguard-redis:6379']

  - job_name: 'nginx'
    static_configs:
      - targets: ['devguard-app:80']
    metrics_path: '/nginx_status'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF

    # Grafana datasource configuration
    mkdir -p "$DEPLOY_DIR/docker/grafana/datasources"
    cat > "$DEPLOY_DIR/docker/grafana/datasources/prometheus.yml" <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://devguard-prometheus:9090
    isDefault: true
EOF

    # Grafana dashboard configuration
    mkdir -p "$DEPLOY_DIR/docker/grafana/dashboards"
    cat > "$DEPLOY_DIR/docker/grafana/dashboards/dashboard.yml" <<EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

    log "Monitoring configuration created"
}

# Create backup and maintenance scripts
create_maintenance_scripts() {
    log "Creating maintenance scripts..."
    
    # Backup script
    cat > "$DEPLOY_DIR/backup_system.sh" <<'EOF'
#!/bin/bash

set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="devguard_backup_$TIMESTAMP"

echo "💾 Starting system backup..."

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# Note: Database backup not needed - using Supabase managed database
echo "ℹ️  Database backup skipped - using Supabase managed database"

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
EOF

    # Health check script
    cat > "$DEPLOY_DIR/health_check.sh" <<'EOF'
#!/bin/bash

echo "🏥 DevGuard AI Copilot Health Check"
echo "=================================="

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

echo "=================================="
echo "Health check completed at $(date)"
EOF

    # Update script
    cat > "$DEPLOY_DIR/update_system.sh" <<'EOF'
#!/bin/bash

set -e

echo "🔄 Updating DevGuard AI Copilot..."

# Backup current system
./backup_system.sh

# Pull latest changes
git pull origin main

# Update dependencies
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Rebuild application
../scripts/deploy_cross_platform.sh web

# Restart services
if command -v systemctl &> /dev/null; then
    sudo systemctl restart devguard
elif command -v launchctl &> /dev/null; then
    sudo launchctl unload /Library/LaunchDaemons/com.devguard.ai-copilot.plist
    sudo launchctl load /Library/LaunchDaemons/com.devguard.ai-copilot.plist
elif command -v sc.exe &> /dev/null; then
    sc.exe stop DevGuardAICopilot
    sc.exe start DevGuardAICopilot
fi

# Verify update
sleep 10
./health_check.sh

echo "✅ Update completed!"
EOF

    # Make scripts executable
    chmod +x "$DEPLOY_DIR/backup_system.sh"
    chmod +x "$DEPLOY_DIR/health_check.sh"
    chmod +x "$DEPLOY_DIR/update_system.sh"
    
    log "Maintenance scripts created"
}

# Generate deployment documentation
generate_deployment_docs() {
    log "Generating deployment documentation..."
    
    cat > "$DEPLOY_DIR/README.md" <<EOF
# DevGuard AI Copilot - Deployment Package

This package contains all necessary files and scripts for deploying DevGuard AI Copilot across different platforms.

## Package Contents

- \`web/\` - Web application build
- \`linux/\` - Linux desktop application
- \`macos/\` - macOS desktop application  
- \`windows/\` - Windows desktop application
- \`docker/\` - Docker deployment configuration
- \`config/\` - Environment-specific configurations

## Quick Start

### Docker Deployment (Recommended)

1. Copy the deployment package to your server
2. Navigate to the docker directory:
   \`\`\`bash
   cd docker
   \`\`\`
3. Configure environment variables:
   \`\`\`bash
   cp ../config/production/.env.production .env
   # Edit .env with your specific values
   \`\`\`
4. Start the application:
   \`\`\`bash
   docker-compose -f docker-compose.production.yml up -d
   \`\`\`

### Platform-Specific Deployment

#### Linux
\`\`\`bash
cd linux
chmod +x deploy_linux.sh
./deploy_linux.sh
\`\`\`

#### macOS
\`\`\`bash
cd macos
chmod +x deploy_macos.sh
./deploy_macos.sh
\`\`\`

#### Windows
\`\`\`powershell
cd windows
PowerShell -ExecutionPolicy Bypass -File deploy_windows.ps1
\`\`\`

## Configuration

### Environment Variables

Copy the appropriate environment file from \`config/\` directory:

- \`config/production/.env.production\` - Production environment
- \`config/staging/.env.staging\` - Staging environment
- \`config/development/.env.development\` - Development environment

### Required Environment Variables

- \`JWT_SECRET\` - JWT signing secret (32+ characters)
- \`ENCRYPTION_KEY\` - Data encryption key (32 characters)
- \`GEMINI_API_KEY\` - Google Gemini API key
- \`GITHUB_CLIENT_ID\` - GitHub OAuth client ID
- \`GITHUB_CLIENT_SECRET\` - GitHub OAuth client secret

### Optional Environment Variables

- \`SMTP_*\` - Email configuration
- \`ALERT_WEBHOOK_URL\` - Security alert webhook
- \`REDIS_PASSWORD\` - Redis password (Docker deployment)

## Monitoring

The deployment includes monitoring with Prometheus and Grafana:

- Prometheus: http://localhost:9091
- Grafana: http://localhost:3000 (admin/\${GRAFANA_ADMIN_PASSWORD})

## Maintenance

### Backup
\`\`\`bash
./backup_system.sh
\`\`\`

### Health Check
\`\`\`bash
./health_check.sh
\`\`\`

### Update
\`\`\`bash
./update_system.sh
\`\`\`

## Security

### SSL/TLS

For production deployment, configure SSL certificates:

1. Place your SSL certificate and key in \`config/ssl/\`
2. Update nginx configuration to use your certificates
3. Ensure firewall allows HTTPS traffic (port 443)

### Firewall

Recommended firewall rules:
- Allow HTTP (80) and HTTPS (443) for web access
- Allow application ports (8080, 8081) if needed
- Restrict admin access to specific IP addresses

## Troubleshooting

### Application Won't Start

1. Check logs: \`docker-compose logs devguard-app\`
2. Verify configuration: \`./health_check.sh\`
3. Check database: \`ls -la data/\`

### Performance Issues

1. Monitor resources: \`docker stats\`
2. Check application metrics: http://localhost:9090/metrics
3. Review Grafana dashboards: http://localhost:3000

### Database Issues

1. Check Supabase connectivity: \`curl -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/"\`
2. Restore from backup: \`./restore_system.sh backups/latest_backup.tar.gz\`

## Support

For support and documentation:
- GitHub: https://github.com/devguard/ai-copilot
- Documentation: https://docs.devguard.com
- Issues: https://github.com/devguard/ai-copilot/issues

---

Generated on: $(date)
Version: $APP_VERSION
EOF

    log "Deployment documentation generated"
}

# Main deployment function
main() {
    log "Starting DevGuard AI Copilot cross-platform deployment..."
    
    # Parse command line arguments
    PLATFORM=${1:-all}
    ENVIRONMENT=${2:-production}
    
    log "Platform: $PLATFORM"
    log "Environment: $ENVIRONMENT"
    
    # Execute deployment steps
    detect_os
    check_prerequisites
    setup_environment
    generate_production_config
    build_all_platforms "$PLATFORM"
    create_docker_deployment
    create_platform_scripts
    create_monitoring_config
    create_maintenance_scripts
    generate_deployment_docs
    
    log "🎉 Cross-platform deployment completed successfully!"
    log ""
    log "Deployment package created in: $DEPLOY_DIR"
    log "Next steps:"
    log "1. Review configuration files in config/"
    log "2. Set required environment variables"
    log "3. Choose deployment method:"
    log "   - Docker: cd $DEPLOY_DIR/docker && docker-compose up -d"
    log "   - Linux: cd $DEPLOY_DIR/linux && ./deploy_linux.sh"
    log "   - macOS: cd $DEPLOY_DIR/macos && ./deploy_macos.sh"
    log "   - Windows: cd $DEPLOY_DIR/windows && ./deploy_windows.ps1"
    log ""
    log "For detailed instructions, see: $DEPLOY_DIR/README.md"
}

# Run main function with all arguments
main "$@"