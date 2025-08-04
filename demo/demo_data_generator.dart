import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:devguard_ai_copilot/core/database/services/services.dart';
import 'package:devguard_ai_copilot/core/database/models/models.dart';

/// Demo data generator for showcasing DevGuard AI Copilot functionality
/// Satisfies Requirements: 14.2 (Demo data and scenarios)
class DemoDataGenerator {
  static final DemoDataGenerator _instance = DemoDataGenerator._internal();
  static DemoDataGenerator get instance => _instance;
  DemoDataGenerator._internal();

  final _uuid = const Uuid();
  final _random = Random();

  /// Generate comprehensive demo data
  Future<void> generateDemoData() async {
    print('🎭 Generating demo data for DevGuard AI Copilot...');

    await _generateTeamMembers();
    await _generateSpecifications();
    await _generateTasks();
    await _generateDeployments();
    await _generateSecurityAlerts();
    await _generateAuditLogs();

    print('✅ Demo data generation completed!');
  }

  /// Generate realistic team members
  Future<void> _generateTeamMembers() async {
    print('👥 Creating team members...');

    final teamMembers = [
      TeamMember(
        id: _uuid.v4(),
        name: 'Alice Johnson',
        email: 'alice.johnson@devguard.ai',
        role: 'admin',
        status: 'active',
        assignments: [],
        expertise: ['Flutter', 'Security', 'DevOps', 'Team Leadership'],
        workload: 75,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      TeamMember(
        id: _uuid.v4(),
        name: 'Bob Chen',
        email: 'bob.chen@devguard.ai',
        role: 'developer',
        status: 'active',
        assignments: [],
        expertise: ['React', 'Node.js', 'Database Design', 'API Development'],
        workload: 85,
        createdAt: DateTime.now().subtract(const Duration(days: 75)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      TeamMember(
        id: _uuid.v4(),
        name: 'Carol Martinez',
        email: 'carol.martinez@devguard.ai',
        role: 'security_reviewer',
        status: 'active',
        assignments: [],
        expertise: [
          'Cybersecurity',
          'Penetration Testing',
          'Compliance',
          'Risk Assessment'
        ],
        workload: 60,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      TeamMember(
        id: _uuid.v4(),
        name: 'David Kim',
        email: 'david.kim@devguard.ai',
        role: 'developer',
        status: 'active',
        assignments: [],
        expertise: ['Python', 'Machine Learning', 'Data Analysis', 'AI/ML'],
        workload: 70,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      TeamMember(
        id: _uuid.v4(),
        name: 'Emma Wilson',
        email: 'emma.wilson@devguard.ai',
        role: 'developer',
        status: 'bench',
        assignments: [],
        expertise: [
          'Vue.js',
          'TypeScript',
          'UI/UX Design',
          'Frontend Architecture'
        ],
        workload: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    final teamService = TeamMemberService.instance;
    for (final member in teamMembers) {
      await teamService.createTeamMember(member);
    }

    print('✅ Created ${teamMembers.length} team members');
  }

  /// Generate realistic specifications
  Future<void> _generateSpecifications() async {
    print('📋 Creating specifications...');

    final specifications = [
      Specification(
        id: _uuid.v4(),
        originalInput:
            'Implement OAuth 2.0 authentication with Google and GitHub providers, including JWT token management and refresh token rotation',
        aiInterpretation:
            'This specification requires implementing a comprehensive OAuth 2.0 authentication system supporting multiple providers (Google, GitHub) with secure JWT token management, automatic refresh token rotation, and proper session handling.',
        suggestedBranchName: 'feature/oauth2-authentication',
        suggestedCommitMessage:
            'feat: implement OAuth 2.0 authentication with Google and GitHub providers\n\n- Add OAuth 2.0 flow implementation\n- Integrate Google and GitHub authentication providers\n- Implement JWT token management with refresh rotation\n- Add secure session handling and user profile management',
        status: 'approved',
        assignedTo: 'bob-chen-id',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Specification(
        id: _uuid.v4(),
        originalInput:
            'Create a real-time notification system for security alerts with email, Slack, and in-app notifications',
        aiInterpretation:
            'This specification involves building a multi-channel notification system that can deliver security alerts through email, Slack integration, and in-app notifications with real-time updates using WebSockets.',
        suggestedBranchName: 'feature/notification-system',
        suggestedCommitMessage:
            'feat: implement real-time notification system for security alerts\n\n- Add multi-channel notification support (email, Slack, in-app)\n- Implement WebSocket-based real-time notifications\n- Create notification preferences and filtering\n- Add notification history and acknowledgment tracking',
        status: 'draft',
        assignedTo: null,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Specification(
        id: _uuid.v4(),
        originalInput:
            'Build a comprehensive audit dashboard with filtering, search, and export capabilities for compliance reporting',
        aiInterpretation:
            'This specification requires creating an advanced audit dashboard with sophisticated filtering options, full-text search capabilities, and export functionality to support compliance reporting requirements.',
        suggestedBranchName: 'feature/audit-dashboard',
        suggestedCommitMessage:
            'feat: build comprehensive audit dashboard with advanced features\n\n- Implement advanced filtering and search functionality\n- Add export capabilities (PDF, CSV, JSON)\n- Create compliance reporting templates\n- Add audit trail visualization and analytics',
        status: 'approved',
        assignedTo: 'alice-johnson-id',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      Specification(
        id: _uuid.v4(),
        originalInput:
            'Implement automated security scanning for code repositories with vulnerability detection and remediation suggestions',
        aiInterpretation:
            'This specification involves integrating automated security scanning tools to analyze code repositories, detect vulnerabilities, and provide AI-powered remediation suggestions with integration into the development workflow.',
        suggestedBranchName: 'feature/security-scanning',
        suggestedCommitMessage:
            'feat: implement automated security scanning with vulnerability detection\n\n- Integrate security scanning tools (SAST, DAST, dependency scanning)\n- Add vulnerability detection and classification\n- Implement AI-powered remediation suggestions\n- Create security scanning reports and dashboards',
        status: 'in_progress',
        assignedTo: 'carol-martinez-id',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];

    final specService = SpecService.instance;
    for (final spec in specifications) {
      await specService.createSpecification(spec);
    }

    print('✅ Created ${specifications.length} specifications');
  }

  /// Generate realistic tasks
  Future<void> _generateTasks() async {
    print('📝 Creating tasks...');

    final tasks = [
      Task(
        id: _uuid.v4(),
        title: 'Implement OAuth 2.0 Google Provider',
        description:
            'Set up Google OAuth 2.0 authentication provider with proper scopes and user profile retrieval',
        type: 'feature',
        priority: 'high',
        status: 'in_progress',
        assigneeId: 'bob-chen-id',
        estimatedHours: 16,
        actualHours: 12,
        relatedCommits: ['abc123', 'def456'],
        dependencies: [],
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        dueDate: DateTime.now().add(const Duration(days: 2)),
        completedAt: null,
      ),
      Task(
        id: _uuid.v4(),
        title: 'Design Notification System Architecture',
        description:
            'Create architectural design for multi-channel notification system with scalability considerations',
        type: 'feature',
        priority: 'medium',
        status: 'pending',
        assigneeId: 'david-kim-id',
        estimatedHours: 8,
        actualHours: 0,
        relatedCommits: [],
        dependencies: [],
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        dueDate: DateTime.now().add(const Duration(days: 5)),
        completedAt: null,
      ),
      Task(
        id: _uuid.v4(),
        title: 'Fix Security Alert False Positives',
        description:
            'Investigate and resolve false positive security alerts in honeytoken monitoring system',
        type: 'bug',
        priority: 'high',
        status: 'review',
        assigneeId: 'carol-martinez-id',
        estimatedHours: 6,
        actualHours: 8,
        relatedCommits: ['ghi789', 'jkl012'],
        dependencies: [],
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
        completedAt: null,
      ),
      Task(
        id: _uuid.v4(),
        title: 'Optimize Database Query Performance',
        description:
            'Improve performance of audit log queries and add proper indexing for large datasets',
        type: 'feature',
        priority: 'medium',
        status: 'completed',
        assigneeId: 'alice-johnson-id',
        estimatedHours: 12,
        actualHours: 10,
        relatedCommits: ['mno345', 'pqr678'],
        dependencies: [],
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
        dueDate: DateTime.now().subtract(const Duration(days: 3)),
        completedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: _uuid.v4(),
        title: 'Implement Deployment Rollback Automation',
        description:
            'Create automated rollback mechanism with health checks and verification steps',
        type: 'deployment',
        priority: 'critical',
        status: 'blocked',
        assigneeId: 'alice-johnson-id',
        estimatedHours: 20,
        actualHours: 5,
        relatedCommits: ['stu901'],
        dependencies: ['infrastructure-setup'],
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
        dueDate: DateTime.now().add(const Duration(days: 1)),
        completedAt: null,
      ),
    ];

    final taskService = TaskService.instance;
    for (final task in tasks) {
      await taskService.createTask(task);
    }

    print('✅ Created ${tasks.length} tasks');
  }

  /// Generate realistic deployments
  Future<void> _generateDeployments() async {
    print('🚀 Creating deployments...');

    final deployments = [
      Deployment(
        id: _uuid.v4(),
        environment: 'production',
        version: '1.2.3',
        status: 'success',
        pipelineConfig: 'standard-production-pipeline',
        snapshotId: 'snapshot-prod-123',
        deployedBy: 'alice-johnson-id',
        deployedAt: DateTime.now().subtract(const Duration(days: 2)),
        rollbackAvailable: true,
        healthChecks: ['api-health', 'database-health', 'security-health'],
        logs: [
          'Deployment started',
          'Tests passed',
          'Health checks passed',
          'Deployment completed'
        ],
      ),
      Deployment(
        id: _uuid.v4(),
        environment: 'staging',
        version: '1.2.4-rc.1',
        status: 'in_progress',
        pipelineConfig: 'staging-pipeline',
        snapshotId: 'snapshot-staging-124',
        deployedBy: 'bob-chen-id',
        deployedAt: DateTime.now().subtract(const Duration(minutes: 15)),
        rollbackAvailable: false,
        healthChecks: ['api-health'],
        logs: ['Deployment started', 'Running tests...'],
      ),
      Deployment(
        id: _uuid.v4(),
        environment: 'development',
        version: '1.2.4-dev.5',
        status: 'failed',
        pipelineConfig: 'development-pipeline',
        snapshotId: 'snapshot-dev-125',
        deployedBy: 'david-kim-id',
        deployedAt: DateTime.now().subtract(const Duration(hours: 4)),
        rollbackAvailable: true,
        healthChecks: [],
        logs: ['Deployment started', 'Tests failed', 'Deployment aborted'],
      ),
      Deployment(
        id: _uuid.v4(),
        environment: 'production',
        version: '1.2.2',
        status: 'rolled_back',
        pipelineConfig: 'standard-production-pipeline',
        snapshotId: 'snapshot-prod-122',
        deployedBy: 'alice-johnson-id',
        deployedAt: DateTime.now().subtract(const Duration(days: 5)),
        rollbackAvailable: false,
        healthChecks: ['api-health', 'database-health'],
        logs: [
          'Deployment started',
          'Health checks failed',
          'Initiating rollback',
          'Rollback completed'
        ],
      ),
    ];

    final deploymentService = DeploymentService.instance;
    for (final deployment in deployments) {
      await deploymentService.createDeployment(deployment);
    }

    print('✅ Created ${deployments.length} deployments');
  }

  /// Generate realistic security alerts
  Future<void> _generateSecurityAlerts() async {
    print('🛡️ Creating security alerts...');

    final alerts = [
      SecurityAlert(
        id: _uuid.v4(),
        type: 'database_breach',
        severity: 'critical',
        title: 'Honeytoken Access Detected',
        description:
            'Unauthorized access to honeytoken credit card data detected from IP 192.168.1.100',
        aiExplanation:
            'A honeytoken containing fake credit card information has been accessed, indicating a potential data breach attempt. The access originated from an internal IP address, suggesting possible insider threat or compromised internal system. Immediate investigation is recommended.',
        status: 'investigating',
        detectedAt: DateTime.now().subtract(const Duration(hours: 2)),
        resolvedAt: null,
        rollbackSuggested: true,
        evidence: jsonEncode({
          'honeytoken_type': 'credit_card',
          'access_ip': '192.168.1.100',
          'access_time': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
          'query_pattern':
              'SELECT * FROM users WHERE credit_card LIKE \'4111%\'',
        }),
      ),
      SecurityAlert(
        id: _uuid.v4(),
        type: 'network_anomaly',
        severity: 'medium',
        title: 'Unusual Network Traffic Pattern',
        description:
            'Detected abnormal outbound network connections to suspicious IP addresses',
        aiExplanation:
            'Network monitoring has identified unusual outbound traffic patterns to IP addresses associated with known command and control servers. The traffic volume is 300% above baseline and includes encrypted communications on non-standard ports.',
        status: 'new',
        detectedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        resolvedAt: null,
        rollbackSuggested: false,
        evidence: jsonEncode({
          'suspicious_ips': ['203.0.113.42', '198.51.100.15'],
          'traffic_volume': '300% above baseline',
          'ports': [8443, 9999, 31337],
          'protocol': 'encrypted',
        }),
      ),
      SecurityAlert(
        id: _uuid.v4(),
        type: 'auth_flood',
        severity: 'high',
        title: 'Brute Force Attack Detected',
        description:
            'Multiple failed login attempts detected for admin account',
        aiExplanation:
            'Authentication monitoring has detected 15 consecutive failed login attempts for the admin account from IP 203.0.113.50 within a 5-minute window. This pattern is consistent with a brute force attack. The account has been temporarily locked as a precautionary measure.',
        status: 'resolved',
        detectedAt: DateTime.now().subtract(const Duration(hours: 6)),
        resolvedAt:
            DateTime.now().subtract(const Duration(hours: 5, minutes: 30)),
        rollbackSuggested: false,
        evidence: jsonEncode({
          'target_account': 'admin',
          'failed_attempts': 15,
          'source_ip': '203.0.113.50',
          'time_window': '5 minutes',
          'action_taken': 'account_locked',
        }),
      ),
      SecurityAlert(
        id: _uuid.v4(),
        type: 'system_anomaly',
        severity: 'low',
        title: 'Configuration File Modified',
        description:
            'Unexpected modification detected in application configuration file',
        aiExplanation:
            'File integrity monitoring has detected an unauthorized modification to the main application configuration file. The change appears to be related to logging configuration and may have been made during routine maintenance. However, the modification was not logged through proper change management procedures.',
        status: 'false_positive',
        detectedAt: DateTime.now().subtract(const Duration(days: 1)),
        resolvedAt: DateTime.now().subtract(const Duration(hours: 18)),
        rollbackSuggested: false,
        evidence: jsonEncode({
          'file_path': '/etc/devguard/app.conf',
          'modification_type': 'content_change',
          'changed_section': 'logging',
          'change_size': '3 lines',
        }),
      ),
    ];

    final securityService = SecurityAlertService.instance;
    for (final alert in alerts) {
      await securityService.createSecurityAlert(alert);
    }

    print('✅ Created ${alerts.length} security alerts');
  }

  /// Generate realistic audit logs
  Future<void> _generateAuditLogs() async {
    print('📊 Creating audit logs...');

    final auditLogs = <AuditLog>[];
    final actionTypes = [
      'user_login',
      'specification_created',
      'deployment_started',
      'security_alert_generated',
      'task_assigned',
      'configuration_changed',
      'backup_created',
      'rollback_initiated',
      'team_member_added',
      'copilot_command_executed',
    ];

    final userIds = [
      'alice-johnson-id',
      'bob-chen-id',
      'carol-martinez-id',
      'david-kim-id'
    ];
    final descriptions = {
      'user_login': 'User logged into the system',
      'specification_created': 'New specification created and processed',
      'deployment_started': 'Deployment pipeline initiated',
      'security_alert_generated': 'Security monitoring generated new alert',
      'task_assigned': 'Task assigned to team member',
      'configuration_changed': 'System configuration modified',
      'backup_created': 'Database backup created successfully',
      'rollback_initiated': 'Deployment rollback initiated',
      'team_member_added': 'New team member added to project',
      'copilot_command_executed': 'AI copilot command processed',
    };

    // Generate 50 audit log entries over the past 30 days
    for (int i = 0; i < 50; i++) {
      final actionType = actionTypes[_random.nextInt(actionTypes.length)];
      final userId =
          _random.nextBool() ? userIds[_random.nextInt(userIds.length)] : null;
      final timestamp = DateTime.now().subtract(Duration(
        days: _random.nextInt(30),
        hours: _random.nextInt(24),
        minutes: _random.nextInt(60),
      ));

      auditLogs.add(AuditLog(
        id: _uuid.v4(),
        actionType: actionType,
        description: descriptions[actionType]!,
        aiReasoning: _generateAIReasoning(actionType),
        contextData: _generateContextData(actionType),
        requiresApproval: _random.nextDouble() < 0.2, // 20% require approval
        approvedBy: _random.nextBool() ? userId : null,
        userId: userId,
        timestamp: timestamp,
      ));
    }

    final auditService = AuditLogService.instance;
    for (final log in auditLogs) {
      await auditService.logAction(
        actionType: log.actionType,
        description: log.description,
        aiReasoning: log.aiReasoning,
        contextData: log.contextData,
        requiresApproval: log.requiresApproval,
        approvedBy: log.approvedBy,
        userId: log.userId,
      );
    }

    print('✅ Created ${auditLogs.length} audit log entries');
  }

  /// Generate AI reasoning for audit logs
  String _generateAIReasoning(String actionType) {
    final reasonings = {
      'user_login':
          'User authentication successful, session established with proper security protocols',
      'specification_created':
          'Natural language specification processed and converted to structured development tasks',
      'deployment_started':
          'Automated deployment pipeline triggered based on approved specification',
      'security_alert_generated':
          'Security monitoring detected anomalous behavior requiring investigation',
      'task_assigned':
          'AI-suggested task assignment based on team member expertise and current workload',
      'configuration_changed':
          'System configuration updated to improve security and performance',
      'backup_created':
          'Automated backup created as part of data protection strategy',
      'rollback_initiated':
          'Deployment rollback triggered due to health check failures',
      'team_member_added':
          'New team member onboarded with appropriate role and permissions',
      'copilot_command_executed':
          'AI copilot processed user command and provided contextual assistance',
    };

    return reasonings[actionType] ??
        'System action performed as part of normal operations';
  }

  /// Generate context data for audit logs
  Map<String, dynamic> _generateContextData(String actionType) {
    switch (actionType) {
      case 'user_login':
        return {
          'ip_address': '192.168.1.${_random.nextInt(255)}',
          'user_agent': 'DevGuard-Desktop/1.0.0',
          'session_id': _uuid.v4(),
        };
      case 'specification_created':
        return {
          'spec_id': _uuid.v4(),
          'branch_name': 'feature/demo-${_random.nextInt(1000)}',
          'estimated_hours': _random.nextInt(20) + 4,
        };
      case 'deployment_started':
        return {
          'environment': [
            'development',
            'staging',
            'production'
          ][_random.nextInt(3)],
          'version': '1.2.${_random.nextInt(10)}',
          'pipeline_id': _uuid.v4(),
        };
      case 'security_alert_generated':
        return {
          'alert_type': [
            'database_breach',
            'network_anomaly',
            'auth_flood'
          ][_random.nextInt(3)],
          'severity': ['low', 'medium', 'high', 'critical'][_random.nextInt(4)],
          'source_ip': '192.168.1.${_random.nextInt(255)}',
        };
      case 'task_assigned':
        return {
          'task_id': _uuid.v4(),
          'assignee_id': 'user-${_random.nextInt(5)}',
          'priority': ['low', 'medium', 'high'][_random.nextInt(3)],
        };
      default:
        return {
          'timestamp': DateTime.now().toIso8601String(),
          'component': actionType.split('_').first,
        };
    }
  }

  /// Clear all demo data
  Future<void> clearDemoData() async {
    print('🧹 Clearing existing demo data...');

    // This would clear all data from the database
    // Implementation depends on database service methods

    print('✅ Demo data cleared');
  }

  /// Generate demo snapshots for rollback testing
  Future<void> generateDemoSnapshots() async {
    print('📸 Creating demo snapshots...');

    final snapshots = [
      Snapshot(
        id: _uuid.v4(),
        environment: 'production',
        gitCommit: 'abc123def456',
        databaseBackup: '/backups/prod_20240101_120000.db',
        configFiles: ['/etc/app.conf', '/etc/nginx.conf', '/etc/ssl/certs.pem'],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        verified: true,
      ),
      Snapshot(
        id: _uuid.v4(),
        environment: 'staging',
        gitCommit: 'def456ghi789',
        databaseBackup: '/backups/staging_20240101_180000.db',
        configFiles: ['/etc/app.conf', '/etc/nginx.conf'],
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        verified: true,
      ),
      Snapshot(
        id: _uuid.v4(),
        environment: 'development',
        gitCommit: 'ghi789jkl012',
        databaseBackup: '/backups/dev_20240101_220000.db',
        configFiles: ['/etc/app.conf'],
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        verified: false,
      ),
    ];

    final snapshotService = SnapshotService.instance;
    for (final snapshot in snapshots) {
      await snapshotService.createSnapshot(snapshot);
    }

    print('✅ Created ${snapshots.length} demo snapshots');
  }

  /// Generate performance test data
  Future<void> generatePerformanceTestData() async {
    print('⚡ Generating performance test data...');

    // Generate large number of audit logs for performance testing
    final auditService = AuditLogService.instance;

    for (int i = 0; i < 1000; i++) {
      await auditService.logAction(
        actionType: 'performance_test',
        description: 'Performance test log entry $i',
        aiReasoning: 'Generated for performance testing purposes',
        contextData: {
          'test_id': i,
          'batch': i ~/ 100,
          'timestamp':
              DateTime.now().subtract(Duration(seconds: i)).toIso8601String(),
        },
      );

      if (i % 100 == 0) {
        print('Generated ${i + 1}/1000 performance test entries');
      }
    }

    print('✅ Generated 1000 performance test entries');
  }
}
