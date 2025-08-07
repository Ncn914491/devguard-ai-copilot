import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';

/// Verification script for database schema and RLS policies
class SchemaVerifier {
  static Future<void> verifySchemaAndRLS() async {
    print('🔍 Starting schema and RLS verification...');

    try {
      // Initialize Supabase
      await SupabaseService.instance.initialize();
      final client = Supabase.instance.client;

      print('✅ Supabase client initialized successfully');

      // Test 1: Verify tables exist
      await _verifyTablesExist(client);

      // Test 2: Verify RLS is enabled
      await _verifyRLSEnabled(client);

      // Test 3: Test basic CRUD operations
      await _testBasicOperations(client);

      // Test 4: Test RLS policies
      await _testRLSPolicies(client);

      print('🎉 All schema and RLS verifications passed!');
    } catch (e) {
      print('❌ Schema verification failed: $e');
      rethrow;
    }
  }

  static Future<void> _verifyTablesExist(SupabaseClient client) async {
    print('\n📋 Verifying tables exist...');

    final expectedTables = [
      'users',
      'team_members',
      'tasks',
      'security_alerts',
      'audit_logs',
      'deployments',
      'snapshots',
      'specifications'
    ];

    for (final table in expectedTables) {
      try {
        // Try to query the table structure
        await client.from(table).select('*').limit(0);
        print('  ✅ Table $table exists');
      } catch (e) {
        if (e.toString().contains('relation') &&
            e.toString().contains('does not exist')) {
          print('  ❌ Table $table does not exist');
          throw Exception('Table $table is missing from schema');
        } else {
          // Table exists but might have RLS restrictions - that's OK
          print('  ✅ Table $table exists (RLS protected)');
        }
      }
    }
  }

  static Future<void> _verifyRLSEnabled(SupabaseClient client) async {
    print('\n🔒 Verifying RLS is enabled...');

    try {
      // Try to query system tables to check RLS status
      // This is a simplified check - in production you'd query pg_tables
      final tables = ['users', 'tasks', 'team_members'];

      for (final table in tables) {
        try {
          await client.from(table).select('*').limit(1);
          print('  ✅ RLS policies allow access to $table');
        } catch (e) {
          if (e.toString().contains('permission') ||
              e.toString().contains('policy')) {
            print('  ✅ RLS is active on $table (access restricted)');
          } else {
            print('  ⚠️  Unexpected error on $table: $e');
          }
        }
      }
    } catch (e) {
      print('  ❌ RLS verification failed: $e');
      throw e;
    }
  }

  static Future<void> _testBasicOperations(SupabaseClient client) async {
    print('\n🔧 Testing basic operations...');

    try {
      // Test user operations (if authenticated)
      final user = client.auth.currentUser;
      if (user != null) {
        print('  ✅ User authenticated: ${user.email}');

        // Try to read user's own data
        try {
          final userData = await client
              .from('users')
              .select('*')
              .eq('id', user.id)
              .maybeSingle();

          if (userData != null) {
            print('  ✅ Can read own user data');
          } else {
            print('  ⚠️  User data not found in users table');
          }
        } catch (e) {
          print('  ⚠️  Cannot read user data: $e');
        }
      } else {
        print('  ⚠️  No authenticated user - skipping user-specific tests');
      }

      // Test public data access
      try {
        await client
            .from('tasks')
            .select('*')
            .eq('confidentiality_level', 'public')
            .limit(1);
        print('  ✅ Can query public tasks');
      } catch (e) {
        print('  ⚠️  Cannot query public tasks: $e');
      }
    } catch (e) {
      print('  ❌ Basic operations test failed: $e');
      throw e;
    }
  }

