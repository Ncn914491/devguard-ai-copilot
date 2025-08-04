import 'package:flutter_test/flutter_test.dart';
import 'package:devguard_ai_copilot/core/services/caching_service.dart';
import 'package:devguard_ai_copilot/core/services/lazy_loading_service.dart';
import 'package:devguard_ai_copilot/core/services/optimized_websocket_service.dart';
import 'package:devguard_ai_copilot/core/services/enhanced_file_watcher.dart';
import 'package:devguard_ai_copilot/core/database/services/database_optimization_service.dart';
import 'package:devguard_ai_copilot/core/services/performance_monitoring_service.dart';
import 'package:devguard_ai_copilot/core/services/performance_integration_service.dart';

/// Test suite for performance optimization components
/// Verifies Requirements: 10.1, 10.2, 10.3, 10.4, 10.5
void main() {
  group('Performance Optimization Tests', () {
    late CachingService cachingService;
    late LazyLoadingService lazyLoadingService;
    late OptimizedWebSocketService websocketService;
    late EnhancedFileWatcher fileWatcher;
    late DatabaseOptimizationService databaseOptimization;
    late PerformanceMonitoringService performanceMonitoring;
    late PerformanceIntegrationService integrationService;

    setUpAll(() async {
      // Initialize all services
      cachingService = CachingService.instance;
      lazyLoadingService = LazyLoadingService.instance;
      websocketService = OptimizedWebSocketService.instance;
      fileWatcher = EnhancedFileWatcher.instance;
      databaseOptimization = DatabaseOptimizationService.instance;
      performanceMonitoring = PerformanceMonitoringService.instance;
      integrationService = PerformanceIntegrationService.instance;
    });

    group('Caching Service Tests', () {
      test('should initialize caching service successfully', () async {
        await cachingService.initialize();
        expect(cachingService, isNotNull);
      });

      test('should cache and retrieve data with TTL', () async {
        await cachingService.initialize();

        const testKey = 'test_key';
        const testValue = {'data': 'test_value'};

        // Store data in cache
        cachingService.put(testKey, testValue, ttl: const Duration(seconds: 5));

        // Retrieve data from cache
        final retrieved = cachingService.get<Map<String, dynamic>>(testKey);
        expect(retrieved, equals(testValue));
      });

      test('should handle cache expiration', () async {
        await cachingService.initialize();

        const testKey = 'expiring_key';
        const testValue = {'data': 'expiring_value'};

        // Store data with very short TTL
        cachingService.put(testKey, testValue,
            ttl: const Duration(milliseconds: 100));

        // Wait for expiration
        await Future.delayed(const Duration(milliseconds: 200));

        // Should return null after expiration
        final retrieved = cachingService.get<Map<String, dynamic>>(testKey);
        expect(retrieved, isNull);
      });

      test('should provide cache statistics', () async {
        await cachingService.initialize();

        // Add some test data
        cachingService.put('stats_test_1', {'data': 'value1'});
        cachingService.put('stats_test_2', {'data': 'value2'});

        final stats = cachingService.getStats();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('size'), isTrue);
        expect(stats.containsKey('hits'), isTrue);
        expect(stats.containsKey('misses'), isTrue);
        expect(stats.containsKey('hit_rate'), isTrue);
      });

      test('should handle user session caching', () async {
        await cachingService.initialize();

        const userId = 'test_user_123';
        final sessionData = {
          'user_id': userId,
          'role': 'developer',
          'permissions': ['read', 'write'],
        };

        // Store session data
        cachingService.putUserSession(userId, sessionData);

        // Retrieve session data
        final retrieved = cachingService.getUserSession(userId);
        expect(retrieved, equals(sessionData));
      });
    });

    group('Lazy Loading Service Tests', () {
      test('should load file tree page with pagination', () async {
        const repositoryId = 'test_repo_123';
        const path = '/src';

        final result = await lazyLoadingService.loadFileTreePage(
          repositoryId: repositoryId,
          path: path,
          page: 0,
          pageSize: 50,
        );

        expect(result, isA<FileTreePage>());
        expect(result.nodes, isNotEmpty);
        expect(result.page, equals(0));
        expect(result.pageSize, equals(50));
      });

      test('should load task list with filters', () async {
        const userId = 'test_user_123';

        final result = await lazyLoadingService.loadTaskListPage(
          userId: userId,
          status: 'pending',
          priority: 'high',
          page: 0,
          pageSize: 25,
        );

        expect(result, isA<TaskListPage>());
        expect(result.tasks, isNotEmpty);
        expect(result.page, equals(0));
        expect(result.pageSize, equals(25));
      });

      test('should preload next page in background', () {
        // This test verifies that preloading doesn't throw errors
        expect(() {
          lazyLoadingService.preloadNextPage(
            type: 'file_tree',
            params: {
              'repositoryId': 'test_repo',
              'path': '/src',
              'pageSize': 50,
            },
            currentPage: 0,
          );
        }, returnsNormally);
      });
    });

    group('Optimized WebSocket Service Tests', () {
      test('should initialize WebSocket service successfully', () async {
        await websocketService.initialize();
        expect(websocketService, isNotNull);
      });

      test('should create optimized connection with pooling', () async {
        await websocketService.initialize();

        const userId = 'test_user_123';
        const userRole = 'developer';

        final connectionId = await websocketService.createOptimizedConnection(
          userId: userId,
          userRole: userRole,
          clientType: 'web',
        );

        expect(connectionId, isNotNull);
        expect(connectionId, isA<String>());
        expect(connectionId.isNotEmpty, isTrue);
      });

      test('should broadcast to roles efficiently', () async {
        await websocketService.initialize();

        // Create test connection
        await websocketService.createOptimizedConnection(
          userId: 'test_user',
          userRole: 'developer',
        );

        final event = WebSocketEvent(
          type: 'test_broadcast',
          timestamp: DateTime.now(),
          data: {'message': 'test'},
        );

        // Should not throw error
        expect(() async {
          await websocketService.broadcastToRoles(
            roles: ['developer'],
            event: event,
          );
        }, returnsNormally);
      });

      test('should provide connection statistics', () async {
        await websocketService.initialize();

        final stats = websocketService.getOptimizedStats();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('total_connections'), isTrue);
        expect(stats.containsKey('active_connections'), isTrue);
        expect(stats.containsKey('total_broadcasts'), isTrue);
        expect(stats.containsKey('connection_pools'), isTrue);
      });
    });

    group('Enhanced File Watcher Tests', () {
      test('should initialize file watcher successfully', () async {
        await fileWatcher.initialize();
        expect(fileWatcher, isNotNull);
      });

      test('should provide watcher statistics', () async {
        await fileWatcher.initialize();

        final stats = fileWatcher.getWatcherStats();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('active_watchers'), isTrue);
        expect(stats.containsKey('total_events_processed'), isTrue);
        expect(stats.containsKey('debounced_events'), isTrue);
        expect(stats.containsKey('filtered_events'), isTrue);
      });

      test('should handle watcher configuration', () {
        final config = WatcherConfig.defaultConfig();
        expect(config.enableDebouncing, isTrue);
        expect(config.enableBatchProcessing, isTrue);
        expect(config.maxFileSizeBytes, isNotNull);
      });
    });

    group('Database Optimization Service Tests', () {
      test('should initialize database optimization successfully', () async {
        await databaseOptimization.initialize();
        expect(databaseOptimization, isNotNull);
      });

      test('should provide query statistics', () async {
        await databaseOptimization.initialize();

        final stats = databaseOptimization.getQueryStats();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('total_queries'), isTrue);
        expect(stats.containsKey('cache_hits'), isTrue);
        expect(stats.containsKey('cache_hit_rate'), isTrue);
        expect(stats.containsKey('average_execution_time_ms'), isTrue);
      });

      test('should handle batch operations', () {
        final operations = [
          BatchOperation.insert('test_table', {'id': '1', 'name': 'test'}),
          BatchOperation.update('test_table', {'name': 'updated'},
              where: 'id = ?', whereArgs: ['1']),
        ];

        expect(operations, hasLength(2));
        expect(operations[0].type, equals(BatchOperationType.insert));
        expect(operations[1].type, equals(BatchOperationType.update));
      });
    });

    group('Performance Monitoring Service Tests', () {
      test('should initialize performance monitoring successfully', () async {
        await performanceMonitoring.initialize();
        expect(performanceMonitoring, isNotNull);
      });

      test('should provide comprehensive performance report', () async {
        await performanceMonitoring.initialize();

        final report = performanceMonitoring.getPerformanceReport();
        expect(report, isA<Map<String, dynamic>>());
        expect(report.containsKey('timestamp'), isTrue);
        expect(report.containsKey('system_health'), isTrue);
        expect(report.containsKey('caching_performance'), isTrue);
        expect(report.containsKey('websocket_performance'), isTrue);
        expect(report.containsKey('performance_metrics'), isTrue);
      });

      test('should provide real-time metrics', () async {
        await performanceMonitoring.initialize();

        final metrics = performanceMonitoring.getRealTimeMetrics();
        expect(metrics, isA<Map<String, dynamic>>());
        expect(metrics.containsKey('response_times'), isTrue);
        expect(metrics.containsKey('throughput'), isTrue);
        expect(metrics.containsKey('resource_utilization'), isTrue);
        expect(metrics.containsKey('error_rates'), isTrue);
      });

      test('should detect performance bottlenecks', () async {
        await performanceMonitoring.initialize();

        final bottlenecks = performanceMonitoring.getPerformanceBottlenecks();
        expect(bottlenecks, isA<List<PerformanceBottleneck>>());
        // Bottlenecks list can be empty if system is performing well
      });

      test('should assess system health', () async {
        await performanceMonitoring.initialize();

        final health = performanceMonitoring.getSystemHealth();
        expect(health, isA<SystemHealthStatus>());
        expect(
            [
              SystemHealthStatus.excellent,
              SystemHealthStatus.good,
              SystemHealthStatus.fair,
              SystemHealthStatus.poor,
              SystemHealthStatus.critical,
            ].contains(health),
            isTrue);
      });
    });

    group('Performance Integration Service Tests', () {
      test('should initialize all services successfully', () async {
        await integrationService.initializeAllServices();
        expect(integrationService, isNotNull);
      });

      test('should provide comprehensive status', () async {
        await integrationService.initializeAllServices();

        final status = integrationService.getComprehensiveStatus();
        expect(status, isA<Map<String, dynamic>>());
        expect(status.containsKey('integration_status'), isTrue);
        expect(status.containsKey('service_statuses'), isTrue);
        expect(status.containsKey('performance_metrics'), isTrue);
        expect(status.containsKey('optimization_recommendations'), isTrue);
      });

      test('should optimize operations with integrated approach', () async {
        await integrationService.initializeAllServices();

        final result = await integrationService.optimizeOperation<String>(
          operationKey: 'test_operation',
          operation: () async => 'test_result',
          useCache: true,
          broadcastResult: false,
        );

        expect(result, equals('test_result'));
      });

      test('should batch optimize multiple operations', () async {
        await integrationService.initializeAllServices();

        final operations = [
          () async => 'result1',
          () async => 'result2',
          () async => 'result3',
        ];

        final results =
            await integrationService.batchOptimizeOperations<String>(
          operationKeys: ['op1', 'op2', 'op3'],
          operations: operations,
          useCache: true,
          useBatching: true,
        );

        expect(results, hasLength(3));
        expect(results, equals(['result1', 'result2', 'result3']));
      });

      test('should provide integrated recommendations', () async {
        await integrationService.initializeAllServices();

        final recommendations =
            integrationService.getIntegratedRecommendations();
        expect(recommendations, isA<List<String>>());
        expect(recommendations, isNotEmpty);
      });
    });

    group('Integration Tests', () {
      test('should work together seamlessly', () async {
        // Initialize all services
        await integrationService.initializeAllServices();

        // Test cache integration
        cachingService.put('integration_test', {'data': 'test'});
        final cached =
            cachingService.get<Map<String, dynamic>>('integration_test');
        expect(cached, isNotNull);

        // Test WebSocket integration
        final connectionId = await websocketService.createOptimizedConnection(
          userId: 'integration_user',
          userRole: 'developer',
        );
        expect(connectionId, isNotNull);

        // Test performance monitoring integration
        final health = performanceMonitoring.getSystemHealth();
        expect(health, isA<SystemHealthStatus>());

        // Test comprehensive status
        final status = integrationService.getComprehensiveStatus();
        expect(status['integration_status']['is_initialized'], isTrue);
      });

      test('should handle optimization triggers', () async {
        await integrationService.initializeAllServices();

        // Should not throw error
        expect(() async {
          await integrationService.triggerComprehensiveOptimization();
        }, returnsNormally);
      });

      test('should handle preloading coordination', () async {
        await integrationService.initializeAllServices();

        // Should not throw error
        expect(() async {
          await integrationService.preloadData(
            dataType: 'file_tree',
            params: {
              'repositoryId': 'test_repo',
              'path': '/src',
              'current_page': 0,
            },
          );
        }, returnsNormally);
      });
    });

    tearDownAll(() {
      // Clean up services
      integrationService.dispose();
    });
  });
}
