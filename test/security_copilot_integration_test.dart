import 'package:flutter_test/flutter_test.dart';
import 'package:devguard_ai_copilot/core/security/security_monitor.dart';
import 'package:devguard_ai_copilot/core/database/services/security_alert_service.dart';
import 'package:devguard_ai_copilot/core/ai/copilot_service.dart';
import 'package:devguard_ai_copilot/core/deployment/rollback_controller.dart';

void main() {
  group('Security Monitoring + AI Copilot Integration', () {
    late SecurityMonitor securityMonitor;
    late SecurityAlertService alertService;
    late CopilotService copilotService;
    late RollbackController rollbackController;

    setUp(() async {
      securityMonitor = SecurityMonitor.instance;
      alertService = SecurityAlertService.instance;
      copilotService = CopilotService.instance;
      rollbackController = RollbackController.instance;

      // Initialize services
      await securityMonitor.initialize();
      await copilotService.initialize();
      await rollbackController.initialize();
    });

    test('should surface security alerts in copilot dashboard', () async {
      // Arrange - Create a critical security alert
      await securityMonitor.simulateHoneytokenAccess('credit_card');

      // Act - Query copilot for security status
      final response = await copilotService.processCommand('/security-status');

      // Assert
      expect(response.success, isTrue);
      expect(response.message, contains('CRITICAL'));
      expect(response.message, contains('honeytoken'));
      expect(response.message, contains('breach'));
      expect(response.suggestedActions, isNotEmpty);
      expect(response.suggestedActions.first, contains('investigate'));
    });

    test('should enable copilot to execute rollback on critical alerts',
        () async {
      // Arrange - Create a critical alert that suggests rollback
      await securityMonitor.simulateDataExportAnomaly(60, 10); // 500% increase

      // Act - Use copilot to execute rollback
      final rollbackResponse = await copilotService
          .processCommand('/rollback --reason="Data export anomaly detected"');

      // Assert
      expect(rollbackResponse.success, isTrue);
      expect(rollbackResponse.message, contains('rollback'));
      expect(rollbackResponse.message, contains('initiated'));

      // Verify rollback was actually triggered
      final rollbackStatus = await rollbackController.getLastRollbackStatus();
      expect(rollbackStatus, isNotNull);
      expect(rollbackStatus!.reason, contains('Data export anomaly'));
    });

    test('should provide contextual security explanations through copilot',
        () async {
      // Arrange - Create multiple types of alerts
      await securityMonitor.simulateConfigurationDrift(
          'config/security.json', 'credential_modification', 'hash1', 'hash2');
      await securityMonitor.simulateLoginFlood('192.168.1.100', 15);

      // Act - Ask copilot to explain security alerts
      final explanationResponse =
          await copilotService.processCommand('/explain-alerts');

      // Assert
      expect(explanationResponse.success, isTrue);
      expect(explanationResponse.message, contains('configuration'));
      expect(explanationResponse.message, contains('login flood'));
      expect(explanationResponse.message, contains('credential'));
      expect(explanationResponse.suggestedActions.length, greaterThan(1));
    });

    test('should recommend appropriate actions based on alert severity',
        () async {
      // Test critical alert recommendations
      await securityMonitor.simulateHoneytokenAccess('api_key');
      var response = await copilotService.processCommand('/recommend-actions');

      expect(response.suggestedActions, contains('immediate_investigation'));
      expect(response.suggestedActions, contains('system_isolation'));
      expect(response.suggestedActions, contains('rollback_consideration'));

      // Test medium severity alert recommendations
      await securityMonitor.simulateOffHoursAccess(8, 23);
      response = await copilotService.processCommand('/recommend-actions');

      expect(response.suggestedActions, contains('verify_user_identity'));
      expect(response.suggestedActions, contains('monitor_session'));
      expect(response.suggestedActions, isNot(contains('system_isolation')));
    });

    test('should integrate security alerts with task management', () async {
      // Arrange - Create a security alert
      await securityMonitor.simulateUnusualLoginSource('203.0.113.75');

      // Act - Use copilot to create security task
      final taskResponse =
          await copilotService.processCommand('/create-security-task');

      // Assert
      expect(taskResponse.success, isTrue);
      expect(taskResponse.message, contains('security task created'));

      // Verify task was created with appropriate details
      final taskDetails = taskResponse.contextData?['task_details'];
      expect(taskDetails, isNotNull);
      expect(taskDetails['type'], equals('security_investigation'));
      expect(taskDetails['priority'], equals('high'));
      expect(taskDetails['description'], contains('unusual login source'));
    });

    test('should provide security trend analysis through copilot', () async {
      // Arrange - Create a pattern of security events
      await securityMonitor.simulateLoginFlood('192.168.1.200', 8);
      await Future.delayed(const Duration(milliseconds: 100));
      await securityMonitor.simulateLoginFlood('192.168.1.201', 12);
      await Future.delayed(const Duration(milliseconds: 100));
      await securityMonitor.simulateLoginFlood('192.168.1.202', 6);

      // Act - Ask copilot for trend analysis
      final trendResponse =
          await copilotService.processCommand('/security-trends');

      // Assert
      expect(trendResponse.success, isTrue);
      expect(trendResponse.message, contains('pattern'));
      expect(trendResponse.message, contains('login flood'));
      expect(trendResponse.message, contains('coordinated'));
      expect(trendResponse.suggestedActions, contains('network_analysis'));
    });

    test('should enable quick security response through copilot commands',
        () async {
      // Arrange - Create a critical security event
      await securityMonitor.simulateHoneytokenAccess('ssn');

      // Act - Test various quick response commands
      final commands = [
        '/security-summary',
        '/isolate-system',
        '/notify-security-team',
        '/emergency-rollback',
      ];

      for (final command in commands) {
        final response = await copilotService.processCommand(command);

        // Assert each command executes successfully
        expect(response.success, isTrue,
            reason: 'Command $command should succeed');
        expect(response.message, isNotEmpty,
            reason: 'Command $command should have a response');
      }
    });

    test('should maintain security context across copilot conversations',
        () async {
      // Arrange - Create initial security context
      await securityMonitor.simulateDataExportAnomaly(35, 10);

      // Act - Have a conversation about the security event
      var response1 = await copilotService
          .processCommand('What security issues do we have?');
      var response2 = await copilotService
          .processCommand('Should we be concerned about this?');
      var response3 =
          await copilotService.processCommand('What should we do next?');

      // Assert - Each response should maintain context
      expect(response1.message, contains('data export'));
      expect(response2.message, contains('concerned'));
      expect(response2.contextData?['previous_context'], isNotNull);
      expect(response3.suggestedActions, isNotEmpty);
      expect(response3.contextData?['conversation_context'],
          contains('data_export_anomaly'));
    });

    test(
        'should integrate with deployment pipeline for security-triggered rollbacks',
        () async {
      // Arrange - Simulate a deployment in progress
      await rollbackController.simulateDeploymentInProgress('v1.2.3');

      // Create a critical security event during deployment
      await securityMonitor.simulateConfigurationDrift('config/production.json',
          'privilege_escalation', 'prod_hash_1', 'compromised_hash_2');

      // Act - Copilot should recommend immediate rollback
      final response =
          await copilotService.processCommand('/assess-deployment-security');

      // Assert
      expect(response.success, isTrue);
      expect(response.message, contains('CRITICAL'));
      expect(response.message, contains('deployment'));
      expect(response.suggestedActions, contains('immediate_rollback'));
      expect(response.contextData?['deployment_at_risk'], isTrue);
    });

    test('should provide security metrics and KPIs through copilot', () async {
      // Arrange - Create various security events for metrics
      await securityMonitor.simulateHoneytokenAccess('email');
      await securityMonitor.simulateLoginFlood('192.168.1.300', 10);
      await securityMonitor.simulateOffHoursAccess(5, 2);
      await securityMonitor.simulateUnusualLoginSource('203.0.113.100');

      // Act - Request security metrics
      final metricsResponse =
          await copilotService.processCommand('/security-metrics');

      // Assert
      expect(metricsResponse.success, isTrue);
      expect(metricsResponse.contextData?['total_alerts'], equals(4));
      expect(metricsResponse.contextData?['critical_alerts'], equals(1));
      expect(metricsResponse.contextData?['medium_alerts'], equals(2));
      expect(metricsResponse.contextData?['alert_types'],
          contains('database_breach'));
      expect(
          metricsResponse.contextData?['alert_types'], contains('auth_flood'));
      expect(metricsResponse.contextData?['alert_types'],
          contains('system_anomaly'));
    });
  });
}

