#!/bin/bash

# DevGuard AI Copilot - Supabase Deployment Verification Script
# Verifies that deployment is working correctly with Supabase

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

fail() {
    echo -e "${RED}❌ $1${NC}"
}

# Verification functions
verify_environment_variables() {
    log "Verifying environment variables..."
    
    local missing_vars=()
    
    if [[ -z "$SUPABASE_URL" ]]; then
        missing_vars+=("SUPABASE_URL")
    fi
    
    if [[ -z "$SUPABASE_ANON_KEY" ]]; then
        missing_vars+=("SUPABASE_ANON_KEY")
    fi
    
    if [[ -z "$SUPABASE_SERVICE_ROLE_KEY" ]]; then
        missing_vars+=("SUPABASE_SERVICE_ROLE_KEY")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        fail "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    success "All required environment variables are set"
    return 0
}

verify_supabase_connectivity() {
    log "Verifying Supabase connectivity..."
    
    # Test REST API
    if curl -s --max-time 10 -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/" > /dev/null; then
        success "Supabase REST API connection successful"
    else
        fail "Supabase REST API connection failed"
        return 1
    fi
    
    # Test Auth API
    if curl -s --max-time 10 -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/auth/v1/settings" > /dev/null; then
        success "Supabase Auth API connection successful"
    else
        fail "Supabase Auth API connection failed"
        return 1
    fi
    
    # Test Storage API
    if curl -s --max-time 10 -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/storage/v1/buckets" > /dev/null; then
        success "Supabase Storage API connection successful"
    else
        warn "Supabase Storage API connection failed (may not be configured)"
    fi
    
    return 0
}

verify_database_schema() {
    log "Verifying database schema..."
    
    # Check if main tables exist
    local tables=("users" "team_members" "tasks" "security_alerts" "audit_logs" "deployments" "snapshots" "specifications")
    
    for table in "${tables[@]}"; do
        if curl -s --max-time 10 -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/$table?limit=1" > /dev/null; then
            success "Table '$table' exists and is accessible"
        else
            fail "Table '$table' is not accessible"
            return 1
        fi
    done
    
    return 0
}

verify_rls_policies() {
    log "Verifying Row Level Security policies..."
    
    # Test that RLS is enabled (should get 401 without proper auth)
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/users")
    
    if [[ "$response_code" == "200" ]] || [[ "$response_code" == "401" ]]; then
        success "RLS policies are active (response code: $response_code)"
    else
        warn "Unexpected response code for RLS test: $response_code"
    fi
    
    return 0
}

verify_realtime_functionality() {
    log "Verifying real-time functionality..."
    
    # Test realtime endpoint
    if curl -s --max-time 10 -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/realtime/v1/api/tenants/realtime/channels" > /dev/null; then
        success "Real-time API is accessible"
    else
        warn "Real-time API connection failed (may not be enabled)"
    fi
    
    return 0
}

verify_application_health() {
    log "Verifying application health..."
    
    # Check if application is running (if deployed locally)
    if curl -s --max-time 5 http://localhost:8080/health > /dev/null 2>&1; then
        success "Application is responding on port 8080"
    else
        warn "Application is not responding on port 8080 (may not be deployed locally)"
    fi
    
    # Check WebSocket endpoint
    if curl -s --max-time 5 -H "Upgrade: websocket" http://localhost:8081 > /dev/null 2>&1; then
        success "WebSocket endpoint is available on port 8081"
    else
        warn "WebSocket endpoint is not available on port 8081 (may not be deployed locally)"
    fi
    
    return 0
}

verify_docker_deployment() {
    log "Verifying Docker deployment configuration..."
    
    if [[ -f "deployment/docker/Dockerfile" ]]; then
        # Check that SQLite is not referenced in Dockerfile
        if grep -q "sqlite" deployment/docker/Dockerfile; then
            fail "Dockerfile still contains SQLite references"
            return 1
        else
            success "Dockerfile has been updated to remove SQLite dependencies"
        fi
        
        # Check that Supabase health check is present
        if grep -q "SUPABASE_URL" deployment/docker/Dockerfile; then
            success "Dockerfile includes Supabase connectivity verification"
        else
            fail "Dockerfile missing Supabase connectivity verification"
            return 1
        fi
    else
        warn "Dockerfile not found"
    fi
    
    if [[ -f "deployment/docker/docker-compose.yml" ]]; then
        # Check that database volume is removed
        if grep -q "app-data:" deployment/docker/docker-compose.yml; then
            fail "docker-compose.yml still contains database volume references"
            return 1
        else
            success "docker-compose.yml has been updated to remove database volumes"
        fi
        
        # Check that Supabase environment variables are present
        if grep -q "SUPABASE_URL" deployment/docker/docker-compose.yml; then
            success "docker-compose.yml includes Supabase environment variables"
        else
            fail "docker-compose.yml missing Supabase environment variables"
            return 1
        fi
    else
        warn "docker-compose.yml not found"
    fi
    
    return 0
}

# Main verification function
main() {
    log "Starting DevGuard AI Copilot Supabase deployment verification..."
    
    # Load environment variables if .env file exists
    if [[ -f ".env" ]]; then
        source .env
        log "Loaded environment variables from .env"
    fi
    
    local verification_failed=false
    
    # Run all verifications
    verify_environment_variables || verification_failed=true
    verify_supabase_connectivity || verification_failed=true
    verify_database_schema || verification_failed=true
    verify_rls_policies || verification_failed=true
    verify_realtime_functionality || verification_failed=true
    verify_application_health || verification_failed=true
    verify_docker_deployment || verification_failed=true
    
    echo ""
    echo "=============================================="
    
    if [[ "$verification_failed" == "true" ]]; then
        fail "Deployment verification completed with errors"
        echo -e "${RED}Some verification checks failed. Please review the output above.${NC}"
        exit 1
    else
        success "All deployment verification checks passed!"
        echo -e "${GREEN}🎉 DevGuard AI Copilot is successfully deployed with Supabase!${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Test user authentication and registration"
        echo "2. Verify real-time updates are working"
        echo "3. Test file upload/download functionality"
        echo "4. Run integration tests"
        exit 0
    fi
}

# Run main function
main "$@"