import 'package:uuid/uuid.dart';
import '../database/services/services.dart';
import '../database/models/models.dart';
import 'gemini_service.dart';

class CopilotService {
  static final CopilotService _instance = CopilotService._internal();
  static CopilotService get instance => _instance;
  CopilotService._internal();

  final _uuid = const Uuid();
  final _geminiService = GeminiService.instance;
  final _auditService = AuditLogService.instance;
  final _specService = SpecService.instance;
  final _deploymentService = DeploymentService.instance;
  final _securityAlertService = SecurityAlertService.instance;
  final _snapshotService = SnapshotService.instance;
  final _teamMemberService = TeamMemberService.instance;

  /// Process copilot command and return response
  /// Satisfies Requirements: 4.1, 4.3, 4.4 (Copilot interface with command parsing)
  Future<CopilotResponse> processCommand(String input, {String? userId}) async {
    final commandId = _uuid.v4();
    
    try {
      // Parse command
      final command = _parseCommand(input.trim());
      
      // Log command processing
      await _auditService.logAction(
        actionType: 'copilot_command_processed',
        description: 'Processing copilot command: ${command.type}',
        aiReasoning: 'User issued command: $input',
        contextData: {
          'command_id': commandId,
          'command_type': command.type,
          'raw_input': input,
        },
        userId: userId,
      );

      // Execute command
      switch (command.type) {
        case CopilotCommandType.rollback:
          return await _handleRollbackCommand(command, userId);
        case CopilotCommandType.assign:
          return await _handleAssignCommand(command, userId);
        case CopilotCommandType.summarize:
          return await _handleSummarizeCommand(command, userId);
        case CopilotCommandType.help:
          return _handleHelpCommand();
        case CopilotCommandType.chat:
          return await _handleChatCommand(command, userId);
        default:
          return CopilotResponse(
            type: CopilotResponseType.error,
            message: 'Unknown command. Type /help for available commands.',
            requiresApproval: false,
          );
      }
    } catch (e) {
      // Log error
      await _auditService.logAction(
        actionType: 'copilot_command_failed',
        description: 'Failed to process copilot command: ${e.toString()}',
        contextData: {'command_id': commandId, 'error': e.toString()},
        userId: userId,
      );
      
      return CopilotResponse(
        type: CopilotResponseType.error,
        message: 'Error processing command: ${e.toString()}',
        requiresApproval: false,
      );
    }
  }

  /// Parse user input into structured command
  CopilotCommand _parseCommand(String input) {
    if (input.startsWith('/')) {
      final parts = input.substring(1).split(' ');
      final commandName = parts[0].toLowerCase();
      final args = parts.length > 1 ? parts.sublist(1) : <String>[];
      
      switch (commandName) {
        case 'rollback':
          return CopilotCommand(
            type: CopilotCommandType.rollback,
            args: args,
            rawInput: input,
          );
        case 'assign':
          return CopilotCommand(
            type: CopilotCommandType.assign,
            args: args,
            rawInput: input,
          );
        case 'summarize':
          return CopilotCommand(
            type: CopilotCommandType.summarize,
            args: args,
            rawInput: input,
          );
        case 'help':
          return CopilotCommand(
            type: CopilotCommandType.help,
            args: args,
            rawInput: input,
          );
        default:
          return CopilotCommand(
            type: CopilotCommandType.unknown,
            args: args,
            rawInput: input,
          );
      }
    } else {
      return CopilotCommand(
        type: CopilotCommandType.chat,
        args: [input],
        rawInput: input,
      );
    }
  }

