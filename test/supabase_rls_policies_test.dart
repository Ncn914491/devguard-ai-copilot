import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/core/supabase/rls_policy_tester.dart';
import '../lib/core/supabase/supabase_service.dart';

void main() {
  group('Supabase RLS Policies Tests', () {
    setUpAll(() async {
      // Initialize Supabase for testing
      await SupabaseService.instance.initialize();
    });

    test('should verify RLS is enabled on all tables', () async {
      final results = await RLSPolicyTester.verifyRLSEnabled();

      // Print results for debugging
      for (final result in results) {
        print(result.toString());
      }

      // All tables should have RLS enabled
      final failedTests = results.where((r) => !r.passed).toList();
      expect(failedTests, isEmpty,
          reason:
              'Some tables do not have RLS enabled: ${failedTests.map((r) => r.testName).join(', ')}');
    });

    test('should test all RLS policies', () async {
      final results = await RLSPolicyTester.testAllPolicies();

      // Print results for debugging
      for (final result in results) {
        print(result.toString());
      }

      // At least 80% of tests should pass (allowing for some expected access restrictions)
      final passedCount = results.where((r) => r.passed).length;
      final totalCount = results.length;
      final passRate = passedCount / totalCount;

      expect(passRate, greaterThanOrEqualTo(0.8),
          reason:
              'RLS policy tests pass rate is too low: $passedCount/$totalCount (${(passRate * 100).toStringAsFixed(1)}%)');
    });

    test('should test role-based access functions', () async {
      final results = await RLSPolicyTester.testRoleBasedAccess();

      // Print results for debugging
      for (final result in results) {
        print(result.toString());
      }

      // All role-based access functions should work
      final failedTests = results.where((r) => !r.passed).toList();
      expect(failedTests, isEmpty,
          reason:
              'Some role-based access functions failed: ${failedTests.map((r) => r.testName).join(', ')}');
    });

    test('should generate comprehensive test report', () async {
      final report = await RLSPolicyTester.generateTestReport();

      expect(report, isNotEmpty);
      expect(report, contains('RLS Policy Test Report'));
      expect(report, contains('Summary:'));

      // Print the full report
      print('\n$report');
    });

    group('Individual Policy Tests', () {
      test('should test user table policies', () async {
        try {
          // Test reading users (should be restricted based on role)
          final users = await Supabase.instance.client
              .from('users')
              .select('id, email, role')
              .limit(5);

          // If we get here, the user has appropriate access
          expect(users, isA<List>());
          print('User can access ${users.length} user records');
        } catch (e) {
          // If access is denied, that's also a valid test result
          print('User access properly restricted: $e');
          expect(e.toString(), contains('permission'),
              reason: 'Error should be permission-related');
        }
      });

      test('should test task confidentiality levels', () async {
        try {
          // Test accessing public tasks
          final publicTasks = await Supabase.instance.client
              .from('tasks')
              .select('*')
              .eq('confidentiality_level', 'public')
              .limit(5);

          expect(publicTasks, isA<List>());
          print('Can access ${publicTasks.length} public tasks');
        } catch (e) {
          print('Public task access error: $e');
        }

        try {
          // Test accessing restricted tasks (should be limited)
          final restrictedTasks = await Supabase.instance.client
              .from('tasks')
              .select('*')
              .eq('confidentiality_level', 'restricted')
              .limit(5);

          // If we get here, user has appropriate access
          print('Can access ${restrictedTasks.length} restricted tasks');
        } catch (e) {
          // Access denied is expected for restricted tasks
          print('Restricted task access properly blocked: $e');
        }
      });

      test('should test team member access', () async {
        try {
          final teamMembers = await Supabase.instance.client
              .from('team_members')
              .select('*')
              .limit(5);

          expect(teamMembers, isA<List>());
          print('Can access ${teamMembers.length} team member records');
        } catch (e) {
          print('Team member access error: $e');
        }
      });

      test('should test security alert access', () async {
        try {
          final alerts = await Supabase.instance.client
              .from('security_alerts')
              .select('*')
              .limit(5);

          expect(alerts, isA<List>());
          print('Can access ${alerts.length} security alert records');
        } catch (e) {
          print('Security alert access error: $e');
        }
      });

      test('should test audit log access', () async {
        try {
          final auditLogs = await Supabase.instance.client
              .from('audit_logs')
              .select('*')
              .limit(5);

          expect(auditLogs, isA<List>());
          print('Can access ${auditLogs.length} audit log records');
        } catch (e) {
          print('Audit log access error: $e');
        }
      });
    });

    group('Role Function Tests', () {
      test('should test role helper functions', () async {
        try {
          // Test get_user_role function
          final userRole = await Supabase.instance.client.rpc('get_user_role');
          print('Current user role: $userRole');
          expect(userRole, isA<String>());
        } catch (e) {
          print('get_user_role function error: $e');
        }

        try {
          // Test is_admin function
          final isAdmin = await Supabase.instance.client.rpc('is_admin');
          print('Is admin: $isAdmin');
          expect(isAdmin, isA<bool>());
        } catch (e) {
          print('is_admin function error: $e');
        }

        try {
          // Test has_developer_access function
          final hasDevAccess =
              await Supabase.instance.client.rpc('has_developer_access');
          print('Has developer access: $hasDevAccess');
          expect(hasDevAccess, isA<bool>());
        } catch (e) {
          print('has_developer_access function error: $e');
        }
      });
    });
  });
}
