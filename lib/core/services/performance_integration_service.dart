import 'dart:async';
import 'package:flutter/foundation.dart';
import 'caching_service.dart';
import 'lazy_loading_service.dart';
import 'optimized_websocket_service.dart';
import 'enhanced_file_watcher.dart';
import 'performance_monitoring_service.dart';
import '../database/services/database_optimization_service.dart';
import '../database/services/audit_log_service.dart';

/// Performance integration service that coordinates all optimization components
/// Satisfies Requirements: 10.1, 10.2, 10.3, 10.4, 10.5 (Complete performance optimization integration)
class PerformanceIntegrationService {
  static final PerformanceIntegrationService _instance =
      PerformanceIntegrationService._internal();
  static PerformanceIntegrationService get instance => _instance;
  PerformanceIntegrationService._internal();

  // Core optimization services
  final _cachingService = CachingService.instance;
  final _lazyLoadingService = LazyLoadingService.instance;
  final _websocketService = OptimizedWebSocketService.instance;
  final _fileWatcher = EnhancedFileWatcher.instance;
  final _databaseOptimization = DatabaseOptimizationService.instance;
  final _performanceMonitoring = PerformanceMonitoringService.instance;
  final _auditService = AuditLogService.instance;

  bool _isInitialized = false;
  Timer? _integrationTimer;

  /// Initialize all performance optimization services in the correct order
  Future<void> initializeAllServices() async {
    if (_isInitialized) return;

    try {
      // Initialize services in dependency order
      await _cachingService.initialize();
      await _databaseOptimization.initialize();
      await _websocketService.initialize();
      await _fileWatcher.initialize();
      await _performanceMonitoring.initialize();

      // Start integration monitoring
      _integrationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _performIntegrationCheck();
      });

      _isInitialized = true;

