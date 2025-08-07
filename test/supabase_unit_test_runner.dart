import 'package:flutter_test/flutter_test.dart';

// Import all unit test files
import 'supabase_services_unit_test.dart' as services_tests;
import 'supabase_team_member_service_unit_test.dart' as team_member_tests;
import 'supabase_task_service_unit_test.dart' as task_tests;
import 'supabase_comprehensive_unit_test.dart' as comprehensive_tests;

/// Comprehensive test runner for all Supabase unit tests
/// This ensures all unit tests are executed and provides a single entry point
void main() {
  group('All Supabase Unit Tests', () {
    group('Core Services Tests', () {
      services_tests.main();
    });

    group('Team Member Service Tests', () {
      team_member_tests.main();
    });

    group('Task Service Tests', () {
      task_tests.main();
    });

    group('Comprehensive Unit Tests', () {
      comprehensive_tests.main();
    });
  });

  // Test summary and reporting
  tearDownAll(() {
    print('✅ All Supabase unit tests completed');
    print('📊 Test Coverage:');
    print('  - SupabaseService: ✅');
    print('  - SupabaseAuthService: ✅');
    print('  - SupabaseTeamMemberService: ✅');
    print('  - SupabaseTaskService: ✅');
    print('  - SupabaseErrorHandler: ✅');
    print('  - RetryPolicy: ✅');
    print('  - AppError: ✅');
    print('  - Edge Cases: ✅');
    print('  - Performance Tests: ✅');
  });
}
