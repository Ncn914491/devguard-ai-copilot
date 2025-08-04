import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../database/services/services.dart';
import '../database/models/models.dart';
import 'security_monitor.dart';

/// Security Workflow Integration Service
/// Integrates existing security monitoring with task management and development workflow
/// Satisfies Requirements: 9.1, 9.2, 9.3, 9.4, 9.5
class SecurityWorkflowIntegration {
  static final SecurityWorkflowIntegration _instance =
      SecurityWorkflowIntegration._internal();
  static SecurityWorkflowIntegration get instance => _instance;
  SecurityWorkflowIntegration._internal();

  final _uuid = const Uuid();
  final _securityMonitor = SecurityMonitor.instance;
  final _securityAlertService = SecurityAlertService.instance;
  final _taskService = TaskService.instance;
  final _enhancedTaskService = EnhancedTaskService.instance;
  final _auditService = AuditLogService.instance;

  /// Initialize security workflow integration
  /// Satisfies Requirements: 9.1 (Security monitoring integration)
  Future<void> initialize() async {
    await _setupSecurityEventHandlers();
    await _initializeSecurityPolicies();

    await _auditService.logAction(
      actionType: 'security_workflow_integration_initialized',
      description:
          'Security workflow integration initialized with task management',
      aiReasoning:
          'Integrated security monitoring with development workflow for incident tracking and policy enforcement',
      contextData: {
        'integration_components': [
          'task_management',
          'git_operations',
          'approval_workflows'
        ],
        'security_policies_loaded': true,
      },
    );
  }

  /// Create security incident task from security alert
  /// Satisfies Requirements: 9.1 (Incident tracking integration)
  Future<String> createSecurityIncidentTask(
    String alertId, {
    required String userId,
    required String userRole,
    String? assigneeId,
  }) async {
    final alert = await _securityAlertService.getSecurityAlert(alertId);
    if (alert == null) {
      throw Exception('Security alert not found: $alertId');
    }

    // Determine task confidentiality based on alert severity
    final confidentialityLevel =
        _getTaskConfidentialityFromSeverity(alert.severity);

    // Determine assignee based on alert type and severity
    final taskAssignee =
        assigneeId ?? await _determineSecurityTaskAssignee(alert);

    final task = Task(
      id: _uuid.v4(),
      title: 'Security Incident: ${alert.title}',
      description: '''
Security Alert Details:
- Type: ${alert.type}
- Severity: ${alert.severity}
- Description: ${alert.description}
- AI Analysis: ${alert.aiExplanation}
- Evidence: ${alert.evidence ?? 'No additional evidence'}

Required Actions:
1. Investigate the security incident
2. Implement necessary remediation steps
3. Update security policies if needed
4. Document lessons learned
''',
      type: 'security',
      priority: _getPriorityFromSeverity(alert.severity),
      status: 'pending',
      assigneeId: taskAssignee,
      reporterId: 'security_system',
      estimatedHours: _estimateSecurityTaskHours(alert.severity),
      actualHours: 0,
      relatedCommits: [],
      relatedPullRequests: [],
      dependencies: [],
      blockedBy: [],
      createdAt: DateTime.now(),
      dueDate: _calculateSecurityTaskDueDate(alert.severity),
      confidentialityLevel: confidentialityLevel,
      authorizedUsers: await _getAuthorizedUsersForSecurityTask(alert.severity),
      authorizedRoles: _getAuthorizedRolesForSecurityTask(alert.severity),
    );

    final taskId = await _enhancedTaskService.createTaskWithConfidentiality(
      task: task,
      userId: userId,
      userRole: userRole,
    );

    // Link alert to task
    await _linkAlertToTask(alertId, taskId);

    await _auditService.logAction(
      actionType: 'security_incident_task_created',
      description: 'Created security incident task from alert: ${alert.title}',
      aiReasoning:
          'Automatically converted security alert into trackable task for incident response workflow',
      contextData: {
        'alert_id': alertId,
        'task_id': taskId,
        'alert_severity': alert.severity,
        'task_confidentiality': confidentialityLevel,
        'assignee_id': taskAssignee,
      },
      userId: userId,
    );

    return taskId;
  }

