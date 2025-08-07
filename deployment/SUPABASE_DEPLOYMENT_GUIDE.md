# DevGuard AI Copilot - Supabase Deployment Guide

This guide covers deploying DevGuard AI Copilot with Supabase backend instead of local SQLite database.

## Prerequisites

### Required Environment Variables

```bash
# Supabase Configuration
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# GitHub OAuth (configured in Supabase Auth)
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret
GITHUB_OAUTH_REDIRECT_URI=your_callback_url

# AI Integration
GEMINI_API_KEY=your_gemini_api_key
```

### System Requirements

- Flutter SDK (latest stable)
- Docker (for containerized deployment)
- curl (for connectivity verification)
- Active Supabase project with:
  - Database schema applied
  - Row Level Security policies configured
  - Authentication providers enabled
  - Storage buckets created (optional)

## Deployment Methods

### 1. Quick Deployment with Supabase

```bash
# Set environment variables
export SUPABASE_URL="your_supabase_url"
export SUPABASE_ANON_KEY="your_anon_key"
export SUPABASE_SERVICE_ROLE_KEY="your_service_role_key"

# Run Supabase-enabled deployment
./scripts/deploy_with_supabase.sh
```

### 2. Docker Deployment

```bash
# Build and run with Docker Compose
cd deployment/docker
docker-compose -f docker-compose.yml up -d

# Or build custom image
docker build -f Dockerfile -t devguard-ai-copilot .
docker run -d \
  -e SUPABASE_URL="$SUPABASE_URL" \
  -e SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  -e SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" \
  -p 8080:8080 \
  devguard-ai-copilot
```

### 3. Platform-Specific Deployment

#### Linux
```bash
# Deploy on Linux with Supabase
cd deployment/linux
./deploy_linux_supabase.sh
```

#### Windows
```powershell
# Deploy on Windows with Supabase
cd deployment\windows
.\deploy_windows_supabase.ps1
```

## Verification

### Automated Verification
```bash
# Run comprehensive deployment verification
./scripts/verify_deployment_supabase.sh
```

### Manual Verification

1. **Supabase Connectivity**
   ```bash
   curl -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/"
   ```

2. **Database Schema**
   ```bash
   curl -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/users?limit=1"
   ```

3. **Authentication**
   ```bash
   curl -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/auth/v1/settings"
   ```

4. **Application Health**
   ```bash
   curl http://localhost:8080/health
   ```

## Configuration Files

### Environment Files Updated
- `.env.example` - Template with Supabase configuration
- `.env.development` - Development environment with Supabase
- `.env.staging` - Staging environment configuration
- `.env.production` - Production environment configuration

### Docker Configuration Updated
- `deployment/docker/Dockerfile` - Removed SQLite dependencies
- `deployment/docker/docker-compose.yml` - Added Supabase environment variables
- Health checks now verify Supabase connectivity

### Deployment Scripts Updated
- `scripts/deploy_with_supabase.sh` - Complete Supabase deployment script
- `scripts/deploy_cross_platform.sh` - Updated to use Supabase
- `scripts/verify_deployment_supabase.sh` - Deployment verification

## Key Changes from SQLite

### Removed Components
- ❌ SQLite database files
- ❌ Local database initialization
- ❌ Database migration scripts (local)
- ❌ SQLite backup procedures
- ❌ Database volume mounts in Docker

### Added Components
- ✅ Supabase client configuration
- ✅ Supabase connectivity verification
- ✅ Real-time subscription management
- ✅ Row Level Security integration
- ✅ Cloud storage capabilities
- ✅ Managed authentication

## Troubleshooting

### Common Issues

1. **Connection Failed**
   ```bash
   # Check environment variables
   echo $SUPABASE_URL
   echo $SUPABASE_ANON_KEY
   
   # Test connectivity
   curl -v -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/"
   ```

2. **Authentication Issues**
   ```bash
   # Verify auth configuration
   curl -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/auth/v1/settings"
   ```

3. **RLS Policy Errors**
   - Check that RLS policies are properly configured
   - Verify user roles and permissions
   - Test with service role key for admin operations

4. **Real-time Issues**
   ```bash
   # Check real-time endpoint
   curl -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/realtime/v1/api/tenants/realtime/channels"
   ```

### Health Check Endpoints

- Application: `http://localhost:8080/health`
- WebSocket: `http://localhost:8081` (upgrade to WebSocket)
- Supabase REST: `$SUPABASE_URL/rest/v1/`
- Supabase Auth: `$SUPABASE_URL/auth/v1/settings`

## Performance Considerations

### Supabase Optimizations
- Use connection pooling (handled by Supabase)
- Implement proper indexing on frequently queried columns
- Use select() to limit returned columns
- Implement client-side caching for static data

### Real-time Optimizations
- Subscribe only to necessary tables/rows
- Implement proper cleanup of subscriptions
- Use filters to reduce unnecessary updates
- Handle connection drops gracefully

## Security Best Practices

### Environment Variables
- Never commit actual keys to version control
- Use different keys for different environments
- Rotate keys regularly
- Use service role key only for admin operations

### Row Level Security
- Implement comprehensive RLS policies
- Test policies thoroughly
- Use least privilege principle
- Audit access patterns regularly

## Monitoring

### Application Metrics
- Connection pool usage
- Query performance
- Real-time subscription count
- Error rates and types

### Supabase Metrics
- Database performance (via Supabase dashboard)
- Authentication success/failure rates
- Storage usage
- Real-time connection count

## Backup and Recovery

### What's Backed Up
- Application logs
- Configuration files
- Custom code and assets

### What's NOT Backed Up (Managed by Supabase)
- Database data
- User authentication data
- File storage
- Real-time subscriptions

### Recovery Procedures
1. Restore application configuration
2. Verify Supabase connectivity
3. Test authentication flows
4. Validate real-time functionality

## Support

For deployment issues:
1. Run verification script: `./scripts/verify_deployment_supabase.sh`
2. Check application logs
3. Verify Supabase project status
4. Test connectivity manually
5. Review RLS policies and permissions

---

**Note**: This deployment uses Supabase as a managed backend service. Database operations, authentication, and real-time features are handled by Supabase infrastructure, eliminating the need for local database management.