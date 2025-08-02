# DevGuard AI Copilot - Deployment Guide

This guide covers deployment options for DevGuard AI Copilot across different platforms and environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Desktop Application Deployment](#desktop-application-deployment)
3. [Containerized Deployment](#containerized-deployment)
4. [Cloud Deployment](#cloud-deployment)
5. [Platform-Specific Instructions](#platform-specific-instructions)
6. [Configuration](#configuration)
7. [Monitoring and Maintenance](#monitoring-and-maintenance)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

**Minimum Requirements:**
- RAM: 4GB
- Storage: 2GB free space
- CPU: Dual-core processor
- Network: Internet connection for git operations

**Recommended Requirements:**
- RAM: 8GB or more
- Storage: 10GB free space
- CPU: Quad-core processor or better
- Network: Stable broadband connection

### Software Dependencies

- **Flutter SDK** (for building from source)
- **Git** (for repository operations)
- **Docker** (for containerized deployment)
- **Node.js** (for backend services, if applicable)

## Desktop Application Deployment

### Quick Installation

#### Windows
1. Download `DevGuard-AI-Copilot-1.0.0-Windows-Setup.exe`
2. Run the installer as Administrator
3. Follow the installation wizard
4. Launch from Start Menu or Desktop shortcut

#### macOS
1. Download `DevGuard-AI-Copilot-1.0.0-macOS.dmg`
2. Open the DMG file
3. Drag DevGuard AI Copilot to Applications folder
4. Launch from Applications or Launchpad

#### Linux
1. Download the appropriate package:
   - **Ubuntu/Debian**: `devguard-ai-copilot_1.0.0_amd64.deb`
   - **Generic Linux**: `DevGuard-AI-Copilot-1.0.0-Linux.tar.gz`

2. Install the package:
   ```bash
   # Ubuntu/Debian
   sudo dpkg -i devguard-ai-copilot_1.0.0_amd64.deb
   sudo apt-get install -f  # Fix dependencies if needed
   
   # Generic Linux
   tar -xzf DevGuard-AI-Copilot-1.0.0-Linux.tar.gz
   cd linux/
   ./devguard_ai_copilot
   ```

### Building from Source

#### Prerequisites
- Flutter SDK 3.x or later
- Platform-specific build tools

#### Build Commands

```bash
# Clone the repository
git clone https://github.com/devguard/ai-copilot.git
cd ai-copilot

# Install dependencies
flutter pub get

# Run tests
flutter test

# Build for your platform
flutter build windows --release  # Windows
flutter build macos --release    # macOS
flutter build linux --release    # Linux
```

#### Cross-Platform Build

Use the provided build scripts for automated cross-platform builds:

```bash
# Windows (PowerShell)
.\scripts\build_all_platforms.ps1 -Version "1.0.0" -BuildMode "release"

# Unix/Linux/macOS (Bash)
./scripts/build_all_platforms.sh --version "1.0.0" --build-mode "release"
```

## Containerized Deployment

### Docker Deployment

#### Single Container

```bash
# Build the image
docker build -t devguard/ai-copilot:latest -f deployment/docker/Dockerfile .

# Run the container
docker run -d \
  --name devguard-ai-copilot \
  -p 8080:8080 \
  -v devguard_data:/data \
  -v devguard_logs:/var/log/devguard \
  devguard/ai-copilot:latest
```

#### Docker Compose (Recommended)

```bash
# Navigate to deployment directory
cd deployment/docker

# Create environment file
cp .env.example .env
# Edit .env with your configuration

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f devguard-ai-copilot

# Stop services
docker-compose down
```

### Kubernetes Deployment

#### Prerequisites
- Kubernetes cluster (1.20+)
- kubectl configured
- Helm 3.x (optional)

#### Basic Deployment

```yaml
# devguard-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devguard-ai-copilot
  labels:
    app: devguard-ai-copilot
spec:
  replicas: 2
  selector:
    matchLabels:
      app: devguard-ai-copilot
  template:
    metadata:
      labels:
        app: devguard-ai-copilot
    spec:
      containers:
      - name: devguard-ai-copilot
        image: devguard/ai-copilot:latest
        ports:
        - containerPort: 8080
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_PATH
          value: "/data/devguard.db"
        volumeMounts:
        - name: data-volume
          mountPath: /data
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: devguard-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: devguard-service
spec:
  selector:
    app: devguard-ai-copilot
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer
```

Deploy to Kubernetes:

```bash
kubectl apply -f devguard-deployment.yaml
```

## Cloud Deployment

### AWS Deployment

#### EC2 Instance

1. Launch an EC2 instance (t3.medium or larger)
2. Install Docker and Docker Compose
3. Clone the repository and deploy using Docker Compose
4. Configure security groups for ports 80, 443, 8080

#### ECS Deployment

```json
{
  "family": "devguard-ai-copilot",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "devguard-ai-copilot",
      "image": "devguard/ai-copilot:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/devguard-ai-copilot",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### Google Cloud Platform

#### Cloud Run Deployment

```bash
# Build and push to Container Registry
gcloud builds submit --tag gcr.io/PROJECT-ID/devguard-ai-copilot

# Deploy to Cloud Run
gcloud run deploy devguard-ai-copilot \
  --image gcr.io/PROJECT-ID/devguard-ai-copilot \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 2Gi \
  --cpu 2
```

### Azure Deployment

#### Container Instances

```bash
# Create resource group
az group create --name devguard-rg --location eastus

# Deploy container
az container create \
  --resource-group devguard-rg \
  --name devguard-ai-copilot \
  --image devguard/ai-copilot:latest \
  --cpu 2 \
  --memory 4 \
  --ports 8080 \
  --environment-variables NODE_ENV=production
```

## Platform-Specific Instructions

### Windows Server Deployment

#### IIS Integration (if web interface available)

1. Install IIS with Application Request Routing
2. Configure reverse proxy to application port
3. Set up SSL certificates
4. Configure Windows Service for auto-start

#### Windows Service Installation

```powershell
# Install as Windows Service using NSSM
nssm install "DevGuard AI Copilot" "C:\Program Files\DevGuard AI Copilot\devguard_ai_copilot.exe"
nssm set "DevGuard AI Copilot" Start SERVICE_AUTO_START
nssm start "DevGuard AI Copilot"
```

### Linux Server Deployment

#### Systemd Service

Create `/etc/systemd/system/devguard-ai-copilot.service`:

```ini
[Unit]
Description=DevGuard AI Copilot
After=network.target

[Service]
Type=simple
User=devguard
WorkingDirectory=/opt/devguard-ai-copilot
ExecStart=/opt/devguard-ai-copilot/devguard_ai_copilot
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=DATABASE_PATH=/var/lib/devguard/devguard.db

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable devguard-ai-copilot
sudo systemctl start devguard-ai-copilot
```

### macOS Server Deployment

#### LaunchDaemon Configuration

Create `/Library/LaunchDaemons/com.devguard.ai-copilot.plist`:

```xml
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
```

Load the daemon:

```bash
sudo launchctl load /Library/LaunchDaemons/com.devguard.ai-copilot.plist
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment mode | `development` |
| `DATABASE_PATH` | SQLite database path | `./devguard.db` |
| `LOG_LEVEL` | Logging level | `info` |
| `GITHUB_TOKEN` | GitHub API token | - |
| `GITLAB_TOKEN` | GitLab API token | - |
| `SECURITY_MONITORING_ENABLED` | Enable security monitoring | `true` |
| `AUDIT_LOGGING_ENABLED` | Enable audit logging | `true` |

### Configuration Files

#### Main Configuration (`config/app.json`)

```json
{
  "app": {
    "name": "DevGuard AI Copilot",
    "version": "1.0.0",
    "environment": "production"
  },
  "database": {
    "type": "sqlite",
    "path": "/data/devguard.db",
    "backup_enabled": true,
    "backup_interval": "24h"
  },
  "security": {
    "monitoring_enabled": true,
    "honeytoken_enabled": true,
    "audit_logging": true,
    "encryption_enabled": true
  },
  "integrations": {
    "github": {
      "enabled": true,
      "api_url": "https://api.github.com"
    },
    "gitlab": {
      "enabled": true,
      "api_url": "https://gitlab.com/api/v4"
    }
  },
  "monitoring": {
    "health_checks_enabled": true,
    "metrics_enabled": true,
    "prometheus_endpoint": "/metrics"
  }
}
```

#### Logging Configuration (`config/logging.json`)

```json
{
  "level": "info",
  "format": "json",
  "outputs": [
    {
      "type": "file",
      "path": "/var/log/devguard/app.log",
      "max_size": "100MB",
      "max_files": 10
    },
    {
      "type": "console",
      "enabled": true
    }
  ],
  "audit": {
    "enabled": true,
    "path": "/var/log/devguard/audit.log",
    "retention_days": 90
  }
}
```

## Monitoring and Maintenance

### Health Checks

The application provides several health check endpoints:

- `/health` - Basic health status
- `/health/detailed` - Detailed system health
- `/metrics` - Prometheus metrics

### Monitoring Setup

#### Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'devguard-ai-copilot'
    static_configs:
      - targets: ['devguard-ai-copilot:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s
```

#### Grafana Dashboards

Import the provided Grafana dashboards from `deployment/monitoring/grafana/dashboards/`:

- System Overview Dashboard
- Security Monitoring Dashboard
- Application Performance Dashboard
- Error Tracking Dashboard

### Log Management

#### Log Rotation

Configure log rotation to prevent disk space issues:

```bash
# /etc/logrotate.d/devguard-ai-copilot
/var/log/devguard/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 devguard devguard
    postrotate
        systemctl reload devguard-ai-copilot
    endscript
}
```

### Backup and Recovery

#### Database Backup

```bash
#!/bin/bash
# backup-devguard.sh

BACKUP_DIR="/backup/devguard"
DATE=$(date +%Y%m%d_%H%M%S)
DB_PATH="/data/devguard.db"

mkdir -p "$BACKUP_DIR"

# Create database backup
sqlite3 "$DB_PATH" ".backup $BACKUP_DIR/devguard_$DATE.db"

# Compress backup
gzip "$BACKUP_DIR/devguard_$DATE.db"

# Keep only last 30 days of backups
find "$BACKUP_DIR" -name "devguard_*.db.gz" -mtime +30 -delete

echo "Backup completed: devguard_$DATE.db.gz"
```

#### Configuration Backup

```bash
#!/bin/bash
# backup-config.sh

CONFIG_DIR="/etc/devguard"
BACKUP_DIR="/backup/devguard-config"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Create configuration backup
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" -C "$CONFIG_DIR" .

# Keep only last 10 configuration backups
ls -t "$BACKUP_DIR"/config_*.tar.gz | tail -n +11 | xargs -r rm

echo "Configuration backup completed: config_$DATE.tar.gz"
```

### Updates and Upgrades

#### Rolling Updates (Docker)

```bash
# Pull new image
docker pull devguard/ai-copilot:latest

# Update with zero downtime
docker-compose up -d --no-deps devguard-ai-copilot
```

#### Blue-Green Deployment

```bash
#!/bin/bash
# blue-green-deploy.sh

NEW_VERSION="$1"
CURRENT_CONTAINER="devguard-ai-copilot"
NEW_CONTAINER="devguard-ai-copilot-new"

# Start new version
docker run -d --name "$NEW_CONTAINER" \
  -p 8081:8080 \
  -v devguard_data:/data \
  "devguard/ai-copilot:$NEW_VERSION"

# Health check new version
sleep 30
if curl -f http://localhost:8081/health; then
  # Switch traffic
  docker stop "$CURRENT_CONTAINER"
  docker rename "$CURRENT_CONTAINER" "devguard-ai-copilot-old"
  docker rename "$NEW_CONTAINER" "$CURRENT_CONTAINER"
  
  # Update port mapping
  docker stop "$CURRENT_CONTAINER"
  docker run -d --name "$CURRENT_CONTAINER-final" \
    -p 8080:8080 \
    -v devguard_data:/data \
    "devguard/ai-copilot:$NEW_VERSION"
  
  # Cleanup
  docker rm "$CURRENT_CONTAINER"
  docker rename "$CURRENT_CONTAINER-final" "$CURRENT_CONTAINER"
  docker rm "devguard-ai-copilot-old"
  
  echo "Deployment successful"
else
  echo "Health check failed, rolling back"
  docker stop "$NEW_CONTAINER"
  docker rm "$NEW_CONTAINER"
  exit 1
fi
```

## Troubleshooting

### Common Issues

#### Application Won't Start

1. **Check system requirements**
   ```bash
   # Check available memory
   free -h
   
   # Check disk space
   df -h
   
   # Check CPU usage
   top
   ```

2. **Verify dependencies**
   ```bash
   # Check Flutter installation
   flutter doctor
   
   # Check Git installation
   git --version
   
   # Check database permissions
   ls -la /data/devguard.db
   ```

3. **Review logs**
   ```bash
   # Application logs
   tail -f /var/log/devguard/app.log
   
   # System logs
   journalctl -u devguard-ai-copilot -f
   
   # Docker logs
   docker logs devguard-ai-copilot
   ```

#### Performance Issues

1. **Monitor resource usage**
   ```bash
   # System resources
   htop
   
   # Application metrics
   curl http://localhost:8080/metrics
   
   # Database performance
   sqlite3 /data/devguard.db ".timer on" ".stats on"
   ```

2. **Optimize configuration**
   - Increase memory allocation
   - Adjust database cache size
   - Enable compression
   - Configure connection pooling

#### Network Connectivity Issues

1. **Test external connections**
   ```bash
   # GitHub API
   curl -I https://api.github.com
   
   # GitLab API
   curl -I https://gitlab.com/api/v4
   
   # DNS resolution
   nslookup api.github.com
   ```

2. **Check firewall settings**
   ```bash
   # Linux (iptables)
   iptables -L
   
   # Linux (ufw)
   ufw status
   
   # Windows
   netsh advfirewall show allprofiles
   ```

#### Database Issues

1. **Check database integrity**
   ```bash
   sqlite3 /data/devguard.db "PRAGMA integrity_check;"
   ```

2. **Repair database**
   ```bash
   # Create backup first
   cp /data/devguard.db /data/devguard.db.backup
   
   # Repair database
   sqlite3 /data/devguard.db ".recover" | sqlite3 /data/devguard_recovered.db
   ```

3. **Reset database** (last resort)
   ```bash
   # Stop application
   systemctl stop devguard-ai-copilot
   
   # Backup current database
   mv /data/devguard.db /data/devguard.db.old
   
   # Start application (will create new database)
   systemctl start devguard-ai-copilot
   ```

### Getting Help

- **Documentation**: Check the official documentation
- **GitHub Issues**: Report bugs and feature requests
- **Community Forum**: Ask questions and share experiences
- **Support Email**: team@devguard.ai

### Diagnostic Information

When reporting issues, please include:

1. **System Information**
   ```bash
   # Operating system
   uname -a
   
   # Application version
   ./devguard_ai_copilot --version
   
   # Resource usage
   free -h && df -h
   ```

2. **Configuration**
   - Environment variables
   - Configuration files (sanitized)
   - Docker/Kubernetes manifests

3. **Logs**
   - Application logs (last 100 lines)
   - System logs (relevant entries)
   - Error messages and stack traces

4. **Steps to Reproduce**
   - Detailed steps that led to the issue
   - Expected vs actual behavior
   - Screenshots or recordings if applicable

---

For additional support and updates, visit our [GitHub repository](https://github.com/devguard/ai-copilot) or contact our support team.