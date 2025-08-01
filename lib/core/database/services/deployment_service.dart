import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../database_service.dart';
import '../models/deployment.dart';
import 'audit_log_service.dart';

class DeploymentService {
  static final DeploymentService _instance = DeploymentService._internal();
  static DeploymentService get instance => _instance;
  DeploymentService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;

  Future<Database> get _db async => await DatabaseService.instance.database;

  /// Create a new deployment
  /// Satisfies Requirements: 7.1 (Automatic rollback snapshot creation)
  Future<String> createDeployment(Deployment deployment) async {
    final db = await _db;
    final id = deployment.id.isEmpty ? _uuid.v4() : deployment.id;
    
    final deploymentWithId = deployment.copyWith(
      id: id,
      deployedAt: DateTime.now(),
    );

    await db.insert('deployments', deploymentWithId.toMap());
    
    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'deployment_created',
      description: 'Deployment created: ${deployment.version} to ${deployment.environment}',
      contextData: {
        'deployment_id': id, 
        'environment': deployment.environment, 
        'version': deployment.version,
        'deployed_by': deployment.deployedBy,
        'snapshot_id': deployment.snapshotId,
      },
    );

    return id;
  }

  /// Get deployment by ID
  /// Satisfies Requirements: 7.4 (System integrity verification and status reporting)
  Future<Deployment?> getDeployment(String id) async {
    final db = await _db;
    final maps = await db.query(
      'deployments',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Deployment.fromMap(maps.first);
    }
    return null;
  }

  /// Get all deployments
  /// Satisfies Requirements: 7.1, 7.4 (Deployment tracking and status monitoring)
  Future<List<Deployment>> getAllDeployments() async {
    final db = await _db;
    final maps = await db.query('deployments', orderBy: 'deployed_at DESC');
    return maps.map((map) => Deployment.fromMap(map)).toList();
  }

  /// Get deployments by environment
  /// Satisfies Requirements: 7.1 (Environment-specific deployment tracking)
  Future<List<Deployment>> getDeploymentsByEnvironment(String environment) async {
    final db = await _db;
    final maps = await db.query(
      'deployments',
      where: 'environment = ?',
      whereArgs: [environment],
      orderBy: 'deployed_at DESC',
    );
    return maps.map((map) => Deployment.fromMap(map)).toList();
  }

  /// Get deployments by status
  /// Satisfies Requirements: 7.4 (Deployment status monitoring)
  Future<List<Deployment>> getDeploymentsByStatus(String status) async {
    final db = await _db;
    final maps = await db.query(
      'deployments',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'deployed_at DESC',
    );
    return maps.map((map) => Deployment.fromMap(map)).toList();
  }

  /// Update deployment
  /// Satisfies Requirements: 9.1 (Audit logging for all changes)
  Future<void> updateDeployment(Deployment deployment) async {
    final db = await _db;
    
    await db.update(
      'deployments',
      deployment.toMap(),
      where: 'id = ?',
      whereArgs: [deployment.id],
    );

    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'deployment_updated',
      description: 'Updated deployment: ${deployment.version} - Status: ${deployment.status}',
      contextData: {
        'deployment_id': deployment.id, 
        'status': deployment.status,
        'environment': deployment.environment,
      },
    );
  }

  /// Update deployment status
  /// Satisfies Requirements: 7.4 (Deployment status tracking)
  Future<void> updateDeploymentStatus(String deploymentId, String status, {String? logs}) async {
    final deployment = await getDeployment(deploymentId);
    if (deployment == null) return;

    final updatedDeployment = deployment.copyWith(
      status: status,
      logs: logs ?? deployment.logs,
    );

    await updateDeployment(updatedDeployment);

    // Log status change (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'deployment_status_updated',
      description: 'Deployment status changed: ${deployment.version} -> $status',
      contextData: {
        'deployment_id': deploymentId, 
        'old_status': deployment.status, 
        'new_status': status,
        'environment': deployment.environment,
      },
    );
  }

  /// Mark deployment as failed and suggest rollback
  /// Satisfies Requirements: 2.4 (Automatic rollback suggestions on failure)
  Future<void> markDeploymentFailed(String deploymentId, String errorDetails) async {
    final deployment = await getDeployment(deploymentId);
    if (deployment == null) return;

    final failedDeployment = deployment.copyWith(
      status: 'failed',
      logs: errorDetails,
    );

    await updateDeployment(failedDeployment);

    // Log failure with rollback suggestion (Requirement 2.4, 9.1)
    await _auditService.logAction(
      actionType: 'deployment_failed',
      description: 'Deployment failed: ${deployment.version} in ${deployment.environment}',
      aiReasoning: 'Deployment failure detected. Automatic rollback to snapshot ${deployment.snapshotId} is recommended to restore system stability.',
      contextData: {
        'deployment_id': deploymentId, 
        'environment': deployment.environment,
        'snapshot_id': deployment.snapshotId,
        'error_details': errorDetails,
        'rollback_suggested': true,
      },
      requiresApproval: true,
    );
  }

  /// Get latest successful deployment for environment
  /// Satisfies Requirements: 7.1 (Last known good state tracking)
  Future<Deployment?> getLatestSuccessfulDeployment(String environment) async {
    final db = await _db;
    final maps = await db.query(
      'deployments',
      where: 'environment = ? AND status = ?',
      whereArgs: [environment, 'success'],
      orderBy: 'deployed_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Deployment.fromMap(maps.first);
    }
    return null;
  }

  /// Get deployments with rollback available
  /// Satisfies Requirements: 7.1, 7.2 (Rollback availability tracking)
  Future<List<Deployment>> getDeploymentsWithRollback(String environment) async {
    final db = await _db;
    final maps = await db.query(
      'deployments',
      where: 'environment = ? AND rollback_available = ?',
      whereArgs: [environment, 1],
      orderBy: 'deployed_at DESC',
    );
    return maps.map((map) => Deployment.fromMap(map)).toList();
  }

  /// Disable rollback for deployment
  /// Satisfies Requirements: 7.1 (Rollback availability management)
  Future<void> disableRollback(String deploymentId, {String? reason}) async {
    final deployment = await getDeployment(deploymentId);
    if (deployment == null) return;

    final updatedDeployment = deployment.copyWith(rollbackAvailable: false);
    await updateDeployment(updatedDeployment);

    // Log rollback disabling (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'rollback_disabled',
      description: 'Rollback disabled for deployment: ${deployment.version}',
      contextData: {
        'deployment_id': deploymentId, 
        'reason': reason ?? 'Manual disable',
      },
    );
  }

  /// Delete deployment
  /// Satisfies Requirements: 9.1 (Audit logging for all actions)
  Future<void> deleteDeployment(String id) async {
    final db = await _db;
    final deployment = await getDeployment(id);
    
    await db.delete(
      'deployments',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'deployment_deleted',
      description: 'Deleted deployment: ${deployment?.version ?? id}',
      contextData: {'deployment_id': id},
    );
  }

  /// Get failed deployments
  /// Satisfies Requirements: 2.4 (Deployment failure tracking)
  Future<List<Deployment>> getFailedDeployments() async {
    final db = await _db;
    final maps = await db.query(
      'deployments',
      where: 'status = ?',
      whereArgs: ['failed'],
      orderBy: 'deployed_at DESC',
    );
    return maps.map((map) => Deployment.fromMap(map)).toList();
  }
}