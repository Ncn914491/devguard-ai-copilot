import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devguard_ai_copilot/core/supabase/services/supabase_task_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_error_handler.dart';
import 'package:devguard_ai_copilot/core/database/models/task.dart';

// Generate mocks
@GenerateMocks([
  SupabaseClient,
  PostgrestClient,
  PostgrestFilterBuilder,
  PostgrestTransformBuilder,
])
import 'supabase_task_service_unit_test.mocks.dart';

void main() {
  group('SupabaseTaskService Unit Tests', () {
    late SupabaseTaskService service;
    late MockSupabaseClient mockClient;
    late MockPostgrestClient mockPostgrestClient;
    late MockPostgrestFilterBuilder mockFilterBuilder;

    setUp(() {
      service = SupabaseTaskService.instance;
      mockClient = MockSupabaseClient();
      mockPostgrestClient = MockPostgrestClient();
      mockFilterBuilder = MockPostgrestFilterBuilder();

      when(mockClient.from('tasks')).thenReturn(mockPostgrestClient);
    });

    group('fromMap', () {
      test('should convert map to Task correctly', () {
        final map = {
          'id': 'task-123',
          'title': 'Test Task',
          'description': 'Test Description',
          'type': 'feature',
          'priority': 'high',
          'status': 'in_progress',
          'assignee_id': 'user-123',
          'reporter_id': 'user-456',
          'estimated_hours': 8,
          'actual_hours': 6,
          'related_commits': ['commit-1', 'commit-2'],
          'related_pull_requests': ['pr-1'],
          'dependencies': ['task-456'],
          'blocked_by': [],
          'created_at': '2024-01-01T00:00:00Z',
          'due_date': '2024-01-15T00:00:00Z',
          'completed_at': null,
          'confidentiality_level': 'team',
          'authorized_users': ['user-123'],
          'authorized_roles': ['developer'],
        };

        final task = service.fromMap(map);

        expect(task.id, 'task-123');
        expect(task.title, 'Test Task');
        expect(task.description, 'Test Description');
        expect(task.type, 'feature');
        expect(task.priority, 'high');
        expect(task.status, 'in_progress');
        expect(task.assigneeId, 'user-123');
        expect(task.reporterId, 'user-456');
        expect(task.estimatedHours, 8);
        expect(task.actualHours, 6);
        expect(task.relatedCommits, ['commit-1', 'commit-2']);
        expect(task.relatedPullRequests, ['pr-1']);
        expect(task.dependencies, ['task-456']);
        expect(task.blockedBy, isEmpty);
        expect(task.confidentialityLevel, 'team');
        expect(task.authorizedUsers, ['user-123']);
        expect(task.authorizedRoles, ['developer']);
        expect(task.completedAt, isNull);
      });

      test('should handle null values gracefully', () {
        final map = {
          'id': 'task-123',
          'title': 'Test Task',
          'description': 'Test Description',
          'type': 'feature',
          'priority': 'high',
          'status': 'pending',
          'assignee_id': '',
          'reporter_id': '',
          'estimated_hours': null,
          'actual_hours': null,
          'related_commits': null,
          'related_pull_requests': null,
          'dependencies': null,
          'blocked_by': null,
          'created_at': '2024-01-01T00:00:00Z',
          'due_date': '2024-01-15T00:00:00Z',
          'completed_at': null,
          'confidentiality_level': null,
          'authorized_users': null,
          'authorized_roles': null,
        };

        final task = service.fromMap(map);

        expect(task.estimatedHours, 0);
        expect(task.actualHours, 0);
        expect(task.relatedCommits, isEmpty);
        expect(task.relatedPullRequests, isEmpty);
        expect(task.dependencies, isEmpty);
        expect(task.blockedBy, isEmpty);
        expect(task.confidentialityLevel, 'team');
        expect(task.authorizedUsers, isEmpty);
        expect(task.authorizedRoles, isEmpty);
      });
    });

    group('toMap', () {
      test('should convert Task to map correctly', () {
        final task = Task(
          id: 'task-123',
          title: 'Test Task',
          description: 'Test Description',
          type: 'feature',
          priority: 'high',
          status: 'in_progress',
          assigneeId: 'user-123',
          reporterId: 'user-456',
          estimatedHours: 8,
          actualHours: 6,
          relatedCommits: ['commit-1', 'commit-2'],
          relatedPullRequests: ['pr-1'],
          dependencies: ['task-456'],
          blockedBy: [],
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
          dueDate: DateTime.parse('2024-01-15T00:00:00Z'),
          completedAt: null,
          confidentialityLevel: 'team',
          authorizedUsers: ['user-123'],
          authorizedRoles: ['developer'],
        );

        final map = service.toMap(task);

        expect(map['id'], 'task-123');
        expect(map['title'], 'Test Task');
        expect(map['description'], 'Test Description');
        expect(map['type'], 'feature');
        expect(map['priority'], 'high');
        expect(map['status'], 'in_progress');
        expect(map['assignee_id'], 'user-123');
        expect(map['reporter_id'], 'user-456');
        expect(map['estimated_hours'], 8);
        expect(map['actual_hours'], 6);
        expect(map['related_commits'], ['commit-1', 'commit-2']);
        expect(map['related_pull_requests'], ['pr-1']);
        expect(map['dependencies'], ['task-456']);
        expect(map['blocked_by'], isEmpty);
        expect(map['confidentiality_level'], 'team');
        expect(map['authorized_users'], ['user-123']);
        expect(map['authorized_roles'], ['developer']);
        expect(map['completed_at'], isNull);
      });
    });

    group('validateData', () {
      test('should pass validation for valid data', () {
        final data = {
          'id': 'task-123',
          'title': 'Test Task',
          'description': 'Test Description',
          'type': 'feature',
          'priority': 'high',
          'status': 'pending',
          'due_date': '2024-01-15T00:00:00Z',
          'estimated_hours': 8,
          'actual_hours': 6,
          'confidentiality_level': 'team',
        };

        expect(() => service.validateData(data), returnsNormally);
      });

      test('should throw validation error for missing title', () {
        final data = {
          'id': 'task-123',
          'title': '',
          'description': 'Test Description',
          'type': 'feature',
          'priority': 'high',
          'status': 'pending',
          'due_date': '2024-01-15T00:00:00Z',
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'Task title is required',
          )),
        );
      });

      test('should throw validation error for missing description', () {
        final data = {
          'id': 'task-123',
          'title': 'Test Task',
          'description': '',
          'type': 'feature',
          'priority': 'high',
          'status': 'pending',
          'due_date': '2024-01-15T00:00:00Z',
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'Task description is required',
          )),
        );
      });

      test('should throw validation error for invalid type', () {
        final data = {
          'id': 'task-123',
          'title': 'Test Task',
          'description': 'Test Description',
          'type': 'invalid_type',
          'priority': 'high',
          'status': 'pending',
          'due_date': '2024-01-15T00:00:00Z',
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            contains('Invalid type'),
          )),
        );
      });

      test('should throw validation error for invalid priority', () {
        final data = {
          'id': 'task-123',
          'title': 'Test Task',
          'description': 'Test Description',
          'type': 'feature',
          'priority': 'invalid_priority',
          'status': 'pending',
          'due_date': '2024-01-15T00:00:00Z',
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            contains('Invalid priority'),
          )),
        );
      });

      test('should throw validation error for invalid status', () {
        final data = {
          'id': 'task-123',
          'title': 'Test Task',
          'description': 'Test Description',
          'type': 'feature',
          'priority': 'high',
          'status': 'invalid_status',
          'due_date': '2024-01-15T00:00:00Z',
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            contains('Invalid status'),
          )),
        );
      });

      test('should throw validation error for missing due date', () {
        final data = {
          'id': 'task-123',
          'title': 'Test Task',
          'description': 'Test Description',
          'type': 'feature',
          'priority': 'high',
          'status': 'pending',
          'due_date': null,
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'Task due date is required',
          )),
        );
      });

      test('should throw validation error for invalid confidentiality level',
          () {
        final data = {
          'id': 'task-123',
          'title': 'Test Task',
          'description': 'Test Description',
          'type': 'feature',
          'priority': 'high',
          'status': 'pending',
          'due_date': '2024-01-15T00:00:00Z',
          'confidentiality_level': 'invalid_level',
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            contains('Invalid confidentiality level'),
          )),
        );
      });

      test('should throw validation error for negative estimated hours', () {
        final data = {
          'id': 'task-123',
          'title': 'Test Task',
          'description': 'Test Description',
          'type': 'feature',
          'priority': 'high',
          'status': 'pending',
          'due_date': '2024-01-15T00:00:00Z',
          'estimated_hours': -5,
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'Estimated hours must be a non-negative integer',
          )),
        );
      });
    });

    group('Authorization Tests', () {
      late Task publicTask;
      late Task teamTask;
      late Task restrictedTask;
      late Task confidentialTask;

      setUp(() {
        publicTask = Task(
          id: 'public-task',
          title: 'Public Task',
          description: 'Public Description',
          type: 'feature',
          priority: 'medium',
          status: 'pending',
          assigneeId: 'user-123',
          reporterId: 'user-456',
          estimatedHours: 4,
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

        teamTask = Task(
          id: 'team-task',
          title: 'Team Task',
          description: 'Team Description',
          type: 'feature',
          priority: 'medium',
          status: 'pending',
          assigneeId: 'user-123',
          reporterId: 'user-456',
          estimatedHours: 4,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          confidentialityLevel: 'team',
          authorizedUsers: [],
          authorizedRoles: [],
        );

        restrictedTask = Task(
          id: 'restricted-task',
          title: 'Restricted Task',
          description: 'Restricted Description',
          type: 'security',
          priority: 'high',
          status: 'pending',
          assigneeId: 'user-789',
          reporterId: 'user-456',
          estimatedHours: 8,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          confidentialityLevel: 'restricted',
          authorizedUsers: ['user-123'],
          authorizedRoles: ['lead_developer'],
        );

        confidentialTask = Task(
          id: 'confidential-task',
          title: 'Confidential Task',
          description: 'Confidential Description',
          type: 'security',
          priority: 'critical',
          status: 'pending',
          assigneeId: 'user-789',
          reporterId: 'user-456',
          estimatedHours: 16,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          confidentialityLevel: 'confidential',
          authorizedUsers: ['user-admin'],
          authorizedRoles: ['admin'],
        );
      });

      group('_isAuthorizedToView', () {
        test('should allow admin to view all tasks', () {
          expect(service.isAuthorizedToView(publicTask, 'admin-user', 'admin'),
              true);
          expect(service.isAuthorizedToView(teamTask, 'admin-user', 'admin'),
              true);
          expect(
              service.isAuthorizedToView(restrictedTask, 'admin-user', 'admin'),
              true);
          expect(
              service.isAuthorizedToView(
                  confidentialTask, 'admin-user', 'admin'),
              true);
        });

        test('should allow anyone to view public tasks', () {
          expect(service.isAuthorizedToView(publicTask, 'any-user', 'viewer'),
              true);
          expect(
              service.isAuthorizedToView(publicTask, 'any-user', 'developer'),
              true);
          expect(
              service.isAuthorizedToView(
                  publicTask, 'any-user', 'lead_developer'),
              true);
        });

        test('should allow team members to view team tasks', () {
          expect(service.isAuthorizedToView(teamTask, 'dev-user', 'developer'),
              true);
          expect(
              service.isAuthorizedToView(
                  teamTask, 'lead-user', 'lead_developer'),
              true);
          expect(service.isAuthorizedToView(teamTask, 'viewer-user', 'viewer'),
              false);
        });

        test('should allow authorized users to view restricted tasks', () {
          expect(
              service.isAuthorizedToView(
                  restrictedTask, 'user-123', 'developer'),
              true);
          expect(
              service.isAuthorizedToView(
                  restrictedTask, 'user-456', 'developer'),
              false);
        });

        test('should allow authorized roles to view restricted tasks', () {
          expect(
              service.isAuthorizedToView(
                  restrictedTask, 'lead-user', 'lead_developer'),
              true);
          expect(
              service.isAuthorizedToView(
                  restrictedTask, 'dev-user', 'developer'),
              false);
        });

        test('should allow assignee and reporter to view their tasks', () {
          expect(
              service.isAuthorizedToView(restrictedTask, 'user-789', 'viewer'),
              true); // assignee
          expect(
              service.isAuthorizedToView(restrictedTask, 'user-456', 'viewer'),
              true); // reporter
          expect(
              service.isAuthorizedToView(restrictedTask, 'user-999', 'viewer'),
              false); // neither
        });

        test('should restrict access to confidential tasks', () {
          expect(
              service.isAuthorizedToView(
                  confidentialTask, 'user-admin', 'admin'),
              true);
          expect(
              service.isAuthorizedToView(
                  confidentialTask, 'user-123', 'lead_developer'),
              false);
          expect(
              service.isAuthorizedToView(
                  confidentialTask, 'user-456', 'developer'),
              true); // reporter
          expect(
              service.isAuthorizedToView(
                  confidentialTask, 'user-789', 'developer'),
              true); // assignee
        });
      });

      group('_isAuthorizedToModify', () {
        test('should allow admin to modify all tasks', () {
          expect(
              service.isAuthorizedToModify(publicTask, 'admin-user', 'admin'),
              true);
          expect(service.isAuthorizedToModify(teamTask, 'admin-user', 'admin'),
              true);
          expect(
              service.isAuthorizedToModify(
                  restrictedTask, 'admin-user', 'admin'),
              true);
          expect(
              service.isAuthorizedToModify(
                  confidentialTask, 'admin-user', 'admin'),
              true);
        });

        test('should allow lead developers to modify public and team tasks',
            () {
          expect(
              service.isAuthorizedToModify(
                  publicTask, 'lead-user', 'lead_developer'),
              true);
          expect(
              service.isAuthorizedToModify(
                  teamTask, 'lead-user', 'lead_developer'),
              true);
          expect(
              service.isAuthorizedToModify(
                  restrictedTask, 'lead-user', 'lead_developer'),
              false);
          expect(
              service.isAuthorizedToModify(
                  confidentialTask, 'lead-user', 'lead_developer'),
              false);
        });

        test('should allow users to modify their own tasks', () {
          expect(
              service.isAuthorizedToModify(
                  restrictedTask, 'user-789', 'developer'),
              true); // assignee
          expect(
              service.isAuthorizedToModify(
                  restrictedTask, 'user-456', 'developer'),
              true); // reporter
          expect(
              service.isAuthorizedToModify(
                  restrictedTask, 'user-999', 'developer'),
              false); // neither
        });

        test('should allow authorized users to modify restricted tasks', () {
          expect(
              service.isAuthorizedToModify(
                  restrictedTask, 'user-123', 'developer'),
              true);
          expect(
              service.isAuthorizedToModify(
                  restrictedTask, 'user-456', 'developer'),
              true); // also reporter
        });
      });
    });

    group('updateTaskStatus', () {
      test('should update task status successfully', () async {
        const taskId = 'task-123';
        const newStatus = 'completed';
        const userId = 'user-123';
        const userRole = 'admin';

        final existingTask = Task(
          id: taskId,
          title: 'Test Task',
          description: 'Test Description',
          type: 'feature',
          priority: 'medium',
          status: 'in_progress',
          assigneeId: 'user-456',
          reporterId: userId,
          estimatedHours: 4,
          actualHours: 3,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          confidentialityLevel: 'team',
          authorizedUsers: [],
          authorizedRoles: [],
        );

        // Mock getting existing task
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', taskId)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.maybeSingle()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any))
            .thenAnswer((_) async => service.toMap(existingTask));

        // Mock update operation
        when(mockPostgrestClient.update(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', taskId)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenAnswer((_) async => {});

        await service.updateTaskStatus(taskId, newStatus,
            userId: userId, userRole: userRole);

        verify(mockPostgrestClient.update(any)).called(1);
      });

      test('should throw error for non-existent task', () async {
        const taskId = 'non-existent';
        const newStatus = 'completed';

        // Mock task not found
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', taskId)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.maybeSingle()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenAnswer((_) async => null);

        expect(
          () => service.updateTaskStatus(taskId, newStatus),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'Task not found',
          )),
        );
      });

      test('should throw authorization error for unauthorized user', () async {
        const taskId = 'task-123';
        const newStatus = 'completed';
        const userId = 'unauthorized-user';
        const userRole = 'viewer';

        final existingTask = Task(
          id: taskId,
          title: 'Test Task',
          description: 'Test Description',
          type: 'feature',
          priority: 'medium',
          status: 'in_progress',
          assigneeId: 'user-456',
          reporterId: 'user-789',
          estimatedHours: 4,
          actualHours: 3,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          confidentialityLevel: 'restricted',
          authorizedUsers: ['user-999'],
          authorizedRoles: ['admin'],
        );

        // Mock getting existing task
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', taskId)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.maybeSingle()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any))
            .thenAnswer((_) async => service.toMap(existingTask));

        expect(
          () => service.updateTaskStatus(taskId, newStatus,
              userId: userId, userRole: userRole),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'You do not have permission to modify this task',
          )),
        );
      });
    });

    group('addRelatedCommit', () {
      test('should add related commit successfully', () async {
        const taskId = 'task-123';
        const commitHash = 'abc123def456';
        const userId = 'user-123';
        const userRole = 'developer';

        final existingTask = Task(
          id: taskId,
          title: 'Test Task',
          description: 'Test Description',
          type: 'feature',
          priority: 'medium',
          status: 'in_progress',
          assigneeId: userId,
          reporterId: 'user-456',
          estimatedHours: 4,
          actualHours: 3,
          relatedCommits: ['existing-commit'],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          confidentialityLevel: 'team',
          authorizedUsers: [],
          authorizedRoles: [],
        );

        // Mock getting existing task
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', taskId)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.maybeSingle()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any))
            .thenAnswer((_) async => service.toMap(existingTask));

        // Mock update operation
        when(mockPostgrestClient.update(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', taskId)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenAnswer((_) async => {});

        await service.addRelatedCommit(taskId, commitHash,
            userId: userId, userRole: userRole);

        verify(mockPostgrestClient.update(any)).called(1);
      });

      test('should not add duplicate commit', () async {
        const taskId = 'task-123';
        const commitHash = 'existing-commit';
        const userId = 'user-123';
        const userRole = 'developer';

        final existingTask = Task(
          id: taskId,
          title: 'Test Task',
          description: 'Test Description',
          type: 'feature',
          priority: 'medium',
          status: 'in_progress',
          assigneeId: userId,
          reporterId: 'user-456',
          estimatedHours: 4,
          actualHours: 3,
          relatedCommits: ['existing-commit'],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          confidentialityLevel: 'team',
          authorizedUsers: [],
          authorizedRoles: [],
        );

        // Mock getting existing task
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', taskId)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.maybeSingle()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any))
            .thenAnswer((_) async => service.toMap(existingTask));

        // Mock update operation
        when(mockPostgrestClient.update(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', taskId)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenAnswer((_) async => {});

        await service.addRelatedCommit(taskId, commitHash,
            userId: userId, userRole: userRole);

        // Should still call update, but the commit list should remain the same
        verify(mockPostgrestClient.update(any)).called(1);
      });
    });

    group('getTaskStatistics', () {
      test('should calculate task statistics correctly', () async {
        final now = DateTime.now();
        final mockTasks = [
          service.toMap(Task(
            id: 'task-1',
            title: 'Task 1',
            description: 'Description 1',
            type: 'feature',
            priority: 'high',
            status: 'completed',
            assigneeId: 'user-1',
            reporterId: 'user-2',
            estimatedHours: 8,
            actualHours: 6,
            relatedCommits: [],
            relatedPullRequests: [],
            dependencies: [],
            blockedBy: [],
            createdAt: now,
            dueDate: now.add(const Duration(days: 7)),
            confidentialityLevel: 'public',
            authorizedUsers: [],
            authorizedRoles: [],
          )),
          service.toMap(Task(
            id: 'task-2',
            title: 'Task 2',
            description: 'Description 2',
            type: 'bug',
            priority: 'medium',
            status: 'in_progress',
            assigneeId: 'user-1',
            reporterId: 'user-2',
            estimatedHours: 4,
            actualHours: 2,
            relatedCommits: [],
            relatedPullRequests: [],
            dependencies: [],
            blockedBy: [],
            createdAt: now,
            dueDate: now.subtract(const Duration(days: 1)), // Overdue
            confidentialityLevel: 'team',
            authorizedUsers: [],
            authorizedRoles: [],
          )),
          service.toMap(Task(
            id: 'task-3',
            title: 'Task 3',
            description: 'Description 3',
            type: 'feature',
            priority: 'low',
            status: 'pending',
            assigneeId: 'user-3',
            reporterId: 'user-2',
            estimatedHours: 2,
            actualHours: 0,
            relatedCommits: [],
            relatedPullRequests: [],
            dependencies: [],
            blockedBy: [],
            createdAt: now,
            dueDate: now.add(const Duration(days: 3)),
            confidentialityLevel: 'public',
            authorizedUsers: [],
            authorizedRoles: [],
          )),
        ];

        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order('created_at', ascending: false))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenAnswer((_) async => mockTasks);

        final stats = await service.getTaskStatistics(
            userId: 'user-1', userRole: 'admin');

        expect(stats['total'], 3);
        expect(stats['completed'], 1);
        expect(stats['in_progress'], 1);
        expect(stats['pending'], 1);
        expect(stats['overdue'], 1);

        final typeDistribution = stats['typeDistribution'] as Map<String, int>;
        expect(typeDistribution['feature'], 2);
        expect(typeDistribution['bug'], 1);

        final priorityDistribution =
            stats['priorityDistribution'] as Map<String, int>;
        expect(priorityDistribution['high'], 1);
        expect(priorityDistribution['medium'], 1);
        expect(priorityDistribution['low'], 1);

        expect(stats['averageEstimatedHours'], closeTo(4.67, 0.1));
        expect(stats['averageActualHours'], closeTo(2.67, 0.1));
      });

      test('should handle empty task list', () async {
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order('created_at', ascending: false))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);

        final stats = await service.getTaskStatistics();

        expect(stats['total'], 0);
        expect(stats['completed'], 0);
        expect(stats['in_progress'], 0);
        expect(stats['pending'], 0);
        expect(stats['overdue'], 0);
        expect(stats['averageEstimatedHours'], 0.0);
        expect(stats['averageActualHours'], 0.0);
      });
    });

    group('Error Handling', () {
      test('should handle database errors gracefully', () async {
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order('created_at', ascending: false))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenThrow(
            PostgrestException(message: 'Database error', code: 'PGRST000'));

        expect(
          () => service.getAllTasks(),
          throwsA(isA<AppError>().having(
            (e) => e.type,
            'type',
            AppErrorType.database,
          )),
        );
      });

      test('should handle authorization errors gracefully', () async {
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order('created_at', ascending: false))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenThrow(
            PostgrestException(message: 'RLS violation', code: '42501'));

        expect(
          () => service.getAllTasks(),
          throwsA(isA<AppError>().having(
            (e) => e.type,
            'type',
            AppErrorType.authorization,
          )),
        );
      });
    });
  });
}

// Extension method to access private methods for testing
extension SupabaseTaskServiceTestExtension on SupabaseTaskService {
  bool isAuthorizedToView(Task task, String? userId, String? userRole) {
    return _isAuthorizedToView(task, userId, userRole);
  }

  bool isAuthorizedToModify(Task task, String? userId, String? userRole) {
    return _isAuthorizedToModify(task, userId, userRole);
  }
}
