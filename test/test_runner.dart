import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Import all test files
import 'admin_signup_test.dart' as admin_signup_test;
import 'audit_logging_test.dart' as audit_logging_test;
import 'auth_service_test.dart' as auth_service_test;
import 'copilot_integration_test.dart' as copilot_integration_test;
import 'copilot_sidebar_test.dart' as copilot_sidebar_test;
import 'database_test.dart' as database_test;
import 'deployment_pipeline_test.dart' as deployment_pipeline_test;
import 'devops_integration_test.dart' as devops_integration_test;
import 'email_service_test.dart' as email_service_test;
import 'error_handling_test.dart' as error_handling_test;
import 'gemini_service_test.dart' as gemini_service_test;
import 'github_integration_test.dart' as github_integration_test;
import 'notification_service_test.dart' as notification_service_test;
import 'onboarding_integration_test.dart' as onboarding_integration_test;
import 'onboarding_system_test.dart' as onboarding_system_test;
import 'performance_optimization_test.dart' as performance_optimization_test;
import 'project_service_test.dart' as project_service_test;
import 'real_time_communication_test.dart' as real_time_communication_test;
import 'rollback_integration_test.dart' as rollback_integration_test;
import 'security_alert_integration_test.dart'
    as security_alert_integration_test;
import 'security_copilot_integration_test.dart'
    as security_copilot_integration_test;
import 'security_monitor_test.dart' as security_monitor_test;
import 'security_monitoring_test.dart' as security_monitoring_test;
import 'security_workflow_integration_test.dart'
    as security_workflow_integration_test;
import 'spec_workflow_test.dart' as spec_workflow_test;
import 'system_health_monitor_test.dart' as system_health_monitor_test;
import 'task_management_test.dart' as task_management_test;
import 'websocket_service_test.dart' as websocket_service_test;
import 'widget_test.dart' as widget_test;

// Import new comprehensive test suites
import 'integration/comprehensive_integration_test.dart'
    as comprehensive_integration_test;
import 'integration/end_to_end_workflow_test.dart' as end_to_end_workflow_test;
import 'performance/performance_test_suite.dart' as performance_test_suite;

void main() {
  // Initialize SQLite FFI for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DevGuard AI Copilot - Complete Test Suite', () {
    group('Authentication & Authorization Tests', () {
      admin_signup_test.main();
      auth_service_test.main();
    });

    group('Database & Data Management Tests', () {
      database_test.main();
      audit_logging_test.main();
      task_management_test.main();
      spec_workflow_test.main();
    });

    group('AI & Copilot Integration Tests', () {
      copilot_integration_test.main();
      copilot_sidebar_test.main();
      gemini_service_test.main();
    });

    group('DevOps & Deployment Tests', () {
      devops_integration_test.main();
      deployment_pipeline_test.main();
      rollback_integration_test.main();
      github_integration_test.main();
    });

    group('Security & Monitoring Tests', () {
      security_monitor_test.main();
      security_monitoring_test.main();
      security_alert_integration_test.main();
      security_copilot_integration_test.main();
      security_workflow_integration_test.main();
      system_health_monitor_test.main();
    });

    group('Communication & Notification Tests', () {
      real_time_communication_test.main();
      websocket_service_test.main();
      notification_service_test.main();
      email_service_test.main();
    });

    group('Onboarding & User Management Tests', () {
      onboarding_integration_test.main();
      onboarding_system_test.main();
      project_service_test.main();
    });

    group('Error Handling & System Tests', () {
      error_handling_test.main();
      performance_optimization_test.main();
      widget_test.main();
    });
  });

  // Run comprehensive integration tests
  group('Comprehensive Integration Tests', () {
    comprehensive_integration_test.main();
  });

  // Run end-to-end workflow tests
  group('End-to-End Workflow Tests', () {
    end_to_end_workflow_test.main();
  });

  // Run performance tests
  group('Performance Test Suite', () {
    performance_test_suite.main();
  });
}

/// Test configuration and utilities
class TestConfig {
  static const String testDatabasePath = ':memory:';
  static const Duration testTimeout = Duration(seconds: 30);

  static Map<String, dynamic> getTestEnvironment() {
    return {
      'environment': 'test',
      'database': testDatabasePath,
      'enableLogging': false,
      'mockExternalServices': true,
    };
  }
}

/// Test utilities for common setup and teardown
class TestUtils {
  static Future<void> setupTestDatabase() async {
    // Initialize test database with schema
    final db = await databaseFactory.openDatabase(TestConfig.testDatabasePath);

    // Run migrations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS test_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.close();
  }

  static Future<void> cleanupTestDatabase() async {
    // Clean up test data
    final db = await databaseFactory.openDatabase(TestConfig.testDatabasePath);
    await db.execute('DELETE FROM test_data');
    await db.close();
  }

  static Map<String, dynamic> createMockUser({
    String? id,
    String? email,
    String? role,
  }) {
    return {
      'id': id ?? 'test-user-123',
      'email': email ?? 'test@example.com',
      'role': role ?? 'developer',
      'name': 'Test User',
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> createMockProject({
    String? id,
    String? name,
  }) {
    return {
      'id': id ?? 'test-project-123',
      'name': name ?? 'Test Project',
      'description': 'Test project description',
      'adminEmail': 'admin@example.com',
      'createdAt': DateTime.now().toIso8601String(),
      'isActive': true,
    };
  }
}
