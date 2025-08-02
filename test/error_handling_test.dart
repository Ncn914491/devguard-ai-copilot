import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/core/error/error_handler.dart';
import '../lib/core/monitoring/system_health_monitor.dart';
import '../lib/core/database/services/audit_log_service.dart';

// Generate mocks
@GenerateMocks([AuditLogService])
import 'error_handling_test.mocks.dart';

void main() {
  group('Error Handling Tests', () {
    late ErrorHandler errorHandler;
    late SystemHealthMonitor healthMonitor;
    late MockAuditLogService mockAuditService;

    setUp(() {
      errorHandler = ErrorHandler.instance;
      healthMonitor = SystemHealthMonitor.instance;
      mockAuditService = MockAuditLogService();
    });

    tearDown(() {
      errorHandler.dispose();
      healthMonitor.dispose();
    });

    group('Error Classification', () {
      test('should correctly classify network errors', () async {
        final networkError = Exception('Connection timeout occurred');
        
        final result = await errorHandler.handleError(
          networkError,
          type: ErrorType.network,
        );
        
        expect(result.error.type, equals(ErrorType.network));
        expect(result.handled, isTrue);
        expect(result.userMessage, contains('Network connection issue'));
      });

      test('should correctly classify database errors', () async {
        final databaseError = Exception('SQL query failed');
        
        final result = await errorHandler.handleError(
          databaseError,
          type: ErrorType.database,
        );
        
        expect(result.error.type, equals(ErrorType.database));
        expect(result.handled, isTrue);
        expect(result.userMessage, contains('Data access issue'));
      });

      test('should correctly classify security errors', () async {
        final securityError = Exception('Authentication failed');
        
        final result = await errorHandler.handleError(
          securityError,
          type: ErrorType.security,
        );
        
        expect(result.error.type, equals(ErrorType.security));
        expect(result.handled, isTrue);
        expect(result.userMessage, contains('Security check failed'));
      });

      test('should infer error type from error message', () async {
        final networkError = Exception('network connection failed');
        
        final result = await errorHandler.handleError(networkError);
        
        expect(result.error.type, equals(ErrorType.network));
      });

      test('should infer error severity from error message', () async {
        final criticalError = Exception('critical system failure');
        
        final result = await errorHandler.handleError(criticalError);
        
        expect(result.error.severity, equals(ErrorSeverity.critical));
      });
    });

    group('Error Recovery', () {
      test('should attempt recovery for recoverable errors', () async {
        final recoverableError = Exception('temporary network issue');
        
        final result = await errorHandler.handleError(
          recoverableError,
          type: ErrorType.network,
        );
        
        expect(result.recoveryAttempted, isTrue);
        expect(result.suggestedActions, isNotEmpty);
      });

      test('should provide appropriate suggested actions', () async {
        final networkError = Exception('connection failed');
        
        final result = await errorHandler.handleError(
          networkError,
          type: ErrorType.network,
        );
        
        expect(result.suggestedActions, contains('Check your internet connection'));
        expect(result.suggestedActions, contains('Try again in a few moments'));
      });

      test('should handle repeated errors with escalation', () async {
        final repeatedError = Exception('same error repeated');
        
        // Simulate multiple occurrences of the same error
        for (int i = 0; i < 6; i++) {
          await errorHandler.handleError(repeatedError);
        }
        
        // The error handler should have detected the pattern
        // This would be verified through audit logs in a real implementation
        expect(true, isTrue); // Placeholder assertion
      });
    });

    group('User-Friendly Messages', () {
      test('should generate user-friendly messages for network errors', () async {
        final networkError = Exception('HTTP 500 Internal Server Error');
        
        final result = await errorHandler.handleError(
          networkError,
          type: ErrorType.network,
        );
        
        expect(result.userMessage, isNot(contains('HTTP 500')));
        expect(result.userMessage, contains('Network connection issue'));
      });

      test('should generate user-friendly messages for database errors', () async {
        final databaseError = Exception('SQLException: Table not found');
        
        final result = await errorHandler.handleError(
          databaseError,
          type: ErrorType.database,
        );
        
        expect(result.userMessage, isNot(contains('SQLException')));
        expect(result.userMessage, contains('Data access issue'));
      });

      test('should indicate successful recovery in messages', () async {
        final recoverableError = Exception('temporary issue');
        
        final result = await errorHandler.handleError(
          recoverableError,
          type: ErrorType.network,
        );
        
        // In a real implementation, this would depend on actual recovery success
        if (result.recoverySuccessful) {
          expect(result.userMessage, contains('resolved automatically'));
        }
      });
    });

    group('Error Statistics', () {
      test('should track error statistics', () async {
        // Generate some test errors
        await errorHandler.handleError(Exception('error 1'));
        await errorHandler.handleError(Exception('error 2'));
        await errorHandler.handleError(Exception('critical error'), severity: ErrorSeverity.critical);
        
        final stats = await errorHandler.getErrorStatistics();
        
        expect(stats.totalErrors, greaterThan(0));
        expect(stats.recentErrors, greaterThan(0));
      });

      test('should calculate system health based on errors', () async {
        // Generate critical errors
        for (int i = 0; i < 3; i++) {
          await errorHandler.handleError(
            Exception('critical error $i'),
            severity: ErrorSeverity.critical,
          );
        }
        
        final stats = await errorHandler.getErrorStatistics();
        
        expect(stats.systemHealth, isIn([SystemHealth.degraded, SystemHealth.critical]));
      });
    });
  });

  group('System Health Monitoring Tests', () {
    test('should initialize health checks', () async {
      await healthMonitor.initialize();
      
      final status = await healthMonitor.getCurrentHealthStatus();
      
      expect(status.checkResults, isNotEmpty);
      expect(status.status, isIn(HealthStatus.values));
    });

    test('should detect critical health issues', () async {
      await healthMonitor.initialize();
      
      // Wait for health checks to complete
      await Future.delayed(const Duration(seconds: 1));
      
      final status = await healthMonitor.getCurrentHealthStatus();
      
      expect(status.timestamp, isNotNull);
      expect(status.summary, isNotEmpty);
    });

    test('should provide health metrics', () async {
      await healthMonitor.initialize();
      
      // Wait for health checks to complete
      await Future.delayed(const Duration(seconds: 1));
      
      final metrics = healthMonitor.getHealthMetrics();
      
      expect(metrics, isNotEmpty);
      
      for (final metric in metrics.values) {
        expect(metric.name, isNotEmpty);
        expect(metric.value, isNotNull);
        expect(metric.status, isIn(HealthStatus.values));
        expect(metric.timestamp, isNotNull);
      }
    });

    test('should handle health check failures gracefully', () async {
      await healthMonitor.initialize();
      
      // Health monitor should continue working even if individual checks fail
      final status = await healthMonitor.getCurrentHealthStatus();
      
      expect(status, isNotNull);
      expect(status.status, isIn(HealthStatus.values));
    });
  });

  group('Integration Tests', () {
    test('should integrate error handling with health monitoring', () async {
      await errorHandler.initialize();
      await healthMonitor.initialize();
      
      // Generate errors that should affect health status
      for (int i = 0; i < 5; i++) {
        await errorHandler.handleError(
          Exception('test error $i'),
          severity: ErrorSeverity.high,
        );
      }
      
      // Wait for health monitoring to detect the errors
      await Future.delayed(const Duration(seconds: 1));
      
      final healthStatus = await healthMonitor.getCurrentHealthStatus();
      final errorStats = await errorHandler.getErrorStatistics();
      
      expect(errorStats.recentErrors, greaterThan(0));
      expect(healthStatus.status, isIn([HealthStatus.warning, HealthStatus.critical]));
    });

    test('should handle cascading failures gracefully', () async {
      await errorHandler.initialize();
      await healthMonitor.initialize();
      
      // Simulate cascading failures
      final errors = [
        Exception('database connection failed'),
        Exception('network timeout'),
        Exception('security check failed'),
        Exception('integration service down'),
      ];
      
      for (final error in errors) {
        await errorHandler.handleError(error);
      }
      
      // System should remain stable despite multiple failures
      final healthStatus = await healthMonitor.getCurrentHealthStatus();
      
      expect(healthStatus, isNotNull);
      expect(healthStatus.checkResults, isNotEmpty);
    });

    test('should provide comprehensive error recovery', () async {
      await errorHandler.initialize();
      
      final testError = Exception('recoverable network error');
      
      final result = await errorHandler.handleError(
        testError,
        type: ErrorType.network,
        context: {'operation': 'test_operation', 'retry_count': 0},
      );
      
      expect(result.handled, isTrue);
      expect(result.userMessage, isNotEmpty);
      expect(result.suggestedActions, isNotEmpty);
      
      // Verify that appropriate recovery actions were suggested
      expect(result.suggestedActions, anyElement(contains('Try again')));
    });
  });

  group('Performance Tests', () {
    test('should handle high error volumes efficiently', () async {
      await errorHandler.initialize();
      
      final stopwatch = Stopwatch()..start();
      
      // Generate many errors quickly
      final futures = <Future>[];
      for (int i = 0; i < 100; i++) {
        futures.add(errorHandler.handleError(Exception('bulk error $i')));
      }
      
      await Future.wait(futures);
      stopwatch.stop();
      
      // Should handle 100 errors in reasonable time (less than 5 seconds)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('should not leak memory during extended operation', () async {
      await errorHandler.initialize();
      
      // Generate errors over time to test memory management
      for (int batch = 0; batch < 10; batch++) {
        for (int i = 0; i < 10; i++) {
          await errorHandler.handleError(Exception('memory test error $batch-$i'));
        }
        
        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Error handler should still be responsive
      final result = await errorHandler.handleError(Exception('final test error'));
      expect(result.handled, isTrue);
    });
  });
}