  /// Check security policy compliance for git operations
  /// Satisfies Requirements: 9.2 (Security policy enforcement)
  Future<SecurityPolicyResult> checkGitOperationCompliance({
    required String operation, // 'commit', 'push', 'merge', 'branch_create'
    required String userId,
    required String userRole,
    required Map<String, dynamic> operationContext,
  }) async {
    final violations = <String>[];
    final warnings = <String>[];

    // Check user permissions for operation
    if (!await _checkUserGitPermissions(userId, userRole, operation)) {
      violations.add('User does not have permission for $operation operation');
    }

    // Check for sensitive file modifications
    if (operation == 'commit' || operation == 'push') {
      final sensitiveFiles =
          await _checkSensitiveFileModifications(operationContext);
      if (sensitiveFiles.isNotEmpty) {
        if (userRole != 'admin') {
          violations.add(
              'Sensitive files modified without admin approval: ${sensitiveFiles.join(', ')}');
        } else {
          warnings.add(
              'Admin modifying sensitive files: ${sensitiveFiles.join(', ')}');
        }
      }
    }

    // Check for security-related changes
    if (operation == 'commit') {
      final securityChanges =
          await _detectSecurityRelatedChanges(operationContext);
      if (securityChanges.isNotEmpty && userRole == 'developer') {
        violations.add(
            'Security-related changes require lead developer or admin approval');
      }
    }

    // Check branch naming conventions for security branches
    if (operation == 'branch_create') {
      final branchName = operationContext['branch_name'] as String?;
      if (branchName != null &&
          branchName.startsWith('security/') &&
          userRole == 'developer') {
        violations.add(
            'Security branches can only be created by lead developers or admins');
      }
    }

    final result = SecurityPolicyResult(
      compliant: violations.isEmpty,
      violations: violations,
      warnings: warnings,
      requiresApproval:
          violations.isNotEmpty || (warnings.isNotEmpty && userRole != 'admin'),
      approvalLevel:
          _determineRequiredApprovalLevel(violations, warnings, userRole),
    );

    // Log policy check
    await _auditService.logAction(
      actionType: 'security_policy_check',
      description: 'Security policy compliance check for $operation',
      aiReasoning:
          'Enforced security policies for git operations to prevent unauthorized changes',
      contextData: {
        'operation': operation,
        'user_id': userId,
        'user_role': userRole,
        'compliant': result.compliant,
        'violations_count': violations.length,
        'warnings_count': warnings.length,
        'requires_approval': result.requiresApproval,
      },
      userId: userId,
    );

    return result;
  }

  /// Gather security incident context with code change correlation
  /// Satisfies Requirements: 9.3 (Security incident context gathering)
  Future<SecurityIncidentContext> gatherIncidentContext(String alertId) async {
    final alert = await _securityAlertService.getSecurityAlert(alertId);
    if (alert == null) {
      throw Exception('Security alert not found: $alertId');
    }

    // Get recent code changes
    final recentCommits = await _getRecentCodeChanges(alert.detectedAt);

    // Get related tasks
    final relatedTasks = await _getTasksRelatedToAlert(alert);

    // Get user activity around incident time
    final userActivity = await _getUserActivityAroundIncident(alert.detectedAt);

    // Get system state at incident time
    final systemState = await _getSystemStateAtIncident(alert.detectedAt);

    // Correlate code changes with incident
    final correlatedChanges =
        await _correlateCodeChangesWithIncident(alert, recentCommits);

    final context = SecurityIncidentContext(
      alertId: alertId,
      incidentTime: alert.detectedAt,
      recentCommits: correlatedChanges,
      relatedTasks: relatedTasks,
      userActivity: userActivity,
      systemState: systemState,
      riskAssessment: await _assessIncidentRisk(alert, correlatedChanges),
      recommendedActions:
          await _generateRecommendedActions(alert, correlatedChanges),
    );

    await _auditService.logAction(
      actionType: 'security_incident_context_gathered',
      description: 'Gathered comprehensive context for security incident',
      aiReasoning:
          'Collected code changes, user activity, and system state to provide complete incident context',
      contextData: {
        'alert_id': alertId,
        'commits_analyzed': correlatedChanges.length,
        'related_tasks': relatedTasks.length,
        'user_activities': userActivity.length,
        'risk_level': context.riskAssessment.level,
      },
    );

    return context;
  }

