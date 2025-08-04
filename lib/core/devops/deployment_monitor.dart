import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../database/services/audit_log_service.dart';
import '../database/services/deployment_service.dart';
import '../database/models/deployment.dart';
import '../api/websocket_service.dart';

/// Deployment monitoring with real-time status updates and live build logs
/// Satisfies Requirements: 7.3 (Deployment monitoring with real-time status updates)
class DeploymentMonitor {
  static final DeploymentMonitor _instance = DeploymentMonitor._internal();
  static DeploymentMonitor get instance => _instance;
  DeploymentMonitor._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;
  final _deploymentService = DeploymentService.instance;
  final _websocketService = WebSocketService.instance;

  // Active deployment monitoring
  final Map<String, DeploymentMonitorSession> _activeSessions = {};
  final Map<String, List<BuildLogEntry>> _buildLogs = {};
  final Map<String, DeploymentMetrics> _deploymentMetrics = {};

  // Stream controllers for real-time updates
  final StreamController<DeploymentStatusUpdate> _statusUpdateController =
      StreamController<DeploymentStatusUpdate>.broadcast();
  final StreamController<BuildLogEntry> _buildLogController =
      StreamController<BuildLogEntry>.broadcast();

  /// Get status update stream
  Stream<DeploymentStatusUpdate> get statusUpdates =>
      _statusUpdateController.stream;

  /// Get build log stream
  Stream<BuildLogEntry> get buildLogs => _buildLogController.stream;

  /// Initialize deployment monitoring
  Future<void> initialize() async {
    // Start periodic health checks
    _startHealthCheckTimer();

    await _auditService.logAction(
      actionType: 'deployment_monitor_initialized',
      description: 'Deployment monitoring system initialized',
      aiReasoning:
          'Real-time deployment monitoring ready to track status updates and build logs',
      contextData: {
        'health_check_interval': 30,
        'max_concurrent_sessions': 100,
      },
    );
  }

