# DevGuard AI Copilot - Supabase Troubleshooting Guide

This guide helps resolve common issues when using DevGuard AI Copilot with Supabase backend.

## Table of Contents

1. [Connection Issues](#connection-issues)
2. [Authentication Problems](#authentication-problems)
3. [Database Access Issues](#database-access-issues)
4. [Real-time Subscription Problems](#real-time-subscription-problems)
5. [Row-Level Security Issues](#row-level-security-issues)
6. [Performance Issues](#performance-issues)
7. [Migration Issues](#migration-issues)
8. [Environment Configuration](#environment-configuration)

## Connection Issues

### Problem: Cannot connect to Supabase

**Symptoms:**
- Application fails to start
- "Connection refused" errors
- Timeout errors

**Solutions:**

1. **Verify Environment Variables**
   ```bash
   # Check if variables are set
   echo $SUPABASE_URL
   echo $SUPABASE_ANON_KEY
   
   # Variables should look like:
   # SUPABASE_URL=https://your-project.supabase.co
   # SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

2. **Test Connectivity**
   ```bash
   curl -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/"
   ```

3. **Check Supabase Project Status**
   - Visit your Supabase dashboard
   - Ensure project is not paused
   - Check for any service outages

4. **Verify Network Access**
   ```bash
   # Test basic connectivity
   ping your-project.supabase.co
   
   # Test HTTPS access
   curl -I https://your-project.supabase.co
   ```

### Problem: SSL/TLS Certificate Issues

**Symptoms:**
- Certificate verification errors
- SSL handshake failures

**Solutions:**

1. **Update System Certificates**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update && sudo apt-get install ca-certificates
   
   # macOS
   brew install ca-certificates
   ```

2. **Check System Time**
   ```bash
   # Ensure system time is correct
   date
   sudo ntpdate -s time.nist.gov
   ```

## Authentication Problems

### Problem: Authentication fails with valid credentials

**Symptoms:**
- Login returns "Invalid credentials"
- OAuth redirects fail
- Token validation errors

**Solutions:**

1. **Check Auth Configuration**
   ```bash
   curl -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/auth/v1/settings"
   ```

2. **Verify Email Confirmation**
   - Check if email confirmation is required
   - Look for confirmation emails in spam folder
   - Disable email confirmation for testing

3. **OAuth Configuration**
   ```bash
   # Check GitHub OAuth settings in Supabase dashboard
   # Ensure redirect URLs match your application
   ```

4. **Test with Service Role Key**
   ```dart
   // For debugging, test with service role key
   final response = await supabase.auth.admin.listUsers();
   ```

### Problem: Token expires too quickly

**Symptoms:**
- Frequent re-authentication required
- "Token expired" errors

**Solutions:**

1. **Check Token Expiry Settings**
   - Visit Supabase dashboard → Authentication → Settings
   - Adjust JWT expiry time
   - Enable automatic token refresh

2. **Implement Token Refresh**
   ```dart
   // Ensure automatic refresh is enabled
   supabase.auth.onAuthStateChange.listen((data) {
     if (data.event == AuthChangeEvent.tokenRefreshed) {
       print('Token refreshed successfully');
     }
   });
   ```

## Database Access Issues

### Problem: "Permission denied" errors

**Symptoms:**
- Cannot read/write data
- RLS policy violations
- Access denied errors

**Solutions:**

1. **Check User Role**
   ```sql
   -- In Supabase SQL editor
   SELECT auth.uid(), auth.role();
   ```

2. **Verify RLS Policies**
   ```sql
   -- Check if RLS is enabled
   SELECT schemaname, tablename, rowsecurity 
   FROM pg_tables 
   WHERE schemaname = 'public';
   
   -- List RLS policies
   SELECT * FROM pg_policies WHERE schemaname = 'public';
   ```

3. **Test with Service Role**
   ```dart
   // Use service role for admin operations
   final supabaseAdmin = SupabaseClient(
     supabaseUrl,
     serviceRoleKey, // Use service role key
   );
   ```

### Problem: Data not appearing in queries

**Symptoms:**
- Empty result sets
- Missing records
- Inconsistent data

**Solutions:**

1. **Check RLS Policies**
   ```sql
   -- Temporarily disable RLS for testing
   ALTER TABLE your_table DISABLE ROW LEVEL SECURITY;
   
   -- Re-enable after testing
   ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;
   ```

2. **Verify Data Exists**
   ```sql
   -- Check raw data with service role
   SELECT * FROM your_table LIMIT 10;
   ```

3. **Debug RLS Policies**
   ```sql
   -- Check what auth.uid() returns
   SELECT auth.uid() as current_user_id;
   
   -- Test policy conditions
   SELECT * FROM your_table WHERE your_policy_condition;
   ```

## Real-time Subscription Problems

### Problem: Real-time updates not working

**Symptoms:**
- No live updates
- Subscription connection fails
- Events not received

**Solutions:**

1. **Check Real-time Configuration**
   ```bash
   curl -H "apikey: $SUPABASE_ANON_KEY" \
        "$SUPABASE_URL/realtime/v1/api/tenants/realtime/channels"
   ```

2. **Enable Real-time on Tables**
   ```sql
   -- Enable real-time for a table
   ALTER PUBLICATION supabase_realtime ADD TABLE your_table;
   ```

3. **Check Subscription Code**
   ```dart
   // Proper subscription setup
   final subscription = supabase
     .from('your_table')
     .stream(primaryKey: ['id'])
     .listen((data) {
       print('Real-time update: $data');
     });
   
   // Don't forget to cancel
   subscription.cancel();
   ```

4. **Verify Network Connection**
   ```dart
   // Check WebSocket connection
   supabase.realtime.onOpen(() {
     print('Real-time connection opened');
   });
   
   supabase.realtime.onClose((event) {
     print('Real-time connection closed: $event');
   });
   ```

### Problem: Too many real-time connections

**Symptoms:**
- Connection limit exceeded
- Performance degradation
- Memory leaks

**Solutions:**

1. **Implement Connection Management**
   ```dart
   class RealtimeManager {
     final Map<String, StreamSubscription> _subscriptions = {};
     
     void subscribe(String key, Stream stream) {
       // Cancel existing subscription
       _subscriptions[key]?.cancel();
       
       // Create new subscription
       _subscriptions[key] = stream.listen((data) {
         // Handle data
       });
     }
     
     void dispose() {
       for (final subscription in _subscriptions.values) {
         subscription.cancel();
       }
       _subscriptions.clear();
     }
   }
   ```

2. **Use Filters to Reduce Load**
   ```dart
   // Subscribe only to relevant data
   final subscription = supabase
     .from('tasks')
     .stream(primaryKey: ['id'])
     .eq('assignee_id', currentUserId)
     .listen((data) {
       // Handle filtered data
     });
   ```

## Row-Level Security Issues

### Problem: RLS policies too restrictive

**Symptoms:**
- Cannot access own data
- Admin users blocked
- Legitimate operations fail

**Solutions:**

1. **Review Policy Logic**
   ```sql
   -- Example: Allow users to access their own data
   CREATE POLICY "Users can access own data" ON users
     FOR ALL USING (auth.uid() = id);
   
   -- Example: Allow admins full access
   CREATE POLICY "Admins have full access" ON users
     FOR ALL USING (
       (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
     );
   ```

2. **Test Policies Step by Step**
   ```sql
   -- Test auth.uid()
   SELECT auth.uid();
   
   -- Test role lookup
   SELECT role FROM users WHERE id = auth.uid();
   
   -- Test full policy condition
   SELECT * FROM users WHERE auth.uid() = id;
   ```

3. **Use Policy Debugging**
   ```sql
   -- Enable statement logging
   SET log_statement = 'all';
   
   -- Check what queries are being executed
   ```

### Problem: RLS policies too permissive

**Symptoms:**
- Users see data they shouldn't
- Security vulnerabilities
- Data leaks

**Solutions:**

1. **Audit All Policies**
   ```sql
   -- List all policies
   SELECT 
     schemaname,
     tablename,
     policyname,
     permissive,
     roles,
     cmd,
     qual,
     with_check
   FROM pg_policies 
   WHERE schemaname = 'public';
   ```

2. **Test with Different User Roles**
   ```dart
   // Test as different users
   final testUsers = ['admin', 'developer', 'viewer'];
   
   for (final role in testUsers) {
     // Switch user context and test access
   }
   ```

3. **Implement Least Privilege**
   ```sql
   -- Start restrictive and add permissions as needed
   CREATE POLICY "Deny all by default" ON sensitive_table
     FOR ALL USING (false);
   
   -- Add specific permissions
   CREATE POLICY "Allow admin access" ON sensitive_table
     FOR ALL USING (
       (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
     );
   ```

## Performance Issues

### Problem: Slow query performance

**Symptoms:**
- Long response times
- Timeouts
- High CPU usage

**Solutions:**

1. **Add Database Indexes**
   ```sql
   -- Add indexes on frequently queried columns
   CREATE INDEX idx_tasks_assignee ON tasks(assignee_id);
   CREATE INDEX idx_tasks_status ON tasks(status);
   CREATE INDEX idx_tasks_created_at ON tasks(created_at);
   ```

2. **Optimize Queries**
   ```dart
   // Use select() to limit columns
   final data = await supabase
     .from('tasks')
     .select('id, title, status')
     .eq('assignee_id', userId);
   
   // Use pagination
   final data = await supabase
     .from('tasks')
     .select()
     .range(0, 19); // First 20 records
   ```

3. **Implement Caching**
   ```dart
   class CacheService {
     final Map<String, CacheEntry> _cache = {};
     
     Future<T?> get<T>(String key) async {
       final entry = _cache[key];
       if (entry != null && !entry.isExpired) {
         return entry.data as T;
       }
       return null;
     }
     
     void set<T>(String key, T data, Duration ttl) {
       _cache[key] = CacheEntry(data, DateTime.now().add(ttl));
     }
   }
   ```

### Problem: High memory usage

**Symptoms:**
- Application crashes
- Out of memory errors
- Slow performance

**Solutions:**

1. **Implement Pagination**
   ```dart
   // Load data in chunks
   Future<List<Task>> loadTasks(int page, int pageSize) async {
     final start = page * pageSize;
     final end = start + pageSize - 1;
     
     return await supabase
       .from('tasks')
       .select()
       .range(start, end);
   }
   ```

2. **Clean Up Subscriptions**
   ```dart
   @override
   void dispose() {
     // Cancel all subscriptions
     _subscription?.cancel();
     super.dispose();
   }
   ```

## Migration Issues

### Problem: Data migration fails

**Symptoms:**
- Migration script errors
- Data corruption
- Incomplete migration

**Solutions:**

1. **Run Migration Verification**
   ```bash
   dart run lib/core/supabase/migrations/migration_verification_service.dart
   ```

2. **Check Migration Logs**
   ```bash
   # Check application logs
   tail -f logs/migration.log
   
   # Check for specific errors
   grep -i error logs/migration.log
   ```

3. **Manual Data Verification**
   ```sql
   -- Compare record counts
   SELECT 'users' as table_name, COUNT(*) as count FROM users
   UNION ALL
   SELECT 'tasks' as table_name, COUNT(*) as count FROM tasks;
   ```

4. **Rollback if Necessary**
   ```bash
   dart run lib/core/supabase/migrations/migration_rollback_service.dart
   ```

## Environment Configuration

### Problem: Environment variables not loading

**Symptoms:**
- Configuration errors
- Default values used
- Connection failures

**Solutions:**

1. **Check File Location**
   ```bash
   # Ensure .env file exists in project root
   ls -la .env
   
   # Check file contents
   cat .env
   ```

2. **Verify Loading Code**
   ```dart
   import 'package:flutter_dotenv/flutter_dotenv.dart';
   
   Future<void> main() async {
     // Load environment variables
     await dotenv.load(fileName: '.env');
     
     // Verify loading
     print('SUPABASE_URL: ${dotenv.env['SUPABASE_URL']}');
   }
   ```

3. **Check for Syntax Errors**
   ```bash
   # Environment file format
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-key-here
   # No spaces around = sign
   # No quotes unless needed
   ```

## Diagnostic Commands

### Quick Health Check
```bash
#!/bin/bash
echo "🔍 DevGuard AI Copilot - Supabase Health Check"

# Check environment variables
echo "Environment Variables:"
echo "SUPABASE_URL: ${SUPABASE_URL:0:30}..."
echo "SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."

# Test Supabase connectivity
echo -e "\nTesting Supabase connectivity..."
curl -s -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/" > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Supabase REST API accessible"
else
    echo "❌ Supabase REST API not accessible"
fi

# Test authentication endpoint
curl -s -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/auth/v1/settings" > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Supabase Auth accessible"
else
    echo "❌ Supabase Auth not accessible"
fi

# Test application health
curl -s http://localhost:8080/health > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Application health check passed"
else
    echo "❌ Application health check failed"
fi
```

### Database Schema Check
```sql
-- Run in Supabase SQL editor
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;
```

### RLS Policy Audit
```sql
-- Check all RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

## Getting Help

If you're still experiencing issues:

1. **Check Application Logs**
   ```bash
   tail -f logs/app.log
   ```

2. **Enable Debug Mode**
   ```dart
   // Add to main.dart
   Logger.root.level = Level.ALL;
   ```

3. **Run Verification Script**
   ```bash
   ./scripts/verify_deployment_supabase.sh
   ```

4. **Contact Support**
   - Include error messages
   - Provide configuration (without sensitive keys)
   - Share relevant log entries
   - Describe steps to reproduce

---

**Remember**: Never share your actual Supabase keys in support requests. Use placeholder values or redacted keys.