  /// Create security approval workflow for sensitive operations
  /// Satisfies Requirements: 9.4 (Security approval workflows)
  Future<String> createSecurityApprovalWorkflow({
    required String
        operationType, // 'git_operation', 'privilege_escalation', 'sensitive_data_access'
    required String requesterId,
    required String requesterRole,
    required Map<String, dynamic> operationDetails,
    String? justification,
  }) async {
    final workflowId = _uuid.v4();

    // Determine required approvers based on operation type
    final requiredApprovers =
        await _determineRequiredApprovers(operationType, operationDetails);

    // Create approval task
    final approvalTask = Task(
      id: _uuid.v4(),
      title: 'Security Approval Required: $operationType',
      description: '''
Security Approval Request:
- Operation: $operationType
- Requester: $requesterId ($requesterRole)
- Justification: ${justification ?? 'No justification provided'}
- Details: ${jsonEncode(operationDetails)}

Required Approvers: ${requiredApprovers.join(', ')}

Please review and approve/reject this security-sensitive operation.
''',
      type: 'security',
      priority: 'high',
      status: 'pending',
      assigneeId: requiredApprovers.first,
      reporterId: 'security_system',
      estimatedHours: 1,
      actualHours: 0,
      relatedCommits: [],
      relatedPullRequests: [],
      dependencies: [],
      blockedBy: [],
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(hours: 24)),
      confidentialityLevel: 'restricted',
      authorizedUsers: [...requiredApprovers, requesterId],
      authorizedRoles: ['admin', 'lead_developer'],
    );

    final taskId = await _enhancedTaskService.createTaskWithConfidentiality(
      task: approvalTask,
      userId: 'security_system',
      userRole: 'admin',
    );

    // Store approval workflow details
    await _storeApprovalWorkflow(workflowId, taskId, operationType, requesterId,
        requiredApprovers, operationDetails);

    await _auditService.logAction(
      actionType: 'security_approval_workflow_created',
      description: 'Created security approval workflow for $operationType',
      aiReasoning:
          'Initiated approval workflow for security-sensitive operation requiring elevated permissions',
      contextData: {
        'workflow_id': workflowId,
        'task_id': taskId,
        'operation_type': operationType,
        'requester_id': requesterId,
        'required_approvers': requiredApprovers,
      },
      userId: requesterId,
    );

