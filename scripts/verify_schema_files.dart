import 'dart:io';

/// Simple script to verify that all required schema files exist and are properly formatted
Future<void> main() async {
  print('🔍 Verifying Supabase schema files...');

  final results = <String, bool>{};

  // Check required files
  final requiredFiles = [
    'lib/core/supabase/migrations/001_initial_schema.sql',
    'lib/core/supabase/migrations/002_rls_policies.sql',
    'lib/core/supabase/migrations/apply_schema.dart',
    'lib/core/supabase/rls_policy_tester.dart',
    'test/supabase_rls_policies_test.dart',
    'lib/core/supabase/migrations/verify_schema.dart',
  ];

  for (final filePath in requiredFiles) {
    final file = File(filePath);
    final exists = await file.exists();
    results[filePath] = exists;

    if (exists) {
      final content = await file.readAsString();
      final size = content.length;
      print('✅ $filePath (${size} characters)');

      // Basic content validation
      if (filePath.endsWith('.sql')) {
        if (content.contains('CREATE TABLE') &&
            content.contains('CREATE POLICY')) {
          print('   📋 Contains table and policy definitions');
        } else if (content.contains('CREATE TABLE')) {
          print('   📋 Contains table definitions');
        } else if (content.contains('CREATE POLICY')) {
          print('   🔒 Contains RLS policy definitions');
        }
      } else if (filePath.endsWith('.dart')) {
        if (content.contains('class ') && content.contains('Future<')) {
          print('   💻 Contains Dart class and async methods');
        }
      }
    } else {
      print('❌ $filePath (missing)');
    }
  }

  // Check schema content
  print('\n📋 Verifying schema content...');

  final schemaFile =
      File('lib/core/supabase/migrations/001_initial_schema.sql');
  if (await schemaFile.exists()) {
    final content = await schemaFile.readAsString();

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
      if (content.contains('CREATE TABLE $table')) {
        print('✅ Table $table defined');
      } else {
        print('❌ Table $table missing');
      }
    }

    // Check for RLS enablement
    if (content.contains('ENABLE ROW LEVEL SECURITY')) {
      print('✅ RLS enabled on tables');
    } else {
      print('❌ RLS not enabled');
    }
  }

  // Check RLS policies content
  print('\n🔒 Verifying RLS policies content...');

  final rlsFile = File('lib/core/supabase/migrations/002_rls_policies.sql');
  if (await rlsFile.exists()) {
    final content = await rlsFile.readAsString();

    final expectedPolicies = [
      'users_select_policy',
      'tasks_select_policy',
      'security_alerts_select_policy',
      'audit_logs_select_policy',
    ];

    for (final policy in expectedPolicies) {
      if (content.contains(policy)) {
        print('✅ Policy $policy defined');
      } else {
        print('⚠️  Policy $policy not found (may use different naming)');
      }
    }

    // Check for helper functions
    final helperFunctions = [
      'get_user_role',
      'is_admin',
      'has_developer_access',
      'can_access_confidential_data',
    ];

    for (final func in helperFunctions) {
      if (content.contains('FUNCTION $func')) {
        print('✅ Helper function $func defined');
      } else {
        print('❌ Helper function $func missing');
      }
    }
  }

  // Summary
  print('\n📊 Summary:');
  final totalFiles = requiredFiles.length;
  final existingFiles = results.values.where((exists) => exists).length;

  print('Files created: $existingFiles/$totalFiles');

  if (existingFiles == totalFiles) {
    print('🎉 All required files are present!');

    print('\n📝 Next steps:');
    print('1. Apply schema to Supabase: supabase db push');
    print('2. Apply RLS policies through Supabase dashboard or CLI');
    print('3. Test the implementation with actual Supabase instance');
    print('4. Update environment configuration if needed');

    exit(0);
  } else {
    print('❌ Some files are missing. Task is not complete.');
    exit(1);
  }
}