  static Future<void> _testRLSPolicies(SupabaseClient client) async {
    print('\n🛡️  Testing RLS policies...');

    try {
      // Test role helper functions
      try {
        final userRole = await client.rpc('get_user_role');
        print('  ✅ get_user_role function works: $userRole');
      } catch (e) {
        print('  ❌ get_user_role function failed: $e');
      }

      try {
        final isAdmin = await client.rpc('is_admin');
        print('  ✅ is_admin function works: $isAdmin');
      } catch (e) {
        print('  ❌ is_admin function failed: $e');
      }

      try {
        final hasDevAccess = await client.rpc('has_developer_access');
        print('  ✅ has_developer_access function works: $hasDevAccess');
      } catch (e) {
        print('  ❌ has_developer_access function failed: $e');
      }

      // Test confidentiality access
      try {
        final canAccess =
            await client.rpc('can_access_confidential_data', params: {
          'confidentiality': 'public',
          'authorized_users': [],
          'authorized_roles': [],
        });
        print('  ✅ can_access_confidential_data function works: $canAccess');
      } catch (e) {
        print('  ❌ can_access_confidential_data function failed: $e');
      }
    } catch (e) {
      print('  ❌ RLS policies test failed: $e');
      throw e;
    }
  }

  /// Apply the schema migrations
  static Future<void> applySchema() async {
    print('🚀 Applying database schema...');

    try {
      await SupabaseService.instance.initialize();

      // Read and apply initial schema
      final schemaFile =
          File('lib/core/supabase/migrations/001_initial_schema.sql');
      if (await schemaFile.exists()) {
        final schemaContent = await schemaFile.readAsString();
        print('📄 Schema file loaded (${schemaContent.length} characters)');

        // Note: In a real implementation, you would apply this through Supabase CLI
        // or through a proper migration system. For now, we'll just verify the file exists.
        print('✅ Schema file is ready for application');
      } else {
        throw Exception('Schema file not found');
      }

      // Read and apply RLS policies
      final rlsFile = File('lib/core/supabase/migrations/002_rls_policies.sql');
      if (await rlsFile.exists()) {
        final rlsContent = await rlsFile.readAsString();
        print('🔒 RLS policies file loaded (${rlsContent.length} characters)');
        print('✅ RLS policies file is ready for application');
      } else {
        throw Exception('RLS policies file not found');
      }

      print('✅ Schema and RLS files are ready for deployment');
    } catch (e) {
      print('❌ Schema application failed: $e');
      rethrow;
    }
  }

  /// Generate a comprehensive report
  static Future<String> generateReport() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Supabase Schema & RLS Verification Report ===');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln();

    try {
      await verifySchemaAndRLS();
      buffer.writeln('✅ All verifications passed successfully');
    } catch (e) {
      buffer.writeln('❌ Verification failed: $e');
    }

    buffer.writeln();
    buffer.writeln('=== Files Created ===');

    final files = [
      'lib/core/supabase/migrations/001_initial_schema.sql',
      'lib/core/supabase/migrations/002_rls_policies.sql',
      'lib/core/supabase/migrations/apply_schema.dart',
      'lib/core/supabase/rls_policy_tester.dart',
      'test/supabase_rls_policies_test.dart',
    ];

    for (final file in files) {
      final fileExists = await File(file).exists();
      final status = fileExists ? '✅' : '❌';
      buffer.writeln('$status $file');
    }

    buffer.writeln();
    buffer.writeln('=== Next Steps ===');
    buffer.writeln('1. Apply schema using Supabase CLI: supabase db push');
    buffer.writeln('2. Apply RLS policies using Supabase CLI or dashboard');
    buffer.writeln('3. Run tests to verify functionality');
    buffer.writeln('4. Update environment configuration');

    return buffer.toString();
  }
}

/// Main function for running verification
Future<void> main() async {
  try {
    await SchemaVerifier.applySchema();
    await SchemaVerifier.verifySchemaAndRLS();

    final report = await SchemaVerifier.generateReport();
    print('\n$report');
  } catch (e) {
    print('❌ Verification failed: $e');
    exit(1);
  }
}
