# DevGuard AI Copilot - Deployment Guide

## Overview

This comprehensive deployment guide covers all aspects of deploying the DevGuard AI Copilot application across different platforms and environments. The guide focuses on using free and open-source resources while maintaining production-ready standards.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Database Configuration](#database-configuration)
4. [Application Configuration](#application-configuration)
5. [Docker Deployment](#docker-deployment)
6. [Platform-Specific Deployment](#platform-specific-deployment)
7. [CI/CD Pipeline Setup](#cicd-pipeline-setup)
8. [Monitoring and Logging](#monitoring-and-logging)
9. [Security Configuration](#security-configuration)
10. [Backup and Recovery](#backup-and-recovery)
11. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

#### Minimum Requirements
- **CPU**: 2 cores, 2.4 GHz
- **RAM**: 4 GB
- **Storage**: 20 GB available space
- **Network**: Stable internet connection

#### Recommended Requirements
- **CPU**: 4 cores, 3.0 GHz
- **RAM**: 8 GB
- **Storage**: 50 GB SSD
- **Network**: High-speed internet connection

### Software Dependencies

#### Required Software
- **Flutter SDK**: 3.10.0 or higher
- **Dart SDK**: 3.0.0 or higher
- **Docker**: 20.10 or higher
- **Docker Compose**: 2.0 or higher
- **Git**: 2.30 or higher

#### Optional Software
- **Node.js**: 18.0 or higher (for additional tooling)
- **Python**: 3.8 or higher (for deployment scripts)
- **nginx**: 1.20 or higher (for reverse proxy)

### Installation Commands

#### Ubuntu/Debian
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Flutter dependencies
sudo apt install -y curl git unzip xz-utils zip libglu1-mesa

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Flutter
cd /opt
sudo git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

#### macOS
```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install git curl unzip
brew install --cask docker

# Install Flutter
brew install flutter

# Verify installation
flutter doctor
```

#### Windows
```powershell
# Install Chocolatey (if not already installed)
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install dependencies
choco install git curl 7zip docker-desktop flutter -y

# Verify installation
flutter doctor
```

## Environment Setup

### Environment Variables

Create a `.env` file in the project root:

```bash
# Application Configuration
APP_NAME=DevGuard AI Copilot
APP_VERSION=1.0.0
APP_ENVIRONMENT=production
APP_DEBUG=false
APP_PORT=8080

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

# Security Configuration
JWT_SECRET=your_super_secure_jwt_secret_key_here
JWT_EXPIRY_HOURS=24
JWT_REFRESH_EXPIRY_DAYS=30
ENCRYPTION_KEY=your_32_character_encryption_key

# AI Integration
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-pro
AI_RATE_LIMIT=100

# GitHub Integration
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret
GITHUB_WEBHOOK_SECRET=your_webhook_secret

# Email Configuration (Optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
SMTP_FROM_ADDRESS=noreply@devguard.com

# WebSocket Configuration
WEBSOCKET_PORT=8081
WEBSOCKET_MAX_CONNECTIONS=1000

# Security Monitoring
SECURITY_MONITORING_ENABLED=true
HONEYTOKEN_COUNT=20
ALERT_WEBHOOK_URL=https://your-webhook-url.com/alerts

# Logging
LOG_LEVEL=info
LOG_FILE_PATH=./logs/devguard.log
LOG_MAX_SIZE=100MB
LOG_MAX_FILES=10

# Performance
CACHE_ENABLED=true
CACHE_TTL_SECONDS=3600
MAX_CONCURRENT_OPERATIONS=50
```

### Directory Structure

Create the required directory structure:

```bash
mkdir -p devguard-ai-copilot/{data,logs,backups,config,scripts,docker}
cd devguard-ai-copilot

# Create subdirectories
mkdir -p data/{database,uploads,temp}
mkdir -p logs/{app,security,performance}
mkdir -p backups/{database,config}
mkdir -p config/{nginx,ssl}
mkdir -p scripts/{deployment,maintenance}
```

## Database Configuration

### Supabase Configuration (Primary Backend)

The application uses Supabase as the primary backend, providing PostgreSQL database, authentication, real-time capabilities, and storage:

```bash
# Supabase configuration is handled through environment variables
# No local database setup required
```

### Supabase Project Setup

1. Create a Supabase project at https://supabase.com
2. Get your project URL and anon key from the project settings
3. Configure environment variables (see Environment Variables section)
4. Run database migrations through Supabase dashboard or CLI

### Database Migration (Legacy SQLite to Supabase)

If migrating from an existing SQLite installation:

```bash
# Run the migration script
dart run scripts/run_migration.dart

# Verify migration
dart run lib/core/supabase/migrations/migration_verification_service.dart
```

### Database Backup Script

Create `scripts/backup_database.sh`:

```bash
#!/bin/bash

# Database backup script
BACKUP_DIR="./backups/database"
DB_PATH="./data/database/devguard.db"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/devguard_backup_$TIMESTAMP.db"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create backup
cp "$DB_PATH" "$BACKUP_FILE"

# Compress backup
gzip "$BACKUP_FILE"

# Keep only last 30 backups
find "$BACKUP_DIR" -name "devguard_backup_*.db.gz" -mtime +30 -delete

echo "Database backup completed: $BACKUP_FILE.gz"
```

## Application Configuration

### Flutter Build Configuration

Create `scripts/build_app.sh`:

```bash
#!/bin/bash

set -e

echo "🚀 Building DevGuard AI Copilot..."

# Clean previous builds
flutter clean
flutter pub get

# Run code generation
dart run build_runner build --delete-conflicting-outputs

# Run tests
echo "Running tests..."
flutter test

# Build for web
echo "Building for web..."
flutter build web --release --web-renderer html

# Build for Linux (if on Linux)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Building for Linux..."
    flutter build linux --release
fi

# Build for macOS (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Building for macOS..."
    flutter build macos --release
fi

# Build for Windows (if on Windows)
if [[ "$OSTYPE" == "msys" ]]; then
    echo "Building for Windows..."
    flutter build windows --release
fi

echo "✅ Build completed successfully!"
```

### Configuration Validation Script

Create `scripts/validate_config.dart`:

```dart
import 'dart:io';
import 'dart:convert';

void main() async {
  print('🔍 Validating configuration...');
  
  // Check environment file
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('❌ .env file not found');
    exit(1);
  }
  
  // Parse environment variables
  final envContent = await envFile.readAsString();
  final envVars = <String, String>{};
  
  for (final line in envContent.split('\n')) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    
    final parts = line.split('=');
    if (parts.length >= 2) {
      envVars[parts[0].trim()] = parts.sublist(1).join('=').trim();
    }
  }
  
  // Required environment variables
  final requiredVars = [
    'APP_NAME',
    'APP_VERSION',
    'APP_ENVIRONMENT',
    'DATABASE_PATH',
    'JWT_SECRET',
    'GEMINI_API_KEY',
  ];
  
  bool isValid = true;
  
  for (final varName in requiredVars) {
    if (!envVars.containsKey(varName) || envVars[varName]!.isEmpty) {
      print('❌ Missing required environment variable: $varName');
      isValid = false;
    }
  }
  
  // Validate JWT secret length
  if (envVars['JWT_SECRET'] != null && envVars['JWT_SECRET']!.length < 32) {
    print('❌ JWT_SECRET must be at least 32 characters long');
    isValid = false;
  }
  
  // Check directory structure
  final requiredDirs = [
    'data',
    'logs',
    'backups',
  ];
  
  for (final dir in requiredDirs) {
    if (!Directory(dir).existsSync()) {
      print('❌ Missing required directory: $dir');
      isValid = false;
    }
  }
  
  if (isValid) {
    print('✅ Configuration validation passed');
  } else {
    print('❌ Configuration validation failed');
    exit(1);
  }
}
```

## Docker Deployment

### Dockerfile

Create `docker/Dockerfile`:

```dockerfile
# Multi-stage build for Flutter web application
FROM ubuntu:22.04 AS build-env

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:${PATH}"

# Set up Flutter
RUN flutter doctor -v
RUN flutter config --enable-web

# Copy source code
WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get

COPY . .

# Build the application
RUN flutter build web --release --web-renderer html

# Production stage
FROM nginx:alpine

# Install SQLite
RUN apk add --no-cache sqlite

# Copy built application
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Create application directories
RUN mkdir -p /app/data /app/logs /app/backups
RUN chown -R nginx:nginx /app

# Copy application files
COPY --from=build-env /app/lib /app/lib
COPY --from=build-env /app/pubspec.yaml /app/
COPY --from=build-env /app/.env /app/

# Expose ports
EXPOSE 80 8080 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Start script
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
```

### Docker Compose Configuration

Create `docker/docker-compose.yml`:

```yaml
version: '3.8'

services:
  devguard-app:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    container_name: devguard-ai-copilot
    restart: unless-stopped
    ports:
      - "80:80"
      - "8080:8080"
      - "8081:8081"
    volumes:
      - ../data:/app/data
      - ../logs:/app/logs
      - ../backups:/app/backups
      - ../config:/app/config
    environment:
      - APP_ENVIRONMENT=production
      - DATABASE_PATH=/app/data/devguard.db
      - LOG_FILE_PATH=/app/logs/devguard.log
    networks:
      - devguard-network
    depends_on:
      - devguard-redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  devguard-redis:
    image: redis:7-alpine
    container_name: devguard-redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    networks:
      - devguard-network
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  devguard-nginx:
    image: nginx:alpine
    container_name: devguard-nginx
    restart: unless-stopped
    ports:
      - "443:443"
    volumes:
      - ../config/nginx:/etc/nginx/conf.d
      - ../config/ssl:/etc/ssl/certs
    networks:
      - devguard-network
    depends_on:
      - devguard-app

volumes:
  redis-data:

networks:
  devguard-network:
    driver: bridge
```

### Nginx Configuration

Create `config/nginx/default.conf`:

```nginx
upstream devguard_app {
    server devguard-app:8080;
}

upstream devguard_websocket {
    server devguard-app:8081;
}

server {
    listen 80;
    server_name localhost;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name localhost;

    # SSL Configuration
    ssl_certificate /etc/ssl/certs/devguard.crt;
    ssl_certificate_key /etc/ssl/certs/devguard.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Static files
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # API endpoints
    location /api/ {
        proxy_pass http://devguard_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket endpoints
    location /ws {
        proxy_pass http://devguard_websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket timeouts
        proxy_read_timeout 86400;
    }

    # Health check
    location /health {
        proxy_pass http://devguard_app/health;
        access_log off;
    }
}
```

### Docker Start Script

Create `docker/start.sh`:

```bash
#!/bin/bash

set -e

echo "🚀 Starting DevGuard AI Copilot..."

# Wait for dependencies
echo "Waiting for Redis..."
while ! nc -z devguard-redis 6379; do
    sleep 1
done

# Initialize database if needed
if [ ! -f /app/data/devguard.db ]; then
    echo "Initializing database..."
    cd /app
    dart run lib/core/database/migrations/run_migrations.dart
fi

# Start the application in background
echo "Starting application server..."
cd /app
dart run lib/main.dart &

# Start nginx
echo "Starting nginx..."
nginx -g "daemon off;"
```

## Platform-Specific Deployment

### Linux Deployment

Create `scripts/deploy_linux.sh`:

```bash
#!/bin/bash

set -e

echo "🐧 Deploying DevGuard AI Copilot on Linux..."

# Build application
./scripts/build_app.sh

# Create systemd service
sudo tee /etc/systemd/system/devguard.service > /dev/null <<EOF
[Unit]
Description=DevGuard AI Copilot
After=network.target

[Service]
Type=simple
User=devguard
WorkingDirectory=/opt/devguard-ai-copilot
ExecStart=/opt/devguard-ai-copilot/build/linux/x64/release/bundle/devguard_ai_copilot
Restart=always
RestartSec=10
Environment=PATH=/usr/bin:/usr/local/bin
Environment=DISPLAY=:0

[Install]
WantedBy=multi-user.target
EOF

# Create user and directories
sudo useradd -r -s /bin/false devguard || true
sudo mkdir -p /opt/devguard-ai-copilot
sudo cp -r . /opt/devguard-ai-copilot/
sudo chown -R devguard:devguard /opt/devguard-ai-copilot

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable devguard
sudo systemctl start devguard

echo "✅ Linux deployment completed!"
echo "Service status: sudo systemctl status devguard"
echo "Logs: sudo journalctl -u devguard -f"
```

### macOS Deployment

Create `scripts/deploy_macos.sh`:

```bash
#!/bin/bash

set -e

echo "🍎 Deploying DevGuard AI Copilot on macOS..."

# Build application
./scripts/build_app.sh

# Create launch daemon
sudo tee /Library/LaunchDaemons/com.devguard.ai-copilot.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.devguard.ai-copilot</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/DevGuard AI Copilot.app/Contents/MacOS/devguard_ai_copilot</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>/Applications/DevGuard AI Copilot.app/Contents/MacOS</string>
</dict>
</plist>
EOF

# Copy application
sudo cp -r build/macos/Build/Products/Release/devguard_ai_copilot.app "/Applications/DevGuard AI Copilot.app"

# Load launch daemon
sudo launchctl load /Library/LaunchDaemons/com.devguard.ai-copilot.plist

echo "✅ macOS deployment completed!"
echo "Application installed in /Applications/DevGuard AI Copilot.app"
```

### Windows Deployment

Create `scripts/deploy_windows.ps1`:

```powershell
# Deploy DevGuard AI Copilot on Windows

Write-Host "🪟 Deploying DevGuard AI Copilot on Windows..." -ForegroundColor Green

# Build application
& .\scripts\build_app.sh

# Create installation directory
$InstallDir = "C:\Program Files\DevGuard AI Copilot"
New-Item -ItemType Directory -Force -Path $InstallDir

# Copy application files
Copy-Item -Recurse -Force "build\windows\runner\Release\*" $InstallDir

# Create Windows service
$ServiceName = "DevGuardAICopilot"
$ServiceDisplayName = "DevGuard AI Copilot"
$ServiceDescription = "AI-powered development copilot with security monitoring"
$ServicePath = "$InstallDir\devguard_ai_copilot.exe"

# Install service using sc.exe
& sc.exe create $ServiceName binPath= $ServicePath DisplayName= $ServiceDisplayName start= auto
& sc.exe description $ServiceName $ServiceDescription

# Start service
& sc.exe start $ServiceName

Write-Host "✅ Windows deployment completed!" -ForegroundColor Green
Write-Host "Service installed: $ServiceDisplayName"
Write-Host "Service status: sc query $ServiceName"
```

## CI/CD Pipeline Setup

### GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy DevGuard AI Copilot

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Run code generation
        run: dart run build_runner build --delete-conflicting-outputs
        
      - name: Run tests
        run: flutter test --coverage
        
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info

  build:
    needs: test
    runs-on: ubuntu-latest
    strategy:
      matrix:
        platform: [web, linux]
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Build for ${{ matrix.platform }}
        run: |
          if [ "${{ matrix.platform }}" == "web" ]; then
            flutter build web --release --web-renderer html
          elif [ "${{ matrix.platform }}" == "linux" ]; then
            sudo apt-get update
            sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
            flutter build linux --release
          fi
          
      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build-${{ matrix.platform }}
          path: build/${{ matrix.platform }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - name: Download build artifacts
        uses: actions/download-artifact@v3
        
      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v2
        
      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
          
      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: .
          file: docker/Dockerfile
          push: true
          tags: |
            devguard/ai-copilot:latest
            devguard/ai-copilot:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy-production:
    needs: deploy
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - name: Deploy to production
        run: |
          echo "Deploying to production server..."
          # Add your production deployment commands here
```

### GitLab CI/CD Pipeline

Create `.gitlab-ci.yml`:

```yaml
stages:
  - test
  - build
  - deploy

variables:
  FLUTTER_VERSION: "3.10.0"

before_script:
  - apt-get update -qq && apt-get install -y -qq git curl unzip
  - git clone https://github.com/flutter/flutter.git -b stable
  - export PATH="$PATH:`pwd`/flutter/bin"
  - flutter doctor -v
  - flutter pub get

test:
  stage: test
  script:
    - dart run build_runner build --delete-conflicting-outputs
    - flutter test --coverage
    - flutter analyze
  coverage: '/lines......: \d+\.\d+\%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml

build_web:
  stage: build
  script:
    - flutter build web --release --web-renderer html
  artifacts:
    paths:
      - build/web/
    expire_in: 1 hour

build_linux:
  stage: build
  before_script:
    - apt-get update -qq
    - apt-get install -y -qq clang cmake ninja-build pkg-config libgtk-3-dev
  script:
    - flutter build linux --release
  artifacts:
    paths:
      - build/linux/
    expire_in: 1 hour

deploy_docker:
  stage: deploy
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -f docker/Dockerfile -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - docker tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA $CI_REGISTRY_IMAGE:latest
    - docker push $CI_REGISTRY_IMAGE:latest
  only:
    - main
```

## Monitoring and Logging

### Application Monitoring

Create `scripts/setup_monitoring.sh`:

```bash
#!/bin/bash

echo "📊 Setting up monitoring..."

# Create monitoring directories
mkdir -p monitoring/{prometheus,grafana,alertmanager}

# Prometheus configuration
cat > monitoring/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'devguard-app'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF

# Grafana dashboard
cat > monitoring/grafana/dashboard.json <<EOF
{
  "dashboard": {
    "title": "DevGuard AI Copilot Monitoring",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{status}}"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      },
      {
        "title": "Active Users",
        "type": "stat",
        "targets": [
          {
            "expr": "websocket_connections_active",
            "legendFormat": "Active Connections"
          }
        ]
      }
    ]
  }
}
EOF

echo "✅ Monitoring setup completed!"
```

### Log Management

Create `scripts/setup_logging.sh`:

```bash
#!/bin/bash

echo "📝 Setting up logging..."

# Create log rotation configuration
sudo tee /etc/logrotate.d/devguard <<EOF
/opt/devguard-ai-copilot/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 devguard devguard
    postrotate
        systemctl reload devguard
    endscript
}
EOF

# Create rsyslog configuration
sudo tee /etc/rsyslog.d/50-devguard.conf <<EOF
# DevGuard AI Copilot logging
:programname, isequal, "devguard" /var/log/devguard/app.log
& stop
EOF

# Restart rsyslog
sudo systemctl restart rsyslog

echo "✅ Logging setup completed!"
```

## Security Configuration

### SSL/TLS Setup

Create `scripts/setup_ssl.sh`:

```bash
#!/bin/bash

echo "🔒 Setting up SSL/TLS..."

# Create SSL directory
mkdir -p config/ssl

# Generate self-signed certificate (for development)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout config/ssl/devguard.key \
    -out config/ssl/devguard.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Set proper permissions
chmod 600 config/ssl/devguard.key
chmod 644 config/ssl/devguard.crt

# For production, use Let's Encrypt
if [ "$1" == "production" ]; then
    # Install certbot
    sudo apt-get update
    sudo apt-get install -y certbot python3-certbot-nginx
    
    # Get certificate
    sudo certbot --nginx -d your-domain.com
fi

echo "✅ SSL/TLS setup completed!"
```

### Firewall Configuration

Create `scripts/setup_firewall.sh`:

```bash
#!/bin/bash

echo "🛡️ Setting up firewall..."

# Enable UFW
sudo ufw --force enable

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow ssh

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow application ports
sudo ufw allow 8080/tcp
sudo ufw allow 8081/tcp

# Allow specific IPs for admin access (replace with your IPs)
# sudo ufw allow from YOUR_ADMIN_IP to any port 22

# Show status
sudo ufw status verbose

echo "✅ Firewall setup completed!"
```

## Backup and Recovery

### Automated Backup Script

Create `scripts/backup_system.sh`:

```bash
#!/bin/bash

set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="devguard_full_backup_$TIMESTAMP"

echo "💾 Starting system backup..."

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# Backup database
echo "Backing up database..."
cp data/devguard.db "$BACKUP_DIR/$BACKUP_NAME/"

# Backup configuration
echo "Backing up configuration..."
cp -r config "$BACKUP_DIR/$BACKUP_NAME/"
cp .env "$BACKUP_DIR/$BACKUP_NAME/"

# Backup logs (last 7 days)
echo "Backing up recent logs..."
find logs -name "*.log" -mtime -7 -exec cp {} "$BACKUP_DIR/$BACKUP_NAME/" \;

# Create archive
echo "Creating archive..."
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

# Upload to cloud storage (optional)
if [ -n "$BACKUP_CLOUD_URL" ]; then
    echo "Uploading to cloud storage..."
    curl -X POST -F "file=@$BACKUP_NAME.tar.gz" "$BACKUP_CLOUD_URL"
fi

# Clean old backups (keep last 30)
find "$BACKUP_DIR" -name "devguard_full_backup_*.tar.gz" -mtime +30 -delete

echo "✅ Backup completed: $BACKUP_NAME.tar.gz"
```

### Recovery Script

Create `scripts/restore_system.sh`:

```bash
#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <backup_file>"
    echo "Available backups:"
    ls -la backups/devguard_full_backup_*.tar.gz
    exit 1
fi

BACKUP_FILE="$1"
RESTORE_DIR="./restore_temp"

echo "🔄 Starting system restore from $BACKUP_FILE..."

# Stop application
echo "Stopping application..."
sudo systemctl stop devguard || docker-compose down || true

# Create restore directory
mkdir -p "$RESTORE_DIR"

# Extract backup
echo "Extracting backup..."
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

# Find backup directory
BACKUP_DIR=$(find "$RESTORE_DIR" -name "devguard_full_backup_*" -type d | head -1)

if [ -z "$BACKUP_DIR" ]; then
    echo "❌ Invalid backup file"
    exit 1
fi

# Restore database
echo "Restoring database..."
cp "$BACKUP_DIR/devguard.db" data/

# Restore configuration
echo "Restoring configuration..."
cp -r "$BACKUP_DIR/config/"* config/
cp "$BACKUP_DIR/.env" .

# Set permissions
chown -R devguard:devguard data/ config/ || true
chmod 600 config/ssl/devguard.key || true

# Clean up
rm -rf "$RESTORE_DIR"

# Start application
echo "Starting application..."
sudo systemctl start devguard || docker-compose up -d

echo "✅ System restore completed!"
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Application Won't Start

```bash
# Check logs
sudo journalctl -u devguard -f

# Check configuration
dart run scripts/validate_config.dart

# Check permissions
ls -la data/ logs/ config/

# Check dependencies
flutter doctor
```

#### 2. Database Connection Issues

```bash
# Check database file
ls -la data/devguard.db

# Check database integrity
sqlite3 data/devguard.db "PRAGMA integrity_check;"

# Restore from backup
./scripts/restore_system.sh backups/latest_backup.tar.gz
```

#### 3. WebSocket Connection Problems

```bash
# Check WebSocket port
netstat -tlnp | grep 8081

# Check firewall
sudo ufw status

# Test WebSocket connection
wscat -c ws://localhost:8081
```

#### 4. High Memory Usage

```bash
# Check memory usage
free -h
ps aux | grep devguard

# Restart application
sudo systemctl restart devguard

# Check for memory leaks
valgrind --tool=memcheck ./build/linux/x64/release/bundle/devguard_ai_copilot
```

### Health Check Script

Create `scripts/health_check.sh`:

```bash
#!/bin/bash

echo "🏥 DevGuard AI Copilot Health Check"
echo "=================================="

# Check application status
if systemctl is-active --quiet devguard; then
    echo "✅ Application: Running"
else
    echo "❌ Application: Not running"
fi

# Check database
if [ -f "data/devguard.db" ]; then
    echo "✅ Database: Present"
    DB_SIZE=$(du -h data/devguard.db | cut -f1)
    echo "   Size: $DB_SIZE"
else
    echo "❌ Database: Missing"
fi

# Check disk space
DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo "✅ Disk Space: $DISK_USAGE% used"
else
    echo "⚠️  Disk Space: $DISK_USAGE% used (Warning: >80%)"
fi

# Check memory usage
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ "$MEMORY_USAGE" -lt 80 ]; then
    echo "✅ Memory: $MEMORY_USAGE% used"
else
    echo "⚠️  Memory: $MEMORY_USAGE% used (Warning: >80%)"
fi

# Check network connectivity
if curl -s --max-time 5 http://localhost:8080/health > /dev/null; then
    echo "✅ Network: Application responding"
else
    echo "❌ Network: Application not responding"
fi

# Check log file size
if [ -f "logs/devguard.log" ]; then
    LOG_SIZE=$(du -h logs/devguard.log | cut -f1)
    echo "✅ Logs: $LOG_SIZE"
else
    echo "⚠️  Logs: No log file found"
fi

echo "=================================="
echo "Health check completed at $(date)"
```

### Performance Monitoring Script

Create `scripts/performance_monitor.sh`:

```bash
#!/bin/bash

echo "📈 Performance Monitoring Report"
echo "==============================="

# CPU Usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
echo "CPU Usage: $CPU_USAGE%"

# Memory Usage
MEMORY_INFO=$(free -h | awk 'NR==2{printf "Used: %s/%s (%.0f%%)", $3,$2,$3*100/$2}')
echo "Memory: $MEMORY_INFO"

# Application Process Info
if pgrep -f devguard > /dev/null; then
    APP_PID=$(pgrep -f devguard)
    APP_CPU=$(ps -p $APP_PID -o %cpu --no-headers)
    APP_MEM=$(ps -p $APP_PID -o %mem --no-headers)
    echo "Application CPU: $APP_CPU%"
    echo "Application Memory: $APP_MEM%"
else
    echo "❌ Application process not found"
fi

# Network Connections
CONNECTIONS=$(netstat -an | grep :8080 | wc -l)
echo "Active Connections: $CONNECTIONS"

# Database Size
if [ -f "data/devguard.db" ]; then
    DB_SIZE=$(du -h data/devguard.db | cut -f1)
    echo "Database Size: $DB_SIZE"
fi

# Log File Sizes
echo "Log Files:"
find logs -name "*.log" -exec du -h {} \; | sort -hr | head -5

echo "==============================="
echo "Report generated at $(date)"
```

## Maintenance

### Regular Maintenance Tasks

Create a cron job for regular maintenance:

```bash
# Edit crontab
crontab -e

# Add maintenance tasks
0 2 * * * /opt/devguard-ai-copilot/scripts/backup_system.sh
0 3 * * 0 /opt/devguard-ai-copilot/scripts/health_check.sh
*/15 * * * * /opt/devguard-ai-copilot/scripts/performance_monitor.sh >> /var/log/devguard/performance.log
```

### Update Script

Create `scripts/update_system.sh`:

```bash
#!/bin/bash

set -e

echo "🔄 Updating DevGuard AI Copilot..."

# Backup current system
./scripts/backup_system.sh

# Pull latest changes
git pull origin main

# Update dependencies
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Build application
./scripts/build_app.sh

# Restart application
sudo systemctl restart devguard

# Verify update
sleep 10
./scripts/health_check.sh

echo "✅ Update completed successfully!"
```

---

This comprehensive deployment guide provides everything needed to deploy the DevGuard AI Copilot application in production environments while maintaining security, performance, and reliability standards using free and open-source tools.

**Last Updated**: January 15, 2024  
**Version**: 1.0.0