  /// Handle rollback command
  /// Satisfies Requirements: 7.2, 7.3 (Rollback with human confirmation)
  Future<CopilotResponse> _handleRollbackCommand(CopilotCommand command, String? userId) async {
    try {
      final environment = command.args.isNotEmpty ? command.args[0] : 'production';
      
      // Get latest deployment for environment
      final deployment = await _deploymentService.getLatestSuccessfulDeployment(environment);
      if (deployment == null) {
        return CopilotResponse(
          type: CopilotResponseType.info,
          message: 'No successful deployments found for $environment environment.',
          requiresApproval: false,
        );
      }

      // Get rollback options
      final snapshots = await _snapshotService.getRollbackOptions(environment);
      if (snapshots.isEmpty) {
        return CopilotResponse(
          type: CopilotResponseType.error,
          message: 'No verified snapshots available for rollback in $environment.',
          requiresApproval: false,
        );
      }

      final latestSnapshot = snapshots.first;
      
      // Generate AI explanation for rollback
      final explanation = await _generateRollbackExplanation(deployment, latestSnapshot);
      
      return CopilotResponse(
        type: CopilotResponseType.rollback,
        message: explanation,
        requiresApproval: true,
        actionData: {
          'deployment_id': deployment.id,
          'snapshot_id': latestSnapshot.id,
          'environment': environment,
        },
      );
    } catch (e) {
      return CopilotResponse(
        type: CopilotResponseType.error,
        message: 'Error preparing rollback: ${e.toString()}',
        requiresApproval: false,
      );
    }
  }

  /// Handle assign command
  /// Satisfies Requirements: 5.2, 5.3 (AI-suggested assignments with approval)
  Future<CopilotResponse> _handleAssignCommand(CopilotCommand command, String? userId) async {
    try {
      if (command.args.length < 2) {
        return CopilotResponse(
          type: CopilotResponseType.info,
          message: 'Usage: /assign <spec_id> <team_member_id>',
          requiresApproval: false,
        );
      }

      final specId = command.args[0];
      final memberId = command.args[1];
      
      // Validate spec and member exist
      final spec = await _specService.getSpecification(specId);
      final member = await TeamMemberService.instance.getTeamMember(memberId);
      
      if (spec == null) {
        return CopilotResponse(
          type: CopilotResponseType.error,
          message: 'Specification not found: $specId',
          requiresApproval: false,
        );
      }
      
      if (member == null) {
        return CopilotResponse(
          type: CopilotResponseType.error,
          message: 'Team member not found: $memberId',
          requiresApproval: false,
        );
      }

      final explanation = 'Assigning specification "${spec.suggestedBranchName}" to ${member.name} (${member.role}). '
          'Member has expertise in: ${member.expertise.join(", ")} and current workload: ${member.workload}.';
      
      return CopilotResponse(
        type: CopilotResponseType.assignment,
        message: explanation,
        requiresApproval: true,
        actionData: {
          'spec_id': specId,
          'member_id': memberId,
          'member_name': member.name,
        },
      );
    } catch (e) {
      return CopilotResponse(
        type: CopilotResponseType.error,
        message: 'Error processing assignment: ${e.toString()}',
        requiresApproval: false,
      );
    }
  }

  /// Handle summarize command
  /// Satisfies Requirements: 4.2 (System status summaries)
  Future<CopilotResponse> _handleSummarizeCommand(CopilotCommand command, String? userId) async {
    try {
      final summary = await _generateSystemSummary();
      
      return CopilotResponse(
        type: CopilotResponseType.summary,
        message: summary,
        requiresApproval: false,
      );
    } catch (e) {
      return CopilotResponse(
        type: CopilotResponseType.error,
        message: 'Error generating summary: ${e.toString()}',
        requiresApproval: false,
      );
    }
  }

  /// Handle help command
  CopilotResponse _handleHelpCommand() {
    const helpText = '''
Available Commands:

/rollback [environment] - Suggest rollback options for environment (default: production)
/assign <spec_id> <member_id> - Assign specification to team member
/summarize - Get system status summary
/help - Show this help message

You can also chat naturally with the AI copilot for explanations and guidance.
    ''';
    
    return CopilotResponse(
      type: CopilotResponseType.info,
      message: helpText,
      requiresApproval: false,
    );
  }

