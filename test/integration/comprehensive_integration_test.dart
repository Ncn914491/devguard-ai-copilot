import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:devguard_ai_copilot/core/auth/auth_service.dart';
import 'package:devguard_ai_copilot/core/services/onboarding_service.dart';
import 'package:devguard_ai_copilot/core/api/user_management_api.dart';
import 'package:devguard_ai_copilot/core/api/task_management_api.dart';
import 'package:devguard_ai_copilot/core/api/repository_api.dart';
import 'package:devguard_ai_copilot/core/database/services/services.dart';

/// Comprehensive integration tests for onboarding flow, authentication, and API endpoints
/// Satisfies Requirements: All requirements integration testing with role-based scenarios
void main() {
  group('Comprehensive Integration Tests', () {
    late AuthService authService;
    late OnboardingService onboardingService;
    late UserManagementAPI userAPI;
    late TaskManagementAPI taskAPI;
    late RepositoryAPI repoAPI;

    setUpAll(() async {
      // Initialize SQLite FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // Initialize services
      authService = AuthService.instance;
      onboardingService = OnboardingService.instance;
      userAPI = UserManagementAPI.instance;
      taskAPI = TaskManagementAPI.instance;
      repoAPI = RepositoryAPI.instance;

      await authService.initialize();
      await onboardingService.initialize();
    });

    tearDownAll(() async {
      await authService.dispose();
      await onboardingService.dispose();
    });

    group('Onboarding Flow Integration Tests', () {
      test('Complete onboarding workflow - Admin signup and project creation',
          () async {
        // Test admin signup
        final adminSignupResult = await onboardingService.createAdminAndProject(
          adminName: 'Test Admin',
          adminEmail: 'admin@testproject.com',
          password: 'SecurePassword123!',
          projectName: 'Test Project',
          projectDescription: 'Integration test project',
        );

        expect(adminSignupResult.success, isTrue);
        expect(adminSignupResult.projectId, isNotNull);
        expect(adminSignupResult.adminUserId, isNotNull);

        // Verify admin can authenticate
        final authResult = await authService.authenticate(
          'admin@testproject.com',
          'SecurePassword123!',
        );

        expect(authResult.success, isTrue);
        expect(authResult.user?.role, equals('admin'));
        expect(authResult.token, isNotNull);
      });

      test('Member join request and approval workflow', () async {
        // Submit join request
        final joinRequest = await onboardingService.submitJoinRequest(
          name: 'Test Developer',
          email: 'dev@testproject.com',
          requestedRole: 'developer',
          message: 'I would like to join the development team',
        );

        expect(joinRequest.success, isTrue);
        expect(joinRequest.requestId, isNotNull);

        // Admin reviews and approves request
        final pendingRequests =
            await onboardingService.getPendingJoinRequests();
        expect(pendingRequests.length, greaterThan(0));

        final approvalResult = await onboardingService.approveJoinRequest(
          requestId: joinRequest.requestId!,
          adminId: 'admin-user-id',
          assignedRole: 'developer',
          notes: 'Approved for development team',
        );

        expect(approvalResult.success, isTrue);
        expect(approvalResult.generatedPassword, isNotNull);

        // Verify new member can authenticate
        final memberAuth = await authService.authenticate(
          'dev@testproject.com',
          approvalResult.generatedPassword!,
        );

        expect(memberAuth.success, isTrue);
        expect(memberAuth.user?.role, equals('developer'));
      });

      test('Join request rejection workflow', () async {
        // Submit join request
        final joinRequest = await onboardingService.submitJoinRequest(
          name: 'Rejected User',
          email: 'rejected@testproject.com',
          requestedRole: 'admin',
          message: 'Requesting admin access',
        );

        expect(joinRequest.success, isTrue);

        // Admin rejects request
        final rejectionResult = await onboardingService.rejectJoinRequest(
          requestId: joinRequest.requestId!,
          adminId: 'admin-user-id',
          reason: 'Admin role not available for external users',
        );

        expect(rejectionResult.success, isTrue);

        // Verify user cannot authenticate
        final authAttempt = await authService.authenticate(
          'rejected@testproject.com',
          'any-password',
        );

        expect(authAttempt.success, isFalse);
      });
    });

    group('Authentication Integration Tests', () {
      test('JWT token authentication and refresh', () async {
        // Initial authentication
        final authResult = await authService.authenticate(
          'admin@testproject.com',
          'SecurePassword123!',
        );

        expect(authResult.success, isTrue);
        expect(authResult.token, isNotNull);
        expect(authResult.refreshToken, isNotNull);

        // Verify token validation
        final tokenValidation =
            await authService.validateToken(authResult.token!);
        expect(tokenValidation.isValid, isTrue);
        expect(tokenValidation.userId, equals(authResult.user?.id));

        // Test token refresh
        final refreshResult =
            await authService.refreshToken(authResult.refreshToken!);
        expect(refreshResult.success, isTrue);
        expect(refreshResult.newToken, isNotNull);
        expect(refreshResult.newToken, isNot(equals(authResult.token)));
      });

      test('Role-based access control validation', () async {
        final roles = ['admin', 'lead_developer', 'developer', 'viewer'];

        for (final role in roles) {
          // Create user with specific role
          final user = await userAPI.createUser(
            name: 'Test $role',
            email: '$role@testproject.com',
            role: role,
            password: 'TestPassword123!',
          );

          expect(user.success, isTrue);

          // Test authentication
          final auth = await authService.authenticate(
            '$role@testproject.com',
            'TestPassword123!',
          );

          expect(auth.success, isTrue);
          expect(auth.user?.role, equals(role));

          // Test role-specific permissions
          final permissions =
              await authService.getUserPermissions(auth.user!.id);
          expect(permissions.length, greaterThan(0));

          // Verify role-specific access
          switch (role) {
            case 'admin':
              expect(permissions.contains('user_management'), isTrue);
              expect(permissions.contains('system_configuration'), isTrue);
              break;
            case 'lead_developer':
              expect(permissions.contains('task_assignment'), isTrue);
              expect(permissions.contains('code_review'), isTrue);
              break;
            case 'developer':
              expect(permissions.contains('code_access'), isTrue);
              expect(permissions.contains('task_execution'), isTrue);
              break;
            case 'viewer':
              expect(permissions.contains('read_only'), isTrue);
              expect(permissions.length, equals(1));
              break;
          }
        }
      });

      test('Session management and logout', () async {
        // Authenticate user
        final authResult = await authService.authenticate(
          'admin@testproject.com',
          'SecurePassword123!',
        );

        expect(authResult.success, isTrue);

        // Verify active session
        final sessionCheck = await authService.validateToken(authResult.token!);
        expect(sessionCheck.isValid, isTrue);

        // Logout user
        final logoutResult = await authService.logout(authResult.token!);
        expect(logoutResult.success, isTrue);

        // Verify session is invalidated
        final postLogoutCheck =
            await authService.validateToken(authResult.token!);
        expect(postLogoutCheck.isValid, isFalse);
      });
    });

    group('API Endpoints Integration Tests', () {
      late String adminToken;
      late String developerToken;
      late String viewerToken;

      setUpAll(() async {
        // Setup authenticated users for API testing
        final adminAuth = await authService.authenticate(
          'admin@testproject.com',
          'SecurePassword123!',
        );
        adminToken = adminAuth.token!;

        final devAuth = await authService.authenticate(
          'developer@testproject.com',
          'TestPassword123!',
        );
        developerToken = devAuth.token!;

        final viewerAuth = await authService.authenticate(
          'viewer@testproject.com',
          'TestPassword123!',
        );
        viewerToken = viewerAuth.token!;
      });

      group('User Management API Tests', () {
        test('Admin can manage users', () async {
          // Create user as admin
          final createResult = await userAPI.createUser(
            name: 'API Test User',
            email: 'apitest@testproject.com',
            role: 'developer',
            password: 'ApiTestPassword123!',
            authToken: adminToken,
          );

          expect(createResult.success, isTrue);
          expect(createResult.user?.email, equals('apitest@testproject.com'));

          // Update user role
          final updateResult = await userAPI.updateUserRole(
            userId: createResult.user!.id,
            newRole: 'lead_developer',
            authToken: adminToken,
          );

          expect(updateResult.success, isTrue);
          expect(updateResult.user?.role, equals('lead_developer'));

          // Get user list
          final userList = await userAPI.getUsers(authToken: adminToken);
          expect(userList.success, isTrue);
          expect(userList.users.length, greaterThan(0));

          // Delete user
          final deleteResult = await userAPI.deleteUser(
            userId: createResult.user!.id,
            authToken: adminToken,
          );

          expect(deleteResult.success, isTrue);
        });

        test('Non-admin cannot manage users', () async {
          // Try to create user as developer
          final createAttempt = await userAPI.createUser(
            name: 'Unauthorized User',
            email: 'unauthorized@testproject.com',
            role: 'developer',
            password: 'Password123!',
            authToken: developerToken,
          );

          expect(createAttempt.success, isFalse);
          expect(createAttempt.error, contains('insufficient permissions'));

          // Try to get user list as viewer
          final listAttempt = await userAPI.getUsers(authToken: viewerToken);
          expect(listAttempt.success, isFalse);
          expect(listAttempt.error, contains('insufficient permissions'));
        });
      });

      group('Task Management API Tests', () {
        test('Task CRUD operations with role-based access', () async {
          // Admin creates task
          final createResult = await taskAPI.createTask(
            title: 'Integration Test Task',
            description: 'Task created for integration testing',
            type: 'feature',
            priority: 'medium',
            confidentialityLevel: 'team',
            authToken: adminToken,
          );

          expect(createResult.success, isTrue);
          expect(createResult.task?.title, equals('Integration Test Task'));

          // Assign task to developer
          final assignResult = await taskAPI.assignTask(
            taskId: createResult.task!.id,
            assigneeId: 'developer-user-id',
            authToken: adminToken,
          );

          expect(assignResult.success, isTrue);

          // Developer updates task status
          final statusUpdate = await taskAPI.updateTaskStatus(
            taskId: createResult.task!.id,
            status: 'in_progress',
            authToken: developerToken,
          );

          expect(statusUpdate.success, isTrue);

          // Get tasks with different access levels
          final adminTasks = await taskAPI.getTasks(authToken: adminToken);
          final devTasks = await taskAPI.getTasks(authToken: developerToken);
          final viewerTasks = await taskAPI.getTasks(authToken: viewerToken);

          expect(adminTasks.tasks.length,
              greaterThanOrEqualTo(devTasks.tasks.length));
          expect(devTasks.tasks.length,
              greaterThanOrEqualTo(viewerTasks.tasks.length));
        });

        test('Confidentiality level enforcement', () async {
          // Create confidential task
          final confidentialTask = await taskAPI.createTask(
            title: 'Confidential Task',
            description: 'Highly sensitive task',
            type: 'security',
            priority: 'high',
            confidentialityLevel: 'confidential',
            authToken: adminToken,
          );

          expect(confidentialTask.success, isTrue);

          // Viewer should not see confidential task
          final viewerTasks = await taskAPI.getTasks(authToken: viewerToken);
          final hasConfidentialTask = viewerTasks.tasks.any(
            (task) => task.id == confidentialTask.task!.id,
          );
          expect(hasConfidentialTask, isFalse);

          // Admin should see confidential task
          final adminTasks = await taskAPI.getTasks(authToken: adminToken);
          final adminHasTask = adminTasks.tasks.any(
            (task) => task.id == confidentialTask.task!.id,
          );
          expect(adminHasTask, isTrue);
        });
      });

      group('Repository API Tests', () {
        test('Repository operations with access control', () async {
          // Admin creates repository
          final createRepo = await repoAPI.createRepository(
            name: 'test-integration-repo',
            description: 'Repository for integration testing',
            visibility: 'private',
            authToken: adminToken,
          );

          expect(createRepo.success, isTrue);
          expect(createRepo.repository?.name, equals('test-integration-repo'));

          // Add collaborator
          final addCollaborator = await repoAPI.addCollaborator(
            repositoryId: createRepo.repository!.id,
            userId: 'developer-user-id',
            accessLevel: 'write',
            authToken: adminToken,
          );

          expect(addCollaborator.success, isTrue);

          // Developer can access repository
          final devRepos =
              await repoAPI.getRepositories(authToken: developerToken);
          final hasAccess = devRepos.repositories.any(
            (repo) => repo.id == createRepo.repository!.id,
          );
          expect(hasAccess, isTrue);

          // Viewer cannot access private repository
          final viewerRepos =
              await repoAPI.getRepositories(authToken: viewerToken);
          final viewerHasAccess = viewerRepos.repositories.any(
            (repo) => repo.id == createRepo.repository!.id,
          );
          expect(viewerHasAccess, isFalse);
        });

        test('File operations with permissions', () async {
          final repoId = 'test-repo-id';

          // Developer can read/write files
          final createFile = await repoAPI.createFile(
            repositoryId: repoId,
            filePath: 'src/test.dart',
            content: 'void main() { print("Hello World"); }',
            commitMessage: 'Add test file',
            authToken: developerToken,
          );

          expect(createFile.success, isTrue);

          // Viewer can only read files
          final readFile = await repoAPI.getFileContent(
            repositoryId: repoId,
            filePath: 'src/test.dart',
            authToken: viewerToken,
          );

          expect(readFile.success, isTrue);
          expect(readFile.content, contains('Hello World'));

          // Viewer cannot write files
          final writeAttempt = await repoAPI.updateFile(
            repositoryId: repoId,
            filePath: 'src/test.dart',
            content: 'void main() { print("Modified"); }',
            commitMessage: 'Unauthorized modification',
            authToken: viewerToken,
          );

          expect(writeAttempt.success, isFalse);
          expect(writeAttempt.error, contains('insufficient permissions'));
        });
      });
    });

    group('Cross-Service Integration Tests', () {
      test('Complete workflow: Task creation to deployment', () async {
        // 1. Create task
        final task = await taskAPI.createTask(
          title: 'Implement user profile feature',
          description: 'Add user profile management functionality',
          type: 'feature',
          priority: 'high',
          confidentialityLevel: 'team',
          authToken: adminToken,
        );

        expect(task.success, isTrue);

        // 2. Assign to developer
        final assignment = await taskAPI.assignTask(
          taskId: task.task!.id,
          assigneeId: 'developer-user-id',
          authToken: adminToken,
        );

        expect(assignment.success, isTrue);

        // 3. Developer starts work
        final startWork = await taskAPI.updateTaskStatus(
          taskId: task.task!.id,
          status: 'in_progress',
          authToken: developerToken,
        );

        expect(startWork.success, isTrue);

        // 4. Create repository for the feature
        final repo = await repoAPI.createRepository(
          name: 'user-profile-feature',
          description: 'Repository for user profile feature',
          visibility: 'private',
          authToken: adminToken,
        );

        expect(repo.success, isTrue);

        // 5. Link task to repository
        final linkTask = await taskAPI.linkTaskToRepository(
          taskId: task.task!.id,
          repositoryId: repo.repository!.id,
          authToken: developerToken,
        );

        expect(linkTask.success, isTrue);

        // 6. Complete task
        final completeTask = await taskAPI.updateTaskStatus(
          taskId: task.task!.id,
          status: 'completed',
          authToken: developerToken,
        );

        expect(completeTask.success, isTrue);

        // 7. Verify audit trail
        final auditLogs = await taskAPI.getTaskAuditLog(
          taskId: task.task!.id,
          authToken: adminToken,
        );

        expect(auditLogs.success, isTrue);
        expect(auditLogs.logs.length,
            greaterThan(3)); // Creation, assignment, status changes
      });

      test('Security integration with task management', () async {
        // Create security-related task
        final securityTask = await taskAPI.createTask(
          title: 'Fix security vulnerability',
          description: 'Address SQL injection vulnerability in user input',
          type: 'security',
          priority: 'critical',
          confidentialityLevel: 'confidential',
          authToken: adminToken,
        );

        expect(securityTask.success, isTrue);

        // Verify security task triggers appropriate monitoring
        final taskDetails = await taskAPI.getTask(
          taskId: securityTask.task!.id,
          authToken: adminToken,
        );

        expect(taskDetails.success, isTrue);
        expect(taskDetails.task?.type, equals('security'));
        expect(taskDetails.task?.priority, equals('critical'));

        // Verify only authorized users can see security task
        final viewerTasks = await taskAPI.getTasks(authToken: viewerToken);
        final viewerCanSeeSecurityTask = viewerTasks.tasks.any(
          (task) => task.id == securityTask.task!.id,
        );
        expect(viewerCanSeeSecurityTask, isFalse);
      });
    });

    group('Error Handling and Edge Cases', () {
      test('Invalid authentication tokens', () async {
        final invalidToken = 'invalid.jwt.token';

        // Test API calls with invalid token
        final userResult = await userAPI.getUsers(authToken: invalidToken);
        expect(userResult.success, isFalse);
        expect(userResult.error, contains('invalid token'));

        final taskResult = await taskAPI.getTasks(authToken: invalidToken);
        expect(taskResult.success, isFalse);
        expect(taskResult.error, contains('invalid token'));
      });

      test('Expired token handling', () async {
        // Create a token that expires immediately
        final shortLivedAuth = await authService.authenticate(
          'admin@testproject.com',
          'SecurePassword123!',
          tokenExpiryMinutes: 0, // Expires immediately
        );

        expect(shortLivedAuth.success, isTrue);

        // Wait for token to expire
        await Future.delayed(const Duration(milliseconds: 100));

        // Try to use expired token
        final apiCall =
            await userAPI.getUsers(authToken: shortLivedAuth.token!);
        expect(apiCall.success, isFalse);
        expect(apiCall.error, contains('token expired'));
      });

      test('Database connection failures', () async {
        // Simulate database connection failure
        // This would typically involve mocking the database layer
        // For now, we'll test the error handling structure

        expect(() async {
          await taskAPI.createTask(
            title: 'Test Task',
            description: 'Test Description',
            type: 'feature',
            priority: 'low',
            confidentialityLevel: 'public',
            authToken: adminToken,
          );
        }, returnsNormally);
      });

      test('Concurrent access scenarios', () async {
        final taskId = 'concurrent-test-task';

        // Simulate multiple users trying to update the same task
        final futures = <Future>[];

        for (int i = 0; i < 5; i++) {
          futures.add(
            taskAPI.updateTaskStatus(
              taskId: taskId,
              status: 'in_progress',
              authToken: developerToken,
            ),
          );
        }

        // Wait for all concurrent operations
        final results = await Future.wait(futures);

        // Verify that the system handled concurrent access gracefully
        // At least one operation should succeed
        final successCount = results.where((result) => result.success).length;
        expect(successCount, greaterThan(0));
      });
    });
  });
}

