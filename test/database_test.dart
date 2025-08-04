import 'package:flutter_test/flutter_test.dart';
import 'package:devguard_ai_copilot/core/database/database_service.dart';
import 'package:devguard_ai_copilot/core/database/models/models.dart';
import 'package:devguard_ai_copilot/core/database/services/services.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Database Models and Services Tests', () {
    late DatabaseService databaseService;
    late TeamMemberService teamMemberService;
    late TaskService taskService;
    late SecurityAlertService securityAlertService;
    late DeploymentService deploymentService;
    late SnapshotService snapshotService;
    late AuditLogService auditLogService;
    const uuid = Uuid();

    setUpAll(() async {
      databaseService = DatabaseService.instance;
      await databaseService.initialize();

      teamMemberService = TeamMemberService.instance;
      taskService = TaskService.instance;
      securityAlertService = SecurityAlertService.instance;
      deploymentService = DeploymentService.instance;
      snapshotService = SnapshotService.instance;
      auditLogService = AuditLogService.instance;
    });

    tearDownAll(() async {
      await databaseService.close();
    });

    group('TeamMember Model and Service', () {
      test('should create and retrieve team member', () async {
        // Requirement 5.1: Team dashboard display
        final teamMember = TeamMember(
          id: uuid.v4(),
          name: 'John Doe',
          email: 'john.doe@example.com',
          role: 'developer',
          status: 'active',
          assignments: ['task-1', 'task-2'],
          expertise: ['flutter', 'dart'],
          workload: 8,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final memberId = await teamMemberService.createTeamMember(teamMember);
        expect(memberId, isNotEmpty);

        final retrievedMember = await teamMemberService.getTeamMember(memberId);
        expect(retrievedMember, isNotNull);
        expect(retrievedMember!.name, equals('John Doe'));
        expect(retrievedMember.role, equals('developer'));
        expect(retrievedMember.assignments, contains('task-1'));
      });

      test('should get team members by status', () async {
        // Requirement 5.5: Bench status indication
        final benchMember = TeamMember(
          id: uuid.v4(),
          name: 'Jane Smith',
          email: 'jane.smith@example.com',
          role: 'developer',
          status: 'bench',
          assignments: [],
          expertise: ['react', 'javascript'],
          workload: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await teamMemberService.createTeamMember(benchMember);
        final benchMembers =
            await teamMemberService.getTeamMembersByStatus('bench');
        expect(benchMembers, isNotEmpty);
        expect(benchMembers.first.status, equals('bench'));
      });
    });

    group('Task Model and Service', () {
      test('should create and retrieve task', () async {
        // Requirement 5.4: Git issues/tasks sync and progress tracking
        final task = Task(
          id: uuid.v4(),
          title: 'Implement security monitoring',
          description: 'Add database breach detection',
          type: 'security',
          priority: 'high',
          status: 'pending',
          assigneeId: uuid.v4(),
          estimatedHours: 16,
          actualHours: 0,
          relatedCommits: [],
          dependencies: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
        );

        final taskId = await taskService.createTask(task);
        expect(taskId, isNotEmpty);

        final retrievedTask = await taskService.getTask(taskId);
        expect(retrievedTask, isNotNull);
        expect(retrievedTask!.title, equals('Implement security monitoring'));
        expect(retrievedTask.type, equals('security'));
        expect(retrievedTask.priority, equals('high'));
      });

      test('should update task status', () async {
        // Requirement 5.4: Automatic progress tracking
        final task = Task(
          id: uuid.v4(),
          title: 'Test task status update',
          description: 'Testing status updates',
          type: 'feature',
          priority: 'medium',
          status: 'pending',
          assigneeId: uuid.v4(),
          estimatedHours: 8,
          actualHours: 0,
          relatedCommits: [],
          dependencies: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 3)),
        );

        final taskId = await taskService.createTask(task);
        await taskService.updateTaskStatus(taskId, 'in_progress');

        final updatedTask = await taskService.getTask(taskId);
        expect(updatedTask!.status, equals('in_progress'));
      });
    });

    group('SecurityAlert Model and Service', () {
      test('should create security alert', () async {
        // Requirement 3.2, 3.5: Database breach detection with AI explanations
        final alert = SecurityAlert(
          id: uuid.v4(),
          type: 'database_breach',
          severity: 'critical',
          title: 'Honeytoken Access Detected',
          description: 'Unauthorized access to sensitive data detected',
          aiExplanation:
              'A honeytoken has been accessed, indicating potential database breach.',
          status: 'new',
          detectedAt: DateTime.now(),
          rollbackSuggested: true,
        );

        final alertId = await securityAlertService.createSecurityAlert(alert);
        expect(alertId, isNotEmpty);

        final retrievedAlert =
            await securityAlertService.getSecurityAlert(alertId);
        expect(retrievedAlert, isNotNull);
        expect(retrievedAlert!.type, equals('database_breach'));
        expect(retrievedAlert.severity, equals('critical'));
        expect(retrievedAlert.rollbackSuggested, isTrue);
      });

      test('should create honeytoken alert', () async {
        // Requirement 3.1, 3.2: Honeytoken breach detection
        final alertId = await securityAlertService.createHoneytokenAlert(
          'credit_card',
          '4111-1111-1111-1111',
          'SELECT * FROM users WHERE credit_card = "4111-1111-1111-1111"',
        );

        expect(alertId, isNotEmpty);
        final alert = await securityAlertService.getSecurityAlert(alertId);
        expect(alert!.type, equals('database_breach'));
        expect(alert.severity, equals('critical'));
      });
    });

    group('Deployment Model and Service', () {
      test('should create deployment', () async {
        // Requirement 7.1: Deployment tracking and rollback management
        final deployment = Deployment(
          id: uuid.v4(),
          environment: 'staging',
          version: 'v1.2.3',
          status: 'pending',
          deployedBy: 'test-user',
          deployedAt: DateTime.now(),
          rollbackAvailable: true,
        );

        final deploymentId =
            await deploymentService.createDeployment(deployment);
        expect(deploymentId, isNotEmpty);

        final retrievedDeployment =
            await deploymentService.getDeployment(deploymentId);
        expect(retrievedDeployment, isNotNull);
        expect(retrievedDeployment!.environment, equals('staging'));
        expect(retrievedDeployment.version, equals('v1.2.3'));
        expect(retrievedDeployment.rollbackAvailable, isTrue);
      });

      test('should mark deployment as failed', () async {
        // Requirement 2.4: Automatic rollback suggestions on failure
        final deployment = Deployment(
          id: uuid.v4(),
          environment: 'production',
          version: 'v1.2.4',
          status: 'in_progress',
          snapshotId: 'snapshot-123',
          deployedBy: 'test-user',
          deployedAt: DateTime.now(),
          rollbackAvailable: true,
        );

        final deploymentId =
            await deploymentService.createDeployment(deployment);
        await deploymentService.markDeploymentFailed(
            deploymentId, 'Database connection failed');

        final failedDeployment =
            await deploymentService.getDeployment(deploymentId);
        expect(failedDeployment!.status, equals('failed'));
      });
    });

    group('Snapshot Model and Service', () {
      test('should create and verify snapshot', () async {
        // Requirement 7.1, 7.4: Rollback snapshots and system integrity
        final snapshot = Snapshot(
          id: uuid.v4(),
          environment: 'production',
          gitCommit: 'abc123def456',
          configFiles: ['config/app.yaml', 'config/database.yaml'],
          createdAt: DateTime.now(),
          verified: false,
        );

        final snapshotId = await snapshotService.createSnapshot(snapshot);
        expect(snapshotId, isNotEmpty);

        await snapshotService.verifySnapshot(snapshotId,
            verifiedBy: 'test-user');

        final verifiedSnapshot = await snapshotService.getSnapshot(snapshotId);
        expect(verifiedSnapshot!.verified, isTrue);
      });

      test('should create pre-deployment snapshot', () async {
        // Requirement 2.3: Snapshot creation before deployments
        final snapshotId = await snapshotService.createPreDeploymentSnapshot(
          'staging',
          'def456ghi789',
          ['config/staging.yaml'],
        );

        expect(snapshotId, isNotEmpty);
        final snapshot = await snapshotService.getSnapshot(snapshotId);
        expect(snapshot!.environment, equals('staging'));
        expect(snapshot.gitCommit, equals('def456ghi789'));
      });
    });

    group('AuditLog Model and Service', () {
      test('should log action with audit trail', () async {
        // Requirement 9.1: Complete audit logging with context and reasoning
        final auditId = await auditLogService.logAction(
          actionType: 'test_action',
          description: 'Testing audit logging functionality',
          aiReasoning: 'Automated test execution for audit trail verification',
          contextData: {'test_id': 'audit-test-1', 'component': 'database'},
          userId: 'test-user',
        );

        expect(auditId, isNotEmpty);

        final auditLog = await auditLogService.getAuditLog(auditId);
        expect(auditLog, isNotNull);
        expect(auditLog!.actionType, equals('test_action'));
        expect(auditLog.aiReasoning, contains('Automated test'));
      });

      test('should track approval workflow', () async {
        // Requirement 9.4: Human approval requirement tracking
        final auditId = await auditLogService.logAction(
          actionType: 'critical_action',
          description: 'Action requiring approval',
          requiresApproval: true,
        );

        final pendingLogs = await auditLogService.getLogsRequiringApproval();
        expect(pendingLogs, isNotEmpty);

        await auditLogService.approveAction(auditId, 'approver-user');

        final approvedLog = await auditLogService.getAuditLog(auditId);
        expect(approvedLog!.approved, isTrue);
        expect(approvedLog.approvedBy, equals('approver-user'));
      });

      test('should get audit statistics', () async {
        // Requirement 9.5: Audit trail analysis
        final stats = await auditLogService.getAuditStatistics();
        expect(stats, isA<Map<String, int>>());
        expect(stats.containsKey('total_logs'), isTrue);
        expect(stats.containsKey('ai_actions'), isTrue);
        expect(stats.containsKey('pending_approvals'), isTrue);
        expect(stats.containsKey('approved_actions'), isTrue);
      });
    });

    group('Integration Tests', () {
      test('should maintain audit trail across all services', () async {
        // Requirement 9.1: All DB actions must be logged in AuditLog
        final initialLogCount =
            (await auditLogService.getAuditStatistics())['total_logs']!;

        // Create team member
        final memberId = uuid.v4();
        final member = TeamMember(
          id: memberId,
          name: 'Integration Test User',
          email: 'integration@test.com',
          role: 'developer',
          status: 'active',
          assignments: [],
          expertise: ['testing'],
          workload: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await teamMemberService.createTeamMember(member);

        // Create task
        final task = Task(
          id: uuid.v4(),
          title: 'Integration test task',
          description: 'Testing integration',
          type: 'feature',
          priority: 'low',
          status: 'pending',
          assigneeId: memberId,
          estimatedHours: 1,
          actualHours: 0,
          relatedCommits: [],
          dependencies: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 1)),
        );
        await taskService.createTask(task);

        // Create security alert
        final alert = SecurityAlert(
          id: uuid.v4(),
          type: 'system_anomaly',
          severity: 'medium',
          title: 'Integration test alert',
          description: 'Testing alert creation',
          aiExplanation: 'Test alert for integration testing',
          status: 'new',
          detectedAt: DateTime.now(),
          rollbackSuggested: false,
        );
        await securityAlertService.createSecurityAlert(alert);

        final finalLogCount =
            (await auditLogService.getAuditStatistics())['total_logs']!;
        expect(finalLogCount, greaterThan(initialLogCount));
      });
    });
  });
}