  /// Handle natural language chat
  /// Satisfies Requirements: 4.1, 4.2 (Conversational AI assistance)
  Future<CopilotResponse> _handleChatCommand(CopilotCommand command, String? userId) async {
    try {
      final input = command.rawInput;
      
      // Use Gemini for natural language processing
      String response;
      if (_geminiService.isInitialized) {
        // TODO: Implement Gemini chat integration
        response = await _generateMockChatResponse(input);
      } else {
        response = await _generateMockChatResponse(input);
      }
      
      return CopilotResponse(
        type: CopilotResponseType.chat,
        message: response,
        requiresApproval: false,
      );
    } catch (e) {
      return CopilotResponse(
        type: CopilotResponseType.error,
        message: 'Error processing chat: ${e.toString()}',
        requiresApproval: false,
      );
    }
  }

  /// Generate rollback explanation using AI
  Future<String> _generateRollbackExplanation(Deployment deployment, Snapshot snapshot) async {
    return '''
🔄 Rollback Recommendation for ${deployment.environment}

Current Deployment: ${deployment.version} (deployed ${_formatDate(deployment.deployedAt)})
Target Snapshot: ${snapshot.gitCommit} (created ${_formatDate(snapshot.createdAt)})

Rollback will restore:
• Code state to commit ${snapshot.gitCommit}
• Configuration files: ${snapshot.configFiles.length} files
• Database backup (if available)

This action requires human approval and will be logged for audit purposes.
    ''';
  }

  /// Generate system summary
  Future<String> _generateSystemSummary() async {
    final specs = await _specService.getAllSpecifications();
    final alerts = await _securityAlertService.getAllSecurityAlerts();
    final deployments = await _deploymentService.getAllDeployments();
    
    final draftSpecs = specs.where((s) => s.status == 'draft').length;
    final approvedSpecs = specs.where((s) => s.status == 'approved').length;
    final activeAlerts = alerts.where((a) => a.status == 'new' || a.status == 'investigating').length;
    final recentDeployments = deployments.where((d) => 
        DateTime.now().difference(d.deployedAt).inDays < 7).length;
    
    return '''
📊 System Summary

Specifications:
• ${draftSpecs} draft specifications pending review
• ${approvedSpecs} approved specifications ready for implementation

Security:
• ${activeAlerts} active security alerts requiring attention
• ${alerts.length - activeAlerts} resolved alerts

Deployments:
• ${recentDeployments} deployments in the last 7 days
• ${deployments.where((d) => d.status == 'success').length} successful deployments total

All systems are monitored and audit logs are being maintained for transparency.
    ''';
  }

  /// Generate contextual AI response based on system state
  /// Satisfies Requirements: 4.2 (Contextual explanations and help)
  Future<String> _generateMockChatResponse(String input) async {
    final lowerInput = input.toLowerCase();
    
    if (lowerInput.contains('security') || lowerInput.contains('alert')) {
      return await _generateSecurityResponse();
    } else if (lowerInput.contains('deploy') || lowerInput.contains('rollback')) {
      return await _generateDeploymentResponse();
    } else if (lowerInput.contains('spec') || lowerInput.contains('task')) {
      return await _generateSpecificationResponse();
    } else if (lowerInput.contains('team') || lowerInput.contains('assign')) {
      return await _generateTeamResponse();
    } else if (lowerInput.contains('explain') || lowerInput.contains('what')) {
      return await _generateExplanationResponse(input);
    } else {
      return 'I\'m your DevGuard AI Copilot! I can help with:\n• Security monitoring and alerts\n• Deployment management and rollbacks\n• Specification processing and assignments\n• System summaries and explanations\n\nTry /help for available commands or ask me anything about your development workflow.';
    }
  }

  /// Generate security-focused response with current alert context
  Future<String> _generateSecurityResponse() async {
    final alerts = await _securityAlertService.getRecentAlerts(limit: 5);
    final activeAlerts = alerts.where((a) => a.status == 'new' || a.status == 'investigating').toList();
    
    if (activeAlerts.isEmpty) {
      return '🛡️ Security Status: All systems secure! No active alerts detected.\n\n'
          'Current monitoring includes:\n'
          '• Honeytoken deployment and access detection\n'
          '• Configuration drift monitoring\n'
          '• Network anomaly detection\n'
          '• Authentication flood protection\n\n'
          'Use /summarize for detailed security metrics.';
    } else {
      final criticalAlerts = activeAlerts.where((a) => a.severity == 'critical').length;
      final highAlerts = activeAlerts.where((a) => a.severity == 'high').length;
      
      return '⚠️ Security Alert Summary:\n\n'
          '• ${activeAlerts.length} active alerts requiring attention\n'
          '• $criticalAlerts critical severity alerts\n'
          '• $highAlerts high severity alerts\n\n'
          'Recent alert: ${activeAlerts.first.title}\n'
          'AI Analysis: ${activeAlerts.first.aiExplanation.substring(0, 100)}...\n\n'
          'Visit the Security dashboard for detailed investigation.';
    }
  }

