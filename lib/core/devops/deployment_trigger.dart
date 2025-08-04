import 'dart:async';
import 'package:uuid/uuid.dart';
import '../database/services/audit_log_service.dart';
import '../database/services/deployment_service.dart';
import '../database/models/deployment.dart';
import '../auth/auth_service.dart';
import '../api/websocket_service.dart';
import 'pipeline_config_generator.dart';
import 'deployment_monitor.dart';
import '../deployment/deployment_pipeline.dart' as pipeline;

/// Deployment trigger functionality accessible from role-specific dashboards
/// Satisfies Requirements: 7.4 (Deployment trigger functionality accessible from dashboards)
class DeploymentTrigger {
  static final DeploymentTrigger _instance = DeploymentTrigger._internal();
  static DeploymentTrigger get instance => _instance;
  DeploymentTrigger._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;
  final _deploymentService = DeploymentService.instance;
  final _authService = AuthService.instance;
  final _websocketService = WebSocketService.instance;
  final _configGenerator = PipelineConfigGenerator.instance;
  final _deploymentMonitor = DeploymentMonitor.instance;
  final _deploymentPipeline = pipeline.DeploymentPipeline.instance;

  // Deployment approval tracking
  final Map<String, DeploymentApprovalRequest> _pendingApprovals = {};
  final Map<String, List<String>> _environmentApprovers = {};

  /// Initialize deployment trigger system
  Future<void> initialize() async {
    // Set up default environment approvers
    await _setupDefaultApprovers();

    await _auditService.logAction(
      actionType: 'deployment_trigger_initialized',
      description: 'Deployment trigger system initialized',
      aiReasoning:
          'Role-based deployment triggers ready with approval workflows for different environments',
      contextData: {
        'environment_approvers': _environmentApprovers.keys.toList(),
      },
    );
  }