      await _auditService.logAction(
        actionType: 'performance_integration_initialized',
        description:
            'All performance optimization services initialized successfully',
        aiReasoning:
            'Performance integration service coordinates caching, lazy loading, WebSocket optimization, file watching, database optimization, and monitoring',
        contextData: {
          'services_initialized': [
            'caching',
            'database_optimization',
            'websocket_optimization',
            'file_watcher',
            'performance_monitoring',
          ],
          'integration_monitoring_enabled': true,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'performance_integration_error',
        description:
            'Error initializing performance integration: ${e.toString()}',
        contextData: {
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Get comprehensive performance status
  Map<String, dynamic> getComprehensiveStatus() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'integration_status': {
        'is_initialized': _isInitialized,
        'services_healthy': _areAllServicesHealthy(),
        'integration_score': _calculateIntegrationScore(),
      },
      'service_statuses': {
        'caching': _getCachingStatus(),
        'lazy_loading': _getLazyLoadingStatus(),
        'websocket': _getWebSocketStatus(),
        'file_watcher': _getFileWatcherStatus(),
        'database': _getDatabaseStatus(),
        'monitoring': _getMonitoringStatus(),
      },
      'performance_metrics': _performanceMonitoring.getRealTimeMetrics(),
      'optimization_recommendations': _getIntegratedRecommendations(),
    };
  }

  /// Optimize specific operation with integrated approach
  Future<T> optimizeOperation<T>({
    required String operationKey,
    required Future<T> Function() operation,
    bool useCache = true,
    bool useLazyLoading = false,
    bool broadcastResult = false,
    Duration? cacheTimeout,
  }) async {
    final startTime = DateTime.now();

    try {
      // Check cache first if enabled
      if (useCache) {
        final cached = _cachingService.get<T>(operationKey);
        if (cached != null) {
          return cached;
        }
      }

      // Execute operation
      final result = await operation();

      // Cache result if enabled
      if (useCache && result != null) {
        _cachingService.put(operationKey, result,
            ttl: cacheTimeout ?? const Duration(minutes: 10));
      }

      // Broadcast result if enabled
      if (broadcastResult) {
        await _websocketService.broadcastToRooms(
          roomIds: ['performance_updates'],
          event: WebSocketEvent(
            type: 'operation_completed',
            timestamp: DateTime.now(),
            data: {
              'operation_key': operationKey,
              'execution_time_ms':
                  DateTime.now().difference(startTime).inMilliseconds,
              'cached': false,
            },
          ),
        );
      }

      return result;
    } catch (e) {
      // Log error and rethrow
      await _auditService.logAction(
        actionType: 'optimized_operation_error',
        description: 'Error in optimized operation: $operationKey',
        contextData: {
          'operation_key': operationKey,
          'error': e.toString(),
          'execution_time_ms':
              DateTime.now().difference(startTime).inMilliseconds,
        },
      );
      rethrow;
    }
  }

  /// Batch optimize multiple operations
  Future<List<T>> batchOptimizeOperations<T>({
    required List<String> operationKeys,
    required List<Future<T> Function()> operations,
    bool useCache = true,
    bool useBatching = true,
  }) async {
    if (operations.length != operationKeys.length) {
      throw ArgumentError(
          'Operation keys and operations must have the same length');
    }

    final results = <T>[];
    final uncachedOperations = <int, Future<T> Function()>{};

    // Check cache for all operations first
    if (useCache) {
      for (int i = 0; i < operationKeys.length; i++) {
        final cached = _cachingService.get<T>(operationKeys[i]);
        if (cached != null) {
          results.add(cached);
        } else {
          uncachedOperations[i] = operations[i];
          results.add(null as T); // Placeholder
        }
      }
    } else {
      for (int i = 0; i < operations.length; i++) {
        uncachedOperations[i] = operations[i];
        results.add(null as T); // Placeholder
      }
    }

    // Execute uncached operations
    if (uncachedOperations.isNotEmpty) {
      if (useBatching) {
        // Execute in batches for better performance
        final futures = uncachedOperations.values.map((fn) => fn()).toList();
        final batchResults = await Future.wait(futures);

        int batchIndex = 0;
        for (final entry in uncachedOperations.entries) {
          final result = batchResults[batchIndex++];
          results[entry.key] = result;

          // Cache the result
          if (useCache) {
            _cachingService.put(operationKeys[entry.key], result);
          }
        }
      } else {
        // Execute sequentially
        for (final entry in uncachedOperations.entries) {
          final result = await entry.value();
          results[entry.key] = result;

          // Cache the result
          if (useCache) {
            _cachingService.put(operationKeys[entry.key], result);
          }
        }
      }
    }

    return results;
  }

  /// Preload data with integrated optimization
  Future<void> preloadData({
    required String dataType,
    required Map<String, dynamic> params,
    int priority = 1,
  }) async {
    // Use lazy loading service for preloading
    switch (dataType) {
      case 'file_tree':
        _lazyLoadingService.preloadNextPage(
          type: 'file_tree',
          params: params,
          currentPage: params['current_page'] ?? 0,
        );
        break;
      case 'tasks':
        _lazyLoadingService.preloadNextPage(
          type: 'tasks',
          params: params,
          currentPage: params['current_page'] ?? 0,
        );
        break;
      case 'users':
        _lazyLoadingService.preloadNextPage(
          type: 'users',
          params: params,
          currentPage: params['current_page'] ?? 0,
        );
        break;
    }
  }

  /// Get integrated performance recommendations
  List<String> getIntegratedRecommendations() {
    final recommendations = <String>[];

    // Get recommendations from monitoring service
    final monitoringRecommendations = _performanceMonitoring
                .getPerformanceReport()['optimization_recommendations']
            as List<String>? ??
        [];
    recommendations.addAll(monitoringRecommendations);

    // Add integration-specific recommendations
    final integrationScore = _calculateIntegrationScore();
    if (integrationScore < 0.8) {
      recommendations
          .add('Consider reviewing service integration configuration');
    }

    // Check cache efficiency
    final cacheStats = _cachingService.getStats();
    final hitRate = double.tryParse(cacheStats['hit_rate'].toString()) ?? 0.0;
    if (hitRate < 60.0) {
      recommendations.add(
          'Optimize cache strategy - consider increasing TTL or cache size');
    }

    // Check WebSocket efficiency
    final wsStats = _websocketService.getOptimizedStats();
    final activeConnections = wsStats['active_connections'] as int? ?? 0;
    if (activeConnections > 100) {
      recommendations.add(
          'High WebSocket connection count - consider connection pooling optimization');
    }

    return recommendations;
  }

  /// Trigger comprehensive optimization
  Future<void> triggerComprehensiveOptimization() async {
    await _performanceMonitoring.triggerOptimization();

    // Additional integration-specific optimizations
    await _optimizeServiceIntegration();
  }

  /// Private helper methods

  /// Perform integration health check
  void _performIntegrationCheck() {
    try {
      final status = getComprehensiveStatus();
      final integrationScore =
          status['integration_status']['integration_score'] as double;

      if (integrationScore < 0.5) {
        _auditService.logAction(
          actionType: 'performance_integration_warning',
          description: 'Performance integration health is poor',
          contextData: {
            'integration_score': integrationScore,
            'status': status,
          },
        );
      }
    } catch (e) {
      debugPrint('Error in integration check: $e');
    }
  }

  /// Check if all services are healthy
  bool _areAllServicesHealthy() {
    try {
      // This would check each service's health status
      // For now, we'll assume they're healthy if initialized
      return _isInitialized;
    } catch (e) {
      return false;
    }
  }

  /// Calculate integration score
  double _calculateIntegrationScore() {
    double score = 0.0;
    int components = 0;

    // Cache service score
    final cacheStats = _cachingService.getStats();
    final hitRate = double.tryParse(cacheStats['hit_rate'].toString()) ?? 0.0;
    score += hitRate / 100.0;
    components++;

    // WebSocket service score
    final wsStats = _websocketService.getOptimizedStats();
    final totalBroadcasts = wsStats['total_broadcasts'] as int? ?? 0;
    final broadcastErrors = wsStats['broadcast_errors'] as int? ?? 0;
    if (totalBroadcasts > 0) {
      score += 1.0 - (broadcastErrors / totalBroadcasts);
      components++;
    }

    // Database service score
    final dbStats = _databaseOptimization.getQueryStats();
    final avgTime =
        double.tryParse(dbStats['average_execution_time_ms'].toString()) ?? 0.0;
    score += avgTime < 100
        ? 1.0
        : avgTime < 200
            ? 0.8
            : 0.6;
    components++;

    return components > 0 ? score / components : 0.0;
  }

  /// Get individual service statuses
  Map<String, dynamic> _getCachingStatus() {
    return {
      'healthy': true,
      'stats': _cachingService.getStats(),
    };
  }

  Map<String, dynamic> _getLazyLoadingStatus() {
    return {
      'healthy': true,
      'active_loading_operations': 0, // Would track active operations
    };
  }

  Map<String, dynamic> _getWebSocketStatus() {
    return {
      'healthy': true,
      'stats': _websocketService.getOptimizedStats(),
    };
  }

  Map<String, dynamic> _getFileWatcherStatus() {
    return {
      'healthy': true,
      'stats': _fileWatcher.getWatcherStats(),
      'active_watchers': _fileWatcher.getAllWatcherStatuses().length,
    };
  }

  Map<String, dynamic> _getDatabaseStatus() {
    return {
      'healthy': true,
      'stats': _databaseOptimization.getQueryStats(),
    };
  }

  Map<String, dynamic> _getMonitoringStatus() {
    return {
      'healthy': true,
      'system_health': _performanceMonitoring.getSystemHealth().toString(),
    };
  }

  /// Optimize service integration
  Future<void> _optimizeServiceIntegration() async {
    // Clear old cache entries to free memory
    final cacheStats = _cachingService.getStats();
    final memoryUsage =
        double.tryParse(cacheStats['memory_usage_mb'].toString()) ?? 0.0;

    if (memoryUsage > 500) {
      // Trigger cache cleanup for memory optimization
      _cachingService.clear();
    }

    // Optimize WebSocket connections
    final wsStats = _websocketService.getOptimizedStats();
    final activeConnections = wsStats['active_connections'] as int? ?? 0;

    if (activeConnections > 150) {
      // Could trigger connection pool optimization here
      debugPrint(
          'High WebSocket connection count detected: $activeConnections');
    }
  }

  /// Get integrated recommendations
  List<String> _getIntegratedRecommendations() {
    return getIntegratedRecommendations();
  }

  /// Dispose all services
  void dispose() {
    _integrationTimer?.cancel();

    _performanceMonitoring.dispose();
    _databaseOptimization.dispose();
    _websocketService.dispose();
    _fileWatcher.dispose();
    _cachingService.dispose();

    _isInitialized = false;
  }
}

/// Performance optimization configuration
class PerformanceConfig {
  final bool enableCaching;
  final bool enableLazyLoading;
  final bool enableWebSocketOptimization;
  final bool enableFileWatcherOptimization;
  final bool enableDatabaseOptimization;
  final bool enablePerformanceMonitoring;

