import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:devguard_ai_copilot/core/database/services/enhanced_task_service.dart';
import 'package:devguard_ai_copilot/core/database/models/task.dart';
import 'package:devguard_ai_copilot/core/database/models/task_status_history.dart';
import 'package:devguard_ai_copilot/core/database/models/task_access_log.dart';
import 'package:devguard_ai_copilot/core/database/database_service.dart';
import 'package:devguard_ai_copilot/core/api/task_management_api.dart';
import 'package:devguard_ai_copilot/core/auth/auth_service.dart';

/// Test suite for task management system with confidentiality controls
/// Satisfies Requirements: 5.1, 5.2, 5.3, 5.4, 5.5 (Task management with confidentiality)
void main() {
  group('Task Management System Tests', () {
    late EnhancedTaskService taskService;
    late TaskManagementAPI taskAPI;

    setUpAll(() async {
      // Initialize FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // Initialize services
      taskService = EnhancedTaskService.instance;
      taskAPI = TaskManagementAPI.instance;

      // Initialize database
      await DatabaseService.instance.database;
    });

    tearDownAll(() async {
      await DatabaseService.instance.close();
    });

    group('Enhanced Task Service Tests', () {
      test('should create task with confidentiality controls', () async {
        // Arrange
        final task = Task(
          id: '',
          title: 'Test Confidential Task',
          description: 'This is a test task with confidential level',
          type: 'security',
          priority: 'high',
          status: 'pending',
          assigneeId: 'user123',
          reporterId: 'admin456',
          estimatedHours: 8,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          confidentialityLevel: 'confidential',
          authorizedUsers: ['admin456'],
          authorizedRoles: ['admin'],
        );

        // Act
        final taskId = await taskService.createTaskWithConfidentiality(
          task: task,
          userId: 'admin456',
          userRole: 'admin',
          ipAddress: '127.0.0.1',
          userAgent: 'test-agent',
        );

        // Assert
        expect(taskId, isNotEmpty);

        final createdTask = await taskService.getAuthorizedTask(
          taskId: taskId,
          userId: 'admin456',
          userRole: 'admin',
        );

        expect(createdTask, isNotNull);
        expect(createdTask!.title, equals('Test Confidential Task'));
        expect(createdTask.confidentialityLevel, equals('confidential'));
      });

      test('should deny access to confidential task for unauthorized user',
          () async {
        // Arrange
        final task = Task(
          id: '',
          title: 'Secret Task',
          description: 'This is a secret task',
          type: 'security',
          priority: 'critical',
          status: 'pending',
          assigneeId: 'user123',
          reporterId: 'admin456',
          estimatedHours: 4,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 3)),
          confidentialityLevel: 'confidential',
          authorizedUsers: ['admin456'],
          authorizedRoles: ['admin'],
        );

        final taskId = await taskService.createTaskWithConfidentiality(
          task: task,
          userId: 'admin456',
          userRole: 'admin',
        );

        // Act - Try to access as developer
        final accessedTask = await taskService.getAuthorizedTask(
          taskId: taskId,
          userId: 'dev789',
          userRole: 'developer',
        );

        // Assert
        expect(accessedTask, isNull);
      });

      test('should allow access to team-level task for team members', () async {
        // Arrange
        final task = Task(
          id: '',
          title: 'Team Task',
          description: 'This is a team-level task',
          type: 'feature',
          priority: 'medium',
          status: 'pending',
          assigneeId: 'dev789',
          reporterId: 'lead123',
          estimatedHours: 6,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 5)),
          confidentialityLevel: 'team',
        );

        final taskId = await taskService.createTaskWithConfidentiality(
          task: task,
          userId: 'lead123',
          userRole: 'lead_developer',
        );

        // Act - Access as developer
        final accessedTask = await taskService.getAuthorizedTask(
          taskId: taskId,
          userId: 'dev789',
          userRole: 'developer',
        );

        // Assert
        expect(accessedTask, isNotNull);
        expect(accessedTask!.title, equals('Team Task'));
      });

      test('should record status changes in history', () async {
        // Arrange
        final task = Task(
          id: '',
          title: 'Status Change Task',
          description: 'Task for testing status changes',
          type: 'bug',
          priority: 'high',
          status: 'pending',
          assigneeId: 'dev789',
          reporterId: 'lead123',
          estimatedHours: 4,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 2)),
          confidentialityLevel: 'team',
        );

        final taskId = await taskService.createTaskWithConfidentiality(
          task: task,
          userId: 'lead123',
          userRole: 'lead_developer',
        );

        // Act - Update status
        final updatedTask = task.copyWith(
          id: taskId,
          status: 'in_progress',
        );

        await taskService.updateTaskWithConfidentiality(
          updatedTask: updatedTask,
          userId: 'dev789',
          userRole: 'developer',
        );

        // Assert
        final statusHistory = await taskService.getTaskStatusHistory(taskId);
        expect(statusHistory, isNotEmpty);
        expect(statusHistory.first.oldStatus, equals('pending'));
        expect(statusHistory.first.newStatus, equals('in_progress'));
        expect(statusHistory.first.changedBy, equals('dev789'));
      });

      test('should log all task access attempts', () async {
        // Arrange
        final task = Task(
          id: '',
          title: 'Access Log Task',
          description: 'Task for testing access logging',
          type: 'feature',
          priority: 'low',
          status: 'pending',
          assigneeId: 'dev789',
          reporterId: 'lead123',
          estimatedHours: 2,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 10)),
          confidentialityLevel: 'restricted',
        );

        final taskId = await taskService.createTaskWithConfidentiality(
          task: task,
          userId: 'lead123',
          userRole: 'lead_developer',
        );

        // Act - Multiple access attempts
        await taskService.getAuthorizedTask(
          taskId: taskId,
          userId: 'admin456',
          userRole: 'admin',
          ipAddress: '192.168.1.1',
          userAgent: 'test-browser',
        );

        await taskService.getAuthorizedTask(
          taskId: taskId,
          userId: 'dev789',
          userRole: 'developer',
          ipAddress: '192.168.1.2',
          userAgent: 'test-mobile',
        );

        // Assert
        final accessLogs = await taskService.getTaskAccessLogs(taskId: taskId);
        expect(accessLogs.length,
            greaterThanOrEqualTo(3)); // Create + 2 access attempts

        final adminAccess = accessLogs
            .where(
                (log) => log.userId == 'admin456' && log.actionType == 'view')
            .first;
        expect(adminAccess.accessGranted, isTrue);
        expect(adminAccess.ipAddress, equals('192.168.1.1'));

        final devAccess = accessLogs
            .where((log) => log.userId == 'dev789' && log.actionType == 'view')
            .first;
        expect(devAccess.accessGranted,
            isFalse); // Developer can't access restricted
      });

      test('should filter tasks by confidentiality level', () async {
        // Arrange - Create tasks with different confidentiality levels
        final publicTask = Task(
          id: '',
          title: 'Public Task',
          description: 'Public task',
          type: 'feature',
          priority: 'low',
          status: 'pending',
          assigneeId: 'dev789',
          reporterId: 'lead123',
          estimatedHours: 1,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 1)),
          confidentialityLevel: 'public',
        );

        final teamTask = Task(
          id: '',
          title: 'Team Task',
          description: 'Team task',
          type: 'bug',
          priority: 'medium',
          status: 'pending',
          assigneeId: 'dev789',
          reporterId: 'lead123',
          estimatedHours: 3,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 2)),
          confidentialityLevel: 'team',
        );

        final restrictedTask = Task(
          id: '',
          title: 'Restricted Task',
          description: 'Restricted task',
          type: 'security',
          priority: 'high',
          status: 'pending',
          assigneeId: 'lead123',
          reporterId: 'admin456',
          estimatedHours: 5,
          actualHours: 0,
          relatedCommits: [],
          relatedPullRequests: [],
          dependencies: [],
          blockedBy: [],
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 3)),
          confidentialityLevel: 'restricted',
        );

        await taskService.createTaskWithConfidentiality(
          task: publicTask,
          userId: 'lead123',
          userRole: 'lead_developer',
        );

        await taskService.createTaskWithConfidentiality(
          task: teamTask,
          userId: 'lead123',
          userRole: 'lead_developer',
        );

        await taskService.createTaskWithConfidentiality(
          task: restrictedTask,
          userId: 'admin456',
          userRole: 'admin',
        );

        // Act - Get tasks as developer
        final developerTasks = await taskService.getAuthorizedTasks(
          userId: 'dev789',
          userRole: 'developer',
        );

        // Act - Get tasks as admin
        final adminTasks = await taskService.getAuthorizedTasks(
          userId: 'admin456',
          userRole: 'admin',
        );

        // Assert
        expect(developerTasks.length, equals(2)); // Public + Team
        expect(adminTasks.length, equals(3)); // All tasks

        final devTaskTitles = developerTasks.map((t) => t.title).toList();
        expect(devTaskTitles, contains('Public Task'));
        expect(devTaskTitles, contains('Team Task'));
        expect(devTaskTitles, isNot(contains('Restricted Task')));
      });
    });

    group('Task Management API Tests', () {
      test('should create task via API with proper validation', () async {
        // Act
        final response = await taskAPI.createTask(
          title: 'API Test Task',
          description: 'Task created via API for testing',
          type: 'feature',
          priority: 'medium',
          assigneeId: 'dev789',
          estimatedHours: 4,
          dueDate: DateTime.now().add(const Duration(days: 5)),
          confidentialityLevel: 'team',
        );

        // Assert
        expect(response.success, isTrue);
        expect(response.statusCode, equals(201));
        expect(response.data, isNotEmpty);
      });

      test('should validate task input and reject invalid data', () async {
        // Act
        final response = await taskAPI.createTask(
          title: '', // Invalid: empty title
          description: 'Test',
          type: 'feature',
          priority: 'medium',
          assigneeId: 'dev789',
          estimatedHours: 4,
          dueDate: DateTime.now().add(const Duration(days: 5)),
        );

        // Assert
        expect(response.success, isFalse);
        expect(response.statusCode, equals(400));
        expect(response.message, contains('Title is required'));
      });

      test('should filter tasks by confidentiality in API', () async {
        // Arrange - Create a restricted task
        await taskAPI.createTask(
          title: 'Restricted API Task',
          description: 'Restricted task via API',
          type: 'security',
          priority: 'high',
          assigneeId: 'admin456',
          estimatedHours: 6,
          dueDate: DateTime.now().add(const Duration(days: 3)),
          confidentialityLevel: 'restricted',
        );

        // Act - Get tasks with different user roles
        final response = await taskAPI.getTasks();

        // Assert
        expect(response.success, isTrue);
        expect(response.data, isNotNull);
        // The actual filtering would depend on the current authenticated user
      });
    });

    group('Task Status History Tests', () {
      test('should create status history entry', () async {
        // Arrange
        final history = TaskStatusHistory(
          id: 'hist123',
          taskId: 'task456',
          oldStatus: 'pending',
          newStatus: 'in_progress',
          changedBy: 'dev789',
          changedAt: DateTime.now(),
          notes: 'Started working on the task',
        );

        // Act & Assert
        expect(history.id, equals('hist123'));
        expect(history.taskId, equals('task456'));
        expect(history.oldStatus, equals('pending'));
        expect(history.newStatus, equals('in_progress'));
        expect(history.changedBy, equals('dev789'));
        expect(history.notes, equals('Started working on the task'));
      });

      test('should convert status history to/from map', () async {
        // Arrange
        final history = TaskStatusHistory(
          id: 'hist123',
          taskId: 'task456',
          oldStatus: 'pending',
          newStatus: 'in_progress',
          changedBy: 'dev789',
          changedAt: DateTime.now(),
        );

        // Act
        final map = history.toMap();
        final reconstructed = TaskStatusHistory.fromMap(map);

        // Assert
        expect(reconstructed.id, equals(history.id));
        expect(reconstructed.taskId, equals(history.taskId));
        expect(reconstructed.oldStatus, equals(history.oldStatus));
        expect(reconstructed.newStatus, equals(history.newStatus));
        expect(reconstructed.changedBy, equals(history.changedBy));
      });
    });

    group('Task Access Log Tests', () {
      test('should create access log entry', () async {
        // Arrange
        final accessLog = TaskAccessLog(
          id: 'log123',
          taskId: 'task456',
          userId: 'dev789',
          actionType: 'view',
          accessGranted: true,
          confidentialityLevel: 'team',
          userRole: 'developer',
          timestamp: DateTime.now(),
          ipAddress: '192.168.1.100',
          userAgent: 'Mozilla/5.0',
          details: 'Task viewed successfully',
        );

        // Act & Assert
        expect(accessLog.id, equals('log123'));
        expect(accessLog.taskId, equals('task456'));
        expect(accessLog.userId, equals('dev789'));
        expect(accessLog.actionType, equals('view'));
        expect(accessLog.accessGranted, isTrue);
        expect(accessLog.confidentialityLevel, equals('team'));
        expect(accessLog.userRole, equals('developer'));
        expect(accessLog.ipAddress, equals('192.168.1.100'));
        expect(accessLog.userAgent, equals('Mozilla/5.0'));
        expect(accessLog.details, equals('Task viewed successfully'));
      });

      test('should convert access log to/from map', () async {
        // Arrange
        final accessLog = TaskAccessLog(
          id: 'log123',
          taskId: 'task456',
          userId: 'dev789',
          actionType: 'update',
          accessGranted: false,
          confidentialityLevel: 'restricted',
          userRole: 'developer',
          timestamp: DateTime.now(),
          details: 'Access denied - insufficient clearance',
        );

        // Act
        final map = accessLog.toMap();
        final reconstructed = TaskAccessLog.fromMap(map);

        // Assert
        expect(reconstructed.id, equals(accessLog.id));
        expect(reconstructed.taskId, equals(accessLog.taskId));
        expect(reconstructed.userId, equals(accessLog.userId));
        expect(reconstructed.actionType, equals(accessLog.actionType));
        expect(reconstructed.accessGranted, equals(accessLog.accessGranted));
        expect(reconstructed.confidentialityLevel,
            equals(accessLog.confidentialityLevel));
        expect(reconstructed.userRole, equals(accessLog.userRole));
        expect(reconstructed.details, equals(accessLog.details));
      });
    });
  });
}