  /// Trigger deployment from dashboard (role-based access control)
  Future<DeploymentTriggerResult> triggerDeployment({
    required String projectId,
    required String environment,
    required String version,
    String? branch,
    Map<String, dynamic>? configuration,
    String? reason,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user has permission to deploy to this environment
      final hasPermission =
          await _checkDeploymentPermission(currentUser.role, environment);
      if (!hasPermission) {
        throw Exception(
            'Insufficient permissions to deploy to $environment environment');
      }

      final deploymentId = _uuid.v4();

      // Check if approval is required for this environment
      final requiresApproval =
          await _requiresApproval(environment, currentUser.role);

      if (requiresApproval) {
        // Create approval request
        final approvalRequest = await _createApprovalRequest(
          deploymentId: deploymentId,
          projectId: projectId,
          environment: environment,
          version: version,
          requestedBy: currentUser.id,
          reason: reason,
          configuration: configuration,
        );

        await _auditService.logAction(
          actionType: 'deployment_approval_requested',
          description: 'Deployment approval requested',
          contextData: {
            'deployment_id': deploymentId,
            'project_id': projectId,
            'environment': environment,
            'version': version,
            'requested_by': currentUser.id,
            'reason': reason,
          },
          userId: currentUser.id,
        );

        return DeploymentTriggerResult(
          deploymentId: deploymentId,
          status: DeploymentTriggerStatus.pendingApproval,
          message:
              'Deployment approval requested. Waiting for approval from authorized personnel.',
          approvalRequestId: approvalRequest.id,
        );
      } else {
        // Execute deployment immediately
        final result = await _executeDeployment(
          deploymentId: deploymentId,
          projectId: projectId,
          environment: environment,
          version: version,
          branch: branch,
          configuration: configuration,
          triggeredBy: currentUser.id,
          reason: reason,
        );

        return result;
      }
    } catch (e) {
      await _auditService.logAction(
        actionType: 'deployment_trigger_error',
        description: 'Error triggering deployment: ${e.toString()}',
        contextData: {
          'project_id': projectId,
          'environment': environment,
          'version': version,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return DeploymentTriggerResult(
        deploymentId: '',
        status: DeploymentTriggerStatus.failed,
        message: 'Failed to trigger deployment: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Approve pending deployment
  Future<DeploymentTriggerResult> approveDeployment({
    required String approvalRequestId,
    String? approvalNotes,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final approvalRequest = _pendingApprovals[approvalRequestId];
      if (approvalRequest == null) {
        throw Exception('Approval request not found');
      }

      // Check if user can approve deployments to this environment
      final canApprove = await _canApproveDeployment(
          currentUser.role, approvalRequest.environment);
      if (!canApprove) {
        throw Exception(
            'Insufficient permissions to approve deployments to ${approvalRequest.environment}');
      }

      // Update approval request
      final approvedRequest = approvalRequest.copyWith(
        status: ApprovalStatus.approved,
        approvedBy: currentUser.id,
        approvedAt: DateTime.now(),
        approvalNotes: approvalNotes,
      );
      _pendingApprovals[approvalRequestId] = approvedRequest;

      // Execute the deployment
      final result = await _executeDeployment(
        deploymentId: approvalRequest.deploymentId,
        projectId: approvalRequest.projectId,
        environment: approvalRequest.environment,
        version: approvalRequest.version,
        configuration: approvalRequest.configuration,
        triggeredBy: approvalRequest.requestedBy,
        approvedBy: currentUser.id,
        reason: approvalRequest.reason,
      );

      await _auditService.logAction(
        actionType: 'deployment_approved_and_executed',
        description: 'Deployment approved and executed',
        contextData: {
          'approval_request_id': approvalRequestId,
          'deployment_id': approvalRequest.deploymentId,
          'environment': approvalRequest.environment,
          'approved_by': currentUser.id,
          'approval_notes': approvalNotes,
        },
        userId: currentUser.id,
        approvedBy: currentUser.id,
      );

      // Clean up approval request after delay
      Timer(const Duration(hours: 1), () {
        _pendingApprovals.remove(approvalRequestId);
      });

      return result;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'deployment_approval_error',
        description: 'Error approving deployment: ${e.toString()}',
        contextData: {
          'approval_request_id': approvalRequestId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return DeploymentTriggerResult(
        deploymentId: '',
        status: DeploymentTriggerStatus.failed,
        message: 'Failed to approve deployment: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Reject pending deployment
  Future<void> rejectDeployment({
    required String approvalRequestId,
    required String rejectionReason,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final approvalRequest = _pendingApprovals[approvalRequestId];
      if (approvalRequest == null) {
        throw Exception('Approval request not found');
      }

      // Check if user can reject deployments to this environment
      final canReject = await _canApproveDeployment(
          currentUser.role, approvalRequest.environment);
      if (!canReject) {
        throw Exception(
            'Insufficient permissions to reject deployments to ${approvalRequest.environment}');
      }

      // Update approval request
      final rejectedRequest = approvalRequest.copyWith(
        status: ApprovalStatus.rejected,
        approvedBy: currentUser.id,
        approvedAt: DateTime.now(),
        approvalNotes: rejectionReason,
      );
      _pendingApprovals[approvalRequestId] = rejectedRequest;

      // Notify requester
      await _websocketService.broadcastDeploymentStatus(
        deploymentId: approvalRequest.deploymentId,
        status: 'rejected',
        message: 'Deployment request rejected: $rejectionReason',
        metadata: {
          'rejected_by': currentUser.id,
          'rejection_reason': rejectionReason,
        },
      );

      await _auditService.logAction(
        actionType: 'deployment_rejected',
        description: 'Deployment request rejected',
        contextData: {
          'approval_request_id': approvalRequestId,
          'deployment_id': approvalRequest.deploymentId,
          'environment': approvalRequest.environment,
          'rejected_by': currentUser.id,
          'rejection_reason': rejectionReason,
        },
        userId: currentUser.id,
      );

      // Clean up approval request after delay
      Timer(const Duration(hours: 1), () {
        _pendingApprovals.remove(approvalRequestId);
      });
    } catch (e) {
      await _auditService.logAction(
        actionType: 'deployment_rejection_error',
        description: 'Error rejecting deployment: ${e.toString()}',
        contextData: {
          'approval_request_id': approvalRequestId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );
      rethrow;
    }
  }

  /// Get pending approval requests (for approvers)
  Future<List<DeploymentApprovalRequest>> getPendingApprovals({
    String? environment,
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return [];
    }

    // Filter approvals based on user's approval permissions
    final approvals = _pendingApprovals.values.where((approval) {
      if (approval.status != ApprovalStatus.pending) return false;
      if (environment != null && approval.environment != environment)
        return false;

      // Check if user can approve for this environment
      return _canApproveDeploymentSync(currentUser.role, approval.environment);
    }).toList();

    // Sort by creation time (newest first)
    approvals.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    return approvals;
  }

  /// Get deployment history for dashboard
  Future<List<DeploymentHistoryEntry>> getDeploymentHistory({
    String? environment,
    int limit = 20,
  }) async {
    try {
      final deployments = await _deploymentService.getAllDeployments();

      var filteredDeployments = deployments.where((deployment) {
        if (environment != null && deployment.environment != environment)
          return false;
        return true;
      }).toList();

      // Sort by deployment time (newest first)
      filteredDeployments.sort((a, b) => b.deployedAt.compareTo(a.deployedAt));

      // Take only the requested number
      if (filteredDeployments.length > limit) {
        filteredDeployments = filteredDeployments.sublist(0, limit);
      }

      // Convert to history entries
      return filteredDeployments
          .map((deployment) => DeploymentHistoryEntry(
                id: deployment.id,
                environment: deployment.environment,
                version: deployment.version,
                status: deployment.status,
                deployedBy: deployment.deployedBy,
                deployedAt: deployment.deployedAt,
                duration: _calculateDeploymentDuration(deployment),
              ))
          .toList();
    } catch (e) {
      await _auditService.logAction(
        actionType: 'deployment_history_error',
        description: 'Error retrieving deployment history: ${e.toString()}',
        contextData: {
          'environment': environment,
          'limit': limit,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );
      return [];
    }
  }

  /// Get available environments for user
  Future<List<EnvironmentInfo>> getAvailableEnvironments() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return [];
    }

    final environments = <EnvironmentInfo>[];

    // Check each environment
    for (final env in ['development', 'staging', 'production']) {
      final canDeploy = await _checkDeploymentPermission(currentUser.role, env);
      final canApprove = await _canApproveDeployment(currentUser.role, env);
      final requiresApproval = await _requiresApproval(env, currentUser.role);

      if (canDeploy || canApprove) {
        environments.add(EnvironmentInfo(
          name: env,
          displayName: env.toUpperCase(),
          canDeploy: canDeploy,
          canApprove: canApprove,
          requiresApproval: requiresApproval,
          description: _getEnvironmentDescription(env),
        ));
      }
    }

    return environments;
  }

  /// Private helper methods

  /// Set up default environment approvers
  Future<void> _setupDefaultApprovers() async {
    _environmentApprovers['development'] = ['admin', 'lead_developer'];
    _environmentApprovers['staging'] = ['admin', 'lead_developer'];
    _environmentApprovers['production'] = ['admin'];
  }

  /// Check if user has permission to deploy to environment
  Future<bool> _checkDeploymentPermission(
      String userRole, String environment) async {
    switch (environment) {
      case 'development':
        return ['admin', 'lead_developer', 'developer'].contains(userRole);
      case 'staging':
        return ['admin', 'lead_developer'].contains(userRole);
      case 'production':
        return ['admin'].contains(userRole);
      default:
        return false;
    }
  }

  /// Check if user can approve deployments to environment
  Future<bool> _canApproveDeployment(
      String userRole, String environment) async {
    final approvers = _environmentApprovers[environment] ?? [];
    return approvers.contains(userRole);
  }

  /// Synchronous version of can approve deployment
  bool _canApproveDeploymentSync(String userRole, String environment) {
    final approvers = _environmentApprovers[environment] ?? [];
    return approvers.contains(userRole);
  }

  /// Check if deployment requires approval
  Future<bool> _requiresApproval(String environment, String userRole) async {
    // Production always requires approval unless user is admin
    if (environment == 'production' && userRole != 'admin') {
      return true;
    }

    // Staging requires approval unless user is admin or lead_developer
    if (environment == 'staging' &&
        !['admin', 'lead_developer'].contains(userRole)) {
      return true;
    }

    return false;
  }

  /// Create approval request
  Future<DeploymentApprovalRequest> _createApprovalRequest({
    required String deploymentId,
    required String projectId,
    required String environment,
    required String version,
    required String requestedBy,
    String? reason,
    Map<String, dynamic>? configuration,
  }) async {
    final requestId = _uuid.v4();

    final request = DeploymentApprovalRequest(
      id: requestId,
      deploymentId: deploymentId,
      projectId: projectId,
      environment: environment,
      version: version,
      requestedBy: requestedBy,
      requestedAt: DateTime.now(),
      status: ApprovalStatus.pending,
      reason: reason,
      configuration: configuration ?? {},
    );

    _pendingApprovals[requestId] = request;

    // Notify potential approvers
    final approvers = _environmentApprovers[environment] ?? [];
    for (final approverRole in approvers) {
      await _websocketService.broadcastDeploymentStatus(
        deploymentId: deploymentId,
        status: 'approval_requested',
        message: 'Deployment approval requested for $environment',
        metadata: {
          'approval_request_id': requestId,
          'environment': environment,
          'version': version,
          'requested_by': requestedBy,
          'approver_role': approverRole,
        },
      );
    }

    return request;
  }

  /// Execute deployment
  Future<DeploymentTriggerResult> _executeDeployment({
    required String deploymentId,
    required String projectId,
    required String environment,
    required String version,
    String? branch,
    Map<String, dynamic>? configuration,
    required String triggeredBy,
    String? approvedBy,
    String? reason,
  }) async {
    try {
      // Generate pipeline configuration
      final pipelineConfig = await _configGenerator.generateConfiguration(
        projectId: projectId,
        projectType: ProjectType.flutter, // Default to Flutter for now
        targetPlatforms: [Platform.windows, Platform.web],
        projectSettings: configuration ?? {},
      );

      // Start deployment monitoring
      final monitorSession = await _deploymentMonitor.startMonitoring(
        deploymentId: deploymentId,
        environment: environment,
        version: version,
        metadata: {
          'project_id': projectId,
          'triggered_by': triggeredBy,
          'approved_by': approvedBy,
          'reason': reason,
        },
      );

      // Execute deployment pipeline
      final deploymentResult = await _deploymentPipeline.executePipeline(
        pipeline.PipelineConfig(
          id: pipelineConfig.id,
          specId: projectId,
          branchName: branch ?? 'main',
          stages: pipelineConfig.stages
              .map((stage) => pipeline.PipelineStage(
                    name: stage.name,
                    description: stage.description,
                    commands: stage.commands,
                    timeout: stage.timeout,
                  ))
              .toList(),
          environment: environment,
          createdAt: DateTime.now(),
        ),
        environment,
      );

      await _auditService.logAction(
        actionType: 'deployment_executed',
        description: 'Deployment executed successfully',
        contextData: {
          'deployment_id': deploymentId,
          'project_id': projectId,
          'environment': environment,
          'version': version,
          'triggered_by': triggeredBy,
          'approved_by': approvedBy,
          'success': deploymentResult.success,
        },
        userId: triggeredBy,
        approvedBy: approvedBy,
      );

      return DeploymentTriggerResult(
        deploymentId: deploymentId,
        status: deploymentResult.success
            ? DeploymentTriggerStatus.success
            : DeploymentTriggerStatus.failed,
        message: deploymentResult.success
            ? 'Deployment executed successfully'
            : 'Deployment failed: ${deploymentResult.error}',
        monitorSessionId: monitorSession.id,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'deployment_execution_error',
        description: 'Error executing deployment: ${e.toString()}',
        contextData: {
          'deployment_id': deploymentId,
          'project_id': projectId,
          'environment': environment,
          'error': e.toString(),
        },
        userId: triggeredBy,
      );

      return DeploymentTriggerResult(
        deploymentId: deploymentId,
        status: DeploymentTriggerStatus.failed,
        message: 'Failed to execute deployment: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Calculate deployment duration
  Duration? _calculateDeploymentDuration(Deployment deployment) {
    // In a real implementation, this would calculate based on completion time
    // For now, return a simulated duration
    return Duration(minutes: 5 + (deployment.id.hashCode % 15));
  }

  /// Get environment description
  String _getEnvironmentDescription(String environment) {
    switch (environment) {
      case 'development':
        return 'Development environment for testing new features';
      case 'staging':
        return 'Staging environment for pre-production testing';
      case 'production':
        return 'Production environment serving live users';
      default:
        return 'Unknown environment';
    }
  }
}

/// Deployment trigger status
enum DeploymentTriggerStatus {
  success,
  failed,
  pendingApproval,
  cancelled,
}

/// Approval status
enum ApprovalStatus {
  pending,
  approved,
  rejected,
}

/// Deployment trigger result
class DeploymentTriggerResult {
  final String deploymentId;
  final DeploymentTriggerStatus status;
  final String message;
  final String? error;
  final String? approvalRequestId;
  final String? monitorSessionId;

  DeploymentTriggerResult({
    required this.deploymentId,
    required this.status,
    required this.message,
    this.error,
    this.approvalRequestId,
    this.monitorSessionId,
  });
}

/// Deployment approval request
class DeploymentApprovalRequest {
  final String id;
  final String deploymentId;
  final String projectId;
  final String environment;
  final String version;
  final String requestedBy;
  final DateTime requestedAt;
  final ApprovalStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? approvalNotes;
  final String? reason;
  final Map<String, dynamic> configuration;

  DeploymentApprovalRequest({
    required this.id,
    required this.deploymentId,
    required this.projectId,
    required this.environment,
    required this.version,
    required this.requestedBy,
    required this.requestedAt,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.approvalNotes,
    this.reason,
    required this.configuration,
  });

  DeploymentApprovalRequest copyWith({
    String? id,
    String? deploymentId,
    String? projectId,
    String? environment,
    String? version,
    String? requestedBy,
    DateTime? requestedAt,
    ApprovalStatus? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? approvalNotes,
    String? reason,
    Map<String, dynamic>? configuration,
  }) {
    return DeploymentApprovalRequest(
      id: id ?? this.id,
      deploymentId: deploymentId ?? this.deploymentId,
      projectId: projectId ?? this.projectId,
      environment: environment ?? this.environment,
      version: version ?? this.version,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      approvalNotes: approvalNotes ?? this.approvalNotes,
      reason: reason ?? this.reason,
      configuration: configuration ?? this.configuration,
    );
  }
}

/// Deployment history entry
class DeploymentHistoryEntry {
  final String id;
  final String environment;
  final String version;
  final String status;
  final String deployedBy;
  final DateTime deployedAt;
  final Duration? duration;

  DeploymentHistoryEntry({
    required this.id,
    required this.environment,
    required this.version,
    required this.status,
    required this.deployedBy,
    required this.deployedAt,
    this.duration,
  });
}

/// Environment information
class EnvironmentInfo {
  final String name;
  final String displayName;
  final bool canDeploy;
  final bool canApprove;
  final bool requiresApproval;
  final String description;

  EnvironmentInfo({
    required this.name,
    required this.displayName,
    required this.canDeploy,
    required this.canApprove,
    required this.requiresApproval,
    required this.description,
  });
}
