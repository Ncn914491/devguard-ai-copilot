import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:devguard_ai_copilot/core/security/security_workflow_integration.dart';
import 'package:devguard_ai_copilot/core/security/git_security_enforcer.dart';
import 'package:devguard_ai_copilot/core/security/security_audit_reporter.dart';
import 'package:devguard_ai_copilot/core/database/services/services.dart';
import 'package:devguard_ai_copilot/core/database/models/models.dart';

/// Comprehensive test for Security Workflow Integration
/// Verifies Requirements: 9.1, 9.2, 9.3, 9.4, 9.5
void main() {
  group('Security Workflow Integration Tests', () {
    late SecurityWorkflowIntegration securityWorkflow;
    late GitSecurityEnforcer gitEnforcer;
    late SecurityAuditReporter auditReporter;
    late SecurityAlertService alertService;
    late EnhancedTaskService taskService;

    setUpAll(() async {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Initialize services
      securityWorkflow = SecurityWorkflowIntegration.instance;
      gitEnforcer = GitSecurityEnforcer.instance;
      auditReporter = SecurityAuditReporter.instance;
      alertService = SecurityAlertService.instance;
      taskService = EnhancedTaskService.instance;

      // Initialize security workflow integration
      await securityWorkflow.initialize();
    });

    group(
        'Requirement 9.1: Security Monitoring Integration with Task Management',
        () {
      test('should create security incident task from alert', () async {
        // Create a test security alert
        final alert = SecurityAlert(
          id: 'test-alert-1',
          type: 'database_breach',
          severity: 'critical',
          title: 'Test Security Breach',
          description: 'Test security breach for integration testing',
          aiExplanation:
              'This is a test alert for verifying task creation integration',
          status: 'new',
          detectedAt: DateTime.now(),
          rollbackSuggested: true,
        );

        await alertService.createSecurityAlert(alert);

        // Create security incident task from alert
        final taskId = await securityWorkflow.createSecurityIncidentTask(
          alert.id,
          userId: 'test-user',
          userRole: 'admin',
        );

        expect(taskId, isNotEmpty);

        // Verify task was created with correct properties
        final task = await taskService.getAuthorizedTask(
          taskId: taskId,
          userId: 'test-user',
          userRole: 'admin',
        );

        expect(task, isNotNull);
        expect(task!.type, equals('security'));
        expect(task.title, contains('Security Incident'));
        expect(task.priority, equals('critical'));
        expect(task.confidentialityLevel, equals('confidential'));
      });

      test('should link alert to task correctly', () async {
        final alert = SecurityAlert(
          id: 'test-alert-2',
          type: 'auth_flood',
          severity: 'high',
          title: 'Authentication Flood',
          description: 'Multiple failed login attempts detected',
          aiExplanation: 'Potential brute force attack detected',
          status: 'new',
          detectedAt: DateTime.now(),
          rollbackSuggested: false,
        );

        await alertService.createSecurityAlert(alert);

        final taskId = await securityWorkflow.createSecurityIncidentTask(
          alert.id,
          userId: 'test-user',
          userRole: 'admin',
        );

        // Verify the link exists in database
        final db = await DatabaseService.instance.database;
        final links = await db.query(
          'alert_task_links',
          where: 'alert_id = ? AND task_id = ?',
          whereArgs: [alert.id, taskId],
        );

        expect(links, hasLength(1));
      });
    });

    group('Requirement 9.2: Security Policy Enforcement in Git Operations', () {
      test('should enforce commit security policies', () async {
        final result = await gitEnforcer.enforceCommitSecurity(
          userId: 'test-developer',
          userRole: 'developer',
          modifiedFiles: ['config/security.json', 'src/auth.dart'],
          commitMessage: 'Update security config',
          fileChanges: {
            'config/security.json': '{"api_key": "secret-key-123"}',
            'src/auth.dart': 'const password = "hardcoded-password";',
          },
        );

        expect(result.allowed, isFalse);
        expect(result.violations, isNotEmpty);
        expect(result.violations.any((v) => v.contains('sensitive')), isTrue);
        expect(result.requiresApproval, isTrue);
      });

      test('should enforce push security policies', () async {
        final result = await gitEnforcer.enforcePushSecurity(
          userId: 'test-developer',
          userRole: 'developer',
          branchName: 'main',
          commitHashes: ['abc123', 'def456'],
        );

        expect(result.allowed, isFalse);
        expect(result.violations,
            contains('Only admins can push to protected branch: main'));
        expect(result.requiresApproval, isTrue);
      });

      test('should enforce code access security', () async {
        final result = await gitEnforcer.enforceCodeAccess(
          userId: 'test-viewer',
          userRole: 'viewer',
          filePath: 'secrets/api-keys.json',
          accessType: 'read',
        );

        expect(result.allowed, isFalse);
        expect(result.violations, isNotEmpty);
        expect(result.requiresApproval, isTrue);
      });

      test('should allow valid operations for authorized users', () async {
        final result = await gitEnforcer.enforceCommitSecurity(
          userId: 'test-admin',
          userRole: 'admin',
          modifiedFiles: ['src/feature.dart'],
          commitMessage: 'Add new feature implementation',
          fileChanges: {
            'src/feature.dart': 'class NewFeature { void doSomething() {} }',
          },
        );

        expect(result.allowed, isTrue);
        expect(result.violations, isEmpty);
        expect(result.requiresApproval, isFalse);
      });
    });

    group('Requirement 9.3: Security Incident Context Gathering', () {
      test('should gather comprehensive incident context', () async {
        final alert = SecurityAlert(
          id: 'test-alert-context',
          type: 'system_anomaly',
          severity: 'high',
          title: 'System Anomaly Detected',
          description: 'Unusual system behavior detected',
          aiExplanation: 'System showing signs of potential compromise',
          status: 'new',
          detectedAt: DateTime.now(),
          rollbackSuggested: true,
        );

        await alertService.createSecurityAlert(alert);

        final context = await securityWorkflow.gatherIncidentContext(alert.id);

        expect(context.alertId, equals(alert.id));
        expect(context.incidentTime, equals(alert.detectedAt));
        expect(context.riskAssessment, isNotNull);
        expect(context.recommendedActions, isNotEmpty);
        expect(context.recommendedActions,
            contains('Investigate the security incident thoroughly'));
      });

      test('should correlate code changes with incidents', () async {
        final alert = SecurityAlert(
          id: 'test-alert-correlation',
          type: 'database_breach',
          severity: 'critical',
          title: 'Database Breach',
          description: 'Unauthorized database access detected',
          aiExplanation: 'Potential data exfiltration attempt',
          status: 'new',
          detectedAt: DateTime.now(),
          rollbackSuggested: true,
        );

        await alertService.createSecurityAlert(alert);

        final context = await securityWorkflow.gatherIncidentContext(alert.id);

        expect(context.recentCommits, isNotNull);
        expect(context.userActivity, isNotNull);
        expect(context.systemState, isNotNull);
      });
    });

    group('Requirement 9.4: Security Approval Workflows', () {
      test('should create security approval workflow', () async {
        final workflowId =
            await securityWorkflow.createSecurityApprovalWorkflow(
          operationType: 'git_operation',
          requesterId: 'test-developer',
          requesterRole: 'developer',
          operationDetails: {
            'operation': 'push',
            'branch': 'main',
            'files': ['config/security.json'],
          },
          justification: 'Emergency security fix required',
        );

        expect(workflowId, isNotEmpty);

        // Verify workflow was stored
        final db = await DatabaseService.instance.database;
        final workflows = await db.query(
          'security_approval_workflows',
          where: 'id = ?',
          whereArgs: [workflowId],
        );

        expect(workflows, hasLength(1));
        expect(workflows.first['status'], equals('pending'));
        expect(workflows.first['operation_type'], equals('git_operation'));
      });

      test('should process security approval decision', () async {
        final workflowId =
            await securityWorkflow.createSecurityApprovalWorkflow(
          operationType: 'privilege_escalation',
          requesterId: 'test-developer',
          requesterRole: 'developer',
          operationDetails: {
            'requested_role': 'admin',
            'duration': '1 hour',
          },
          justification: 'Need admin access for emergency deployment',
        );

        // Process approval
        await securityWorkflow.processSecurityApproval(
          workflowId: workflowId,
          approverId: 'test-admin',
          approverRole: 'admin',
          approved: true,
          comments: 'Approved for emergency deployment',
        );

        // Verify workflow status updated
        final db = await DatabaseService.instance.database;
        final workflows = await db.query(
          'security_approval_workflows',
          where: 'id = ?',
          whereArgs: [workflowId],
        );

        expect(workflows.first['status'], equals('approved'));
        expect(workflows.first['approved_by'], equals('test-admin'));
        expect(workflows.first['approval_comments'],
            equals('Approved for emergency deployment'));
      });

      test('should reject unauthorized approval attempts', () async {
        final workflowId =
            await securityWorkflow.createSecurityApprovalWorkflow(
          operationType: 'sensitive_data_access',
          requesterId: 'test-developer',
          requesterRole: 'developer',
          operationDetails: {
            'data_type': 'customer_pii',
            'purpose': 'debugging',
          },
        );

        // Attempt approval by unauthorized user
        expect(
          () => securityWorkflow.processSecurityApproval(
            workflowId: workflowId,
            approverId: 'unauthorized-user',
            approverRole: 'developer',
            approved: true,
          ),
          throwsException,
        );
      });
    });

    group('Requirement 9.5: Security Audit Reporting', () {
      test('should generate comprehensive security audit report', () async {
        // Create test data
        final alert1 = SecurityAlert(
          id: 'audit-alert-1',
          type: 'database_breach',
          severity: 'critical',
          title: 'Database Breach 1',
          description: 'Test breach 1',
          aiExplanation: 'Test explanation 1',
          status: 'resolved',
          detectedAt: DateTime.now().subtract(const Duration(days: 1)),
          resolvedAt: DateTime.now(),
          rollbackSuggested: true,
        );

        final alert2 = SecurityAlert(
          id: 'audit-alert-2',
          type: 'auth_flood',
          severity: 'high',
          title: 'Auth Flood 1',
          description: 'Test flood 1',
          aiExplanation: 'Test explanation 2',
          status: 'new',
          detectedAt: DateTime.now(),
          rollbackSuggested: false,
        );

        await alertService.createSecurityAlert(alert1);
        await alertService.createSecurityAlert(alert2);

        final startDate = DateTime.now().subtract(const Duration(days: 7));
        final endDate = DateTime.now();

        final report = await auditReporter.generateComprehensiveReport(
          startDate: startDate,
          endDate: endDate,
        );

        expect(report.reportId, isNotEmpty);
        expect(report.securityAlerts, hasLength(greaterThanOrEqualTo(2)));
        expect(report.metrics.totalAlerts, greaterThanOrEqualTo(2));
        expect(report.metrics.criticalAlerts, greaterThanOrEqualTo(1));
        expect(report.recommendations, isNotEmpty);
        expect(report.complianceAssessment, isNotNull);
      });

      test('should generate security incident timeline', () async {
        final alert = SecurityAlert(
          id: 'timeline-alert',
          type: 'system_anomaly',
          severity: 'medium',
          title: 'Timeline Test Alert',
          description: 'Alert for timeline testing',
          aiExplanation: 'Test timeline generation',
          status: 'new',
          detectedAt: DateTime.now(),
          rollbackSuggested: false,
        );

        await alertService.createSecurityAlert(alert);

        final timeline = await auditReporter.generateIncidentTimeline(
          alertId: alert.id,
          timeWindow: const Duration(hours: 2),
        );

        expect(timeline.alertId, equals(alert.id));
        expect(timeline.incidentTime, equals(alert.detectedAt));
        expect(timeline.timeWindow, equals(const Duration(hours: 2)));
        expect(timeline.events, isNotNull);
      });

      test('should generate security compliance report', () async {
        final startDate = DateTime.now().subtract(const Duration(days: 30));
        final endDate = DateTime.now();

        final report = await auditReporter.generateComplianceReport(
          startDate: startDate,
          endDate: endDate,
          complianceFrameworks: ['SOC2', 'ISO27001'],
        );

        expect(report.reportId, isNotEmpty);
        expect(report.frameworks, contains('SOC2'));
        expect(report.frameworks, contains('ISO27001'));
        expect(report.assessments, hasLength(2));
        expect(report.overallScore, greaterThanOrEqualTo(0));
        expect(report.overallScore, lessThanOrEqualTo(100));
      });

      test('should generate security metrics dashboard', () async {
        final startDate = DateTime.now().subtract(const Duration(days: 7));
        final endDate = DateTime.now();

        final dashboard = await auditReporter.generateMetricsDashboard(
          startDate: startDate,
          endDate: endDate,
        );

        expect(dashboard.generatedAt, isNotNull);
        expect(dashboard.dateRange.start, equals(startDate));
        expect(dashboard.dateRange.end, equals(endDate));
        expect(dashboard.alertMetrics, isNotNull);
        expect(dashboard.taskMetrics, isNotNull);
        expect(dashboard.gitMetrics, isNotNull);
        expect(dashboard.trendAnalysis, isNotNull);
        expect(dashboard.riskScore, greaterThanOrEqualTo(0));
      });
    });

    group('Integration Tests', () {
      test('should handle complete security workflow end-to-end', () async {
        // 1. Create security alert
        final alert = SecurityAlert(
          id: 'e2e-alert',
          type: 'database_breach',
          severity: 'critical',
          title: 'End-to-End Test Breach',
          description: 'Complete workflow test',
          aiExplanation: 'Testing complete security workflow',
          status: 'new',
          detectedAt: DateTime.now(),
          rollbackSuggested: true,
        );

        await alertService.createSecurityAlert(alert);

        // 2. Create incident task from alert
        final taskId = await securityWorkflow.createSecurityIncidentTask(
          alert.id,
          userId: 'test-admin',
          userRole: 'admin',
        );

        expect(taskId, isNotEmpty);

        // 3. Gather incident context
        final context = await securityWorkflow.gatherIncidentContext(alert.id);
        expect(context.alertId, equals(alert.id));

        // 4. Create approval workflow for remediation
        final workflowId =
            await securityWorkflow.createSecurityApprovalWorkflow(
          operationType: 'git_operation',
          requesterId: 'test-developer',
          requesterRole: 'developer',
          operationDetails: {
            'operation': 'emergency_patch',
            'files': ['security/patch.dart'],
          },
          justification: 'Emergency patch for security breach',
        );

        expect(workflowId, isNotEmpty);

        // 5. Process approval
        await securityWorkflow.processSecurityApproval(
          workflowId: workflowId,
          approverId: 'test-admin',
          approverRole: 'admin',
          approved: true,
          comments: 'Approved for emergency patch',
        );

        // 6. Generate audit report
        final report = await auditReporter.generateComprehensiveReport(
          startDate: DateTime.now().subtract(const Duration(hours: 1)),
          endDate: DateTime.now(),
        );

        expect(report.securityAlerts, isNotEmpty);
        expect(report.securityTasks, isNotEmpty);
        expect(report.approvalWorkflows, isNotEmpty);
      });

      test('should enforce security policies across all operations', () async {
        // Test git commit enforcement
        final commitResult = await gitEnforcer.enforceCommitSecurity(
          userId: 'test-developer',
          userRole: 'developer',
          modifiedFiles: ['secrets/api-keys.json'],
          commitMessage: 'password = "secret123"',
          fileChanges: {
            'secrets/api-keys.json': '{"api_key": "sk-1234567890"}',
          },
        );

        expect(commitResult.allowed, isFalse);
        expect(commitResult.violations.length, greaterThan(0));

        // Test code access enforcement
        final accessResult = await gitEnforcer.enforceCodeAccess(
          userId: 'test-developer',
          userRole: 'developer',
          filePath: 'config/security.json',
          accessType: 'write',
        );

        expect(accessResult.allowed, isFalse);
        expect(accessResult.violations, isNotEmpty);

        // Test push enforcement
        final pushResult = await gitEnforcer.enforcePushSecurity(
          userId: 'test-developer',
          userRole: 'developer',
          branchName: 'security/critical-fix',
          commitHashes: ['abc123'],
        );

        expect(pushResult.allowed, isFalse);
        expect(
            pushResult.violations,
            contains(
                'Only lead developers and admins can create security branches'));
      });
    });

    tearDown(() async {
      // Clean up test data
      final db = await DatabaseService.instance.database;
      await db.delete('security_alerts');
      await db.delete('tasks');
      await db.delete('alert_task_links');
      await db.delete('security_approval_workflows');
      await db.delete('audit_logs');
    });
  });
}
