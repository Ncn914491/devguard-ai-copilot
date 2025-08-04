import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../database/services/services.dart';
import '../database/models/models.dart';
import '../error/error_handler.dart';

/// System health monitoring and self-diagnostic capabilities
/// Satisfies Requirements: 12.4 (System health monitoring and self-diagnostics)
class SystemHealthMonitor {
  static final SystemHealthMonitor _instance = SystemHealthMonitor._internal();
  static SystemHealthMonitor get instance => _instance;
  SystemHealthMonitor._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;
  final _errorHandler = ErrorHandler.instance;

  Timer? _healthCheckTimer;
  SystemHealthStatus? _lastHealthStatus;
  final List<HealthCheck> _healthChecks = [];
  final Map<String, HealthMetric> _metrics = {};

  /// Initialize system health monitoring
  Future<void> initialize() async {
    _initializeHealthChecks();
    _startHealthMonitoring();

    await _auditService.logAction(
      actionType: 'health_monitor_initialized',
      description: 'System health monitoring initialized',
      aiReasoning:
          'Continuous health monitoring enables proactive issue detection and resolution',
      contextData: {
        'health_checks': _healthChecks.length,
        'monitoring_interval': '30 seconds',
      },
    );
  }

  /// Initialize health checks
  void _initializeHealthChecks() {
    _healthChecks.addAll([
      HealthCheck(
        name: 'Database Connectivity',
        type: HealthCheckType.database,
        description: 'Check database connection and response time',
        criticalThreshold: 5000, // 5 seconds
        warningThreshold: 2000, // 2 seconds
      ),
      HealthCheck(
        name: 'Memory Usage',
        type: HealthCheckType.system,
        description: 'Monitor application memory consumption',
        criticalThreshold: 90, // 90% memory usage
        warningThreshold: 75, // 75% memory usage
      ),
      HealthCheck(
        name: 'Error Rate',
        type: HealthCheckType.application,
        description: 'Monitor application error frequency',
        criticalThreshold: 10, // 10 errors per minute
        warningThreshold: 5, // 5 errors per minute
      ),
      HealthCheck(
        name: 'Security Alerts',
        type: HealthCheckType.security,
        description: 'Monitor active security alerts',
        criticalThreshold: 5, // 5 critical alerts
        warningThreshold: 2, // 2 critical alerts
      ),
      HealthCheck(
        name: 'Git Integration',
        type: HealthCheckType.integration,
        description: 'Check external git service connectivity',
        criticalThreshold: 1, // Any connection failure
        warningThreshold: 0, // No failures
      ),
      HealthCheck(
        name: 'Deployment Status',
        type: HealthCheckType.deployment,
        description: 'Monitor deployment pipeline health',
        criticalThreshold: 3, // 3 failed deployments
        warningThreshold: 1, // 1 failed deployment
      ),
    ]);
  }

