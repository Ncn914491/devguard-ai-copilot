import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../database/models/deployment.dart';
import '../supabase_error_handler.dart';
import 'supabase_base_service.dart';

/// Supabase implementation of deployment service
/// Replaces SQLite queries with supabase.from('deployments') operations
/// Requirements: 1.2, 1.4, 3.6 - Deployment tracking and management
class SupabaseDeploymentService extends SupabaseBaseService<Deployment> {
  static final SupabaseDeploymentService _instance =
      SupabaseDeploymentService._internal();
  static SupabaseDeploymentService get instance => _instance;
  SupabaseDeploymentService._internal();

  @override
  String get tableName => 'deployments';

  @override
  Deployment fromMap(Map<String, dynamic> map) {
    return Deployment(
      id: map['id'] ?? '',
      environment: map['environment'] ?? '',
      version: map['version'] ?? '',
      status: map['status'] ?? '',
      pipelineConfig: _parseJsonData(map['pipeline_config']),
      snapshotId: map['snapshot_id'],
      deployedBy: map['deployed_by'] ?? '',
      deployedAt: _parseDateTime(map['deployed_at']),
      rollbackAvailable: map['rollback_available'] == true,
      healthChecks: _parseJsonData(map['health_checks']),
      logs: _parseJsonData(map['logs']),
    );
  }

  @override
  Map<String, dynamic> toMap(Deployment item) {
    return {
      'id': item.id,
      'environment': item.environment,
      'version': item.version,
      'status': item.status,
      'pipeline_config': _encodeJsonData(item.pipelineConfig),
      'snapshot_id': item.snapshotId,
      'deployed_by': item.deployedBy,
      'deployed_at': item.deployedAt.toIso8601String(),
      'rollback_available': item.rollbackAvailable,
      'health_checks': _encodeJsonData(item.healthChecks),
      'logs': _encodeJsonData(item.logs),
    };
  }

  @override
  void validateData(Map<String, dynamic> data) {
    // Validate required fields
    if (data['environment'] == null ||
        data['environment'].toString().trim().isEmpty) {
      throw AppError.validation('Environment is required');
    }

    if (data['version'] == null || data['version'].toString().trim().isEmpty) {
      throw AppError.validation('Version is required');
    }

    if (data['status'] == null || data['status'].toString().trim().isEmpty) {
      throw AppError.validation('Status is required');
    }

    if (data['deployed_by'] == null ||
        data['deployed_by'].toString().trim().isEmpty) {
      throw AppError.validation('Deployed by is required');
    }

    if (data['deployed_at'] == null) {
      throw AppError.validation('Deployment timestamp is required');
    }

    // Validate environment
    const validEnvironments = ['development', 'staging', 'production'];
    if (!validEnvironments.contains(data['environment'])) {
      throw AppError.validation(
          'Invalid environment. Must be one of: ${validEnvironments.join(', ')}');
    }

    // Validate status
    const validStatuses = [
      'pending',
      'in_progress',
      'success',
      'failed',
      'rolled_back'
    ];
    if (!validStatuses.contains(data['status'])) {
      throw AppError.validation(
          'Invalid status. Must be one of: ${validStatuses.join(', ')}');
    }

    // Validate version format (semantic versioning)
    final version = data['version'].toString();
    if (!RegExp(r'^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?$').hasMatch(version)) {
      throw AppError.validation(
          'Version must follow semantic versioning format (e.g., 1.0.0 or 1.0.0-beta.1)');
    }
  }