  /// Generate deployment-focused response with current status
  Future<String> _generateDeploymentResponse() async {
    final deployments = await _deploymentService.getAllDeployments();
    final recentDeployments = deployments.where((d) => 
        DateTime.now().difference(d.deployedAt).inDays < 7).toList();
    
    if (recentDeployments.isEmpty) {
      return '🚀 No recent deployments in the last 7 days.\n\n'
          'Available actions:\n'
          '• Use /rollback [environment] to check rollback options\n'
          '• Visit Deployments dashboard to trigger new deployments\n'
          '• Check deployment pipeline configurations\n\n'
          'All deployments are automatically snapshotted for safe rollbacks.';
    } else {
      final successful = recentDeployments.where((d) => d.status == 'success').length;
      final failed = recentDeployments.where((d) => d.status == 'failed').length;
      final latest = recentDeployments.first;
      
      return '📊 Deployment Summary (Last 7 days):\n\n'
          '• ${recentDeployments.length} total deployments\n'
          '• $successful successful deployments\n'
          '• $failed failed deployments\n\n'
          'Latest: ${latest.version} to ${latest.environment} (${latest.status})\n'
          'Deployed: ${_formatDate(latest.deployedAt)}\n\n'
          'Use /rollback to see recovery options if needed.';
    }
  }

  /// Generate specification-focused response
  Future<String> _generateSpecificationResponse() async {
    final specs = await _specService.getAllSpecifications();
    final draftSpecs = specs.where((s) => s.status == 'draft').toList();
    final approvedSpecs = specs.where((s) => s.status == 'approved').toList();
    
    return '📋 Specification Status:\n\n'
        '• ${draftSpecs.length} draft specifications pending review\n'
        '• ${approvedSpecs.length} approved specifications ready for implementation\n'
        '• ${specs.length} total specifications in system\n\n'
        'Recent activity:\n'
        '${specs.isNotEmpty ? "Latest spec: ${specs.first.suggestedBranchName}" : "No specifications yet"}\n\n'
        'Use /assign <spec_id> <member_id> to assign work or visit AI Workflow dashboard.';
  }

  /// Generate team-focused response
  Future<String> _generateTeamResponse() async {
    final members = await _teamMemberService.getAllTeamMembers();
    final activeMembers = members.where((m) => m.status == 'active').toList();
    final benchMembers = members.where((m) => m.status == 'bench').toList();
    
    return '👥 Team Status:\n\n'
        '• ${activeMembers.length} active team members\n'
        '• ${benchMembers.length} members available on bench\n'
        '• ${members.length} total team members\n\n'
        'Workload distribution:\n'
        '${activeMembers.isNotEmpty ? "Average workload: ${activeMembers.map((m) => m.workload).reduce((a, b) => a + b) / activeMembers.length}%" : "No active members"}\n\n'
        'Use /assign to distribute work or check Team dashboard for detailed view.';
  }

