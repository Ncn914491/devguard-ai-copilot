import 'dart:async';
import '../database/services/task_service.dart';
import '../database/services/audit_log_service.dart';
import '../auth/auth_service.dart';
import '../database/models/task.dart';
import 'websocket_service.dart';

/// Task Management API with confidentiality controls and real-time updates
/// Satisfies Requirements: 5.1, 5.2, 5.3, 5.4, 5.5 (Task management with confidentiality)
class TaskManagementAPI {
  static final TaskManagementAPI _instance = TaskManagementAPI._internal();
  static TaskManagementAPI get instance => _instance;
  TaskManagementAPI._internal();

  final _taskService = TaskService.instance;
  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;
  final _websocketService = WebSocketService.instance;

  /// Get tasks with filtering and confidentiality controls
  /// GET /api/tasks
  Future<APIResponse<List<Task>>> getTasks({
    String? assigneeId,
    String? status,
    String? priority,
    String? type,
    String? confidentialityLevel,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<List<Task>>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      final currentUser = _authService.currentUser!;
      List<Task> tasks = [];

      // Get tasks based on filters
      if (assigneeId != null) {
        tasks = await _taskService.getTasksByAssignee(assigneeId);
      } else if (status != null) {
        tasks = await _taskService.getTasksByStatus(status);
      } else if (priority != null) {
        tasks = await _taskService.getTasksByPriority(priority);
      } else if (type != null) {
        tasks = await _taskService.getTasksByType(type);
      } else {
        tasks = await _taskService.getAllTasks();
      }

      // Apply confidentiality filtering
      final filteredTasks = _filterTasksByConfidentiality(tasks, currentUser);

      // Apply additional filters
      if (confidentialityLevel != null) {
        tasks = filteredTasks
            .where(
                (task) => _getTaskConfidentiality(task) == confidentialityLevel)
            .toList();
      } else {
        tasks = filteredTasks;
      }

      await _auditService.logAction(
        actionType: 'tasks_retrieved',
        description: 'Retrieved tasks with filters',
        contextData: {
          'assignee_id': assigneeId,
          'status': status,
          'priority': priority,
          'type': type,
          'confidentiality_level': confidentialityLevel,
          'result_count': tasks.length,
          'total_before_filtering': filteredTasks.length,
        },
        userId: currentUser.id,
      );

      return APIResponse<List<Task>>(
        success: true,
        message: 'Tasks retrieved successfully',
        data: tasks,
        statusCode: 200,
        metadata: {
          'total_count': tasks.length,
          'filters_applied': {
            'assignee_id': assigneeId,
            'status': status,
            'priority': priority,
            'type': type,
            'confidentiality_level': confidentialityLevel,
          },
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'tasks_retrieval_error',
        description: 'Error retrieving tasks: ${e.toString()}',
        contextData: {'error': e.toString()},
        userId: _authService.currentUser?.id,
      );

      return APIResponse<List<Task>>(
        success: false,
        message: 'Failed to retrieve tasks: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Get task by ID with confidentiality check
  /// GET /api/tasks/{id}
  Future<APIResponse<Task>> getTask(String taskId) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<Task>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Validate task ID
      if (taskId.trim().isEmpty) {
        return APIResponse<Task>(
          success: false,
          message: 'Task ID is required',
          statusCode: 400,
        );
      }

      final task = await _taskService.getTask(taskId);
      if (task == null) {
        return APIResponse<Task>(
          success: false,
          message: 'Task not found',
          statusCode: 404,
        );
      }

      final currentUser = _authService.currentUser!;

      // Check confidentiality access
      if (!_canAccessTask(task, currentUser)) {
        await _auditService.logAction(
          actionType: 'task_access_denied',
          description: 'Access denied to confidential task',
          contextData: {
            'task_id': taskId,
            'task_title': task.title,
            'confidentiality_level': _getTaskConfidentiality(task),
            'user_role': currentUser.role,
          },
          userId: currentUser.id,
        );

        return APIResponse<Task>(
          success: false,
          message: 'Access denied: insufficient clearance for this task',
          statusCode: 403,
        );
      }

      await _auditService.logAction(
        actionType: 'task_retrieved',
        description: 'Retrieved task: ${task.title}',
        contextData: {
          'task_id': taskId,
          'task_type': task.type,
          'task_priority': task.priority,
          'confidentiality_level': _getTaskConfidentiality(task),
        },
        userId: currentUser.id,
      );

      return APIResponse<Task>(
        success: true,
        message: 'Task retrieved successfully',
        data: task,
        statusCode: 200,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'task_retrieval_error',
        description: 'Error retrieving task: ${e.toString()}',
        contextData: {
          'task_id': taskId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<Task>(
        success: false,
        message: 'Failed to retrieve task: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Create new task with confidentiality controls
  /// POST /api/tasks
  Future<APIResponse<String>> createTask({
    required String title,
    required String description,
    required String type,
    required String priority,
    required String assigneeId,
    required int estimatedHours,
    required DateTime dueDate,
    List<String> dependencies = const [],
    String confidentialityLevel = 'team',
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<String>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('create_tasks') &&
          !_authService.hasPermission('assign_tasks')) {
        return APIResponse<String>(
          success: false,
          message: 'Insufficient permissions to create tasks',
          statusCode: 403,
        );
      }

      // Validate input
      final validationError = _validateTaskInput(
        title: title,
        description: description,
        type: type,
        priority: priority,
        assigneeId: assigneeId,
        estimatedHours: estimatedHours,
        confidentialityLevel: confidentialityLevel,
      );
      if (validationError != null) {
        return APIResponse<String>(
          success: false,
          message: validationError,
          statusCode: 400,
        );
      }

      // Check confidentiality permissions
      final currentUser = _authService.currentUser!;
      if (!_canSetConfidentialityLevel(confidentialityLevel, currentUser)) {
        return APIResponse<String>(
          success: false,
          message: 'Insufficient permissions to set this confidentiality level',
          statusCode: 403,
        );
      }

      // Create task
      final task = Task(
        id: '',
        title: title.trim(),
        description: description.trim(),
        type: type.toLowerCase(),
        priority: priority.toLowerCase(),
        status: 'pending',
        assigneeId: assigneeId,
        reporterId: currentUser.id,
        estimatedHours: estimatedHours,
        actualHours: 0,
        relatedCommits: [],
        relatedPullRequests: [],
        dependencies: dependencies,
        blockedBy: [],
        createdAt: DateTime.now(),
        dueDate: dueDate,
        confidentialityLevel: confidentialityLevel,
      );

      final taskId = await _taskService.createTask(task);

      // Broadcast task creation via WebSocket
      await _websocketService.broadcastTaskUpdate(
        taskId: taskId,
        update: {
          'action': 'created',
          'task': _taskToMap(task.copyWith(id: taskId)),
          'confidentiality_level': confidentialityLevel,
        },
        targetUsers: _getAuthorizedUsers(confidentialityLevel, currentUser),
      );

      await _auditService.logAction(
        actionType: 'task_created',
        description: 'Created new task: $title',
        contextData: {
          'task_id': taskId,
          'title': title,
          'type': type,
          'priority': priority,
          'assignee_id': assigneeId,
          'confidentiality_level': confidentialityLevel,
          'estimated_hours': estimatedHours,
        },
        userId: currentUser.id,
      );

      return APIResponse<String>(
        success: true,
        message: 'Task created successfully',
        data: taskId,
        statusCode: 201,
        metadata: {
          'task_id': taskId,
          'confidentiality_level': confidentialityLevel,
          'assignee_id': assigneeId,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'task_creation_error',
        description: 'Error creating task: ${e.toString()}',
        contextData: {
          'title': title,
          'type': type,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<String>(
        success: false,
        message: 'Failed to create task: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Update task with confidentiality and permission checks
  /// PUT /api/tasks/{id}
  Future<APIResponse<void>> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? assigneeId,
    int? actualHours,
    String? confidentialityLevel,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<void>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Get existing task
      final existingTask = await _taskService.getTask(taskId);
      if (existingTask == null) {
        return APIResponse<void>(
          success: false,
          message: 'Task not found',
          statusCode: 404,
        );
      }

      final currentUser = _authService.currentUser!;

      // Check access to task
      if (!_canAccessTask(existingTask, currentUser)) {
        return APIResponse<void>(
          success: false,
          message: 'Access denied: insufficient clearance for this task',
          statusCode: 403,
        );
      }

      // Check update permissions
      final canAssignTasks = _authService.hasPermission('assign_tasks');
      final canEditAssignedTasks =
          _authService.hasPermission('edit_assigned_tasks');
      final isAssignee = existingTask.assigneeId == currentUser.id;

      if (!canAssignTasks && !canEditAssignedTasks && !isAssignee) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions to update this task',
          statusCode: 403,
        );
      }

      // Validate assignment changes
      if (assigneeId != null && !canAssignTasks) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions to reassign tasks',
          statusCode: 403,
        );
      }

      // Validate confidentiality changes
      if (confidentialityLevel != null &&
          !_canSetConfidentialityLevel(confidentialityLevel, currentUser)) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions to change confidentiality level',
          statusCode: 403,
        );
      }

      // Update task
      final updatedTask = existingTask.copyWith(
        title: title?.trim(),
        description: description?.trim(),
        status: status?.toLowerCase(),
        priority: priority?.toLowerCase(),
        assigneeId: assigneeId,
        actualHours: actualHours,
        completedAt:
            status?.toLowerCase() == 'completed' ? DateTime.now() : null,
      );

      await _taskService.updateTask(updatedTask);

      // Broadcast task update via WebSocket
      await _websocketService.broadcastTaskUpdate(
        taskId: taskId,
        update: {
          'action': 'updated',
          'changes': {
            'title': title,
            'description': description,
            'status': status,
            'priority': priority,
            'assignee_id': assigneeId,
            'actual_hours': actualHours,
          },
          'task': _taskToMap(updatedTask),
        },
        targetUsers: _getAuthorizedUsers(
          confidentialityLevel ?? _getTaskConfidentiality(existingTask),
          currentUser,
        ),
      );

      await _auditService.logAction(
        actionType: 'task_updated',
        description: 'Updated task: ${existingTask.title}',
        contextData: {
          'task_id': taskId,
          'changes': {
            'title': title,
            'description': description,
            'status': status,
            'priority': priority,
            'assignee_id': assigneeId,
            'actual_hours': actualHours,
            'confidentiality_level': confidentialityLevel,
          },
        },
        userId: currentUser.id,
      );

      return APIResponse<void>(
        success: true,
        message: 'Task updated successfully',
        statusCode: 200,
        metadata: {
          'updated_fields': {
            'title': title != null,
            'description': description != null,
            'status': status != null,
            'priority': priority != null,
            'assignee_id': assigneeId != null,
            'actual_hours': actualHours != null,
            'confidentiality_level': confidentialityLevel != null,
          },
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'task_update_error',
        description: 'Error updating task: ${e.toString()}',
        contextData: {
          'task_id': taskId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<void>(
        success: false,
        message: 'Failed to update task: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Delete task with confidentiality checks
  /// DELETE /api/tasks/{id}
  Future<APIResponse<void>> deleteTask(String taskId) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<void>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('assign_tasks')) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions to delete tasks',
          statusCode: 403,
        );
      }

      // Get task to delete
      final task = await _taskService.getTask(taskId);
      if (task == null) {
        return APIResponse<void>(
          success: false,
          message: 'Task not found',
          statusCode: 404,
        );
      }

      final currentUser = _authService.currentUser!;

      // Check access to task
      if (!_canAccessTask(task, currentUser)) {
        return APIResponse<void>(
          success: false,
          message: 'Access denied: insufficient clearance for this task',
          statusCode: 403,
        );
      }

      // Delete task
      await _taskService.deleteTask(taskId);

      // Broadcast task deletion via WebSocket
      await _websocketService.broadcastTaskUpdate(
        taskId: taskId,
        update: {
          'action': 'deleted',
          'task_id': taskId,
          'task_title': task.title,
        },
        targetUsers: _getAuthorizedUsers(
          _getTaskConfidentiality(task),
          currentUser,
        ),
      );

      await _auditService.logAction(
        actionType: 'task_deleted',
        description: 'Deleted task: ${task.title}',
        contextData: {
          'task_id': taskId,
          'task_title': task.title,
          'task_type': task.type,
          'confidentiality_level': _getTaskConfidentiality(task),
        },
        userId: currentUser.id,
      );

      return APIResponse<void>(
        success: true,
        message: 'Task deleted successfully',
        statusCode: 200,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'task_deletion_error',
        description: 'Error deleting task: ${e.toString()}',
        contextData: {
          'task_id': taskId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<void>(
        success: false,
        message: 'Failed to delete task: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Add commit to task
  /// POST /api/tasks/{id}/commits
  Future<APIResponse<void>> addCommitToTask({
    required String taskId,
    required String commitHash,
    String? commitMessage,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<void>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('commit_code')) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions to link commits',
          statusCode: 403,
        );
      }

      // Get task
      final task = await _taskService.getTask(taskId);
      if (task == null) {
        return APIResponse<void>(
          success: false,
          message: 'Task not found',
          statusCode: 404,
        );
      }

      final currentUser = _authService.currentUser!;

      // Check access to task
      if (!_canAccessTask(task, currentUser)) {
        return APIResponse<void>(
          success: false,
          message: 'Access denied: insufficient clearance for this task',
          statusCode: 403,
        );
      }

      // Add commit to task
      await _taskService.addRelatedCommit(taskId, commitHash);

      // Broadcast commit link via WebSocket
      await _websocketService.broadcastTaskUpdate(
        taskId: taskId,
        update: {
          'action': 'commit_linked',
          'commit_hash': commitHash,
          'commit_message': commitMessage,
          'task_id': taskId,
        },
        targetUsers: _getAuthorizedUsers(
          _getTaskConfidentiality(task),
          currentUser,
        ),
      );

      await _auditService.logAction(
        actionType: 'task_commit_linked',
        description: 'Linked commit to task: ${task.title}',
        contextData: {
          'task_id': taskId,
          'commit_hash': commitHash,
          'commit_message': commitMessage,
        },
        userId: currentUser.id,
      );

      return APIResponse<void>(
        success: true,
        message: 'Commit linked to task successfully',
        statusCode: 200,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'task_commit_link_error',
        description: 'Error linking commit to task: ${e.toString()}',
        contextData: {
          'task_id': taskId,
          'commit_hash': commitHash,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<void>(
        success: false,
        message: 'Failed to link commit to task: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Get overdue tasks
  /// GET /api/tasks/overdue
  Future<APIResponse<List<Task>>> getOverdueTasks() async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<List<Task>>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      final currentUser = _authService.currentUser!;
      final overdueTasks = await _taskService.getOverdueTasks();

      // Apply confidentiality filtering
      final filteredTasks =
          _filterTasksByConfidentiality(overdueTasks, currentUser);

      await _auditService.logAction(
        actionType: 'overdue_tasks_retrieved',
        description: 'Retrieved overdue tasks',
        contextData: {
          'total_overdue': overdueTasks.length,
          'accessible_overdue': filteredTasks.length,
        },
        userId: currentUser.id,
      );

      return APIResponse<List<Task>>(
        success: true,
        message: 'Overdue tasks retrieved successfully',
        data: filteredTasks,
        statusCode: 200,
        metadata: {
          'total_count': filteredTasks.length,
          'all_overdue_count': overdueTasks.length,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'overdue_tasks_error',
        description: 'Error retrieving overdue tasks: ${e.toString()}',
        contextData: {'error': e.toString()},
        userId: _authService.currentUser?.id,
      );

      return APIResponse<List<Task>>(
        success: false,
        message: 'Failed to retrieve overdue tasks: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Helper methods for confidentiality controls

  /// Filter tasks based on user's confidentiality clearance
  List<Task> _filterTasksByConfidentiality(List<Task> tasks, User user) {
    return tasks.where((task) => _canAccessTask(task, user)).toList();
  }

  /// Check if user can access a task based on confidentiality
  bool _canAccessTask(Task task, User user) {
    final confidentialityLevel = _getTaskConfidentiality(task);

    switch (confidentialityLevel) {
      case 'public':
        return true;
      case 'team':
        return user.role != 'viewer';
      case 'restricted':
        return user.role == 'admin' || user.role == 'lead_developer';
      case 'confidential':
        return user.role == 'admin';
      default:
        return false;
    }
  }

  /// Check if user can set a confidentiality level
  bool _canSetConfidentialityLevel(String level, User user) {
    switch (level) {
      case 'public':
      case 'team':
        return user.role != 'viewer';
      case 'restricted':
        return user.role == 'admin' || user.role == 'lead_developer';
      case 'confidential':
        return user.role == 'admin';
      default:
        return false;
    }
  }

  /// Get task confidentiality level (mock implementation)
  String _getTaskConfidentiality(Task task) {
    // In a real implementation, this would be stored in the task
    // For now, determine based on task type
    switch (task.type) {
      case 'security':
        return 'confidential';
      case 'deployment':
        return 'restricted';
      case 'feature':
      case 'bug':
        return 'team';
      default:
        return 'public';
    }
  }

  /// Get users authorized for a confidentiality level
  List<String> _getAuthorizedUsers(
      String confidentialityLevel, User currentUser) {
    // In a real implementation, this would query the user database
    // For now, return mock authorized user IDs based on level
    switch (confidentialityLevel) {
      case 'public':
        return ['all']; // All users
      case 'team':
        return ['team']; // All team members (non-viewers)
      case 'restricted':
        return ['admin', 'lead_developer'];
      case 'confidential':
        return ['admin'];
      default:
        return [currentUser.id];
    }
  }

  /// Convert task to map for WebSocket broadcasting
  Map<String, dynamic> _taskToMap(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'type': task.type,
      'priority': task.priority,
      'status': task.status,
      'assignee_id': task.assigneeId,
      'estimated_hours': task.estimatedHours,
      'actual_hours': task.actualHours,
      'created_at': task.createdAt.toIso8601String(),
      'due_date': task.dueDate.toIso8601String(),
      'completed_at': task.completedAt?.toIso8601String(),
    };
  }

  /// Validate task input
  String? _validateTaskInput({
    required String title,
    required String description,
    required String type,
    required String priority,
    required String assigneeId,
    required int estimatedHours,
    required String confidentialityLevel,
  }) {
    // Title validation
    if (title.trim().isEmpty) {
      return 'Title is required';
    }
    if (title.trim().length < 3) {
      return 'Title must be at least 3 characters long';
    }

    // Description validation
    if (description.trim().isEmpty) {
      return 'Description is required';
    }
    if (description.trim().length < 10) {
      return 'Description must be at least 10 characters long';
    }

    // Type validation
    const validTypes = ['feature', 'bug', 'security', 'deployment', 'research'];
    if (!validTypes.contains(type.toLowerCase())) {
      return 'Invalid task type specified';
    }

    // Priority validation
    const validPriorities = ['low', 'medium', 'high', 'critical'];
    if (!validPriorities.contains(priority.toLowerCase())) {
      return 'Invalid priority specified';
    }

    // Assignee validation
    if (assigneeId.trim().isEmpty) {
      return 'Assignee is required';
    }

    // Estimated hours validation
    if (estimatedHours <= 0) {
      return 'Estimated hours must be greater than 0';
    }
    if (estimatedHours > 1000) {
      return 'Estimated hours cannot exceed 1000';
    }

    // Confidentiality level validation
    const validLevels = ['public', 'team', 'restricted', 'confidential'];
    if (!validLevels.contains(confidentialityLevel.toLowerCase())) {
      return 'Invalid confidentiality level specified';
    }

    return null;
  }
}

/// Generic API response wrapper
class APIResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int statusCode;
  final Map<String, dynamic>? metadata;

  APIResponse({
    required this.success,
    required this.message,
    this.data,
    required this.statusCode,
    this.metadata,
  });
}

// User model is imported from auth_service.dart