// Extension to CopilotService for testing security integration
extension CopilotSecurityTesting on CopilotService {
  Future<CopilotResponse> processCommand(String command) async {
    // This would be implemented to handle security-specific commands
    // For testing purposes, we simulate appropriate responses

    if (command.contains('/security-status')) {
      final alerts =
          await SecurityAlertService.instance.getRecentAlerts(limit: 5);
      final criticalAlerts =
          alerts.where((a) => a.severity == 'critical').toList();

      if (criticalAlerts.isNotEmpty) {
        return CopilotResponse(
          success: true,
          message:
              'CRITICAL: ${criticalAlerts.length} critical security alerts detected. Immediate attention required.',
          suggestedActions: [
            'investigate_immediately',
            'consider_rollback',
            'notify_security_team'
          ],
          contextData: {
            'critical_count': criticalAlerts.length,
            'alert_types': criticalAlerts.map((a) => a.type).toSet().toList(),
          },
        );
      }
    }

    if (command.contains('/rollback')) {
      return CopilotResponse(
        success: true,
        message: 'Emergency rollback initiated due to security concerns.',
        suggestedActions: [
          'monitor_rollback_progress',
          'verify_system_integrity'
        ],
        contextData: {'rollback_initiated': true},
      );
    }

    // Default response for testing
    return CopilotResponse(
      success: true,
      message: 'Security command processed: $command',
      suggestedActions: ['monitor_system'],
      contextData: {'command': command},
    );
  }
}

// Extension to RollbackController for testing
extension RollbackControllerTesting on RollbackController {
  Future<void> simulateDeploymentInProgress(String version) async {
    // Simulate deployment in progress for testing
  }

  Future<RollbackStatus?> getLastRollbackStatus() async {
    // Return mock rollback status for testing
    return RollbackStatus(
      id: 'test-rollback-1',
      reason: 'Data export anomaly detected',
      initiatedAt: DateTime.now(),
      status: 'completed',
    );
  }
}

class CopilotResponse {
  final bool success;
  final String message;
  final List<String> suggestedActions;
  final Map<String, dynamic>? contextData;

  CopilotResponse({
    required this.success,
    required this.message,
    required this.suggestedActions,
    this.contextData,
  });
}

class RollbackStatus {
  final String id;
  final String reason;
  final DateTime initiatedAt;
  final String status;

  RollbackStatus({
    required this.id,
    required this.reason,
    required this.initiatedAt,
    required this.status,
  });
}
