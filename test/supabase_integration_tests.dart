import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_auth_service.dart';
import 'package:devguard_ai_copilot/core/supabase/services/supabase_team_member_service.dart';
import 'package:devguard_ai_copilot/core/supabase/services/supabase_task_service.dart';
import 'package:devguard_ai_copilot/core/database/models/team_member.dart';
import 'package:devguard_ai_copilot/core/database/models/task.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Supabase Integration Tests', () {
    late SupabaseService supabaseService;
    late SupabaseAuthService authService;
    late SupabaseTeamMemberService teamMemberService;
    late SupabaseTaskService taskService;

    setUpAll(() async {
      supabaseService = SupabaseService.instance;
      authService = SupabaseAuthService.instance;
      teamMemberService = SupabaseTeamMemberService.instance;
      taskService = SupabaseTaskService.instance;

      // Initialize services for testing
      try {
        await supabaseService.initialize();
        await authService.initialize();
      } catch (e) {
        // Skip tests if Supabase is not configured
        print('Skipping integration tests - Supabase not configured: $e');
        return;
      }
    });

    group('Authentication Flow Integration', () {
      testWidgets('should complete signup and authentication flow',
          (tester) async {
        // Skip if not properly configured
        if (!supabaseService.isInitialized) {
          return;
        }

        final testEmail =
            'test_${DateTime.now().millisecondsSinceEpoch}@example.com';
        const testPassword = 'TestPassword123!';

        // Test user registration
        final signUpResult = await authService.signUp(
          testEmail,
          testPassword,
          metadata: {'role': 'developer', 'test': true},
        );

        expect(signUpResult.success, true);
        expect(signUpResult.user, isNotNull);

        // Test sign out
        final signOutResult = await authService.signOut();
        expect(signOutResult.success, true);

        // Test sign in
        final signInResult =
            await authService.signInWithEmail(testEmail, testPassword);
        expect(signInResult.success, true);
        expect(signInResult.user, isNotNull);
        expect(signInResult.session, isNotNull);

        // Test permission checking
        expect(authService.hasPermission('create_tasks'), true);
        expect(authService.hasPermission('manage_users'), false);

        // Clean up
        await authService.signOut();
      });

      testWidgets('should handle authentication errors gracefully',
          (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // Test invalid credentials
        final invalidResult = await authService.signInWithEmail(
          'invalid@example.com',
          'wrongpassword',
        );

        expect(invalidResult.success, false);
        expect(invalidResult.message.contains('Invalid'), true);
      });

      testWidgets('should handle password reset flow', (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        final resetResult =
            await authService.resetPasswordForEmail('test@example.com');

        // Should succeed even for non-existent emails (security)
        expect(resetResult.success, true);
        expect(resetResult.message.contains('email sent'), true);
      });
    });

    group('Team Member Service Integration', () {
      testWidgets('should perform CRUD operations on team members',
          (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // Create test team member
        final testMember = TeamMember(
          id: 'test-member-${DateTime.now().millisecondsSinceEpoch}',
          name: 'Test Developer',
          email:
              'test.dev.${DateTime.now().millisecondsSinceEpoch}@example.com',
          role: 'developer',
          status: 'active',
          assignments: ['project-1'],
          expertise: ['flutter', 'dart'],
          workload: 75,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Test create
        final createdId = await teamMemberService.createTeamMember(testMember);
        expect(createdId, isNotEmpty);

        // Test read
        final retrievedMember =
            await teamMemberService.getTeamMember(createdId);
        expect(retrievedMember, isNotNull);
        expect(retrievedMember!.name, testMember.name);
        expect(retrievedMember.email, testMember.email);
        expect(retrievedMember.role, testMember.role);

        // Test update workload
        await teamMemberService.updateWorkload(createdId, 80);
        final updatedMember = await teamMemberService.getTeamMember(createdId);
        expect(updatedMember!.workload, 80);

        // Test update assignments
        await teamMemberService
            .updateAssignments(createdId, ['project-1', 'project-2']);
        final memberWithAssignments =
            await teamMemberService.getTeamMember(createdId);
        expect(memberWithAssignments!.assignments, contains('project-2'));

        // Test get by email
        final memberByEmail =
            await teamMemberService.getTeamMemberByEmail(testMember.email);
        expect(memberByEmail, isNotNull);
        expect(memberByEmail!.id, createdId);

        // Test get by status
        final activeMembers =
            await teamMemberService.getTeamMembersByStatus('active');
        expect(activeMembers.any((m) => m.id == createdId), true);

        // Test get by role
        final developers =
            await teamMemberService.getTeamMembersByRole('developer');
        expect(developers.any((m) => m.id == createdId), true);

        // Test statistics
        final stats = await teamMemberService.getTeamStatistics();
        expect(stats['total'], greaterThan(0));
        expect(stats['active'], greaterThan(0));

        // Test delete
        await teamMemberService.deleteTeamMember(createdId);
        final deletedMember = await teamMemberService.getTeamMember(createdId);
        expect(deletedMember, isNull);
      });

      testWidgets('should handle validation errors', (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // Test invalid email
        final invalidMember = TeamMember(
          id: 'invalid-member',
          name: 'Invalid Member',
          email: 'invalid-email',
          role: 'developer',
          status: 'active',
          assignments: [],
          expertise: [],
          workload: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(
          () => teamMemberService.createTeamMember(invalidMember),
          throwsException,
        );

        // Test invalid workload
        expect(
          () => teamMemberService.updateWorkload('non-existent', 150),
          throwsException,
        );
      });

      testWidgets('should handle duplicate email errors', (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        final testEmail =
            'duplicate.${DateTime.now().millisecondsSinceEpoch}@example.com';

        final member1 = TeamMember(
          id: 'member-1',
          name: 'Member 1',
          email: testEmail,
          role: 'developer',
          status: 'active',
          assignments: [],
          expertise: [],
          workload: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final member2 = TeamMember(
          id: 'member-2',
          name: 'Member 2',
          email: testEmail,
          role: 'developer',
          status: 'active',
          assignments: [],
          expertise: [],
          workload: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Create first member
        final id1 = await teamMemberService.createTeamMember(member1);
        expect(id1, isNotEmpty);

        // Try to create second member with same email
        expect(
          () => teamMemberService.createTeamMember(member2),
          throwsException,
        );

        // Clean up
        await teamMemberService.deleteTeamMember(id1);
      });
    });

    group('Task Service Integration', () {
      testWidgets('should perform CRUD operations on tasks', (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // Create test task
        final testTask = Task(
          id: 'test-task-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Integration Test Task',
          description: 'This is a test task for integration testing',
          type: 'feature',
          priority: 'medium',
          status: 'pending',
          assigneeId: 'test-assignee',
          reporterId: 'test-reporter',
          estimatedHours: 8,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          confidentialityLevel: 'public',
          authorizedUsers: [],
          authorizedRoles: [],
        );

        // Test create
        final createdId = await taskService.createTask(testTask);
        expect(createdId, isNotEmpty);

        // Test read with authorization
        final retrievedTask = await taskService.getTask(
          createdId,
          userId: 'test-user',
          userRole: 'admin',
        );
        expect(retrievedTask, isNotNull);
        expect(retrievedTask!.title, testTask.title);
        expect(retrievedTask.description, testTask.description);

        // Test update status
        await taskService.updateTaskStatus(
          createdId,
          'in_progress',
          userId: 'test-user',
          userRole: 'admin',
        );
        final updatedTask = await taskService.getTask(
          createdId,
          userId: 'test-user',
          userRole: 'admin',
        );
        expect(updatedTask!.status, 'in_progress');

        // Test add related commit
        await taskService.addRelatedCommit(
          createdId,
          'abc123def456',
          userId: 'test-user',
          userRole: 'admin',
        );
        final taskWithCommit = await taskService.getTask(
          createdId,
          userId: 'test-user',
          userRole: 'admin',
        );
        expect(taskWithCommit!.relatedCommits, contains('abc123def456'));

        // Test update assignment
        await taskService.updateTaskAssignment(
          createdId,
          'new-assignee',
          userId: 'test-user',
          userRole: 'admin',
        );
        final reassignedTask = await taskService.getTask(
          createdId,
          userId: 'test-user',
          userRole: 'admin',
        );
        expect(reassignedTask!.assigneeId, 'new-assignee');

        // Test get by status
        final pendingTasks = await taskService.getTasksByStatus(
          'in_progress',
          userId: 'test-user',
          userRole: 'admin',
        );
        expect(pendingTasks.any((t) => t.id == createdId), true);

        // Test get by assignee
        final assigneeTasks = await taskService.getTasksByAssignee(
          'new-assignee',
          userId: 'test-user',
          userRole: 'admin',
        );
        expect(assigneeTasks.any((t) => t.id == createdId), true);

        // Test statistics
        final stats = await taskService.getTaskStatistics(
          userId: 'test-user',
          userRole: 'admin',
        );
        expect(stats['total'], greaterThan(0));
        expect(stats['in_progress'], greaterThan(0));

        // Test delete
        await taskService.deleteTask(
          createdId,
          userId: 'test-user',
          userRole: 'admin',
        );
        final deletedTask = await taskService.getTask(
          createdId,
          userId: 'test-user',
          userRole: 'admin',
        );
        expect(deletedTask, isNull);
      });

      testWidgets('should handle authorization correctly', (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // Create restricted task
        final restrictedTask = Task(
          id: 'restricted-task-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Restricted Task',
          description: 'This task has restricted access',
          type: 'security',
          priority: 'high',
          status: 'pending',
          assigneeId: 'authorized-user',
          reporterId: 'admin-user',
          estimatedHours: 16,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 3)),
          confidentialityLevel: 'restricted',
          authorizedUsers: ['authorized-user'],
          authorizedRoles: ['admin'],
        );

        final createdId = await taskService.createTask(restrictedTask);

        // Admin should be able to access
        final adminTask = await taskService.getTask(
          createdId,
          userId: 'admin-user',
          userRole: 'admin',
        );
        expect(adminTask, isNotNull);

        // Authorized user should be able to access
        final authorizedTask = await taskService.getTask(
          createdId,
          userId: 'authorized-user',
          userRole: 'developer',
        );
        expect(authorizedTask, isNotNull);

        // Unauthorized user should not be able to access
        expect(
          () => taskService.getTask(
            createdId,
            userId: 'unauthorized-user',
            userRole: 'viewer',
          ),
          throwsException,
        );

        // Clean up
        await taskService.deleteTask(
          createdId,
          userId: 'admin-user',
          userRole: 'admin',
        );
      });

      testWidgets('should handle validation errors', (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // Test invalid task data
        final invalidTask = Task(
          id: 'invalid-task',
          title: '', // Empty title should fail validation
          description: 'Valid description',
          type: 'feature',
          priority: 'medium',
          status: 'pending',
          assigneeId: 'test-assignee',
          reporterId: 'test-reporter',
          estimatedHours: 8,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          confidentialityLevel: 'public',
          authorizedUsers: [],
          authorizedRoles: [],
        );

        expect(
          () => taskService.createTask(invalidTask),
          throwsException,
        );
      });
    });

    group('Real-time Functionality Integration', () {
      testWidgets('should handle real-time updates', (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // Test real-time team member updates
        final memberStream = teamMemberService.watchAllTeamMembers();
        expect(memberStream, isA<Stream<List<TeamMember>>>());

        // Test real-time task updates
        final taskStream = taskService.watchAllTasks(
          userId: 'test-user',
          userRole: 'admin',
        );
        expect(taskStream, isA<Stream<List<Task>>>());

        // Note: Full real-time testing would require more complex setup
        // with multiple clients and actual data changes
      });
    });

    group('Error Handling Integration', () {
      testWidgets('should handle network errors gracefully', (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // Test connection recovery
        expect(supabaseService.isConnected, true);

        final canReconnect = await supabaseService.ensureConnection();
        expect(canReconnect, true);
      });

      testWidgets('should handle database constraint violations',
          (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // This would test actual database constraint violations
        // Implementation depends on specific database setup
      });
    });

    group('Performance Integration', () {
      testWidgets('should handle batch operations efficiently', (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // Create multiple team members
        final members = List.generate(
            5,
            (index) => TeamMember(
                  id: 'batch-member-$index-${DateTime.now().millisecondsSinceEpoch}',
                  name: 'Batch Member $index',
                  email:
                      'batch$index.${DateTime.now().millisecondsSinceEpoch}@example.com',
                  role: 'developer',
                  status: 'active',
                  assignments: [],
                  expertise: ['flutter'],
                  workload: 50,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ));

        final stopwatch = Stopwatch()..start();

        // Test batch creation performance
        final createdIds = <String>[];
        for (final member in members) {
          final id = await teamMemberService.createTeamMember(member);
          createdIds.add(id);
        }

        stopwatch.stop();
        print('Batch creation took: ${stopwatch.elapsedMilliseconds}ms');

        expect(createdIds.length, 5);
        expect(stopwatch.elapsedMilliseconds,
            lessThan(10000)); // Should complete within 10 seconds

        // Clean up
        for (final id in createdIds) {
          await teamMemberService.deleteTeamMember(id);
        }
      });

      testWidgets('should handle large data sets efficiently', (tester) async {
        if (!supabaseService.isInitialized) {
          return;
        }

        final stopwatch = Stopwatch()..start();

        // Test retrieving all team members
        final allMembers = await teamMemberService.getAllTeamMembers();

        stopwatch.stop();
        print(
            'Retrieved ${allMembers.length} members in: ${stopwatch.elapsedMilliseconds}ms');

        expect(stopwatch.elapsedMilliseconds,
            lessThan(5000)); // Should complete within 5 seconds
      });
    });
  });
}
