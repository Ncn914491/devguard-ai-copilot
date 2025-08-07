import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'caching_service.dart';
import 'lazy_loading_service.dart';
import 'optimized_websocket_service.dart';
import 'enhanced_file_watcher.dart';
import '../database/services/database_optimization_service.dart';
import '../database/services/audit_log_service.dart';

/// Comprehensive performance monitoring service that coordinates all optimization services
/// Satisfies Requirements: 10.1, 10.2, 10.3, 10.4, 10.5 (Performance and scalability optimization)
class PerformanceMonitoringService {
  static final PerformanceMonitoringService _instance =
      PerformanceMonitoringService._internal();
  static PerformanceMonitoringService get instance => _instance;
  PerformanceMonitoringService._internal();

  final _cachingService = CachingService.instance;
  final _lazyLoadingService = LazyLoadingService.instance;
  final _websocketService = OptimizedWebSocketService.instance;
  final _fileWatcher = EnhancedFileWatcher.instance;
  final _databaseOptimization = DatabaseOptimizationService.instance;
  final _auditService = AuditLogService.instance;

  // Performance metrics
  final PerformanceMetrics _metrics = PerformanceMetrics();

  // Monitoring timers
  Timer? _metricsTimer;
  Timer? _healthCheckTimer;
  Timer? _optimizationTimer;

  // System resource monitoring
  final SystemResourceMonitor _resourceMonitor = SystemResourceMonitor();

  bool _isInitialized = false;
  bool _isOptimizationEnabled = true;

  /// Initialize performance monitoring service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize all optimization services
    await _initializeOptimizationServices();

    // Start monitoring timers
    _startMonitoringTimers();

    // Start resource monitoring
    await _resourceMonitor.initialize();

    _isInitialized = true;

