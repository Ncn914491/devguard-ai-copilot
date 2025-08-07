import 'package:flutter_test/flutter_test.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_auth_service.dart';
import 'package:devguard_ai_copilot/core/supabase/services/supabase_team_member_service.dart';
import 'package:devguard_ai_copilot/core/supabase/services/supabase_task_service.dart';
import 'package:devguard_ai_copilot/core/database/models/team_member.dart';
import 'package:devguard_ai_copilot/core/database/models/task.dart';
import 'dart:async';
import 'dart:math';

void main() {
  group('Supabase Performance and Load Tests', () {
    late SupabaseService supabaseService;
    late SupabaseAuthService authService;
    late SupabaseTeamMemberService teamMemberService;
    late SupabaseTaskService taskService;

    setUpAll(() async {
      supabaseService = SupabaseService.instance;
      authService = SupabaseAuthService.instance;
      teamMemberService = SupabaseTeamMemberService.instance;
      taskService = SupabaseTaskService.instance;

      try {
        await supabaseService.initialize();
        await authService.initialize();
      } catch (e) {
        print('Skipping performance tests - Supabase not configured: $e');
        return;
      }
    });

    group('Database Performance Tests', () {
      test('should handle concurrent team member operations', () async {
        if (!supabaseService.isInitialized) {
          return;
        }

        const concurrentOperations = 10;
        final stopwatch = Stopwatch()..start();
        final futures = <Future<String>>[];

        // Create concurrent team member creation operations
        for (int i = 0; i < concurrentOperations; i++) {
          final member = TeamMember(
            id: 'perf-member-$i-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Performance Test Member $i',
            email:
                'perf$i.${DateTime.now().millisecondsSinceEpoch}@example.com',
            role: 'developer',
            status: 'active',
            assignments: ['project-$i'],
            expertise: ['flutter', 'dart'],
            workload: Random().nextInt(100),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          futures.add(teamMemberService.createTeamMember(member));
        }

        final results = await Future.wait(futures);
        stopwatch.stop();

        expect(results.length, concurrentOperations);
        expect(results.every((id) => id.isNotEmpty), true);

        print(
            'Concurrent team member creation (${concurrentOperations}x): ${stopwatch.elapsedMilliseconds}ms');
        print(
            'Average per operation: ${stopwatch.elapsedMilliseconds / concurrentOperations}ms');

        // Performance assertion - should complete within reasonable time
        expect(
            stopwatch.elapsedMilliseconds, lessThan(30000)); // 30 seconds max

        // Clean up
        final cleanupFutures =
            results.map((id) => teamMemberService.deleteTeamMember(id));
        await Future.wait(cleanupFutures);
      });

      test('should handle concurrent task operations', () async {
        if (!supabaseService.isInitialized) {
          return;
        }

        const concurrentOperations = 15;
        final stopwatch = Stopwatch()..start();
        final futures = <Future<String>>[];

        // Create concurrent task creation operations
        for (int i = 0; i < concurrentOperations; i++) {
          final task = Task(
            id: 'perf-task-$i-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Performance Test Task $i',
            description: 'This is a performance test task number $i',
            type: ['feature', 'bug', 'security'][i % 3],
            priority: ['low', 'medium', 'high', 'critical'][i % 4],
            status: 'pending',
            assigneeId: 'perf-assignee-$i',
            reporterId: 'perf-reporter-$i',
            estimatedHours: Random().nextInt(20) + 1,
            actualHours: 0,
            relatedCommits: [],
            relatedPullRequests: [],
            dependencies: [],
            blockedBy: [],
            createdAt: DateTime.now(),
            dueDate:
                DateTime.now().add(Duration(days: Random().nextInt(30) + 1)),
            confidentialityLevel: ['public', 'team'][i % 2],
            authorizedUsers: [],
            authorizedRoles: [],
          );

          futures.add(taskService.createTask(task));
        }

        final results = await Future.wait(futures);
        stopwatch.stop();

        expect(results.length, concurrentOperations);
        expect(results.every((id) => id.isNotEmpty), true);

        print(
            'Concurrent task creation (${concurrentOperations}x): ${stopwatch.elapsedMilliseconds}ms');
        print(
            'Average per operation: ${stopwatch.elapsedMilliseconds / concurrentOperations}ms');

        // Performance assertion
        expect(
            stopwatch.elapsedMilliseconds, lessThan(45000)); // 45 seconds max

        // Clean up
        final cleanupFutures = results.map((id) => taskService.deleteTask(
              id,
              userId: 'admin',
              userRole: 'admin',
            ));
        await Future.wait(cleanupFutures);
      });

      test('should handle large data retrieval efficiently', () async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // Create test data first
        const testDataSize = 50;
        final createdIds = <String>[];

        print('Creating $testDataSize test records...');
        for (int i = 0; i < testDataSize; i++) {
          final member = TeamMember(
            id: 'large-data-member-$i-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Large Data Test Member $i',
            email:
                'largedata$i.${DateTime.now().millisecondsSinceEpoch}@example.com',
            role: ['admin', 'lead_developer', 'developer', 'viewer'][i % 4],
            status: ['active', 'inactive', 'bench'][i % 3],
            assignments:
                List.generate(Random().nextInt(5), (j) => 'project-$i-$j'),
            expertise: ['flutter', 'dart', 'react', 'node'][i % 4].split(','),
            workload: Random().nextInt(100),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final id = await teamMemberService.createTeamMember(member);
          createdIds.add(id);
        }

        // Test retrieval performance
        final stopwatch = Stopwatch()..start();

        final allMembers = await teamMemberService.getAllTeamMembers();
        final activeMembers =
            await teamMemberService.getTeamMembersByStatus('active');
        final developers =
            await teamMemberService.getTeamMembersByRole('developer');
        final stats = await teamMemberService.getTeamStatistics();

        stopwatch.stop();

        expect(allMembers.length, greaterThanOrEqualTo(testDataSize));
        expect(activeMembers.length, greaterThan(0));
        expect(developers.length, greaterThan(0));
        expect(stats['total'], greaterThanOrEqualTo(testDataSize));

        print(
            'Large data retrieval operations: ${stopwatch.elapsedMilliseconds}ms');
        print('Retrieved ${allMembers.length} total members');
        print('Retrieved ${activeMembers.length} active members');
        print('Retrieved ${developers.length} developers');

        // Performance assertion
        expect(
            stopwatch.elapsedMilliseconds, lessThan(10000)); // 10 seconds max

        // Clean up
        print('Cleaning up test data...');
        for (final id in createdIds) {
          await teamMemberService.deleteTeamMember(id);
        }
      });

      test('should handle complex query operations efficiently', () async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // Create test tasks with various properties
        const testTaskCount = 30;
        final createdTaskIds = <String>[];

        for (int i = 0; i < testTaskCount; i++) {
          final task = Task(
            id: 'complex-query-task-$i-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Complex Query Test Task $i',
            description:
                'Task for testing complex queries with various filters',
            type: ['feature', 'bug', 'security', 'deployment'][i % 4],
            priority: ['low', 'medium', 'high', 'critical'][i % 4],
            status: ['pending', 'in_progress', 'review', 'completed'][i % 4],
            assigneeId: 'assignee-${i % 5}',
            reporterId: 'reporter-${i % 3}',
            estimatedHours: Random().nextInt(20) + 1,
            actualHours: Random().nextInt(15),
            relatedCommits:
                List.generate(Random().nextInt(3), (j) => 'commit-$i-$j'),
            relatedPullRequests:
                List.generate(Random().nextInt(2), (j) => 'pr-$i-$j'),
            dependencies: i > 0 ? ['complex-query-task-${i - 1}'] : [],
            blockedBy: [],
            createdAt:
                DateTime.now().subtract(Duration(days: Random().nextInt(30))),
            dueDate: DateTime.now().add(Duration(days: Random().nextInt(60))),
            confidentialityLevel: ['public', 'team', 'restricted'][i % 3],
            authorizedUsers: i % 3 == 2 ? ['authorized-user-$i'] : [],
            authorizedRoles: i % 3 == 2 ? ['admin'] : [],
          );

          final id = await taskService.createTask(task);
          createdTaskIds.add(id);
        }

        // Test complex query performance
        final stopwatch = Stopwatch()..start();

        final allTasks =
            await taskService.getAllTasks(userId: 'admin', userRole: 'admin');
        final featureTasks = await taskService.getTasksByType('feature',
            userId: 'admin', userRole: 'admin');
        final highPriorityTasks = await taskService.getTasksByPriority('high',
            userId: 'admin', userRole: 'admin');
        final inProgressTasks = await taskService.getTasksByStatus(
            'in_progress',
            userId: 'admin',
            userRole: 'admin');
        final assigneeTasks = await taskService.getTasksByAssignee('assignee-1',
            userId: 'admin', userRole: 'admin');
        final taskStats = await taskService.getTaskStatistics(
            userId: 'admin', userRole: 'admin');

        stopwatch.stop();

        expect(allTasks.length, greaterThanOrEqualTo(testTaskCount));
        expect(featureTasks.length, greaterThan(0));
        expect(taskStats['total'], greaterThanOrEqualTo(testTaskCount));

        print('Complex query operations: ${stopwatch.elapsedMilliseconds}ms');
        print('All tasks: ${allTasks.length}');
        print('Feature tasks: ${featureTasks.length}');
        print('High priority tasks: ${highPriorityTasks.length}');
        print('In progress tasks: ${inProgressTasks.length}');
        print('Assignee tasks: ${assigneeTasks.length}');

        // Performance assertion
        expect(
            stopwatch.elapsedMilliseconds, lessThan(15000)); // 15 seconds max

        // Clean up
        for (final id in createdTaskIds) {
          await taskService.deleteTask(id, userId: 'admin', userRole: 'admin');
        }
      });
    });

    group('Real-time Performance Tests', () {
      test('should handle multiple real-time subscriptions efficiently',
          () async {
        if (!supabaseService.isInitialized) {
          return;
        }

        final subscriptions = <StreamSubscription>[];
        final receivedUpdates = <String>[];

        try {
          // Create multiple real-time subscriptions
          final teamMemberStream = teamMemberService.watchAllTeamMembers();
          final taskStream =
              taskService.watchAllTasks(userId: 'admin', userRole: 'admin');
          final activeTeamStream =
              teamMemberService.watchTeamMembersByStatus('active');

          final stopwatch = Stopwatch()..start();

          // Subscribe to streams
          subscriptions.add(teamMemberStream.listen((members) {
            receivedUpdates.add('team_members: ${members.length}');
          }));

          subscriptions.add(taskStream.listen((tasks) {
            receivedUpdates.add('tasks: ${tasks.length}');
          }));

          subscriptions.add(activeTeamStream.listen((activeMembers) {
            receivedUpdates.add('active_members: ${activeMembers.length}');
          }));

          // Wait for initial data
          await Future.delayed(const Duration(seconds: 2));

          // Create some data to trigger updates
          final testMember = TeamMember(
            id: 'realtime-test-member-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Realtime Test Member',
            email:
                'realtime.${DateTime.now().millisecondsSinceEpoch}@example.com',
            role: 'developer',
            status: 'active',
            assignments: [],
            expertise: ['flutter'],
            workload: 50,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final memberId = await teamMemberService.createTeamMember(testMember);

          // Wait for real-time updates
          await Future.delayed(const Duration(seconds: 3));

          stopwatch.stop();

          expect(receivedUpdates.length, greaterThan(0));
          print(
              'Real-time subscriptions handled ${receivedUpdates.length} updates in ${stopwatch.elapsedMilliseconds}ms');
          print('Updates received: ${receivedUpdates.join(', ')}');

          // Performance assertion
          expect(
              stopwatch.elapsedMilliseconds, lessThan(10000)); // 10 seconds max

          // Clean up
          await teamMemberService.deleteTeamMember(memberId);
        } finally {
          // Cancel all subscriptions
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
        }
      });

      test('should handle real-time subscription performance under load',
          () async {
        if (!supabaseService.isInitialized) {
          return;
        }

        final updateCounts = <String, int>{};
        final subscriptions = <StreamSubscription>[];

        try {
          // Create subscription
          final teamMemberStream = teamMemberService.watchAllTeamMembers();

          subscriptions.add(teamMemberStream.listen((members) {
            updateCounts['updates'] = (updateCounts['updates'] ?? 0) + 1;
            updateCounts['member_count'] = members.length;
          }));

          // Wait for initial subscription
          await Future.delayed(const Duration(seconds: 1));

          final stopwatch = Stopwatch()..start();

          // Create multiple members rapidly to test real-time performance
          const rapidCreationCount = 10;
          final createdIds = <String>[];

          for (int i = 0; i < rapidCreationCount; i++) {
            final member = TeamMember(
              id: 'rapid-member-$i-${DateTime.now().millisecondsSinceEpoch}',
              name: 'Rapid Test Member $i',
              email:
                  'rapid$i.${DateTime.now().millisecondsSinceEpoch}@example.com',
              role: 'developer',
              status: 'active',
              assignments: [],
              expertise: ['flutter'],
              workload: 50,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final id = await teamMemberService.createTeamMember(member);
            createdIds.add(id);

            // Small delay to avoid overwhelming the system
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // Wait for all real-time updates to propagate
          await Future.delayed(const Duration(seconds: 5));

          stopwatch.stop();

          expect(updateCounts['updates'], greaterThan(0));
          print('Rapid creation real-time performance:');
          print(
              '- Created $rapidCreationCount members in ${stopwatch.elapsedMilliseconds}ms');
          print('- Received ${updateCounts['updates']} real-time updates');
          print('- Final member count: ${updateCounts['member_count']}');

          // Performance assertion
          expect(
              stopwatch.elapsedMilliseconds, lessThan(20000)); // 20 seconds max

          // Clean up
          for (final id in createdIds) {
            await teamMemberService.deleteTeamMember(id);
          }
        } finally {
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
        }
      });
    });

    group('Connection and Recovery Performance Tests', () {
      test('should handle connection recovery efficiently', () async {
        if (!supabaseService.isInitialized) {
          return;
        }

        final stopwatch = Stopwatch()..start();

        // Test connection status
        expect(supabaseService.isConnected, true);

        // Test ensure connection (should be fast if already connected)
        final canConnect1 = await supabaseService.ensureConnection();
        expect(canConnect1, true);

        // Test multiple ensure connection calls
        final connectionFutures =
            List.generate(5, (_) => supabaseService.ensureConnection());
        final connectionResults = await Future.wait(connectionFutures);

        stopwatch.stop();

        expect(connectionResults.every((result) => result == true), true);
        print('Connection recovery tests: ${stopwatch.elapsedMilliseconds}ms');

        // Performance assertion
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds max
      });

      test('should handle authentication performance under load', () async {
        if (!supabaseService.isInitialized) {
          return;
        }

        const authOperationCount = 5;
        final stopwatch = Stopwatch()..start();

        // Test multiple authentication operations
        for (int i = 0; i < authOperationCount; i++) {
          final testEmail =
              'perftest$i.${DateTime.now().millisecondsSinceEpoch}@example.com';
          const testPassword = 'TestPassword123!';

          // Sign up
          final signUpResult =
              await authService.signUp(testEmail, testPassword);
          expect(signUpResult.success, true);

          // Sign out
          final signOutResult = await authService.signOut();
          expect(signOutResult.success, true);

          // Sign in
          final signInResult =
              await authService.signInWithEmail(testEmail, testPassword);
          expect(signInResult.success, true);

          // Sign out again
          await authService.signOut();
        }

        stopwatch.stop();

        print(
            'Authentication performance ($authOperationCount cycles): ${stopwatch.elapsedMilliseconds}ms');
        print(
            'Average per auth cycle: ${stopwatch.elapsedMilliseconds / authOperationCount}ms');

        // Performance assertion
        expect(
            stopwatch.elapsedMilliseconds, lessThan(30000)); // 30 seconds max
      });
    });

    group('Memory and Resource Performance Tests', () {
      test('should handle memory efficiently during large operations',
          () async {
        if (!supabaseService.isInitialized) {
          return;
        }

        // This test would ideally measure memory usage
        // For now, we'll test that large operations complete without errors

        const largeOperationSize = 100;
        final stopwatch = Stopwatch()..start();

        // Create and immediately delete many records to test memory handling
        for (int batch = 0; batch < 5; batch++) {
          final batchIds = <String>[];

          // Create batch
          for (int i = 0; i < largeOperationSize ~/ 5; i++) {
            final member = TeamMember(
              id: 'memory-test-$batch-$i-${DateTime.now().millisecondsSinceEpoch}',
              name: 'Memory Test Member $batch-$i',
              email:
                  'memtest$batch$i.${DateTime.now().millisecondsSinceEpoch}@example.com',
              role: 'developer',
              status: 'active',
              assignments: [],
              expertise: ['flutter'],
              workload: 50,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final id = await teamMemberService.createTeamMember(member);
            batchIds.add(id);
          }

          // Delete batch
          for (final id in batchIds) {
            await teamMemberService.deleteTeamMember(id);
          }

          print('Completed batch $batch');
        }

        stopwatch.stop();

        print('Memory efficiency test: ${stopwatch.elapsedMilliseconds}ms');

        // Performance assertion
        expect(
            stopwatch.elapsedMilliseconds, lessThan(60000)); // 60 seconds max
      });
    });
  });
}