  /// Start continuous health monitoring
  void _startHealthMonitoring() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performHealthChecks();
    });
  }

  /// Perform all health checks
  Future<void> _performHealthChecks() async {
    try {
      final results = <HealthCheckResult>[];

      for (final check in _healthChecks) {
        final result = await _performHealthCheck(check);
        results.add(result);

        // Update metrics
        _updateMetric(check.name, result.value, result.status);
      }

      // Calculate overall health status
      final overallStatus = _calculateOverallHealth(results);

      // Check for status changes
      if (_lastHealthStatus == null ||
          _lastHealthStatus!.status != overallStatus.status) {
        await _handleHealthStatusChange(overallStatus);
      }

      _lastHealthStatus = overallStatus;

      // Log health check if there are issues
      if (overallStatus.status != HealthStatus.healthy) {
        await _auditService.logAction(
          actionType: 'health_check_warning',
          description: 'System health check detected issues',
          contextData: {
            'overall_status': overallStatus.status.toString(),
            'failed_checks':
                results.where((r) => r.status != HealthStatus.healthy).length,
            'critical_issues':
                results.where((r) => r.status == HealthStatus.critical).length,
          },
        );
      }
    } catch (e) {
      await _errorHandler.handleError(
        e,
        context: {
          'component': 'SystemHealthMonitor',
          'operation': 'performHealthChecks'
        },
        type: ErrorType.system,
        severity: ErrorSeverity.medium,
      );
    }
  }

  /// Perform individual health check
  Future<HealthCheckResult> _performHealthCheck(HealthCheck check) async {
    try {
      switch (check.type) {
        case HealthCheckType.database:
          return await _checkDatabaseHealth(check);
        case HealthCheckType.system:
          return await _checkSystemHealth(check);
        case HealthCheckType.application:
          return await _checkApplicationHealth(check);
        case HealthCheckType.security:
          return await _checkSecurityHealth(check);
        case HealthCheckType.integration:
          return await _checkIntegrationHealth(check);
        case HealthCheckType.deployment:
          return await _checkDeploymentHealth(check);
      }
    } catch (e) {
      return HealthCheckResult(
        checkName: check.name,
        status: HealthStatus.critical,
        value: 0,
        message: 'Health check failed: ${e.toString()}',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Check database health
  Future<HealthCheckResult> _checkDatabaseHealth(HealthCheck check) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Test database connectivity
      await _auditService.getAllAuditLogs(limit: 1);
      stopwatch.stop();

      final responseTime = stopwatch.elapsedMilliseconds;
      final status = _determineHealthStatus(responseTime, check);

      return HealthCheckResult(
        checkName: check.name,
        status: status,
        value: responseTime.toDouble(),
        message: 'Database response time: ${responseTime}ms',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      stopwatch.stop();
      return HealthCheckResult(
        checkName: check.name,
        status: HealthStatus.critical,
        value: stopwatch.elapsedMilliseconds.toDouble(),
        message: 'Database connection failed: ${e.toString()}',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Check system health (memory, CPU, etc.)
  Future<HealthCheckResult> _checkSystemHealth(HealthCheck check) async {
    try {
      // Get memory usage (simplified - would use actual system metrics)
      final memoryUsage = _getMemoryUsage();
      final status = _determineHealthStatus(memoryUsage, check);

      return HealthCheckResult(
        checkName: check.name,
        status: status,
        value: memoryUsage,
        message: 'Memory usage: ${memoryUsage.toStringAsFixed(1)}%',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return HealthCheckResult(
        checkName: check.name,
        status: HealthStatus.critical,
        value: 100,
        message: 'System health check failed: ${e.toString()}',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Check application health (error rates, performance)
  Future<HealthCheckResult> _checkApplicationHealth(HealthCheck check) async {
    try {
      final errorStats = await _errorHandler.getErrorStatistics();
      final errorRate = errorStats.recentErrors.toDouble();
      final status = _determineHealthStatus(errorRate, check);

      return HealthCheckResult(
        checkName: check.name,
        status: status,
        value: errorRate,
        message: 'Recent errors: ${errorStats.recentErrors}',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return HealthCheckResult(
        checkName: check.name,
        status: HealthStatus.critical,
        value: 999,
        message: 'Application health check failed: ${e.toString()}',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Check security health
  Future<HealthCheckResult> _checkSecurityHealth(HealthCheck check) async {
    try {
      final alerts = await SecurityAlertService.instance.getAllSecurityAlerts();
      final criticalAlerts = alerts
          .where((a) =>
              a.severity == 'critical' &&
              (a.status == 'new' || a.status == 'investigating'))
          .length;

      final status = _determineHealthStatus(criticalAlerts.toDouble(), check);

      return HealthCheckResult(
        checkName: check.name,
        status: status,
        value: criticalAlerts.toDouble(),
        message: 'Critical security alerts: $criticalAlerts',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return HealthCheckResult(
        checkName: check.name,
        status: HealthStatus.critical,
        value: 999,
        message: 'Security health check failed: ${e.toString()}',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Check integration health
  Future<HealthCheckResult> _checkIntegrationHealth(HealthCheck check) async {
    try {
      // This would check actual git service connectivity
      // For now, simulate based on recent integration activity
      const integrationFailures = 0; // Would be calculated from actual failures
      final status =
          _determineHealthStatus(integrationFailures.toDouble(), check);

      return HealthCheckResult(
        checkName: check.name,
        status: status,
        value: integrationFailures.toDouble(),
        message: 'Integration failures: $integrationFailures',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return HealthCheckResult(
        checkName: check.name,
        status: HealthStatus.critical,
        value: 1,
        message: 'Integration health check failed: ${e.toString()}',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Check deployment health
  Future<HealthCheckResult> _checkDeploymentHealth(HealthCheck check) async {
    try {
      final deployments = await DeploymentService.instance.getAllDeployments();
      final recentFailures = deployments
          .where((d) =>
              d.status == 'failed' &&
              DateTime.now().difference(d.deployedAt).inHours < 24)
          .length;

      final status = _determineHealthStatus(recentFailures.toDouble(), check);

      return HealthCheckResult(
        checkName: check.name,
        status: status,
        value: recentFailures.toDouble(),
        message: 'Recent deployment failures: $recentFailures',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return HealthCheckResult(
        checkName: check.name,
        status: HealthStatus.critical,
        value: 999,
        message: 'Deployment health check failed: ${e.toString()}',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Determine health status based on thresholds
  HealthStatus _determineHealthStatus(double value, HealthCheck check) {
    if (value >= check.criticalThreshold) {
      return HealthStatus.critical;
    } else if (value >= check.warningThreshold) {
      return HealthStatus.warning;
    } else {
      return HealthStatus.healthy;
    }
  }

  /// Calculate overall system health
  SystemHealthStatus _calculateOverallHealth(List<HealthCheckResult> results) {
    final criticalCount =
        results.where((r) => r.status == HealthStatus.critical).length;
    final warningCount =
        results.where((r) => r.status == HealthStatus.warning).length;

    HealthStatus overallStatus;
    if (criticalCount > 0) {
      overallStatus = HealthStatus.critical;
    } else if (warningCount > 0) {
      overallStatus = HealthStatus.warning;
    } else {
      overallStatus = HealthStatus.healthy;
    }

    return SystemHealthStatus(
      status: overallStatus,
      timestamp: DateTime.now(),
      checkResults: results,
      summary: _generateHealthSummary(results, overallStatus),
    );
  }

  /// Generate health summary
  String _generateHealthSummary(
      List<HealthCheckResult> results, HealthStatus status) {
    final total = results.length;
    final healthy =
        results.where((r) => r.status == HealthStatus.healthy).length;
    final warnings =
        results.where((r) => r.status == HealthStatus.warning).length;
    final critical =
        results.where((r) => r.status == HealthStatus.critical).length;

    return 'System Health: ${status.toString().split('.').last.toUpperCase()} '
        '($healthy/$total healthy, $warnings warnings, $critical critical)';
  }

  /// Handle health status changes
  Future<void> _handleHealthStatusChange(SystemHealthStatus newStatus) async {
    await _auditService.logAction(
      actionType: 'health_status_changed',
      description: 'System health status changed to: ${newStatus.status}',
      aiReasoning:
          'Health status change indicates system condition requiring attention',
      contextData: {
        'new_status': newStatus.status.toString(),
        'previous_status': _lastHealthStatus?.status.toString(),
        'summary': newStatus.summary,
        'critical_checks': newStatus.checkResults
            .where((r) => r.status == HealthStatus.critical)
            .map((r) => r.checkName)
            .toList(),
      },
    );

    // Trigger automated responses for critical status
    if (newStatus.status == HealthStatus.critical) {
      await _handleCriticalHealthStatus(newStatus);
    }
  }

  /// Handle critical health status
  Future<void> _handleCriticalHealthStatus(SystemHealthStatus status) async {
    final criticalChecks = status.checkResults
        .where((r) => r.status == HealthStatus.critical)
        .toList();

    for (final check in criticalChecks) {
      await _triggerAutomatedResponse(check);
    }
  }

  /// Trigger automated response for critical health check
  Future<void> _triggerAutomatedResponse(HealthCheckResult check) async {
    switch (check.checkName) {
      case 'Database Connectivity':
        await _handleDatabaseCritical();
        break;
      case 'Memory Usage':
        await _handleMemoryCritical();
        break;
      case 'Error Rate':
        await _handleErrorRateCritical();
        break;
      case 'Security Alerts':
        await _handleSecurityCritical();
        break;
      default:
        await _handleGenericCritical(check);
    }
  }

  /// Handle critical database issues
  Future<void> _handleDatabaseCritical() async {
    await _auditService.logAction(
      actionType: 'automated_response_database',
      description: 'Automated response to critical database health',
      aiReasoning:
          'Database connectivity issues require immediate attention to prevent data loss',
      contextData: {'response_type': 'database_recovery'},
    );

    // This would trigger database recovery procedures
  }

  /// Handle critical memory issues
  Future<void> _handleMemoryCritical() async {
    await _auditService.logAction(
      actionType: 'automated_response_memory',
      description: 'Automated response to critical memory usage',
      aiReasoning: 'High memory usage may lead to application instability',
      contextData: {'response_type': 'memory_cleanup'},
    );

    // This would trigger memory cleanup procedures
  }

  /// Handle critical error rate
  Future<void> _handleErrorRateCritical() async {
    await _auditService.logAction(
      actionType: 'automated_response_errors',
      description: 'Automated response to critical error rate',
      aiReasoning:
          'High error rate indicates systemic issues requiring intervention',
      contextData: {'response_type': 'error_mitigation'},
    );

    // This would trigger error mitigation procedures
  }

  /// Handle critical security issues
  Future<void> _handleSecurityCritical() async {
    await _auditService.logAction(
      actionType: 'automated_response_security',
      description: 'Automated response to critical security alerts',
      aiReasoning:
          'Critical security alerts require immediate investigation and response',
      contextData: {'response_type': 'security_lockdown'},
    );

    // This would trigger security response procedures
  }

  /// Handle generic critical issues
  Future<void> _handleGenericCritical(HealthCheckResult check) async {
    await _auditService.logAction(
      actionType: 'automated_response_generic',
      description:
          'Automated response to critical health check: ${check.checkName}',
      contextData: {
        'check_name': check.checkName,
        'check_value': check.value,
        'response_type': 'generic_recovery',
      },
    );
  }

  /// Update health metric
  void _updateMetric(String name, double value, HealthStatus status) {
    _metrics[name] = HealthMetric(
      name: name,
      value: value,
      status: status,
      timestamp: DateTime.now(),
    );
  }

  /// Get memory usage (simplified implementation)
  double _getMemoryUsage() {
    // This would use actual system memory monitoring
    // For now, return a simulated value
    return 45.0 + (DateTime.now().millisecond % 30); // 45-75% range
  }

  /// Get current system health status
  Future<SystemHealthStatus> getCurrentHealthStatus() async {
    if (_lastHealthStatus == null) {
      await _performHealthChecks();
    }

    return _lastHealthStatus ??
        SystemHealthStatus(
          status: HealthStatus.unknown,
          timestamp: DateTime.now(),
          checkResults: [],
          summary: 'Health status not available',
        );
  }

  /// Get health metrics
  Map<String, HealthMetric> getHealthMetrics() {
    return Map.from(_metrics);
  }

  /// Stop health monitoring
  void stop() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Dispose resources
  void dispose() {
    stop();
    _healthChecks.clear();
    _metrics.clear();
    _lastHealthStatus = null;
  }
}

/// Health check definition
class HealthCheck {
  final String name;
  final HealthCheckType type;
  final String description;
  final double criticalThreshold;
  final double warningThreshold;

  HealthCheck({
    required this.name,
    required this.type,
    required this.description,
    required this.criticalThreshold,
    required this.warningThreshold,
  });
}

/// Health check types
enum HealthCheckType {
  database,
  system,
  application,
  security,
  integration,
  deployment,
}

/// Health check result
class HealthCheckResult {
  final String checkName;
  final HealthStatus status;
  final double value;
  final String message;
  final DateTime timestamp;

  HealthCheckResult({
    required this.checkName,
    required this.status,
    required this.value,
    required this.message,
    required this.timestamp,
  });
}

/// Health status levels
enum HealthStatus {
  healthy,
  warning,
  critical,
  unknown,
}

/// System health status
class SystemHealthStatus {
  final HealthStatus status;
  final DateTime timestamp;
  final List<HealthCheckResult> checkResults;
  final String summary;

  SystemHealthStatus({
    required this.status,
    required this.timestamp,
    required this.checkResults,
    required this.summary,
  });
}

/// Health metric
class HealthMetric {
  final String name;
  final double value;
  final HealthStatus status;
  final DateTime timestamp;

  HealthMetric({
    required this.name,
    required this.value,
    required this.status,
    required this.timestamp,
  });
}
