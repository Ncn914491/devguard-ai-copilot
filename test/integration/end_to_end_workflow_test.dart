import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:devguard_ai_copilot/core/auth/auth_service.dart';
import 'package:devguard_ai_copilot/core/services/onboarding_service.dart';
import 'package:devguard_ai_copilot/core/api/task_management_api.dart';
import 'package:devguard_ai_copilot/core/api/repository_api.dart';
import 'package:devguard_ai_copilot/core/api/websocket_service.dart';
import 'package:devguard_ai_copilot/core/devops/devops_integration_service.dart';
import 'package:devguard_ai_copilot/core/security/security_monitor.dart';

/// End-to-end testing for complete user workflows from join request to development tasks
/// Satisfies Requirements: 14.2 - Complete user workflows testing
void main() {
  group('End-to-End User Workflow Tests', () {
    late AuthService authService;
    late OnboardingService onboardingService;
    late TaskManagementAPI taskAPI;
    late RepositoryAPI repoAPI;
    late WebSocketService wsService;
    late DevOpsIntegrationService devopsService;
    late SecurityMonitor securityMonitor;

    setUpAll(() async {
      // Initialize SQLite FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // Initialize all services
      authService = AuthService.instance;
      onboardingService = OnboardingService.instance;
      taskAPI = TaskManagementAPI.instance;
      repoAPI = RepositoryAPI.instance;
      wsService = WebSocketService.instance;
      devopsService = DevOpsIntegrationService.instance;
      securityMonitor = SecurityMonitor.instance;

      // Initialize services
      await authService.initialize();
      await onboardingService.initialize();
      await wsService.initialize();
      await devopsService.initialize();
      await securityMonitor.initialize();
    });

    tearDownAll(() async {
      // Cleanup all services
      await authService.dispose();
      await onboardingService.dispose();
      await wsService.dispose();
      await devopsService.dispose();
      securityMonitor.dispose();
    });

    group('Complete New User Journey', () {
      test('End-to-end: From join request to first task completion', () async {
        // Step 1: Admin creates project
        final projectCreation = await onboardingService.createAdminAndProject(
          adminName: 'Project Admin',
          adminEmail: 'admin@newproject.com',
          password: 'AdminPassword123!',
          projectName: 'New Development Project',
          projectDescription: 'A comprehensive development project for testing',
        );

        expect(projectCreation.success, isTrue);
        final projectId = projectCreation.projectId!;
        final adminId = projectCreation.adminUserId!;

        // Step 2: New developer submits join request
        final joinRequest = await onboardingService.submitJoinRequest(
          name: 'Jane Developer',
          email: 'jane@developer.com',
          requestedRole: 'developer',
          message: 'Experienced Flutter developer looking to contribute',
        );

        expect(joinRequest.success, isTrue);
        final requestId = joinRequest.requestId!;

        // Step 3: Admin reviews and approves join request
        final approval = await onboardingService.approveJoinRequest(
          requestId: requestId,
          adminId: adminId,
          assignedRole: 'developer',
          notes: 'Approved based on experience and project needs',
        );

        expect(approval.success, isTrue);
        final generatedPassword = approval.generatedPassword!;

        // Step 4: New developer logs in for the first time
        final firstLogin = await authService.authenticate(
          'jane@developer.com',
          generatedPassword,
        );

        expect(firstLogin.success, isTrue);
        expect(firstLogin.user?.role, equals('developer'));
        final developerToken = firstLogin.token!;
        final developerId = firstLogin.user!.id;

        // Step 5: Admin creates first task for new developer
        final adminAuth = await authService.authenticate(
          'admin@newproject.com',
          'AdminPassword123!',
        );
        final adminToken = adminAuth.token!;

        final taskCreation = await taskAPI.createTask(
          title: 'Setup development environment',
          description:
              'Configure local development environment and familiarize with codebase',
          type: 'setup',
          priority: 'high',
          confidentialityLevel: 'team',
          authToken: adminToken,
        );

        expect(taskCreation.success, isTrue);
        final taskId = taskCreation.task!.id;

        // Step 6: Admin assigns task to new developer
        final taskAssignment = await taskAPI.assignTask(
          taskId: taskId,
          assigneeId: developerId,
          authToken: adminToken,
        );

        expect(taskAssignment.success, isTrue);

        // Step 7: Developer receives task notification (WebSocket)
        final wsConnection = await wsService.connect(developerToken);
        expect(wsConnection.success, isTrue);

        // Simulate real-time notification
        final notifications = <Map<String, dynamic>>[];
        wsService.onNotification = (notification) {
          notifications.add(notification);
        };

        // Trigger task assignment notification
        await wsService.broadcastTaskAssignment(taskId, developerId);

        // Wait for notification
        await Future.delayed(const Duration(milliseconds: 100));
        expect(notifications.length, greaterThan(0));
        expect(notifications.first['type'], equals('task_assigned'));

        // Step 8: Developer views assigned tasks
        final assignedTasks = await taskAPI.getAssignedTasks(
          userId: developerId,
          authToken: developerToken,
        );

        expect(assignedTasks.success, isTrue);
        expect(assignedTasks.tasks.length, equals(1));
        expect(assignedTasks.tasks.first.id, equals(taskId));

        // Step 9: Developer starts working on task
        final startWork = await taskAPI.updateTaskStatus(
          taskId: taskId,
          status: 'in_progress',
          authToken: developerToken,
        );

        expect(startWork.success, isTrue);

        // Step 10: Developer creates repository for the task
        final repoCreation = await repoAPI.createRepository(
          name: 'dev-environment-setup',
          description: 'Repository for development environment setup',
          visibility: 'private',
          authToken: developerToken,
        );

        expect(repoCreation.success, isTrue);
        final repoId = repoCreation.repository!.id;

        // Step 11: Link task to repository
        final linkTaskRepo = await taskAPI.linkTaskToRepository(
          taskId: taskId,
          repositoryId: repoId,
          authToken: developerToken,
        );

        expect(linkTaskRepo.success, isTrue);

        // Step 12: Developer adds files to repository
        final addReadme = await repoAPI.createFile(
          repositoryId: repoId,
          filePath: 'README.md',
          content: '''# Development Environment Setup

This repository contains the setup instructions and configuration files for the development environment.

## Setup Steps
1. Install Flutter SDK
2. Configure IDE
3. Setup database
4. Run initial tests
''',
          commitMessage: 'Add initial README with setup instructions',
          authToken: developerToken,
        );

        expect(addReadme.success, isTrue);

        // Step 13: Developer completes task
        final completeTask = await taskAPI.updateTaskStatus(
          taskId: taskId,
          status: 'completed',
          authToken: developerToken,
        );

        expect(completeTask.success, isTrue);

        // Step 14: Admin reviews completed task
        final taskReview = await taskAPI.getTask(
          taskId: taskId,
          authToken: adminToken,
        );

        expect(taskReview.success, isTrue);
        expect(taskReview.task?.status, equals('completed'));
        expect(taskReview.task?.assigneeId, equals(developerId));

        // Step 15: Verify audit trail exists for entire workflow
        final auditLogs = await taskAPI.getTaskAuditLog(
          taskId: taskId,
          authToken: adminToken,
        );

        expect(auditLogs.success, isTrue);
        expect(auditLogs.logs.length,
            greaterThanOrEqualTo(4)); // Created, assigned, started, completed

        // Verify audit log entries
        final logTypes = auditLogs.logs.map((log) => log.action).toList();
        expect(logTypes, contains('task_created'));
        expect(logTypes, contains('task_assigned'));
        expect(logTypes, contains('status_updated'));
        expect(logTypes, contains('repository_linked'));

        print('✅ Complete new user journey test passed');
      });

      test('End-to-end: Team collaboration workflow', () async {
        // Setup: Create team with multiple roles
        final teamSetup = await _setupTeamEnvironment();

        final adminToken = teamSetup['adminToken'] as String;
        final leadDevToken = teamSetup['leadDevToken'] as String;
        final dev1Token = teamSetup['dev1Token'] as String;
        final dev2Token = teamSetup['dev2Token'] as String;
        final viewerToken = teamSetup['viewerToken'] as String;

        final leadDevId = teamSetup['leadDevId'] as String;
        final dev1Id = teamSetup['dev1Id'] as String;
        final dev2Id = teamSetup['dev2Id'] as String;

        // Step 1: Lead developer creates feature specification
        final featureTask = await taskAPI.createTask(
          title: 'Implement user authentication system',
          description:
              'Build comprehensive user authentication with JWT tokens, role-based access, and session management',
          type: 'feature',
          priority: 'high',
          confidentialityLevel: 'team',
          authToken: leadDevToken,
        );

        expect(featureTask.success, isTrue);
        final mainTaskId = featureTask.task!.id;

        // Step 2: Lead developer breaks down into subtasks
        final subtasks = [
          {
            'title': 'Design authentication database schema',
            'assignee': dev1Id,
            'type': 'design',
          },
          {
            'title': 'Implement JWT token service',
            'assignee': dev1Id,
            'type': 'backend',
          },
          {
            'title': 'Create login/signup UI components',
            'assignee': dev2Id,
            'type': 'frontend',
          },
          {
            'title': 'Implement role-based access control',
            'assignee': dev2Id,
            'type': 'backend',
          },
        ];

        final subtaskIds = <String>[];
        for (final subtask in subtasks) {
          final created = await taskAPI.createTask(
            title: subtask['title'] as String,
            description: 'Subtask of user authentication system',
            type: subtask['type'] as String,
            priority: 'medium',
            confidentialityLevel: 'team',
            parentTaskId: mainTaskId,
            authToken: leadDevToken,
          );

          expect(created.success, isTrue);
          subtaskIds.add(created.task!.id);

          // Assign subtask
          final assigned = await taskAPI.assignTask(
            taskId: created.task!.id,
            assigneeId: subtask['assignee'] as String,
            authToken: leadDevToken,
          );

          expect(assigned.success, isTrue);
        }

        // Step 3: Create shared repository
        final sharedRepo = await repoAPI.createRepository(
          name: 'user-authentication-system',
          description: 'Shared repository for user authentication feature',
          visibility: 'private',
          authToken: leadDevToken,
        );

        expect(sharedRepo.success, isTrue);
        final repoId = sharedRepo.repository!.id;

        // Step 4: Add all developers as collaborators
        for (final devId in [dev1Id, dev2Id]) {
          final addCollaborator = await repoAPI.addCollaborator(
            repositoryId: repoId,
            userId: devId,
            accessLevel: 'write',
            authToken: leadDevToken,
          );

          expect(addCollaborator.success, isTrue);
        }

        // Step 5: Developers work on their assigned subtasks
        // Dev1 works on database schema
        final dev1StartWork = await taskAPI.updateTaskStatus(
          taskId: subtaskIds[0],
          status: 'in_progress',
          authToken: dev1Token,
        );

        expect(dev1StartWork.success, isTrue);

        final schemaFile = await repoAPI.createFile(
          repositoryId: repoId,
          filePath: 'database/auth_schema.sql',
          content: '''-- User Authentication Database Schema
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL DEFAULT 'user',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_sessions_token ON user_sessions(token_hash);
CREATE INDEX idx_sessions_user ON user_sessions(user_id);
''',
          commitMessage: 'Add user authentication database schema',
          authToken: dev1Token,
        );

        expect(schemaFile.success, isTrue);

        // Dev2 works on UI components
        final dev2StartWork = await taskAPI.updateTaskStatus(
          taskId: subtaskIds[2],
          status: 'in_progress',
          authToken: dev2Token,
        );

        expect(dev2StartWork.success, isTrue);

        final uiComponent = await repoAPI.createFile(
          repositoryId: repoId,
          filePath: 'lib/widgets/auth_forms.dart',
          content: '''import 'package:flutter/material.dart';

class LoginForm extends StatefulWidget {
  final Function(String email, String password) onLogin;
  
  const LoginForm({Key? key, required this.onLogin}) : super(key: key);
  
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Email is required';
              if (!value!.contains('@')) return 'Invalid email format';
              return null;
            },
          ),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Password is required';
              if (value!.length < 8) return 'Password must be at least 8 characters';
              return null;
            },
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                widget.onLogin(_emailController.text, _passwordController.text);
              }
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}
''',
          commitMessage: 'Add login form UI component',
          authToken: dev2Token,
        );

        expect(uiComponent.success, isTrue);

        // Step 6: Real-time collaboration notifications
        final notifications = <Map<String, dynamic>>[];

        // Connect all team members to WebSocket
        await wsService.connect(leadDevToken);
        await wsService.connect(dev1Token);
        await wsService.connect(dev2Token);
        await wsService.connect(viewerToken);

        wsService.onNotification = (notification) {
          notifications.add(notification);
        };

        // Broadcast file changes
        await wsService
            .broadcastFileChange(repoId, 'database/auth_schema.sql', {
          'action': 'created',
          'author': dev1Id,
          'timestamp': DateTime.now().toIso8601String(),
        });

        await wsService
            .broadcastFileChange(repoId, 'lib/widgets/auth_forms.dart', {
          'action': 'created',
          'author': dev2Id,
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Wait for notifications
        await Future.delayed(const Duration(milliseconds: 200));
        expect(notifications.length, greaterThanOrEqualTo(2));

        // Step 7: Code review process
        // Dev1 completes database schema task
        final dev1Complete = await taskAPI.updateTaskStatus(
          taskId: subtaskIds[0],
          status: 'review',
          authToken: dev1Token,
        );

        expect(dev1Complete.success, isTrue);

        // Lead developer reviews and approves
        final reviewApproval = await taskAPI.addTaskComment(
          taskId: subtaskIds[0],
          comment:
              'Database schema looks good. Proper indexing and constraints implemented.',
          authToken: leadDevToken,
        );

        expect(reviewApproval.success, isTrue);

        final approveTask = await taskAPI.updateTaskStatus(
          taskId: subtaskIds[0],
          status: 'completed',
          authToken: leadDevToken,
        );

        expect(approveTask.success, isTrue);

        // Step 8: Integration and testing
        // Create integration test
        final integrationTest = await repoAPI.createFile(
          repositoryId: repoId,
          filePath: 'test/auth_integration_test.dart',
          content: '''import 'package:flutter_test/flutter_test.dart';
import '../lib/services/auth_service.dart';

void main() {
  group('Authentication Integration Tests', () {
    test('User registration and login flow', () async {
      final authService = AuthService();
      
      // Test user registration
      final registerResult = await authService.register(
        email: 'test@example.com',
        password: 'TestPassword123!',
      );
      
      expect(registerResult.success, isTrue);
      
      // Test user login
      final loginResult = await authService.login(
        email: 'test@example.com',
        password: 'TestPassword123!',
      );
      
      expect(loginResult.success, isTrue);
      expect(loginResult.token, isNotNull);
    });
  });
}
''',
          commitMessage: 'Add authentication integration tests',
          authToken: leadDevToken,
        );

        expect(integrationTest.success, isTrue);

        // Step 9: Deployment preparation
        final deploymentTask = await taskAPI.createTask(
          title: 'Deploy authentication system to staging',
          description:
              'Deploy the completed authentication system to staging environment for testing',
          type: 'deployment',
          priority: 'high',
          confidentialityLevel: 'team',
          parentTaskId: mainTaskId,
          authToken: leadDevToken,
        );

        expect(deploymentTask.success, isTrue);

        // Step 10: Viewer can see project progress (read-only)
        final viewerTasks = await taskAPI.getTasks(authToken: viewerToken);
        expect(viewerTasks.success, isTrue);

        // Viewer should see public/team level tasks but not confidential ones
        final visibleTasks = viewerTasks.tasks
            .where(
              (task) => ['public', 'team'].contains(task.confidentialityLevel),
            )
            .toList();
        expect(visibleTasks.length, greaterThan(0));

        // Step 11: Complete main feature task
        final completeMainTask = await taskAPI.updateTaskStatus(
          taskId: mainTaskId,
          status: 'completed',
          authToken: leadDevToken,
        );

        expect(completeMainTask.success, isTrue);

        // Step 12: Generate project summary report
        final projectSummary = await taskAPI.getProjectSummary(
          projectId: 'test-project-id',
          authToken: leadDevToken,
        );

        expect(projectSummary.success, isTrue);
        expect(projectSummary.summary.completedTasks, greaterThan(0));
        expect(projectSummary.summary.totalCommits, greaterThan(0));
        expect(projectSummary.summary.activeCollaborators,
            equals(3)); // Lead + 2 devs

        print('✅ Team collaboration workflow test passed');
      });

      test('End-to-end: Security incident response workflow', () async {
        // Setup: Create security team
        final securitySetup = await _setupSecurityTeam();
        final adminToken = securitySetup['adminToken'] as String;
        final securityAnalystToken =
            securitySetup['securityAnalystToken'] as String;
        final developerToken = securitySetup['developerToken'] as String;

        final securityAnalystId = securitySetup['securityAnalystId'] as String;
        final developerId = securitySetup['developerId'] as String;

        // Step 1: Security monitoring detects threat
        await securityMonitor.simulateHoneytokenAccess(
          'sk-fake-api-key-12345',
          'unauthorized_api_access',
        );

        // Wait for security alert processing
        await Future.delayed(const Duration(milliseconds: 100));

        // Step 2: Security alert triggers automatic task creation
        final securityAlerts = await securityMonitor.getRecentAlerts(limit: 1);
        expect(securityAlerts.length, equals(1));

        final alert = securityAlerts.first;
        expect(alert.severity, equals('high'));

        // Step 3: Automatic security task creation
        final securityTask = await taskAPI.createTask(
          title: 'Investigate API key compromise - ${alert.id}',
          description:
              'Investigate unauthorized access to API key: ${alert.details['honeytokenId']}',
          type: 'security',
          priority: 'critical',
          confidentialityLevel: 'confidential',
          authToken: adminToken,
        );

        expect(securityTask.success, isTrue);
        final taskId = securityTask.task!.id;

        // Step 4: Assign to security analyst
        final assignToAnalyst = await taskAPI.assignTask(
          taskId: taskId,
          assigneeId: securityAnalystId,
          authToken: adminToken,
        );

        expect(assignToAnalyst.success, isTrue);

        // Step 5: Security analyst investigates
        final startInvestigation = await taskAPI.updateTaskStatus(
          taskId: taskId,
          status: 'in_progress',
          authToken: securityAnalystToken,
        );

        expect(startInvestigation.success, isTrue);

        // Add investigation notes
        final addNotes = await taskAPI.addTaskComment(
          taskId: taskId,
          comment: '''Investigation findings:
- Honeytoken accessed from IP: 192.168.1.100
- Access time: ${DateTime.now().toIso8601String()}
- No legitimate use case for this API key
- Potential data exfiltration attempt detected
- Recommend immediate key rotation and access audit''',
          authToken: securityAnalystToken,
        );

        expect(addNotes.success, isTrue);

        // Step 6: Create remediation tasks
        final remediationTasks = [
          'Rotate compromised API keys',
          'Audit access logs for suspicious activity',
          'Update security policies',
          'Notify affected users',
        ];

        final remediationTaskIds = <String>[];
        for (final taskTitle in remediationTasks) {
          final remediation = await taskAPI.createTask(
            title: taskTitle,
            description: 'Remediation task for security incident ${alert.id}',
            type: 'security',
            priority: 'high',
            confidentialityLevel: 'confidential',
            parentTaskId: taskId,
            authToken: securityAnalystToken,
          );

          expect(remediation.success, isTrue);
          remediationTaskIds.add(remediation.task!.id);
        }

        // Step 7: Assign remediation tasks to appropriate team members
        // Assign technical tasks to developer
        final assignTechnical = await taskAPI.assignTask(
          taskId: remediationTaskIds[0], // Rotate API keys
          assigneeId: developerId,
          authToken: securityAnalystToken,
        );

        expect(assignTechnical.success, isTrue);

        // Step 8: Developer implements security fixes
        final startFix = await taskAPI.updateTaskStatus(
          taskId: remediationTaskIds[0],
          status: 'in_progress',
          authToken: developerToken,
        );

        expect(startFix.success, isTrue);

        // Create security patch repository
        final securityRepo = await repoAPI.createRepository(
          name: 'security-patch-api-rotation',
          description: 'Security patch for API key rotation',
          visibility: 'private',
          authToken: developerToken,
        );

        expect(securityRepo.success, isTrue);

        // Implement API key rotation
        final securityPatch = await repoAPI.createFile(
          repositoryId: securityRepo.repository!.id,
          filePath: 'lib/security/api_key_rotation.dart',
          content: '''import 'dart:math';
import 'package:crypto/crypto.dart';

class ApiKeyRotationService {
  static const String _keyPrefix = 'sk-';
  static const int _keyLength = 32;
  
  /// Generates a new secure API key
  static String generateApiKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(_keyLength, (i) => random.nextInt(256));
    final hash = sha256.convert(bytes);
    return _keyPrefix + hash.toString().substring(0, _keyLength);
  }
  
  /// Rotates API key for a given user
  static Future<String> rotateUserApiKey(String userId) async {
    final newKey = generateApiKey();
    
    // Store new key in database
    await _storeApiKey(userId, newKey);
    
    // Invalidate old key
    await _invalidateOldKey(userId);
    
    // Log rotation event
    await _logKeyRotation(userId);
    
    return newKey;
  }
  
  static Future<void> _storeApiKey(String userId, String apiKey) async {
    // Implementation for storing new API key
  }
  
  static Future<void> _invalidateOldKey(String userId) async {
    // Implementation for invalidating old key
  }
  
  static Future<void> _logKeyRotation(String userId) async {
    // Implementation for logging rotation event
  }
}
''',
          commitMessage:
              'Implement API key rotation service for security incident response',
          authToken: developerToken,
        );

        expect(securityPatch.success, isTrue);

        // Step 9: Complete remediation task
        final completeRemediation = await taskAPI.updateTaskStatus(
          taskId: remediationTaskIds[0],
          status: 'completed',
          authToken: developerToken,
        );

        expect(completeRemediation.success, isTrue);

        // Step 10: Security analyst verifies fix
        final verifyFix = await taskAPI.addTaskComment(
          taskId: remediationTaskIds[0],
          comment:
              'Verified: API key rotation service implemented correctly. All compromised keys have been rotated.',
          authToken: securityAnalystToken,
        );

        expect(verifyFix.success, isTrue);

        // Step 11: Close security incident
        final closeIncident = await taskAPI.updateTaskStatus(
          taskId: taskId,
          status: 'completed',
          authToken: securityAnalystToken,
        );

        expect(closeIncident.success, isTrue);

        // Step 12: Generate security incident report
        final incidentReport = await taskAPI.generateSecurityReport(
          taskId: taskId,
          authToken: securityAnalystToken,
        );

        expect(incidentReport.success, isTrue);
        expect(incidentReport.report.incidentId, equals(alert.id));
        expect(incidentReport.report.status, equals('resolved'));
        expect(incidentReport.report.remediationActions.length,
            equals(remediationTasks.length));

        // Step 13: Update security monitoring rules
        await securityMonitor.updateMonitoringRules({
          'api_key_access_monitoring': true,
          'enhanced_logging': true,
          'automatic_key_rotation': true,
        });

        print('✅ Security incident response workflow test passed');
      });
    });

    group('Performance and Scalability Workflows', () {
      test('End-to-end: High-volume concurrent operations', () async {
        final adminToken = await _getAdminToken();

        // Create multiple users concurrently
        final userCreationFutures = <Future>[];
        for (int i = 0; i < 20; i++) {
          userCreationFutures.add(
            onboardingService.submitJoinRequest(
              name: 'Concurrent User $i',
              email: 'concurrent$i@test.com',
              requestedRole: 'developer',
              message: 'Concurrent test user',
            ),
          );
        }

        final userResults = await Future.wait(userCreationFutures);
        final successfulUsers =
            userResults.where((result) => result.success).length;
        expect(successfulUsers, equals(20));

        // Create multiple tasks concurrently
        final taskCreationFutures = <Future>[];
        for (int i = 0; i < 50; i++) {
          taskCreationFutures.add(
            taskAPI.createTask(
              title: 'Concurrent Task $i',
              description: 'Task created during concurrent testing',
              type: 'feature',
              priority: 'medium',
              confidentialityLevel: 'team',
              authToken: adminToken,
            ),
          );
        }

        final taskResults = await Future.wait(taskCreationFutures);
        final successfulTasks =
            taskResults.where((result) => result.success).length;
        expect(successfulTasks, equals(50));

        // Verify system remains responsive
        final systemStatus =
            await taskAPI.getSystemStatus(authToken: adminToken);
        expect(systemStatus.success, isTrue);
        expect(systemStatus.status.isHealthy, isTrue);

        print('✅ High-volume concurrent operations test passed');
      });

      test('End-to-end: Large repository operations', () async {
        final developerToken = await _getDeveloperToken();

        // Create repository
        final largeRepo = await repoAPI.createRepository(
          name: 'large-project-repo',
          description: 'Repository for testing large file operations',
          visibility: 'private',
          authToken: developerToken,
        );

        expect(largeRepo.success, isTrue);
        final repoId = largeRepo.repository!.id;

        // Create multiple files and directories
        final fileOperations = <Future>[];

        // Create directory structure
        final directories = [
          'src/main/dart',
          'src/test/dart',
          'lib/core/services',
          'lib/presentation/screens',
          'lib/presentation/widgets',
          'assets/images',
          'assets/fonts',
          'docs/api',
          'docs/user-guide',
          'scripts/build',
        ];

        for (final dir in directories) {
          fileOperations.add(
            repoAPI.createFile(
              repositoryId: repoId,
              filePath: '$dir/.gitkeep',
              content: '# Directory placeholder',
              commitMessage: 'Create directory structure: $dir',
              authToken: developerToken,
            ),
          );
        }

        // Create multiple source files
        for (int i = 0; i < 30; i++) {
          fileOperations.add(
            repoAPI.createFile(
              repositoryId: repoId,
              filePath: 'lib/models/model_$i.dart',
              content: '''class Model$i {
  final String id;
  final String name;
  final DateTime createdAt;
  
  Model$i({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };
  
  factory Model$i.fromJson(Map<String, dynamic> json) => Model$i(
    id: json['id'],
    name: json['name'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}
''',
              commitMessage: 'Add Model$i class',
              authToken: developerToken,
            ),
          );
        }

        // Execute all file operations
        final fileResults = await Future.wait(fileOperations);
        final successfulFiles =
            fileResults.where((result) => result.success).length;
        expect(successfulFiles, equals(fileOperations.length));

        // Test repository browsing performance
        final browseStart = DateTime.now();
        final repoStructure = await repoAPI.getRepositoryStructure(
          repositoryId: repoId,
          authToken: developerToken,
        );
        final browseEnd = DateTime.now();

        expect(repoStructure.success, isTrue);
        expect(repoStructure.structure.files.length, greaterThan(30));

        // Verify browsing performance (should complete within 2 seconds)
        final browseDuration = browseEnd.difference(browseStart);
        expect(browseDuration.inSeconds, lessThan(2));

        print('✅ Large repository operations test passed');
      });
    });
  });
}

/// Helper function to setup team environment
Future<Map<String, dynamic>> _setupTeamEnvironment() async {
  final authService = AuthService.instance;
  final onboardingService = OnboardingService.instance;

  // Create admin
  final adminCreation = await onboardingService.createAdminAndProject(
    adminName: 'Team Admin',
    adminEmail: 'teamadmin@project.com',
    password: 'AdminPassword123!',
    projectName: 'Team Collaboration Project',
    projectDescription: 'Project for testing team collaboration workflows',
  );

  final adminAuth = await authService.authenticate(
    'teamadmin@project.com',
    'AdminPassword123!',
  );

  // Create team members
  final teamMembers = [
    {
      'name': 'Lead Developer',
      'email': 'lead@project.com',
      'role': 'lead_developer'
    },
    {'name': 'Developer One', 'email': 'dev1@project.com', 'role': 'developer'},
    {'name': 'Developer Two', 'email': 'dev2@project.com', 'role': 'developer'},
    {'name': 'Project Viewer', 'email': 'viewer@project.com', 'role': 'viewer'},
  ];

  final tokens = <String, String>{};
  final userIds = <String, String>{};

  for (final member in teamMembers) {
    // Submit join request
    final joinRequest = await onboardingService.submitJoinRequest(
      name: member['name']!,
      email: member['email']!,
      requestedRole: member['role']!,
      message: 'Team member for collaboration testing',
    );

    // Approve request
    final approval = await onboardingService.approveJoinRequest(
      requestId: joinRequest.requestId!,
      adminId: adminCreation.adminUserId!,
      assignedRole: member['role']!,
      notes: 'Approved for team collaboration testing',
    );

    // Authenticate member
    final memberAuth = await authService.authenticate(
      member['email']!,
      approval.generatedPassword!,
    );

    tokens['${member['role']}Token'] = memberAuth.token!;
    userIds['${member['role']}Id'] = memberAuth.user!.id;
  }

  return {
    'adminToken': adminAuth.token!,
    'adminId': adminCreation.adminUserId!,
    ...tokens,
    ...userIds,
  };
}

/// Helper function to setup security team
Future<Map<String, dynamic>> _setupSecurityTeam() async {
  final authService = AuthService.instance;
  final onboardingService = OnboardingService.instance;

  // Create admin
  final adminCreation = await onboardingService.createAdminAndProject(
    adminName: 'Security Admin',
    adminEmail: 'securityadmin@project.com',
    password: 'SecurityAdmin123!',
    projectName: 'Security Response Project',
    projectDescription: 'Project for testing security incident response',
  );

  final adminAuth = await authService.authenticate(
    'securityadmin@project.com',
    'SecurityAdmin123!',
  );

  // Create security team members
  final securityMembers = [
    {
      'name': 'Security Analyst',
      'email': 'analyst@project.com',
      'role': 'security_analyst'
    },
    {
      'name': 'Security Developer',
      'email': 'secdev@project.com',
      'role': 'developer'
    },
  ];

  final tokens = <String, String>{};
  final userIds = <String, String>{};

  for (final member in securityMembers) {
    final joinRequest = await onboardingService.submitJoinRequest(
      name: member['name']!,
      email: member['email']!,
      requestedRole: member['role']!,
      message: 'Security team member',
    );

    final approval = await onboardingService.approveJoinRequest(
      requestId: joinRequest.requestId!,
      adminId: adminCreation.adminUserId!,
      assignedRole: member['role']!,
      notes: 'Approved for security team',
    );

    final memberAuth = await authService.authenticate(
      member['email']!,
      approval.generatedPassword!,
    );

    final roleKey = member['role']!.replaceAll('_', '');
    tokens['${roleKey}Token'] = memberAuth.token!;
    userIds['${roleKey}Id'] = memberAuth.user!.id;
  }

  return {
    'adminToken': adminAuth.token!,
    'adminId': adminCreation.adminUserId!,
    ...tokens,
    ...userIds,
  };
}

/// Helper functions for token management
Future<String> _getAdminToken() async {
  final authService = AuthService.instance;
  final auth = await authService.authenticate(
    'admin@testproject.com',
    'AdminPassword123!',
  );
  return auth.token!;
}

Future<String> _getDeveloperToken() async {
  final authService = AuthService.instance;
  final auth = await authService.authenticate(
    'developer@testproject.com',
    'DeveloperPassword123!',
  );
  return auth.token!;
}