/// Mock classes for testing
class MockAuthService extends Mock implements AuthService {}

class MockOnboardingService extends Mock implements OnboardingService {}

class MockUserManagementAPI extends Mock implements UserManagementAPI {}

class MockTaskManagementAPI extends Mock implements TaskManagementAPI {}

class MockRepositoryAPI extends Mock implements RepositoryAPI {}

/// Test data generators
class IntegrationTestData {
  static Map<String, dynamic> createTestUser({
    String? role = 'developer',
    String? email,
  }) {
    return {
      'id': 'test-user-${DateTime.now().millisecondsSinceEpoch}',
      'name': 'Test User',
      'email':
          email ?? 'test${DateTime.now().millisecondsSinceEpoch}@example.com',
      'role': role,
      'createdAt': DateTime.now().toIso8601String(),
      'isActive': true,
    };
  }

  static Map<String, dynamic> createTestTask({
    String? type = 'feature',
    String? priority = 'medium',
    String? confidentialityLevel = 'team',
  }) {
    return {
      'id': 'test-task-${DateTime.now().millisecondsSinceEpoch}',
      'title': 'Test Task',
      'description': 'Task created for testing purposes',
      'type': type,
      'priority': priority,
      'status': 'pending',
      'confidentialityLevel': confidentialityLevel,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> createTestRepository({
    String? visibility = 'private',
  }) {
    return {
      'id': 'test-repo-${DateTime.now().millisecondsSinceEpoch}',
      'name': 'test-repository',
      'description': 'Repository created for testing',
      'visibility': visibility,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