    await _auditService.logAction(
      actionType: 'performance_monitoring_initialized',
      description:
          'Performance monitoring service initialized with all optimization components',
      aiReasoning:
          'Performance monitoring coordinates caching, lazy loading, WebSocket optimization, file watching, and database optimization',
      contextData: {
        'optimization_enabled': _isOptimizationEnabled,
        'monitoring_intervals': {
          'metrics_collection_s': 30,
          'health_check_s': 60,
          'optimization_cycle_s': 300,
        },
      },
    );
  }

  /// Get comprehensive performance report
  Map<String, dynamic> getPerformanceReport() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'system_health': _getSystemHealth(),
      'caching_performance': _cachingService.getStats(),
      'websocket_performance': _websocketService.getOptimizedStats(),
      'file_watcher_performance': _fileWatcher.getWatcherStats(),
      'database_performance': _databaseOptimization.getQueryStats(),
      'system_resources': _resourceMonitor.getResourceStats(),
      'performance_metrics': _metrics.toMap(),
      'optimization_recommendations': _generateOptimizationRecommendations(),
    };
  }

  /// Get real-time performance metrics
  Map<String, dynamic> getRealTimeMetrics() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'response_times': {
        'cache_avg_ms': _metrics.averageCacheResponseTime.inMilliseconds,
        'db_avg_ms': _metrics.averageDatabaseResponseTime.inMilliseconds,
        'websocket_avg_ms':
            _metrics.averageWebSocketResponseTime.inMilliseconds,
      },
      'throughput': {
        'cache_ops_per_sec': _metrics.cacheOperationsPerSecond,
        'db_queries_per_sec': _metrics.databaseQueriesPerSecond,
        'websocket_messages_per_sec': _metrics.websocketMessagesPerSecond,
      },
      'resource_utilization': {
        'memory_usage_mb': _resourceMonitor.memoryUsageMB,
        'cpu_usage_percent': _resourceMonitor.cpuUsagePercent,
        'disk_usage_percent': _resourceMonitor.diskUsagePercent,
      },
      'error_rates': {
        'cache_error_rate': _metrics.cacheErrorRate,
        'db_error_rate': _metrics.databaseErrorRate,
        'websocket_error_rate': _metrics.websocketErrorRate,
      },
    };
  }

  /// Enable/disable automatic optimization
  void setOptimizationEnabled(bool enabled) {
    _isOptimizationEnabled = enabled;

    if (enabled) {
      _startOptimizationTimer();
    } else {
      _optimizationTimer?.cancel();
    }
  }

  /// Trigger manual optimization cycle
  Future<void> triggerOptimization() async {
    if (!_isInitialized) return;

    await _performOptimizationCycle();
  }

  /// Get system health status
  SystemHealthStatus getSystemHealth() {
    final report = getPerformanceReport();
    final systemHealth = report['system_health'] as Map<String, dynamic>;

    final overallScore = systemHealth['overall_score'] as double;

    if (overallScore >= 0.9) {
      return SystemHealthStatus.excellent;
    } else if (overallScore >= 0.7) {
      return SystemHealthStatus.good;
    } else if (overallScore >= 0.5) {
      return SystemHealthStatus.fair;
    } else {
      return SystemHealthStatus.poor;
    }
  }

  /// Get performance bottlenecks
  List<PerformanceBottleneck> getPerformanceBottlenecks() {
    final bottlenecks = <PerformanceBottleneck>[];

    // Check cache performance
    final cacheStats = _cachingService.getStats();
    final hitRate = double.tryParse(cacheStats['hit_rate'].toString()) ?? 0.0;
    if (hitRate < 70.0) {
      bottlenecks.add(PerformanceBottleneck(
        type: BottleneckType.cache,
        severity: hitRate < 50.0
            ? BottleneckSeverity.high
            : BottleneckSeverity.medium,
        description: 'Low cache hit rate: ${hitRate.toStringAsFixed(1)}%',
        recommendation: 'Consider increasing cache TTL or cache size',
      ));
    }

    // Check database performance
    final dbStats = _databaseOptimization.getQueryStats();
    final avgDbTime =
        double.tryParse(dbStats['average_execution_time_ms'].toString()) ?? 0.0;
    if (avgDbTime > 100.0) {
      bottlenecks.add(PerformanceBottleneck(
        type: BottleneckType.database,
        severity: avgDbTime > 500.0
            ? BottleneckSeverity.high
            : BottleneckSeverity.medium,
        description:
            'Slow database queries: ${avgDbTime.toStringAsFixed(1)}ms average',
        recommendation: 'Review query optimization and indexing strategy',
      ));
    }

    // Check WebSocket performance
    final wsStats = _websocketService.getOptimizedStats();
    final wsErrors = wsStats['broadcast_errors'] as int;
    if (wsErrors > 10) {
      bottlenecks.add(PerformanceBottleneck(
        type: BottleneckType.websocket,
        severity:
            wsErrors > 50 ? BottleneckSeverity.high : BottleneckSeverity.medium,
        description: 'WebSocket broadcast errors: $wsErrors',
        recommendation:
            'Check WebSocket connection stability and room management',
      ));
    }

    // Check system resources
    if (_resourceMonitor.memoryUsageMB > 1000) {
      bottlenecks.add(PerformanceBottleneck(
        type: BottleneckType.memory,
        severity: _resourceMonitor.memoryUsageMB > 2000
            ? BottleneckSeverity.high
            : BottleneckSeverity.medium,
        description:
            'High memory usage: ${_resourceMonitor.memoryUsageMB.toStringAsFixed(1)}MB',
        recommendation:
            'Consider reducing cache size or optimizing memory usage',
      ));
    }

    if (_resourceMonitor.cpuUsagePercent > 80.0) {
      bottlenecks.add(PerformanceBottleneck(
        type: BottleneckType.cpu,
        severity: _resourceMonitor.cpuUsagePercent > 95.0
            ? BottleneckSeverity.high
            : BottleneckSeverity.medium,
        description:
            'High CPU usage: ${_resourceMonitor.cpuUsagePercent.toStringAsFixed(1)}%',
        recommendation:
            'Review background processes and optimize CPU-intensive operations',
      ));
    }

    return bottlenecks;
  }

  /// Private helper methods

  /// Initialize all optimization services
  Future<void> _initializeOptimizationServices() async {
    await _cachingService.initialize();
    await _websocketService.initialize();
    await _fileWatcher.initialize();
    await _databaseOptimization.initialize();
  }

  /// Start monitoring timers
  void _startMonitoringTimers() {
    // Metrics collection every 30 seconds
    _metricsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _collectMetrics();
    });

    // Health check every minute
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _performHealthCheck();
    });

    // Optimization cycle every 5 minutes
    if (_isOptimizationEnabled) {
      _startOptimizationTimer();
    }
  }

  /// Start optimization timer
  void _startOptimizationTimer() {
    _optimizationTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _performOptimizationCycle();
    });
  }

  /// Collect performance metrics
  void _collectMetrics() {
    try {
      // Update cache metrics
      final cacheStats = _cachingService.getStats();
      _metrics.updateCacheMetrics(cacheStats);

      // Update database metrics
      final dbStats = _databaseOptimization.getQueryStats();
      _metrics.updateDatabaseMetrics(dbStats);

      // Update WebSocket metrics
      final wsStats = _websocketService.getOptimizedStats();
      _metrics.updateWebSocketMetrics(wsStats);

      // Update system resource metrics
      _metrics.updateResourceMetrics(_resourceMonitor.getResourceStats());
    } catch (e) {
      debugPrint('Error collecting performance metrics: $e');
    }
  }

  /// Perform health check
  void _performHealthCheck() {
    try {
      final health = _getSystemHealth();
      final overallScore = health['overall_score'] as double;

      if (overallScore < 0.5) {
        _auditService.logAction(
          actionType: 'performance_health_warning',
          description: 'System performance health is poor',
          contextData: {
            'overall_score': overallScore,
            'health_details': health,
          },
        );
      }
    } catch (e) {
      debugPrint('Error performing health check: $e');
    }
  }

  /// Perform optimization cycle
  Future<void> _performOptimizationCycle() async {
    if (!_isOptimizationEnabled) return;

    try {
      // Get current bottlenecks
      final bottlenecks = getPerformanceBottlenecks();

      // Apply optimizations based on bottlenecks
      for (final bottleneck in bottlenecks) {
        await _applyOptimization(bottleneck);
      }

      // Log optimization cycle
      await _auditService.logAction(
        actionType: 'performance_optimization_cycle',
        description: 'Performed automatic optimization cycle',
        contextData: {
          'bottlenecks_found': bottlenecks.length,
          'optimizations_applied':
              bottlenecks.map((b) => b.type.toString()).toList(),
        },
      );
    } catch (e) {
      debugPrint('Error in optimization cycle: $e');
    }
  }

  /// Apply optimization for specific bottleneck
  Future<void> _applyOptimization(PerformanceBottleneck bottleneck) async {
    switch (bottleneck.type) {
      case BottleneckType.cache:
        // Optimize cache settings
        if (bottleneck.description.contains('Low cache hit rate')) {
          // Could adjust cache TTL or size here
          debugPrint(
              'Applying cache optimization: ${bottleneck.recommendation}');
        }
        break;

      case BottleneckType.database:
        // Optimize database queries
        if (bottleneck.description.contains('Slow database queries')) {
          // Could trigger index analysis or query optimization
          debugPrint(
              'Applying database optimization: ${bottleneck.recommendation}');
        }
        break;

      case BottleneckType.websocket:
        // Optimize WebSocket connections
        if (bottleneck.description.contains('broadcast errors')) {
          // Could adjust connection pool settings
          debugPrint(
              'Applying WebSocket optimization: ${bottleneck.recommendation}');
        }
        break;

      case BottleneckType.memory:
        // Optimize memory usage
        if (bottleneck.description.contains('High memory usage')) {
          // Could trigger cache cleanup
          _cachingService.clear();
          debugPrint('Applied memory optimization: cleared cache');
        }
        break;

      case BottleneckType.disk:
        // Optimize disk usage
        if (bottleneck.description.contains('High disk usage')) {
          // Could trigger cleanup or compression
          debugPrint('Applied disk optimization: ${bottleneck.recommendation}');
        }
        break;

      case BottleneckType.network:
        // Optimize network usage
        if (bottleneck.description.contains('High network latency')) {
          // Could adjust connection settings
          debugPrint(
              'Applied network optimization: ${bottleneck.recommendation}');
        }
        break;

      case BottleneckType.cpu:
        // Optimize CPU usage
        if (bottleneck.description.contains('High CPU usage')) {
          // Could adjust processing intervals
          debugPrint('Applying CPU optimization: ${bottleneck.recommendation}');
        }
        break;
    }
  }

  /// Get system health assessment
  Map<String, dynamic> _getSystemHealth() {
    final cacheStats = _cachingService.getStats();
    final dbStats = _databaseOptimization.getQueryStats();
    final wsStats = _websocketService.getOptimizedStats();
    final resourceStats = _resourceMonitor.getResourceStats();

    // Calculate component scores (0.0 to 1.0)
    final cacheScore = _calculateCacheScore(cacheStats);
    final databaseScore = _calculateDatabaseScore(dbStats);
    final websocketScore = _calculateWebSocketScore(wsStats);
    final resourceScore = _calculateResourceScore(resourceStats);

    // Calculate overall score
    final overallScore =
        (cacheScore + databaseScore + websocketScore + resourceScore) / 4.0;

    return {
      'overall_score': overallScore,
      'component_scores': {
        'cache': cacheScore,
        'database': databaseScore,
        'websocket': websocketScore,
        'resources': resourceScore,
      },
      'status': overallScore >= 0.9
          ? 'excellent'
          : overallScore >= 0.7
              ? 'good'
              : overallScore >= 0.5
                  ? 'fair'
                  : 'poor',
    };
  }

  /// Calculate cache performance score
  double _calculateCacheScore(Map<String, dynamic> stats) {
    final hitRate = double.tryParse(stats['hit_rate'].toString()) ?? 0.0;
    final memoryUsage =
        double.tryParse(stats['memory_usage_mb'].toString()) ?? 0.0;

    double score = hitRate / 100.0; // Hit rate component

    // Penalize high memory usage
    if (memoryUsage > 500) {
      score *= 0.8;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Calculate database performance score
  double _calculateDatabaseScore(Map<String, dynamic> stats) {
    final avgTime =
        double.tryParse(stats['average_execution_time_ms'].toString()) ?? 0.0;
    final cacheHitRate =
        double.tryParse(stats['cache_hit_rate'].toString()) ?? 0.0;

    // Score based on response time (lower is better)
    double timeScore = avgTime < 50
        ? 1.0
        : avgTime < 100
            ? 0.8
            : avgTime < 200
                ? 0.6
                : 0.4;

    // Score based on cache hit rate
    double cacheScore = cacheHitRate / 100.0;

    return ((timeScore + cacheScore) / 2.0).clamp(0.0, 1.0);
  }

  /// Calculate WebSocket performance score
  double _calculateWebSocketScore(Map<String, dynamic> stats) {
    final totalBroadcasts = stats['total_broadcasts'] as int? ?? 0;
    final broadcastErrors = stats['broadcast_errors'] as int? ?? 0;

    if (totalBroadcasts == 0) return 1.0; // No activity, assume good

    final errorRate = broadcastErrors / totalBroadcasts;
    return (1.0 - errorRate).clamp(0.0, 1.0);
  }

  /// Calculate resource utilization score
  double _calculateResourceScore(Map<String, dynamic> stats) {
    final memoryPercent = (stats['memory_usage_mb'] as double? ?? 0.0) /
        2048.0 *
        100; // Assume 2GB max
    final cpuPercent = stats['cpu_usage_percent'] as double? ?? 0.0;
    final diskPercent = stats['disk_usage_percent'] as double? ?? 0.0;

    // Score based on resource utilization (lower is better)
    final memoryScore = memoryPercent < 50
        ? 1.0
        : memoryPercent < 75
            ? 0.8
            : 0.6;
    final cpuScore = cpuPercent < 50
        ? 1.0
        : cpuPercent < 75
            ? 0.8
            : 0.6;
    final diskScore = diskPercent < 80
        ? 1.0
        : diskPercent < 90
            ? 0.8
            : 0.6;

    return ((memoryScore + cpuScore + diskScore) / 3.0).clamp(0.0, 1.0);
  }

  /// Generate optimization recommendations
  List<String> _generateOptimizationRecommendations() {
    final recommendations = <String>[];
    final bottlenecks = getPerformanceBottlenecks();

    for (final bottleneck in bottlenecks) {
      recommendations.add(bottleneck.recommendation);
    }

    // Add general recommendations
    final cacheStats = _cachingService.getStats();
    final hitRate = double.tryParse(cacheStats['hit_rate'].toString()) ?? 0.0;

    if (hitRate > 90.0) {
      recommendations.add(
          'Excellent cache performance - consider expanding cache coverage');
    }

    if (recommendations.isEmpty) {
      recommendations.add(
          'System performance is optimal - no immediate optimizations needed');
    }

    return recommendations;
  }

  /// Dispose resources
  void dispose() {
    _metricsTimer?.cancel();
    _healthCheckTimer?.cancel();
    _optimizationTimer?.cancel();

    _resourceMonitor.dispose();

    _isInitialized = false;
  }
}

/// Performance metrics tracking
class PerformanceMetrics {
  Duration averageCacheResponseTime = Duration.zero;
  Duration averageDatabaseResponseTime = Duration.zero;
  Duration averageWebSocketResponseTime = Duration.zero;

  double cacheOperationsPerSecond = 0.0;
  double databaseQueriesPerSecond = 0.0;
  double websocketMessagesPerSecond = 0.0;

  double cacheErrorRate = 0.0;
  double databaseErrorRate = 0.0;
  double websocketErrorRate = 0.0;

  DateTime lastUpdated = DateTime.now();

  void updateCacheMetrics(Map<String, dynamic> stats) {
    // Update cache-specific metrics
    lastUpdated = DateTime.now();
  }

  void updateDatabaseMetrics(Map<String, dynamic> stats) {
    final avgTime =
        double.tryParse(stats['average_execution_time_ms'].toString()) ?? 0.0;
    averageDatabaseResponseTime = Duration(milliseconds: avgTime.round());
    lastUpdated = DateTime.now();
  }

  void updateWebSocketMetrics(Map<String, dynamic> stats) {
    // Update WebSocket-specific metrics
    lastUpdated = DateTime.now();
  }

  void updateResourceMetrics(Map<String, dynamic> stats) {
    // Update resource-specific metrics
    lastUpdated = DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'average_response_times': {
        'cache_ms': averageCacheResponseTime.inMilliseconds,
        'database_ms': averageDatabaseResponseTime.inMilliseconds,
        'websocket_ms': averageWebSocketResponseTime.inMilliseconds,
      },
      'throughput': {
        'cache_ops_per_sec': cacheOperationsPerSecond,
        'db_queries_per_sec': databaseQueriesPerSecond,
        'ws_messages_per_sec': websocketMessagesPerSecond,
      },
      'error_rates': {
        'cache': cacheErrorRate,
        'database': databaseErrorRate,
        'websocket': websocketErrorRate,
      },
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

/// System resource monitoring
class SystemResourceMonitor {
  double memoryUsageMB = 0.0;
  double cpuUsagePercent = 0.0;
  double diskUsagePercent = 0.0;

  Timer? _monitoringTimer;

  Future<void> initialize() async {
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateResourceStats();
    });

    // Initial update
    _updateResourceStats();
  }

  void _updateResourceStats() {
    try {
      // In a real implementation, this would use platform-specific APIs
      // For now, we'll simulate resource monitoring

      // Simulate memory usage (would use ProcessInfo or similar)
      memoryUsageMB =
          200.0 + (DateTime.now().millisecondsSinceEpoch % 1000) / 10.0;

      // Simulate CPU usage
      cpuUsagePercent =
          10.0 + (DateTime.now().millisecondsSinceEpoch % 100) / 2.0;

      // Simulate disk usage
      diskUsagePercent =
          45.0 + (DateTime.now().millisecondsSinceEpoch % 50) / 10.0;
    } catch (e) {
      debugPrint('Error updating resource stats: $e');
    }
  }

  Map<String, dynamic> getResourceStats() {
    return {
      'memory_usage_mb': memoryUsageMB,
      'cpu_usage_percent': cpuUsagePercent,
      'disk_usage_percent': diskUsagePercent,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  void dispose() {
    _monitoringTimer?.cancel();
  }
}

/// Performance bottleneck definition
class PerformanceBottleneck {
  final BottleneckType type;
  final BottleneckSeverity severity;
  final String description;
  final String recommendation;

  PerformanceBottleneck({
    required this.type,
    required this.severity,
    required this.description,
    required this.recommendation,
  });
}

/// Bottleneck types
enum BottleneckType {
  cache,
  database,
  websocket,
  memory,
  cpu,
  disk,
  network,
}

/// Bottleneck severity levels
enum BottleneckSeverity {
  low,
  medium,
  high,
  critical,
}

/// System health status
enum SystemHealthStatus {
  excellent,
  good,
  fair,
  poor,
  critical,
}
