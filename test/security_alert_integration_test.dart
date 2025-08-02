import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/security/security_monitor.dart';
import '../lib/core/database/services/services.dart';
import '../lib/core/database/database_service.dart';
import '../lib/core/database/models/models.dart';

void main() {
  group('Security Alert Integration Tests', () {
    late SecurityMonitor securityMonitor;
    late SecurityAlertService securityAlertService;
    late DatabaseService databaseService;

    setUpAll(() async {
      // Initialize FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      // Initialize database service
      databaseService = DatabaseService.instance;
      await databaseService.initialize(':memory:');
      
      securityMonitor = SecurityMonitor.instance;
      securityAlertService = SecurityAlertService.instance;
    });

    tearDownAll(() async {
      securityMonitor.dispose();
      await databaseService.close();
    });

    test('should generate and display honeytoken alerts', () async {
      await securityMonitor.initialize();
      
      // Simulate honeytoken access
      await securityMonitor.simulateHoneytokenAccess(
        '4111-1111-1111-1111',
        'SELECT * FROM users WHERE credit_card = ?',
      );
      
      // Verify alert was created
      final alerts = await securityAlertService.getAllSecurityAlerts();
      expect(alerts.isNotEmpty, isTrue);
      
      final honeytokenAlert = alerts.firstWhere(
        (alert) => alert.type == 'database_breach',
      );
      
      expect(honeytokenAlert.severity, equals('critical'));
      expect(honeytokenAlert.title, contains('Honeytoken'));
      expect(honeytokenAlert.status, equals('new'));
      expect(honeytokenAlert.aiExplanation.isNotEmpty, isTrue);
    });

    test('should generate and display authentication flood alerts', () async {
      await securityMonitor.initialize();
      
      // Simulate authentication flood
      for (int i = 0; i < 6; i++) {
        await securityMonitor.recordLoginAttempt(false, 'test_user');
      }
      
      // Verify alert was created
      final alerts = await securityAlertService.getAlertsByType('auth_flood');
      expect(alerts.isNotEmpty, isTrue);
      
      final authAlert = alerts.first;
      expect(authAlert.severity, equals('high'));
      expect(authAlert.title, contains('Authentication Flood'));
      expect(authAlert.status, equals('new'));
    });

    test('should filter alerts by severity', () async {
      await securityMonitor.initialize();
      
      // Create alerts of different severities
      await securityMonitor.simulateHoneytokenAccess(
        '4111-1111-1111-1111',
        'test_context',
      ); // Creates critical alert
      
      for (int i = 0; i < 6; i++) {
        await securityMonitor.recordLoginAttempt(false, 'test_user');
      } // Creates high alert
      
      // Test severity filtering
      final criticalAlerts = await securityAlertService.getAlertsBySeverity('critical');
      final highAlerts = await securityAlertService.getAlertsBySeverity('high');
      
      expect(criticalAlerts.isNotEmpty, isTrue);
      expect(highAlerts.isNotEmpty, isTrue);
      expect(criticalAlerts.every((a) => a.severity == 'critical'), isTrue);
      expect(highAlerts.every((a) => a.severity == 'high'), isTrue);
    });

    test('should filter alerts by status', () async {
      await securityMonitor.initialize();
      
      // Create an alert
      await securityMonitor.simulateHoneytokenAccess(
        '4111-1111-1111-1111',
        'test_context',
      );
      
      final newAlerts = await securityAlertService.getAlertsByStatus('new');
      expect(newAlerts.isNotEmpty, isTrue);
      
      // Resolve the alert
      final alertToResolve = newAlerts.first;
      await securityAlertService.resolveAlert(
        alertToResolve.id,
        'resolved',
        resolvedBy: 'test_user',
      );
      
      // Check resolved alerts
      final resolvedAlerts = await securityAlertService.getAlertsByStatus('resolved');
      expect(resolvedAlerts.isNotEmpty, isTrue);
      expect(resolvedAlerts.first.status, equals('resolved'));
    });

    test('should assign alerts to team members', () async {
      await securityMonitor.initialize();
      
      // Create an alert
      await securityMonitor.simulateHoneytokenAccess(
        '4111-1111-1111-1111',
        'test_context',
      );
      
      final alerts = await securityAlertService.getAllSecurityAlerts();
      final alertToAssign = alerts.first;
      
      // Assign the alert
      await securityAlertService.assignAlert(
        alertToAssign.id,
        'security_reviewer_123',
        assignedBy: 'admin_user',
      );
      
      // Verify assignment
      final updatedAlert = await securityAlertService.getSecurityAlert(alertToAssign.id);
      expect(updatedAlert?.assignedTo, equals('security_reviewer_123'));
    });

    test('should provide real-time alert updates', () async {
      await securityMonitor.initialize();
      
      // Get initial alert count
      final initialAlerts = await securityAlertService.getAllSecurityAlerts();
      final initialCount = initialAlerts.length;
      
      // Create new alert
      await securityMonitor.simulateHoneytokenAccess(
        '4111-1111-1111-1111',
        'test_context',
      );
      
      // Verify alert count increased
      final updatedAlerts = await securityAlertService.getAllSecurityAlerts();
      expect(updatedAlerts.length, equals(initialCount + 1));
      
      // Verify the new alert is at the top (most recent)
      final newestAlert = updatedAlerts.first;
      expect(newestAlert.detectedAt.isAfter(
        initialAlerts.isNotEmpty ? initialAlerts.first.detectedAt : DateTime(2000)
      ), isTrue);
    });

    test('should track alert resolution workflow', () async {
      await securityMonitor.initialize();
      
      // Create an alert
      await securityMonitor.simulateHoneytokenAccess(
        '4111-1111-1111-1111',
        'test_context',
      );
      
      final alerts = await securityAlertService.getAllSecurityAlerts();
      final alert = alerts.first;
      
      // Verify initial state
      expect(alert.status, equals('new'));
      expect(alert.resolvedAt, isNull);
      
      // Resolve as false positive
      await securityAlertService.resolveAlert(
        alert.id,
        'false_positive',
        resolvedBy: 'security_reviewer',
      );
      
      // Verify resolution
      final resolvedAlert = await securityAlertService.getSecurityAlert(alert.id);
      expect(resolvedAlert?.status, equals('false_positive'));
      expect(resolvedAlert?.resolvedAt, isNotNull);
    });

    test('should generate AI explanations for alerts', () async {
      await securityMonitor.initialize();
      
      // Create different types of alerts
      await securityMonitor.simulateHoneytokenAccess(
        '4111-1111-1111-1111',
        'SELECT * FROM users WHERE credit_card = ?',
      );
      
      for (int i = 0; i < 6; i++) {
        await securityMonitor.recordLoginAttempt(false, 'test_user');
      }
      
      final alerts = await securityAlertService.getAllSecurityAlerts();
      
      // Verify all alerts have AI explanations
      for (final alert in alerts) {
        expect(alert.aiExplanation.isNotEmpty, isTrue);
        expect(alert.aiExplanation.length, greaterThan(50)); // Substantial explanation
        
        // Verify explanation contains relevant context
        if (alert.type == 'database_breach') {
          expect(alert.aiExplanation.toLowerCase(), contains('honeytoken'));
        } else if (alert.type == 'auth_flood') {
          expect(alert.aiExplanation.toLowerCase(), contains('brute force'));
        }
      }
    });
  });
}