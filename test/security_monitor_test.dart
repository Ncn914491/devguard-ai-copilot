import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/security/security_monitor.dart';
import '../lib/core/database/services/services.dart';
import '../lib/core/database/database_service.dart';

void main() {
  group('SecurityMonitor Tests', () {
    late SecurityMonitor securityMonitor;
    late DatabaseService databaseService;

    setUpAll(() async {
      // Initialize FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      // Initialize database service
      databaseService = DatabaseService.instance;
      await databaseService.initialize(':memory:');
      
      securityMonitor = SecurityMonitor.instance;
    });

    tearDownAll(() async {
      securityMonitor.dispose();
      await databaseService.close();
    });

    test('should initialize security monitoring', () async {
      await securityMonitor.initialize();
      
      final status = await securityMonitor.getSecurityStatus();
      expect(status.isMonitoring, isTrue);
      expect(status.honeytokensDeployed, greaterThan(0));
      expect(status.configFilesMonitored, greaterThan(0));
    });

    test('should detect honeytoken access', () async {
      await securityMonitor.initialize();
      
      // Simulate honeytoken access
      await securityMonitor.simulateHoneytokenAccess(
        '4111-1111-1111-1111',
        'test_access_context',
      );
      
      final alerts = await securityMonitor.getRecentAlerts(limit: 1);
      expect(alerts.isNotEmpty, isTrue);
      expect(alerts.first.type, equals('database_breach'));
    });

    test('should detect authentication flood', () async {
      await securityMonitor.initialize();
      
      // Simulate multiple failed login attempts
      for (int i = 0; i < 6; i++) {
        await securityMonitor.recordLoginAttempt(false, 'test_user');
      }
      
      final alerts = await securityMonitor.getRecentAlerts(limit: 1);
      expect(alerts.isNotEmpty, isTrue);
      expect(alerts.first.type, equals('auth_flood'));
    });

    test('should reset failed login attempts on successful login', () async {
      await securityMonitor.initialize();
      
      // Simulate failed attempts followed by successful login
      for (int i = 0; i < 3; i++) {
        await securityMonitor.recordLoginAttempt(false, 'test_user');
      }
      await securityMonitor.recordLoginAttempt(true, 'test_user');
      
      // Should not trigger flood alert after successful login
      for (int i = 0; i < 3; i++) {
        await securityMonitor.recordLoginAttempt(false, 'test_user');
      }
      
      final alerts = await securityMonitor.getRecentAlerts();
      final authFloodAlerts = alerts.where((a) => a.type == 'auth_flood').toList();
      expect(authFloodAlerts.isEmpty, isTrue);
    });

    test('should provide security status', () async {
      await securityMonitor.initialize();
      
      final status = await securityMonitor.getSecurityStatus();
      expect(status.isMonitoring, isTrue);
      expect(status.honeytokensDeployed, equals(5)); // Based on implementation
      expect(status.honeytokensActive, equals(5));
      expect(status.lastCheck, isNotNull);
      expect(status.lastScanTime, isNotNull);
    });

    test('should stop monitoring', () {
      securityMonitor.stop();
      // Note: We can't easily test the timer state without exposing internal state
      // This test mainly ensures the method doesn't throw
    });
  });
}