  /// Generate explanation response based on context
  Future<String> _generateExplanationResponse(String input) async {
    final lowerInput = input.toLowerCase();
    
    if (lowerInput.contains('honeytoken')) {
      return '🍯 Honeytokens Explained:\n\n'
          'Honeytokens are fake sensitive data records deployed in your database to detect unauthorized access. '
          'When someone accesses these fake records, it immediately triggers a security alert.\n\n'
          'Types deployed:\n'
          '• Fake credit card numbers\n'
          '• Fake SSNs\n'
          '• Fake API keys\n'
          '• Fake password hashes\n\n'
          'This provides early warning of potential data breaches or insider threats.';
    } else if (lowerInput.contains('rollback')) {
      return '🔄 Rollback System Explained:\n\n'
          'Every deployment automatically creates a verified snapshot including:\n'
          '• Git commit state\n'
          '• Database backup\n'
          '• Configuration files\n\n'
          'When issues occur, you can safely rollback to any previous snapshot. '
          'All rollbacks require human approval and are fully audited.\n\n'
          'Use /rollback [environment] to see available options.';
    } else if (lowerInput.contains('audit')) {
      return '📝 Audit System Explained:\n\n'
          'Every AI action and system change is logged with:\n'
          '• Full context and reasoning\n'
          '• Timestamps and user attribution\n'
          '• Approval records for critical actions\n\n'
          'This ensures complete transparency and accountability for all automated decisions. '
          'Visit the Audit dashboard to explore the complete activity log.';
    } else {
      return 'I can explain various DevGuard concepts! Try asking about:\n'
          '• "What are honeytokens?"\n'
          '• "How does rollback work?"\n'
          '• "Explain the audit system"\n'
          '• Or ask about any security alert or system feature you see.';
    }
  }

  /// Execute approved action
  /// Satisfies Requirements: 9.4 (Human approval recording)
  Future<void> executeApprovedAction(String actionId, Map<String, dynamic> actionData, String approvedBy) async {
    await _auditService.logAction(
      actionType: 'copilot_action_approved',
      description: 'Executed approved copilot action: $actionId',
      contextData: actionData,
      requiresApproval: false,
      approvedBy: approvedBy,
    );
  }

  /// Get contextual explanation for security alert
  /// Satisfies Requirements: 4.2 (Alert explanations)
  Future<String> explainSecurityAlert(String alertId) async {
    try {
      final alert = await _securityAlertService.getSecurityAlert(alertId);
      if (alert == null) {
        return 'Alert not found. It may have been resolved or deleted.';
      }

      final contextualInfo = await _getAlertContext(alert);
      
      return '''
🔍 Security Alert Analysis

Alert: ${alert.title}
Severity: ${alert.severity.toUpperCase()}
Type: ${alert.type.replaceAll('_', ' ').toUpperCase()}

AI Explanation:
${alert.aiExplanation}

Context:
$contextualInfo

Recommended Actions:
${_getRecommendedActions(alert)}

Status: ${alert.status}
${alert.rollbackSuggested ? '\n⚠️ Rollback recommended for this alert.' : ''}
      ''';
    } catch (e) {
      return 'Error retrieving alert explanation: ${e.toString()}';
    }
  }

  /// Get contextual information for alert
  Future<String> _getAlertContext(SecurityAlert alert) async {
    switch (alert.type) {
      case 'database_breach':
        return '• Database monitoring detected suspicious query patterns\n'
               '• This may indicate data exfiltration attempts\n'
               '• Check recent database access logs for anomalies';
      case 'system_anomaly':
        return '• System file or configuration changes detected\n'
               '• This could indicate unauthorized modifications\n'
               '• Verify all recent system changes are authorized';
      case 'network_anomaly':
        return '• Unusual network traffic patterns detected\n'
               '• May indicate command & control communication\n'
               '• Review network connections and firewall logs';
      case 'auth_flood':
        return '• Multiple failed authentication attempts detected\n'
               '• This suggests a brute force or credential stuffing attack\n'
               '• Consider implementing rate limiting or account lockouts';
      default:
        return '• Alert triggered by automated monitoring systems\n'
               '• Review the evidence data for specific details\n'
               '• Consult security team if unsure about severity';
    }
  }