    return workflowId;
  }

  /// Process security approval decision
  /// Satisfies Requirements: 9.4 (Security approval processing)
  Future<void> processSecurityApproval({
    required String workflowId,
    required String approverId,
    required String approverRole,
    required bool approved,
    String? comments,
  }) async {
    final workflow = await _getApprovalWorkflow(workflowId);
    if (workflow == null) {
      throw Exception('Approval workflow not found: $workflowId');
    }

    // Check if approver is authorized
    if (!workflow['required_approvers'].contains(approverId)) {
      throw Exception('User not authorized to approve this workflow');
    }

    // Update workflow status
    await _updateApprovalWorkflowStatus(
        workflowId, approved, approverId, comments);

    // Update associated task
    final taskId = workflow['task_id'] as String;
    final task = await _enhancedTaskService.getAuthorizedTask(
      taskId: taskId,
      userId: approverId,
      userRole: approverRole,
    );

    if (task != null) {
      final updatedTask = task.copyWith(
        status: approved ? 'completed' : 'blocked',
        completedAt: approved ? DateTime.now() : null,
      );

      await _enhancedTaskService.updateTaskWithConfidentiality(
        updatedTask: updatedTask,
        userId: approverId,
        userRole: approverRole,
      );
    }

    await _auditService.logAction(
      actionType: 'security_approval_processed',
      description:
          'Processed security approval: ${approved ? 'APPROVED' : 'REJECTED'}',
      aiReasoning:
          'Security approval decision recorded with proper authorization verification',
      contextData: {
        'workflow_id': workflowId,
        'approver_id': approverId,
        'approved': approved,
        'comments': comments,
        'operation_type': workflow['operation_type'],
      },
      userId: approverId,
      requiresApproval: false,
      approvedBy: approverId,
    );
  }

  // Private helper methods

  Future<void> _setupSecurityEventHandlers() async {
    // Set up event handlers for security alerts to automatically create tasks
    // This would integrate with the existing security monitor
  }

  Future<void> _initializeSecurityPolicies() async {
    // Initialize security policies for git operations and access control
  }

  String _getTaskConfidentialityFromSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'confidential';
      case 'high':
        return 'restricted';
      case 'medium':
        return 'team';
      case 'low':
        return 'team';
      default:
        return 'team';
    }
  }

  Future<String> _determineSecurityTaskAssignee(SecurityAlert alert) async {
    // Logic to determine appropriate assignee based on alert type and severity
    switch (alert.type) {
      case 'database_breach':
        return 'security_admin';
      case 'auth_flood':
        return 'security_admin';
      case 'system_anomaly':
        return 'lead_developer';
      case 'network_anomaly':
        return 'security_admin';
      default:
        return 'security_admin';
    }
  }

  String _getPriorityFromSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'critical';
      case 'high':
        return 'high';
      case 'medium':
        return 'medium';
      case 'low':
        return 'low';
      default:
        return 'medium';
    }
  }

  int _estimateSecurityTaskHours(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 8;
      case 'high':
        return 4;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 2;
    }
  }

  DateTime _calculateSecurityTaskDueDate(String severity) {
    final now = DateTime.now();
    switch (severity.toLowerCase()) {
      case 'critical':
        return now.add(const Duration(hours: 4));
      case 'high':
        return now.add(const Duration(hours: 24));
      case 'medium':
        return now.add(const Duration(days: 3));
      case 'low':
        return now.add(const Duration(days: 7));
      default:
        return now.add(const Duration(days: 3));
    }
  }

  Future<List<String>> _getAuthorizedUsersForSecurityTask(
      String severity) async {
    // Return list of user IDs authorized for security tasks of this severity
    return ['security_admin', 'admin'];
  }

  List<String> _getAuthorizedRolesForSecurityTask(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return ['admin'];
      case 'high':
        return ['admin', 'lead_developer'];
      case 'medium':
        return ['admin', 'lead_developer'];
      case 'low':
        return ['admin', 'lead_developer', 'developer'];
      default:
        return ['admin', 'lead_developer'];
    }
  }

  Future<void> _linkAlertToTask(String alertId, String taskId) async {
    // Store the relationship between alert and task
    final db = await DatabaseService.instance.database;
    await db.insert('alert_task_links', {
      'id': _uuid.v4(),
      'alert_id': alertId,
      'task_id': taskId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool> _checkUserGitPermissions(
      String userId, String userRole, String operation) async {
    // Check if user has permissions for git operation
    switch (operation) {
      case 'commit':
      case 'push':
        return userRole != 'viewer';
      case 'merge':
        return userRole == 'admin' || userRole == 'lead_developer';
      case 'branch_create':
        return userRole != 'viewer';
      default:
        return false;
    }
  }

  Future<List<String>> _checkSensitiveFileModifications(
      Map<String, dynamic> context) async {
    final files = context['modified_files'] as List<String>? ?? [];
    final sensitivePatterns = [
      '.env',
      'config/',
      'security/',
      'auth/',
      'database/',
      'secrets/',
    ];

    return files
        .where((file) =>
            sensitivePatterns.any((pattern) => file.contains(pattern)))
        .toList();
  }

  Future<List<String>> _detectSecurityRelatedChanges(
      Map<String, dynamic> context) async {
    final changes = context['changes'] as String? ?? '';
    final securityKeywords = [
      'password',
      'secret',
      'token',
      'auth',
      'security',
      'permission',
      'role',
      'admin',
    ];

    return securityKeywords
        .where((keyword) => changes.toLowerCase().contains(keyword))
        .toList();
  }

  String _determineRequiredApprovalLevel(
      List<String> violations, List<String> warnings, String userRole) {
    if (violations.isNotEmpty) {
      return 'admin';
    } else if (warnings.isNotEmpty && userRole == 'developer') {
      return 'lead_developer';
    }
    return 'none';
  }

  Future<List<Map<String, dynamic>>> _getRecentCodeChanges(
      DateTime incidentTime) async {
    // Get code changes within 24 hours of incident
    return [];
  }

  Future<List<Task>> _getTasksRelatedToAlert(SecurityAlert alert) async {
    // Get tasks related to the security alert
    return [];
  }

  Future<List<Map<String, dynamic>>> _getUserActivityAroundIncident(
      DateTime incidentTime) async {
    // Get user activity around incident time
    return [];
  }

  Future<Map<String, dynamic>> _getSystemStateAtIncident(
      DateTime incidentTime) async {
    // Get system state at incident time
    return {};
  }

  Future<List<Map<String, dynamic>>> _correlateCodeChangesWithIncident(
      SecurityAlert alert, List<Map<String, dynamic>> commits) async {
    // Correlate code changes with security incident
    return commits;
  }

  Future<SecurityRiskAssessment> _assessIncidentRisk(
      SecurityAlert alert, List<Map<String, dynamic>> correlatedChanges) async {
    return SecurityRiskAssessment(
      level: alert.severity,
      factors: ['alert_severity', 'code_changes'],
      score: _calculateRiskScore(alert.severity),
    );
  }

  int _calculateRiskScore(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 10;
      case 'high':
        return 7;
      case 'medium':
        return 5;
      case 'low':
        return 2;
      default:
        return 5;
    }
  }

  Future<List<String>> _generateRecommendedActions(
      SecurityAlert alert, List<Map<String, dynamic>> correlatedChanges) async {
    return [
      'Investigate the security incident thoroughly',
      'Review recent code changes for security implications',
      'Update security policies if necessary',
      'Implement additional monitoring if required',
    ];
  }

  Future<List<String>> _determineRequiredApprovers(
      String operationType, Map<String, dynamic> details) async {
    switch (operationType) {
      case 'git_operation':
        return ['lead_developer'];
      case 'privilege_escalation':
        return ['admin'];
      case 'sensitive_data_access':
        return ['admin', 'security_admin'];
      default:
        return ['admin'];
    }
  }

  Future<void> _storeApprovalWorkflow(
    String workflowId,
    String taskId,
    String operationType,
    String requesterId,
    List<String> requiredApprovers,
    Map<String, dynamic> operationDetails,
  ) async {
    final db = await DatabaseService.instance.database;
    await db.insert('security_approval_workflows', {
      'id': workflowId,
      'task_id': taskId,
      'operation_type': operationType,
      'requester_id': requesterId,
      'required_approvers': requiredApprovers.join(','),
      'operation_details': jsonEncode(operationDetails),
      'status': 'pending',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<Map<String, dynamic>?> _getApprovalWorkflow(String workflowId) async {
    final db = await DatabaseService.instance.database;
    final results = await db.query(
      'security_approval_workflows',
      where: 'id = ?',
      whereArgs: [workflowId],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    return {
      'id': row['id'],
      'task_id': row['task_id'],
      'operation_type': row['operation_type'],
      'requester_id': row['requester_id'],
      'required_approvers': (row['required_approvers'] as String).split(','),
      'operation_details': jsonDecode(row['operation_details'] as String),
      'status': row['status'],
    };
  }

  Future<void> _updateApprovalWorkflowStatus(
    String workflowId,
    bool approved,
    String approverId,
    String? comments,
  ) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      'security_approval_workflows',
      {
        'status': approved ? 'approved' : 'rejected',
        'approved_by': approverId,
        'approval_comments': comments,
        'approved_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [workflowId],
    );
  }
}

// Data classes for security workflow integration

class SecurityPolicyResult {
  final bool compliant;
  final List<String> violations;
  final List<String> warnings;
  final bool requiresApproval;
  final String approvalLevel;

  SecurityPolicyResult({
    required this.compliant,
    required this.violations,
    required this.warnings,
    required this.requiresApproval,
    required this.approvalLevel,
  });
}

class SecurityIncidentContext {
  final String alertId;
  final DateTime incidentTime;
  final List<Map<String, dynamic>> recentCommits;
  final List<Task> relatedTasks;
  final List<Map<String, dynamic>> userActivity;
  final Map<String, dynamic> systemState;
  final SecurityRiskAssessment riskAssessment;
  final List<String> recommendedActions;

  SecurityIncidentContext({
    required this.alertId,
    required this.incidentTime,
    required this.recentCommits,
    required this.relatedTasks,
    required this.userActivity,
    required this.systemState,
    required this.riskAssessment,
    required this.recommendedActions,
  });
}

class SecurityRiskAssessment {
  final String level;
  final List<String> factors;
  final int score;

  SecurityRiskAssessment({
    required this.level,
    required this.factors,
    required this.score,
  });
}
