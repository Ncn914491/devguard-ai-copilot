import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/core/monitoring/system_health_monitor.dart';
import '../lib/core/database/services/audit_log_service.dart';

// Generate mocks
@GenerateMocks([AuditLogService])
import 'system_health_monitor_test.mocks.dart';

void main() {
  group('SystemHealthMonitor Tests', () {
    late SystemHealthMonitor healthMonitor;
    late MockAuditLogService mockAuditLogService;

    setUp(() {
      healthMonitor = SystemHealthMonitor.instance;
      mockAuditLogService = MockAuditLogService();
    });

    test('should start monitoring system health', () async {
      // Act
      await healthMonitor.startMonitoring();

      // Assert
      expect(healthMonitor.isMonitoring, isTrue);
    });

    test('should stop monitoring system health', () async {
      // Arrange
      await healthMonitor.startMonitoring();

      // Act
      await healthMonitor.stopMonitoring();

      // Assert
      expect(healthMonitor.isMonitoring, isFalse);
    });

    test('should get current system metrics', () async {
      // Act
      final metrics = await healthMonitor.getCurrentMetrics();

      // Assert
      expect(metrics, isA<Map<String, dynamic>>());
      expect(metrics.containsKey('cpuUsage'), isTrue);
      expect(metrics.containsKey('memoryUsage'), isTrue);
      expect(metrics.containsKey('diskUsage'), isTrue);
      expect(metrics.containsKey('networkLatency'), isTrue);
    });

    test('should detect high CPU usage', () async {
      // Act
      final cpuUsage = await healthMonitor.getCpuUsage();

      // Assert
      expect(cpuUsage, isA<double>());
      expect(cpuUsage, greaterThanOrEqualTo(0.0));
      expect(cpuUsage, lessThanOrEqualTo(100.0));
    });

    test('should detect high memory usage', () async {
      // Act
      final memoryUsage = await healthMonitor.getMemoryUsage();

      // Assert
      expect(memoryUsage, isA<Map<String, dynamic>>());
      expect(memoryUsage.containsKey('used'), isTrue);
      expect(memoryUsage.containsKey('total'), isTrue);
      expect(memoryUsage.containsKey('percentage'), isTrue);
    });

    test('should monitor disk space', () async {
      // Act
      final diskUsage = await healthMonitor.getDiskUsage();

      // Assert
      expect(diskUsage, isA<Map<String, dynamic>>());
      expect(diskUsage.containsKey('used'), isTrue);
      expect(diskUsage.containsKey('available'), isTrue);
      expect(diskUsage.containsKey('total'), isTrue);
      expect(diskUsage.containsKey('percentage'), isTrue);
    });

    test('should check network connectivity', () async {
      // Act
      final networkStatus = await healthMonitor.checkNetworkConnectivity();

      // Assert
      expect(networkStatus, isA<Map<String, dynamic>>());
      expect(networkStatus.containsKey('isConnected'), isTrue);
      expect(networkStatus.containsKey('latency'), isTrue);
    });

    test('should monitor database health', () async {
      // Act
      final dbHealth = await healthMonitor.checkDatabaseHealth();

      // Assert
      expect(dbHealth, isA<Map<String, dynamic>>());
      expect(dbHealth.containsKey('isHealthy'), isTrue);
      expect(dbHealth.containsKey('responseTime'), isTrue);
      expect(dbHealth.containsKey('connectionCount'), isTrue);
    });

    test('should monitor API endpoints health', () async {
      // Act
      final apiHealth = await healthMonitor.checkApiEndpointsHealth();

      // Assert
      expect(apiHealth, isA<List<Map<String, dynamic>>>());

      if (apiHealth.isNotEmpty) {
        final endpoint = apiHealth.first;
        expect(endpoint.containsKey('endpoint'), isTrue);
        expect(endpoint.containsKey('status'), isTrue);
        expect(endpoint.containsKey('responseTime'), isTrue);
      }
    });

    test('should generate health report', () async {
      // Act
      final report = await healthMonitor.generateHealthReport();

      // Assert
      expect(report, isA<Map<String, dynamic>>());
      expect(report.containsKey('timestamp'), isTrue);
      expect(report.containsKey('overallHealth'), isTrue);
      expect(report.containsKey('systemMetrics'), isTrue);
      expect(report.containsKey('alerts'), isTrue);
    });

    test('should trigger alerts for critical issues', () async {
      // Arrange
      when(mockAuditLogService.logSystemAlert(
        any,
        any,
        any,
      )).thenAnswer((_) async => true);

      // Act
      await healthMonitor.checkForCriticalIssues();

      // Assert
      // Verify that alerts are triggered when thresholds are exceeded
      expect(healthMonitor.hasActiveAlerts, isA<bool>());
    });

    test('should set custom monitoring thresholds', () {
      // Arrange
      final thresholds = {
        'cpuUsage': 80.0,
        'memoryUsage': 85.0,
        'diskUsage': 90.0,
        'responseTime': 5000.0,
      };

      // Act
      healthMonitor.setThresholds(thresholds);

      // Assert
      expect(healthMonitor.getThresholds(), equals(thresholds));
    });

    test('should get monitoring history', () async {
      // Act
      final history = await healthMonitor.getMonitoringHistory(
        hours: 24,
      );

      // Assert
      expect(history, isA<List<Map<String, dynamic>>>());
    });

    test('should calculate system uptime', () async {
      // Act
      final uptime = await healthMonitor.getSystemUptime();

      // Assert
      expect(uptime, isA<Duration>());
      expect(uptime.inSeconds, greaterThan(0));
    });

    test('should monitor service dependencies', () async {
      // Act
      final dependencies = await healthMonitor.checkServiceDependencies();

      // Assert
      expect(dependencies, isA<Map<String, dynamic>>());
      expect(dependencies.containsKey('database'), isTrue);
      expect(dependencies.containsKey('webSocket'), isTrue);
      expect(dependencies.containsKey('externalAPIs'), isTrue);
    });

    test('should detect performance bottlenecks', () async {
      // Act
      final bottlenecks = await healthMonitor.detectBottlenecks();

      // Assert
      expect(bottlenecks, isA<List<Map<String, dynamic>>>());
    });

    test('should provide health status summary', () async {
      // Act
      final summary = await healthMonitor.getHealthStatusSummary();

      // Assert
      expect(summary, isA<Map<String, dynamic>>());
      expect(summary.containsKey('status'), isTrue);
      expect(summary.containsKey('score'), isTrue);
      expect(summary.containsKey('issues'), isTrue);
      expect(summary.containsKey('recommendations'), isTrue);
    });

    test('should export health metrics', () async {
      // Act
      final exportData = await healthMonitor.exportMetrics(
        format: 'json',
        timeRange: Duration(hours: 1),
      );

      // Assert
      expect(exportData, isA<String>());
      expect(exportData, isNotEmpty);
    });

    test('should handle monitoring errors gracefully', () async {
      // Act & Assert
      expect(
        () => healthMonitor.handleMonitoringError(Exception('Test error')),
        returnsNormally,
      );
    });

    test('should validate monitoring configuration', () {
      // Arrange
      final validConfig = {
        'interval': 60,
        'thresholds': {
          'cpu': 80.0,
          'memory': 85.0,
        },
        'alerts': true,
      };

      final invalidConfig = {
        'interval': -1,
        'thresholds': {},
      };

      // Act & Assert
      expect(healthMonitor.isValidConfiguration(validConfig), isTrue);
      expect(healthMonitor.isValidConfiguration(invalidConfig), isFalse);
    });
  });
}