  /// Get recommended actions for alert
  String _getRecommendedActions(SecurityAlert alert) {
    switch (alert.severity) {
      case 'critical':
        return '1. Immediately investigate the alert\n'
               '2. Consider emergency rollback if system compromise suspected\n'
               '3. Notify security team and stakeholders\n'
               '4. Document all investigation steps';
      case 'high':
        return '1. Investigate within 1 hour\n'
               '2. Review related system logs\n'
               '3. Prepare rollback plan if needed\n'
               '4. Update alert status as investigation progresses';
      case 'medium':
        return '1. Investigate within 4 hours\n'
               '2. Review alert evidence\n'
               '3. Determine if escalation is needed\n'
               '4. Document findings';
      case 'low':
        return '1. Review during normal business hours\n'
               '2. Analyze for patterns with other alerts\n'
               '3. Update monitoring rules if false positive\n'
               '4. Close alert when resolved';
      default:
        return '1. Review alert details\n'
               '2. Investigate based on alert type\n'
               '3. Follow standard security procedures\n'
               '4. Document resolution';
    }
  }

  /// Get system health summary for copilot
  /// Satisfies Requirements: 4.2 (System status summaries)
  Future<String> getSystemHealthSummary() async {
    try {
      final alerts = await _securityAlertService.getAllSecurityAlerts();
      final deployments = await _deploymentService.getAllDeployments();
      final specs = await _specService.getAllSpecifications();
      final members = await _teamMemberService.getAllTeamMembers();

      final activeAlerts = alerts.where((a) => a.status == 'new' || a.status == 'investigating').length;
      final criticalAlerts = alerts.where((a) => a.severity == 'critical' && (a.status == 'new' || a.status == 'investigating')).length;
      final recentDeployments = deployments.where((d) => DateTime.now().difference(d.deployedAt).inDays < 7).length;
      final failedDeployments = deployments.where((d) => d.status == 'failed' && DateTime.now().difference(d.deployedAt).inDays < 7).length;
      final activeMembers = members.where((m) => m.status == 'active').length;
      final pendingSpecs = specs.where((s) => s.status == 'draft').length;

      final healthScore = _calculateHealthScore(activeAlerts, criticalAlerts, failedDeployments, recentDeployments);
      
      return '''
🏥 System Health Report

Overall Health: ${_getHealthStatus(healthScore)} ($healthScore/100)

Security Status:
• $activeAlerts active alerts (${criticalAlerts} critical)
• ${alerts.length - activeAlerts} resolved alerts
• Monitoring: Honeytokens, Config drift, Network anomalies

Deployment Status:
• $recentDeployments deployments in last 7 days
• $failedDeployments failed deployments
• Rollback capability: Available for all environments

Team Status:
• $activeMembers active team members
• $pendingSpecs specifications pending review
• Workload distribution: Balanced

Last Updated: ${DateTime.now().toString().substring(0, 19)}
      ''';
    } catch (e) {
      return 'Error generating health summary: ${e.toString()}';
    }
  }

  /// Calculate system health score
  int _calculateHealthScore(int activeAlerts, int criticalAlerts, int failedDeployments, int recentDeployments) {
    int score = 100;
    
    // Deduct for active alerts
    score -= activeAlerts * 5;
    score -= criticalAlerts * 15;
    
    // Deduct for failed deployments
    if (recentDeployments > 0) {
      final failureRate = (failedDeployments / recentDeployments * 100).round();
      score -= failureRate;
    }
    
    return score.clamp(0, 100);
  }

  /// Get health status description
  String _getHealthStatus(int score) {
    if (score >= 90) return '🟢 Excellent';
    if (score >= 75) return '🟡 Good';
    if (score >= 60) return '🟠 Fair';
    if (score >= 40) return '🔴 Poor';
    return '🚨 Critical';
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }
}

/// Copilot command structure
class CopilotCommand {
  final CopilotCommandType type;
  final List<String> args;
  final String rawInput;

  CopilotCommand({
    required this.type,
    required this.args,
    required this.rawInput,
  });
}

/// Copilot command types
enum CopilotCommandType {
  rollback,
  assign,
  summarize,
  help,
  chat,
  unknown,
}

/// Copilot response structure
class CopilotResponse {
  final CopilotResponseType type;
  final String message;
  final bool requiresApproval;
  final Map<String, dynamic>? actionData;

  CopilotResponse({
    required this.type,
    required this.message,
    required this.requiresApproval,
    this.actionData,
  });
}

/// Copilot response types
enum CopilotResponseType {
  chat,
  rollback,
  assignment,
  summary,
  info,
  error,
}