  /// Create a new deployment
  /// Satisfies Requirements: 3.6 (Deployment tracking)
  Future<String> createDeployment(Deployment deployment) async {
    try {
      return await create(deployment);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get deployment by ID
  /// Satisfies Requirements: 3.6 (Deployment retrieval)
  Future<Deployment?> getDeployment(String id) async {
    return await getById(id);
  }

  /// Get all deployments
  /// Satisfies Requirements: 3.6 (Deployment listing)
  Future<List<Deployment>> getAllDeployments() async {
    return await getAll(orderBy: 'deployed_at', ascending: false);
  }

  /// Get deployments by environment
  /// Satisfies Requirements: 3.6 (Environment-based filtering)
  Future<List<Deployment>> getDeploymentsByEnvironment(
      String environment) async {
    try {
      return await getWhere(
        column: 'environment',
        value: environment,
        orderBy: 'deployed_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get deployments by status
  Future<List<Deployment>> getDeploymentsByStatus(String status) async {
    try {
      return await getWhere(
        column: 'status',
        value: status,
        orderBy: 'deployed_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get deployments by user
  Future<List<Deployment>> getDeploymentsByUser(String userId) async {
    try {
      return await getWhere(
        column: 'deployed_by',
        value: userId,
        orderBy: 'deployed_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get latest deployment for environment
  Future<Deployment?> getLatestDeployment(String environment) async {
    try {
      final deployments = await getWhere(
        column: 'environment',
        value: environment,
        orderBy: 'deployed_at',
        ascending: false,
        limit: 1,
      );

      return deployments.isNotEmpty ? deployments.first : null;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get successful deployments
  Future<List<Deployment>> getSuccessfulDeployments(
      {String? environment}) async {
    try {
      if (environment != null) {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .eq('status', 'success')
              .eq('environment', environment)
              .order('deployed_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      } else {
        return await getWhere(
          column: 'status',
          value: 'success',
          orderBy: 'deployed_at',
          ascending: false,
        );
      }
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get failed deployments
  Future<List<Deployment>> getFailedDeployments({String? environment}) async {
    try {
      if (environment != null) {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .eq('status', 'failed')
              .eq('environment', environment)
              .order('deployed_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      } else {
        return await getWhere(
          column: 'status',
          value: 'failed',
          orderBy: 'deployed_at',
          ascending: false,
        );
      }
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get deployments with rollback available
  Future<List<Deployment>> getDeploymentsWithRollback(
      {String? environment}) async {
    try {
      if (environment != null) {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .eq('rollback_available', true)
              .eq('environment', environment)
              .order('deployed_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      } else {
        return await getWhere(
          column: 'rollback_available',
          value: true,
          orderBy: 'deployed_at',
          ascending: false,
        );
      }
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get recent deployments (last N days)
  Future<List<Deployment>> getRecentDeployments(
      {int days = 7, String? environment}) async {
    try {
      final cutoffDate =
          DateTime.now().subtract(Duration(days: days)).toIso8601String();

      if (environment != null) {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .gte('deployed_at', cutoffDate)
              .eq('environment', environment)
              .order('deployed_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      } else {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .gte('deployed_at', cutoffDate)
              .order('deployed_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      }
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update deployment
  /// Satisfies Requirements: 3.6 (Deployment updates)
  Future<void> updateDeployment(Deployment deployment) async {
    try {
      // Check if deployment exists
      final existing = await getById(deployment.id);
      if (existing == null) {
        throw AppError.notFound('Deployment not found');
      }

      await update(deployment.id, deployment);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update deployment status
  Future<void> updateDeploymentStatus(
      String deploymentId, String status) async {
    try {
      final deployment = await getDeployment(deploymentId);
      if (deployment == null) {
        throw AppError.notFound('Deployment not found');
      }

      final updatedDeployment = deployment.copyWith(status: status);
      await updateDeployment(updatedDeployment);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Add health check results
  Future<void> addHealthCheckResults(
      String deploymentId, Map<String, dynamic> healthCheckData) async {
    try {
      final deployment = await getDeployment(deploymentId);
      if (deployment == null) {
        throw AppError.notFound('Deployment not found');
      }

      // Parse existing health checks or create new
      Map<String, dynamic> existingHealthChecks = {};
      if (deployment.healthChecks != null &&
          deployment.healthChecks!.isNotEmpty) {
        try {
          existingHealthChecks =
              jsonDecode(deployment.healthChecks!) as Map<String, dynamic>;
        } catch (e) {
          existingHealthChecks = {};
        }
      }

      // Add timestamp to new health check
      healthCheckData['timestamp'] = DateTime.now().toIso8601String();

      // Merge health checks
      final healthCheckList =
          existingHealthChecks['checks'] as List<dynamic>? ?? [];
      healthCheckList.add(healthCheckData);
      existingHealthChecks['checks'] = healthCheckList;
      existingHealthChecks['last_updated'] = DateTime.now().toIso8601String();

      final updatedDeployment = deployment.copyWith(
        healthChecks: jsonEncode(existingHealthChecks),
      );

      await updateDeployment(updatedDeployment);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Add deployment logs
  Future<void> addDeploymentLogs(String deploymentId, String logEntry) async {
    try {
      final deployment = await getDeployment(deploymentId);
      if (deployment == null) {
        throw AppError.notFound('Deployment not found');
      }

      // Parse existing logs or create new
      Map<String, dynamic> existingLogs = {};
      if (deployment.logs != null && deployment.logs!.isNotEmpty) {
        try {
          existingLogs = jsonDecode(deployment.logs!) as Map<String, dynamic>;
        } catch (e) {
          existingLogs = {};
        }
      }

      // Add new log entry
      final logsList = existingLogs['entries'] as List<dynamic>? ?? [];
      logsList.add({
        'timestamp': DateTime.now().toIso8601String(),
        'message': logEntry,
      });
      existingLogs['entries'] = logsList;
      existingLogs['last_updated'] = DateTime.now().toIso8601String();

      final updatedDeployment = deployment.copyWith(
        logs: jsonEncode(existingLogs),
      );

      await updateDeployment(updatedDeployment);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Delete deployment
  /// Satisfies Requirements: 3.6 (Deployment management)
  Future<void> deleteDeployment(String id) async {
    try {
      // Check if deployment exists
      final existing = await getById(id);
      if (existing == null) {
        throw AppError.notFound('Deployment not found');
      }

      await delete(id);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch all deployments for real-time updates
  /// Satisfies Requirements: 3.6 (Real-time deployment monitoring)
  Stream<List<Deployment>> watchAllDeployments() {
    return watchAll(orderBy: 'deployed_at', ascending: false);
  }

  /// Watch deployments by environment for real-time updates
  Stream<List<Deployment>> watchDeploymentsByEnvironment(String environment) {
    try {
      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('environment', environment)
          .order('deployed_at', ascending: false)
          .map((data) => data
              .map((item) => fromMap(item as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch a specific deployment for real-time updates
  Stream<Deployment?> watchDeployment(String id) {
    return watchById(id);
  }

  /// Get deployment statistics
  Future<Map<String, dynamic>> getDeploymentStatistics() async {
    try {
      final allDeployments = await getAllDeployments();

      final stats = <String, dynamic>{
        'total': allDeployments.length,
        'success': allDeployments.where((d) => d.status == 'success').length,
        'failed': allDeployments.where((d) => d.status == 'failed').length,
        'in_progress':
            allDeployments.where((d) => d.status == 'in_progress').length,
        'rolled_back':
            allDeployments.where((d) => d.status == 'rolled_back').length,
        'with_rollback':
            allDeployments.where((d) => d.rollbackAvailable).length,
        'environmentDistribution': <String, int>{},
        'userDeploymentCount': <String, int>{},
        'successRate': 0.0,
        'averageDeploymentFrequency': 0.0,
      };

      // Calculate environment distribution
      for (final deployment in allDeployments) {
        final envStats = stats['environmentDistribution'] as Map<String, int>;
        envStats[deployment.environment] =
            (envStats[deployment.environment] ?? 0) + 1;
      }

      // Calculate user deployment count
      for (final deployment in allDeployments) {
        final userStats = stats['userDeploymentCount'] as Map<String, int>;
        userStats[deployment.deployedBy] =
            (userStats[deployment.deployedBy] ?? 0) + 1;
      }

      // Calculate success rate
      final successCount = stats['success'] as int;
      final totalCount = stats['total'] as int;
      stats['successRate'] =
          totalCount > 0 ? (successCount / totalCount) * 100 : 0.0;

      // Calculate average deployment frequency (deployments per day over last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentDeployments = allDeployments
          .where((d) => d.deployedAt.isAfter(thirtyDaysAgo))
          .length;
      stats['averageDeploymentFrequency'] = recentDeployments / 30.0;

      return stats;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get deployment history for a version
  Future<List<Deployment>> getDeploymentHistory(String version) async {
    try {
      return await getWhere(
        column: 'version',
        value: version,
        orderBy: 'deployed_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Helper method to parse JSONB data from database
  String? _parseJsonData(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  /// Helper method to encode JSONB data for database
  dynamic _encodeJsonData(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return jsonDecode(value);
    } catch (e) {
      return value; // Return as string if not valid JSON
    }
  }

  /// Helper method to parse DateTime from database
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