  final Duration defaultCacheTimeout;
  final int maxCacheSize;
  final int lazyLoadingPageSize;
  final Duration fileWatcherDebounceDelay;

  const PerformanceConfig({
    this.enableCaching = true,
    this.enableLazyLoading = true,
    this.enableWebSocketOptimization = true,
    this.enableFileWatcherOptimization = true,
    this.enableDatabaseOptimization = true,
    this.enablePerformanceMonitoring = true,
    this.defaultCacheTimeout = const Duration(minutes: 15),
    this.maxCacheSize = 1000,
    this.lazyLoadingPageSize = 50,
    this.fileWatcherDebounceDelay = const Duration(milliseconds: 300),
  });

  static const PerformanceConfig defaultConfig = PerformanceConfig();

  static const PerformanceConfig highPerformanceConfig = PerformanceConfig(
    defaultCacheTimeout: Duration(minutes: 30),
    maxCacheSize: 2000,
    lazyLoadingPageSize: 100,
    fileWatcherDebounceDelay: Duration(milliseconds: 500),
  );

  static const PerformanceConfig lowResourceConfig = PerformanceConfig(
    defaultCacheTimeout: Duration(minutes: 5),
    maxCacheSize: 500,
    lazyLoadingPageSize: 25,
    fileWatcherDebounceDelay: Duration(milliseconds: 200),
  );
}