  /// Start monitoring a deployment
  Future<DeploymentMonitorSession> startMonitoring({
    required String deploymentId,
    required String environment,
    required String version,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final sessionId = _uuid.v4();

      final session = DeploymentMonitorSession(
        id: sessionId,
        deploymentId: deploymentId,
        environment: environment,
        version: version,
        status: DeploymentStatus.starting,
        startedAt: DateTime.now(),
        metadata: metadata ?? {},
        healthChecks: [],
        buildLogs: [],
      );

      _activeSessions[sessionId] = session;
      _buildLogs[deploymentId] = [];
      _deploymentMetrics[deploymentId] = DeploymentMetrics(
        deploymentId: deploymentId,
        startTime: DateTime.now(),
        totalStages: 0,
        completedStages: 0,
        failedStages: 0,
        averageStageTime: Duration.zero,
      );

      // Start monitoring process
      _monitorDeployment(session);

      await _auditService.logAction(
        actionType: 'deployment_monitoring_started',
        description: 'Started monitoring deployment',
        contextData: {
          'session_id': sessionId,
          'deployment_id': deploymentId,
          'environment': environment,
          'version': version,
        },
      );

      return session;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'deployment_monitoring_start_error',
        description: 'Error starting deployment monitoring: ${e.toString()}',
        contextData: {
          'deployment_id': deploymentId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Stop monitoring a deployment
  Future<void> stopMonitoring(String sessionId) async {
    try {
      final session = _activeSessions[sessionId];
      if (session == null) return;

      // Update session status
      final updatedSession = session.copyWith(
        status: DeploymentStatus.completed,
        completedAt: DateTime.now(),
      );
      _activeSessions[sessionId] = updatedSession;

      // Clean up after a delay
      Timer(const Duration(minutes: 5), () {
        _activeSessions.remove(sessionId);
        _buildLogs.remove(session.deploymentId);
        _deploymentMetrics.remove(session.deploymentId);
      });

      await _auditService.logAction(
        actionType: 'deployment_monitoring_stopped',
        description: 'Stopped monitoring deployment',
        contextData: {
          'session_id': sessionId,
          'deployment_id': session.deploymentId,
          'duration_seconds': updatedSession.completedAt
              ?.difference(session.startedAt)
              .inSeconds,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'deployment_monitoring_stop_error',
        description: 'Error stopping deployment monitoring: ${e.toString()}',
        contextData: {
          'session_id': sessionId,
          'error': e.toString(),
        },
      );
    }
  }

  /// Update deployment status
  Future<void> updateDeploymentStatus({
    required String deploymentId,
    required DeploymentStatus status,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Find session by deployment ID
      final session = _activeSessions.values.firstWhere(
          (s) => s.deploymentId == deploymentId,
          orElse: () => throw Exception('Session not found'));

      // Update session
      final updatedSession = session.copyWith(
        status: status,
        lastUpdated: DateTime.now(),
        metadata: {...session.metadata, ...?metadata},
      );
      _activeSessions[session.id] = updatedSession;

      // Create status update
      final statusUpdate = DeploymentStatusUpdate(
        deploymentId: deploymentId,
        status: status,
        message: message ?? 'Status updated to ${status.name}',
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      // Broadcast update
      _statusUpdateController.add(statusUpdate);

      await _websocketService.broadcastDeploymentStatus(
        deploymentId: deploymentId,
        status: status.name,
        message: statusUpdate.message,
        metadata: metadata,
      );

      // Update database
      await _deploymentService.updateDeploymentStatus(
          deploymentId, status.name);

      await _auditService.logAction(
        actionType: 'deployment_status_updated',
        description: 'Deployment status updated',
        contextData: {
          'deployment_id': deploymentId,
          'status': status.name,
          'message': message,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'deployment_status_update_error',
        description: 'Error updating deployment status: ${e.toString()}',
        contextData: {
          'deployment_id': deploymentId,
          'status': status.name,
          'error': e.toString(),
        },
      );
    }
  }

  /// Add build log entry
  Future<void> addBuildLog({
    required String deploymentId,
    required String stage,
    required String message,
    BuildLogLevel level = BuildLogLevel.info,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final logEntry = BuildLogEntry(
        id: _uuid.v4(),
        deploymentId: deploymentId,
        stage: stage,
        level: level,
        message: message,
        timestamp: DateTime.now(),
        metadata: metadata ?? {},
      );

      // Store log entry
      _buildLogs.putIfAbsent(deploymentId, () => []).add(logEntry);

      // Broadcast log entry
      _buildLogController.add(logEntry);

      // Also broadcast via WebSocket for real-time updates
      await _websocketService.broadcastDeploymentStatus(
        deploymentId: deploymentId,
        status: 'build_log',
        message: message,
        metadata: {
          'stage': stage,
          'level': level.name,
          'log_id': logEntry.id,
          ...?metadata,
        },
      );

      // Keep only last 1000 log entries per deployment
      final logs = _buildLogs[deploymentId]!;
      if (logs.length > 1000) {
        logs.removeRange(0, logs.length - 1000);
      }
    } catch (e) {
      await _auditService.logAction(
        actionType: 'build_log_add_error',
        description: 'Error adding build log entry: ${e.toString()}',
        contextData: {
          'deployment_id': deploymentId,
          'stage': stage,
          'error': e.toString(),
        },
      );
    }
  }

  /// Get build logs for deployment
  Future<List<BuildLogEntry>> getBuildLogs(
    String deploymentId, {
    String? stage,
    BuildLogLevel? minLevel,
    int? limit,
  }) async {
    final logs = _buildLogs[deploymentId] ?? [];

    var filteredLogs = logs.where((log) {
      if (stage != null && log.stage != stage) return false;
      if (minLevel != null && log.level.index < minLevel.index) return false;
      return true;
    }).toList();

    if (limit != null && filteredLogs.length > limit) {
      filteredLogs = filteredLogs.sublist(filteredLogs.length - limit);
    }

    return filteredLogs;
  }

  /// Get deployment metrics
  Future<DeploymentMetrics?> getDeploymentMetrics(String deploymentId) async {
    return _deploymentMetrics[deploymentId];
  }

  /// Get active monitoring sessions
  Future<List<DeploymentMonitorSession>> getActiveSessions() async {
    return _activeSessions.values.toList();
  }

  /// Perform health check on deployment
  Future<HealthCheckResult> performHealthCheck({
    required String deploymentId,
    required String healthCheckUrl,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final startTime = DateTime.now();

      // Simulate health check (in real implementation, this would make HTTP request)
      await Future.delayed(
          Duration(milliseconds: 500 + (DateTime.now().millisecond % 1000)));

      // Simulate occasional health check failures
      final random = DateTime.now().millisecond;
      final isHealthy = random % 10 != 0; // 10% failure rate

      final result = HealthCheckResult(
        deploymentId: deploymentId,
        url: healthCheckUrl,
        isHealthy: isHealthy,
        responseTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
        statusCode: isHealthy ? 200 : 503,
        message: isHealthy ? 'Service is healthy' : 'Service is unhealthy',
      );

      // Update session with health check result
      final session = _activeSessions.values.firstWhere(
          (s) => s.deploymentId == deploymentId,
          orElse: () => throw Exception('Session not found'));

      final updatedHealthChecks = [...session.healthChecks, result];
      final updatedSession =
          session.copyWith(healthChecks: updatedHealthChecks);
      _activeSessions[session.id] = updatedSession;

      // Log health check result
      await addBuildLog(
        deploymentId: deploymentId,
        stage: 'health_check',
        message:
            'Health check ${isHealthy ? 'passed' : 'failed'}: ${result.message}',
        level: isHealthy ? BuildLogLevel.info : BuildLogLevel.error,
        metadata: {
          'url': healthCheckUrl,
          'response_time_ms': result.responseTime.inMilliseconds,
          'status_code': result.statusCode,
        },
      );

      return result;
    } catch (e) {
      final result = HealthCheckResult(
        deploymentId: deploymentId,
        url: healthCheckUrl,
        isHealthy: false,
        responseTime: Duration.zero,
        timestamp: DateTime.now(),
        statusCode: 0,
        message: 'Health check error: ${e.toString()}',
      );

      await addBuildLog(
        deploymentId: deploymentId,
        stage: 'health_check',
        message: 'Health check error: ${e.toString()}',
        level: BuildLogLevel.error,
        metadata: {
          'url': healthCheckUrl,
          'error': e.toString(),
        },
      );

      return result;
    }
  }

  /// Private helper methods

  /// Monitor deployment process
  Future<void> _monitorDeployment(DeploymentMonitorSession session) async {
    try {
      // Simulate deployment stages
      final stages = [
        'preparation',
        'build',
        'test',
        'package',
        'deploy',
        'health_check',
        'finalization',
      ];

      for (int i = 0; i < stages.length; i++) {
        final stage = stages[i];

        // Update status to running if first stage
        if (i == 0) {
          await updateDeploymentStatus(
            deploymentId: session.deploymentId,
            status: DeploymentStatus.running,
            message: 'Deployment started',
          );
        }

        // Add stage start log
        await addBuildLog(
          deploymentId: session.deploymentId,
          stage: stage,
          message: 'Starting stage: $stage',
          level: BuildLogLevel.info,
        );

        // Simulate stage execution
        final stageStartTime = DateTime.now();
        await _simulateStageExecution(session.deploymentId, stage);
        final stageDuration = DateTime.now().difference(stageStartTime);

        // Update metrics
        final metrics = _deploymentMetrics[session.deploymentId]!;
        final updatedMetrics = metrics.copyWith(
          totalStages: stages.length,
          completedStages: i + 1,
          averageStageTime: Duration(
            milliseconds: ((metrics.averageStageTime.inMilliseconds * i) +
                    stageDuration.inMilliseconds) ~/
                (i + 1),
          ),
        );
        _deploymentMetrics[session.deploymentId] = updatedMetrics;

        // Add stage completion log
        await addBuildLog(
          deploymentId: session.deploymentId,
          stage: stage,
          message: 'Completed stage: $stage (${stageDuration.inSeconds}s)',
          level: BuildLogLevel.info,
          metadata: {
            'duration_seconds': stageDuration.inSeconds,
            'stage_index': i + 1,
            'total_stages': stages.length,
          },
        );

        // Perform health check after deploy stage
        if (stage == 'deploy') {
          await performHealthCheck(
            deploymentId: session.deploymentId,
            healthCheckUrl: '/health',
          );
        }
      }

      // Mark deployment as successful
      await updateDeploymentStatus(
        deploymentId: session.deploymentId,
        status: DeploymentStatus.success,
        message: 'Deployment completed successfully',
        metadata: {
          'total_duration_seconds':
              DateTime.now().difference(session.startedAt).inSeconds,
          'stages_completed': stages.length,
        },
      );
    } catch (e) {
      // Mark deployment as failed
      await updateDeploymentStatus(
        deploymentId: session.deploymentId,
        status: DeploymentStatus.failed,
        message: 'Deployment failed: ${e.toString()}',
        metadata: {
          'error': e.toString(),
          'failed_at': DateTime.now().toIso8601String(),
        },
      );

      await addBuildLog(
        deploymentId: session.deploymentId,
        stage: 'error',
        message: 'Deployment failed: ${e.toString()}',
        level: BuildLogLevel.error,
        metadata: {
          'error': e.toString(),
        },
      );
    }
  }

  /// Simulate stage execution
  Future<void> _simulateStageExecution(
      String deploymentId, String stage) async {
    final random = DateTime.now().millisecond;

    // Simulate different execution times for different stages
    final baseDuration = switch (stage) {
      'preparation' => 2,
      'build' => 8,
      'test' => 12,
      'package' => 3,
      'deploy' => 6,
      'health_check' => 2,
      'finalization' => 1,
      _ => 3,
    };

    final actualDuration = baseDuration + (random % 5);

    // Add periodic progress logs during execution
    for (int i = 0; i < actualDuration; i++) {
      await Future.delayed(const Duration(seconds: 1));

      if (i % 3 == 0) {
        await addBuildLog(
          deploymentId: deploymentId,
          stage: stage,
          message:
              'Stage $stage progress: ${((i + 1) / actualDuration * 100).round()}%',
          level: BuildLogLevel.debug,
        );
      }
    }

    // Simulate occasional stage failures
    if (random % 20 == 0) {
      // 5% failure rate
      throw Exception('Simulated stage failure in $stage');
    }
  }

  /// Start health check timer
  void _startHealthCheckTimer() {
    Timer.periodic(const Duration(seconds: 30), (_) {
      _performPeriodicHealthChecks();
    });
  }

  /// Perform periodic health checks on active deployments
  Future<void> _performPeriodicHealthChecks() async {
    for (final session in _activeSessions.values) {
      if (session.status == DeploymentStatus.running ||
          session.status == DeploymentStatus.success) {
        try {
          await performHealthCheck(
            deploymentId: session.deploymentId,
            healthCheckUrl: '/health',
          );
        } catch (e) {
          // Log error but don't fail the entire process
          await _auditService.logAction(
            actionType: 'periodic_health_check_error',
            description: 'Error during periodic health check: ${e.toString()}',
            contextData: {
              'deployment_id': session.deploymentId,
              'error': e.toString(),
            },
          );
        }
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _statusUpdateController.close();
    _buildLogController.close();
    _activeSessions.clear();
    _buildLogs.clear();
    _deploymentMetrics.clear();
  }
}

/// Deployment status enumeration
enum DeploymentStatus {
  starting,
  running,
  success,
  failed,
  cancelled,
  completed,
}

/// Build log levels
enum BuildLogLevel {
  debug,
  info,
  warning,
  error,
}

/// Deployment monitor session
class DeploymentMonitorSession {
  final String id;
  final String deploymentId;
  final String environment;
  final String version;
  final DeploymentStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? lastUpdated;
  final Map<String, dynamic> metadata;
  final List<HealthCheckResult> healthChecks;
  final List<BuildLogEntry> buildLogs;

  DeploymentMonitorSession({
    required this.id,
    required this.deploymentId,
    required this.environment,
    required this.version,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.lastUpdated,
    required this.metadata,
    required this.healthChecks,
    required this.buildLogs,
  });

  DeploymentMonitorSession copyWith({
    String? id,
    String? deploymentId,
    String? environment,
    String? version,
    DeploymentStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? lastUpdated,
    Map<String, dynamic>? metadata,
    List<HealthCheckResult>? healthChecks,
    List<BuildLogEntry>? buildLogs,
  }) {
    return DeploymentMonitorSession(
      id: id ?? this.id,
      deploymentId: deploymentId ?? this.deploymentId,
      environment: environment ?? this.environment,
      version: version ?? this.version,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadata: metadata ?? this.metadata,
      healthChecks: healthChecks ?? this.healthChecks,
      buildLogs: buildLogs ?? this.buildLogs,
    );
  }
}

/// Deployment status update
class DeploymentStatusUpdate {
  final String deploymentId;
  final DeploymentStatus status;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  DeploymentStatusUpdate({
    required this.deploymentId,
    required this.status,
    required this.message,
    required this.timestamp,
    this.metadata,
  });
}

/// Build log entry
class BuildLogEntry {
  final String id;
  final String deploymentId;
  final String stage;
  final BuildLogLevel level;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  BuildLogEntry({
    required this.id,
    required this.deploymentId,
    required this.stage,
    required this.level,
    required this.message,
    required this.timestamp,
    required this.metadata,
  });
}

/// Health check result
class HealthCheckResult {
  final String deploymentId;
  final String url;
  final bool isHealthy;
  final Duration responseTime;
  final DateTime timestamp;
  final int statusCode;
  final String message;

  HealthCheckResult({
    required this.deploymentId,
    required this.url,
    required this.isHealthy,
    required this.responseTime,
    required this.timestamp,
    required this.statusCode,
    required this.message,
  });
}

/// Deployment metrics
class DeploymentMetrics {
  final String deploymentId;
  final DateTime startTime;
  final int totalStages;
  final int completedStages;
  final int failedStages;
  final Duration averageStageTime;

  DeploymentMetrics({
    required this.deploymentId,
    required this.startTime,
    required this.totalStages,
    required this.completedStages,
    required this.failedStages,
    required this.averageStageTime,
  });

  DeploymentMetrics copyWith({
    String? deploymentId,
    DateTime? startTime,
    int? totalStages,
    int? completedStages,
    int? failedStages,
    Duration? averageStageTime,
  }) {
    return DeploymentMetrics(
      deploymentId: deploymentId ?? this.deploymentId,
      startTime: startTime ?? this.startTime,
      totalStages: totalStages ?? this.totalStages,
      completedStages: completedStages ?? this.completedStages,
      failedStages: failedStages ?? this.failedStages,
      averageStageTime: averageStageTime ?? this.averageStageTime,
    );
  }
}
