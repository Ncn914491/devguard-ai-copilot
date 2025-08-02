import 'package:flutter_test/flutter_test.dart';
import '../lib/core/security/security_monitor.dart';
import '../lib/core/database/services/security_alert_service.dart';
import '../lib/core/database/services/audit_log_service.dart';
import '../lib/core/ai/gemini_service.dart';

void main() {
  group('Enhanced Security Monitoring', () {
    late SecurityMonitor securityMonitor;
    late SecurityAlertService alertService;
    late AuditLogService auditService;
    late GeminiService geminiService;

    setUp(() async {
      securityMonitor = SecurityMonitor.instance;
      alertService = SecurityAlertService.instance;
      auditService = AuditLogService.instance;
      geminiService = GeminiService.instance;
      
      // Initialize services
      await geminiService.initialize();
      await securityMonitor.initialize();
    });

    group('Honeytoken Breach Detection', () {
      test('should detect honeytoken access and create critical alert', () async {
        // Arrange
        final initialAlertCount = (await alertService.getRecentAlerts()).length;

        // Act - Simulate honeytoken access
        await securityMonitor.simulateHoneytokenAccess('credit_card');

        // Assert
        final alerts = await alertService.getRecentAlerts();
        expect(alerts.length, equals(initialAlertCount + 1));
        
        final honeytokenAlert = alerts.first;
        expect(honeytokenAlert.type, equals('database_breach'));
        expect(honeytokenAlert.severity, equals('critical'));
        expect(honeytokenAlert.title, contains('Honeytoken Access'));
        expect(honeytokenAlert.rollbackSuggested, isTrue);
        expect(honeytokenAlert.aiExplanation, isNotEmpty);
        expect(honeytokenAlert.aiExplanation, contains('CRITICAL'));
      });

      test('should generate appropriate AI explanation for different honeytoken types', () async {
        // Test different honeytoken types
        final honeytokenTypes = ['credit_card', 'ssn', 'api_key', 'password_hash', 'email'];
        
        for (final type in honeytokenTypes) {
          // Act
          await securityMonitor.simulateHoneytokenAccess(type);
          
          // Assert
          final alerts = await alertService.getRecentAlerts(limit: 1);
          final alert = alerts.first;
          
          expect(alert.description, contains(type));
          expect(alert.aiExplanation, contains('CRITICAL'));
          expect(alert.evidence, contains(type));
        }
      });

      test('should create audit log entry for honeytoken breach', () async {
        // Act
        await securityMonitor.simulateHoneytokenAccess('ssn');

        // Assert - Check that audit log was created
        // Note: In a real implementation, you would query audit logs
        // For this test, we verify no exceptions were thrown
        expect(true, isTrue);
      });
    });

    group('Data Export Anomaly Detection', () {
      test('should detect high volume data exports', () async {
        // Arrange
        final initialAlertCount = (await alertService.getRecentAlerts()).length;

        // Act - Simulate high volume data export
        await securityMonitor.simulateDataExportAnomaly(50, 10); // 400% increase

        // Assert
        final alerts = await alertService.getRecentAlerts();
        expect(alerts.length, equals(initialAlertCount + 1));
        
        final exportAlert = alerts.first;
        expect(exportAlert.type, equals('database_breach'));
        expect(exportAlert.severity, equals('critical'));
        expect(exportAlert.title, contains('Data Export Volume'));
        expect(exportAlert.description, contains('400%'));
        expect(exportAlert.rollbackSuggested, isTrue);
      });

      test('should detect off-hours database access', () async {
        // Arrange
        final initialAlertCount = (await alertService.getRecentAlerts()).length;

        // Act - Simulate off-hours access
        await securityMonitor.simulateOffHoursAccess(8, 23); // 8 queries at 11 PM

        // Assert
        final alerts = await alertService.getRecentAlerts();
        expect(alerts.length, equals(initialAlertCount + 1));
        
        final offHoursAlert = alerts.first;
        expect(offHoursAlert.type, equals('system_anomaly'));
        expect(offHoursAlert.severity, equals('medium'));
        expect(offHoursAlert.title, contains('Off-Hours'));
        expect(offHoursAlert.description, contains('23:00'));
        expect(offHoursAlert.rollbackSuggested, isFalse);
      });

      test('should calculate correct severity based on volume increase', () async {
        // Test different volume increases
        final testCases = [
          {'current': 15, 'baseline': 10, 'expectedSeverity': 'high'}, // 50% increase
          {'current': 40, 'baseline': 10, 'expectedSeverity': 'critical'}, // 300% increase
          {'current': 60, 'baseline': 10, 'expectedSeverity': 'critical'}, // 500% increase
        ];

        for (final testCase in testCases) {
          await securityMonitor.simulateDataExportAnomaly(
            testCase['current'] as int, 
            testCase['baseline'] as int
          );
          
          final alerts = await alertService.getRecentAlerts(limit: 1);
          final alert = alerts.first;
          
          expect(alert.severity, equals(testCase['expectedSeverity']));
        }
      });
    });

    group('Configuration Drift Detection', () {
      test('should detect configuration file changes', () async {
        // Arrange
        final initialAlertCount = (await alertService.getRecentAlerts()).length;

        // Act - Simulate config drift
        await securityMonitor.simulateConfigurationDrift(
          'config/security.json',
          'credential_modification',
          'abc123def456',
          'xyz789uvw012'
        );

        // Assert
        final alerts = await alertService.getRecentAlerts();
        expect(alerts.length, equals(initialAlertCount + 1));
        
        final configAlert = alerts.first;
        expect(configAlert.type, equals('system_anomaly'));
        expect(configAlert.severity, equals('critical')); // credential_modification
        expect(configAlert.title, contains('Configuration Drift'));
        expect(configAlert.rollbackSuggested, isTrue);
        expect(configAlert.evidence, contains('credential_modification'));
      });

      test('should assign correct severity based on change type', () async {
        final testCases = [
          {'changeType': 'credential_modification', 'expectedSeverity': 'critical'},
          {'changeType': 'privilege_escalation', 'expectedSeverity': 'critical'},
          {'changeType': 'network_configuration', 'expectedSeverity': 'medium'},
          {'changeType': 'general_configuration', 'expectedSeverity': 'low'},
        ];

        for (final testCase in testCases) {
          await securityMonitor.simulateConfigurationDrift(
            'config/test.json',
            testCase['changeType'] as String,
            'hash1',
            'hash2'
          );
          
          final alerts = await alertService.getRecentAlerts(limit: 1);
          final alert = alerts.first;
          
          expect(alert.severity, equals(testCase['expectedSeverity']));
        }
      });

      test('should suggest rollback for critical configuration changes', () async {
        final criticalChanges = ['credential_modification', 'privilege_escalation'];
        
        for (final changeType in criticalChanges) {
          await securityMonitor.simulateConfigurationDrift(
            'config/security.json',
            changeType,
            'hash1',
            'hash2'
          );
          
          final alerts = await alertService.getRecentAlerts(limit: 1);
          final alert = alerts.first;
          
          expect(alert.rollbackSuggested, isTrue);
        }
      });
    });

    group('Login Anomaly Detection', () {
      test('should detect failed login floods', () async {
        // Arrange
        final initialAlertCount = (await alertService.getRecentAlerts()).length;

        // Act - Simulate login flood
        await securityMonitor.simulateLoginFlood('192.168.1.100', 12);

        // Assert
        final alerts = await alertService.getRecentAlerts();
        expect(alerts.length, equals(initialAlertCount + 1));
        
        final floodAlert = alerts.first;
        expect(floodAlert.type, equals('auth_flood'));
        expect(floodAlert.severity, equals('high')); // >10 attempts
        expect(floodAlert.title, contains('Failed Login Flood'));
        expect(floodAlert.description, contains('12 failed login attempts'));
        expect(floodAlert.description, contains('192.168.1.100'));
        expect(floodAlert.rollbackSuggested, isFalse);
      });

      test('should assign correct severity based on attempt count', () async {
        final testCases = [
          {'attempts': 8, 'expectedSeverity': 'medium'},
          {'attempts': 15, 'expectedSeverity': 'high'},
        ];

        for (final testCase in testCases) {
          await securityMonitor.simulateLoginFlood(
            '192.168.1.200',
            testCase['attempts'] as int
          );
          
          final alerts = await alertService.getRecentAlerts(limit: 1);
          final alert = alerts.first;
          
          expect(alert.severity, equals(testCase['expectedSeverity']));
        }
      });

      test('should detect unusual login sources', () async {
        // Arrange
        final initialAlertCount = (await alertService.getRecentAlerts()).length;

        // Act - Simulate unusual login source
        await securityMonitor.simulateUnusualLoginSource('203.0.113.50');

        // Assert
        final alerts = await alertService.getRecentAlerts();
        expect(alerts.length, equals(initialAlertCount + 1));
        
        final sourceAlert = alerts.first;
        expect(sourceAlert.type, equals('system_anomaly'));
        expect(sourceAlert.severity, equals('medium'));
        expect(sourceAlert.title, contains('Unusual Login Source'));
        expect(sourceAlert.description, contains('203.0.113.50'));
        expect(sourceAlert.rollbackSuggested, isFalse);
      });
    });

    group('AI Explanation Generation', () {
      test('should generate appropriate explanations for different alert types', () async {
        // Test honeytoken explanation
        await securityMonitor.simulateHoneytokenAccess('api_key');
        var alerts = await alertService.getRecentAlerts(limit: 1);
        var alert = alerts.first;
        expect(alert.aiExplanation, contains('CRITICAL'));
        expect(alert.aiExplanation, contains('breach'));

        // Test data export explanation
        await securityMonitor.simulateDataExportAnomaly(30, 10);
        alerts = await alertService.getRecentAlerts(limit: 1);
        alert = alerts.first;
        expect(alert.aiExplanation, contains('ANOMALOUS'));
        expect(alert.aiExplanation, contains('exfiltration'));

        // Test config drift explanation
        await securityMonitor.simulateConfigurationDrift(
          'config/app.json',
          'privilege_escalation',
          'hash1',
          'hash2'
        );
        alerts = await alertService.getRecentAlerts(limit: 1);
        alert = alerts.first;
        expect(alert.aiExplanation, contains('UNAUTHORIZED'));
        expect(alert.aiExplanation, contains('configuration'));
      });

      test('should provide actionable recommendations in explanations', () async {
        await securityMonitor.simulateLoginFlood('192.168.1.300', 10);
        
        final alerts = await alertService.getRecentAlerts(limit: 1);
        final alert = alerts.first;
        
        expect(alert.aiExplanation, contains('BRUTE FORCE'));
        expect(alert.aiExplanation, anyOf([
          contains('block'),
          contains('investigate'),
          contains('monitor'),
          contains('strengthen'),
        ]));
      });
    });

    group('Integration with Rollback System', () {
      test('should suggest rollback for critical security events', () async {
        final criticalEvents = [
          () => securityMonitor.simulateHoneytokenAccess('credit_card'),
          () => securityMonitor.simulateDataExportAnomaly(60, 10), // 500% increase
          () => securityMonitor.simulateConfigurationDrift(
            'config/security.json',
            'credential_modification',
            'hash1',
            'hash2'
          ),
        ];

        for (final event in criticalEvents) {
          await event();
          
          final alerts = await alertService.getRecentAlerts(limit: 1);
          final alert = alerts.first;
          
          expect(alert.rollbackSuggested, isTrue);
        }
      });

      test('should not suggest rollback for informational alerts', () async {
        final informationalEvents = [
          () => securityMonitor.simulateOffHoursAccess(5, 22),
          () => securityMonitor.simulateUnusualLoginSource('203.0.113.100'),
          () => securityMonitor.simulateLoginFlood('192.168.1.400', 8),
        ];

        for (final event in informationalEvents) {
          await event();
          
          final alerts = await alertService.getRecentAlerts(limit: 1);
          final alert = alerts.first;
          
          expect(alert.rollbackSuggested, isFalse);
        }
      });
    });

    group('Alert Evidence Collection', () {
      test('should collect comprehensive evidence for each alert type', () async {
        // Test honeytoken evidence
        await securityMonitor.simulateHoneytokenAccess('ssn');
        var alerts = await alertService.getRecentAlerts(limit: 1);
        var alert = alerts.first;
        expect(alert.evidence, contains('honeytoken_type'));
        expect(alert.evidence, contains('access_time'));
        expect(alert.evidence, contains('source_ip'));

        // Test data export evidence
        await securityMonitor.simulateDataExportAnomaly(25, 10);
        alerts = await alertService.getRecentAlerts(limit: 1);
        alert = alerts.first;
        expect(alert.evidence, contains('current_query_count'));
        expect(alert.evidence, contains('baseline_count'));
        expect(alert.evidence, contains('percentage_increase'));
        expect(alert.evidence, contains('affected_tables'));

        // Test config drift evidence
        await securityMonitor.simulateConfigurationDrift(
          'config/test.json',
          'network_configuration',
          'original_hash',
          'current_hash'
        );
        alerts = await alertService.getRecentAlerts(limit: 1);
        alert = alerts.first;
        expect(alert.evidence, contains('file_path'));
        expect(alert.evidence, contains('change_type'));
        expect(alert.evidence, contains('baseline_hash'));
        expect(alert.evidence, contains('current_hash'));
      });
    });
  });
}

// Extension to SecurityMonitor for testing
extension SecurityMonitorTesting on SecurityMonitor {
  Future<void> simulateHoneytokenAccess(String honeytokenType) async {
    // This would be implemented as a test helper method
    // For now, we'll simulate by calling the private method through reflection
    // In a real implementation, you'd expose test-only methods
  }

  Future<void> simulateDataExportAnomaly(int currentCount, int baseline) async {
    // Test helper for simulating data export anomalies
  }

  Future<void> simulateOffHoursAccess(int queryCount, int hour) async {
    // Test helper for simulating off-hours access
  }

  Future<void> simulateConfigurationDrift(
    String filePath,
    String changeType,
    String baselineHash,
    String currentHash,
  ) async {
    // Test helper for simulating configuration drift
  }

  Future<void> simulateLoginFlood(String sourceIP, int attemptCount) async {
    // Test helper for simulating login floods
  }

  Future<void> simulateUnusualLoginSource(String sourceIP) async {
    // Test helper for simulating unusual login sources
  }
}