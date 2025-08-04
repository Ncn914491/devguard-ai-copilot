import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../database_service.dart';
import '../models/task.dart';
import '../models/task_status_history.dart';
import '../models/task_access_log.dart';
import 'audit_log_service.dart';

/// Enhanced Task Service with confidentiality controls and comprehensive audit logging
/// Satisfies Requirements: 5.1, 5.2, 5.3, 5.4, 5.5 (Task management with confidentiality)
class EnhancedTaskService {
  static final EnhancedTaskService _instance = EnhancedTaskService._internal();
  static EnhancedTaskService get instance => _instance;
  EnhancedTaskService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;

  Future<Database> get _db async => await DatabaseService.instance.database;

  /// Create task with confidentiality controls and audit logging
  /// Satisfies Requirements: 5.1, 5.2 (Task creation with role-based assignment)
  Future<String> createTaskWithConfidentiality({
    required Task task,
    required String userId,
    required String userRole,
    String? ipAddress,
    String? userAgent,
  }) async {
    final db = await _db;
    final taskId = task.id.isEmpty ? _uuid.v4() : task.id;

    final taskWithId = task.copyWith(
      id: taskId,
      createdAt: DateTime.now(),
    );

    // Check if user can create tasks with this confidentiality level
    if (!_canSetConfidentialityLevel(task.confidentialityLevel, userRole)) {
      await _logTaskAccess(
        taskId: taskId,
        userId: userId,
        actionType: 'create',
        accessGranted: false,
        confidentialityLevel: task.confidentialityLevel,
        userRole: userRole,
        ipAddress: ipAddress,
        userAgent: userAgent,
        details:
            'Insufficient permissions to create task with confidentiality level: ${task.confidentialityLevel}',
      );
      throw Exception(
          'Insufficient permissions to create task with confidentiality level: ${task.confidentialityLevel}');
    }

    await db.insert('tasks', taskWithId.toMap());

    // Log successful task creation
    await _logTaskAccess(
      taskId: taskId,
      userId: userId,
      actionType: 'create',
      accessGranted: true,
      confidentialityLevel: task.confidentialityLevel,
      userRole: userRole,
      ipAddress: ipAddress,
      userAgent: userAgent,
      details: 'Task created: ${task.title}',
    );

    await _auditService.logAction(
      actionType: 'task_created_enhanced',
      description: 'Created task with confidentiality controls: ${task.title}',
      contextData: {
        'task_id': taskId,
        'title': task.title,
        'type': task.type,
        'priority': task.priority,
        'confidentiality_level': task.confidentialityLevel,
        'assignee_id': task.assigneeId,
        'reporter_id': task.reporterId,
      },
      userId: userId,
    );

    return taskId;
  }

  /// Get tasks with confidentiality filtering
  /// Satisfies Requirements: 5.2, 5.3 (Role-based visibility controls)
  Future<List<Task>> getAuthorizedTasks({
    required String userId,
    required String userRole,
    String? assigneeId,
    String? status,
    String? priority,
    String? type,
    String? confidentialityLevel,
    String? ipAddress,
    String? userAgent,
  }) async {
    final db = await _db;

    // Build query based on filters
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (assigneeId != null) {
      whereClause += 'assignee_id = ?';
      whereArgs.add(assigneeId);
    }

    if (status != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'status = ?';
      whereArgs.add(status);
    }

    if (priority != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'priority = ?';
      whereArgs.add(priority);
    }

    if (type != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'type = ?';
      whereArgs.add(type);
    }

    if (confidentialityLevel != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'confidentiality_level = ?';
      whereArgs.add(confidentialityLevel);
    }

    final maps = await db.query(
      'tasks',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );

    final allTasks = maps.map((map) => Task.fromMap(map)).toList();

    // Filter tasks based on user's confidentiality clearance
    final authorizedTasks = <Task>[];

    for (final task in allTasks) {
      final canAccess = await _checkTaskAccess(
        task: task,
        userId: userId,
        userRole: userRole,
        actionType: 'view',
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      if (canAccess) {
        authorizedTasks.add(task);
      }
    }

    // Log the retrieval operation
    await _auditService.logAction(
      actionType: 'tasks_retrieved_filtered',
      description: 'Retrieved tasks with confidentiality filtering',
      contextData: {
        'total_tasks': allTasks.length,
        'authorized_tasks': authorizedTasks.length,
        'filters': {
          'assignee_id': assigneeId,
          'status': status,
          'priority': priority,
          'type': type,
          'confidentiality_level': confidentialityLevel,
        },
      },
      userId: userId,
    );

    return authorizedTasks;
  }

  /// Get single task with confidentiality check
  /// Satisfies Requirements: 5.2, 5.3 (Access control enforcement)
  Future<Task?> getAuthorizedTask({
    required String taskId,
    required String userId,
    required String userRole,
    String? ipAddress,
    String? userAgent,
  }) async {
    final db = await _db;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    );

    if (maps.isEmpty) {
      await _logTaskAccess(
        taskId: taskId,
        userId: userId,
        actionType: 'view',
        accessGranted: false,
        confidentialityLevel: 'unknown',
        userRole: userRole,
        ipAddress: ipAddress,
        userAgent: userAgent,
        details: 'Task not found',
      );
      return null;
    }

    final task = Task.fromMap(maps.first);

    final canAccess = await _checkTaskAccess(
      task: task,
      userId: userId,
      userRole: userRole,
      actionType: 'view',
      ipAddress: ipAddress,
      userAgent: userAgent,
    );

    if (!canAccess) {
      return null;
    }

    return task;
  }

  /// Update task with confidentiality and permission checks
  /// Satisfies Requirements: 5.3, 5.4 (Status tracking with access control)
  Future<void> updateTaskWithConfidentiality({
    required Task updatedTask,
    required String userId,
    required String userRole,
    String? ipAddress,
    String? userAgent,
  }) async {
    final db = await _db;

    // Get existing task to check permissions
    final existingTask = await getAuthorizedTask(
      taskId: updatedTask.id,
      userId: userId,
      userRole: userRole,
      ipAddress: ipAddress,
      userAgent: userAgent,
    );

    if (existingTask == null) {
      throw Exception('Task not found or access denied');
    }

    // Check if user can update this task
    final canUpdate = await _checkTaskAccess(
      task: existingTask,
      userId: userId,
      userRole: userRole,
      actionType: 'update',
      ipAddress: ipAddress,
      userAgent: userAgent,
    );

    if (!canUpdate) {
      throw Exception('Insufficient permissions to update this task');
    }

    // Check confidentiality level changes
    if (updatedTask.confidentialityLevel != existingTask.confidentialityLevel) {
      if (!_canSetConfidentialityLevel(
          updatedTask.confidentialityLevel, userRole)) {
        await _logTaskAccess(
          taskId: updatedTask.id,
          userId: userId,
          actionType: 'update',
          accessGranted: false,
          confidentialityLevel: updatedTask.confidentialityLevel,
          userRole: userRole,
          ipAddress: ipAddress,
          userAgent: userAgent,
          details: 'Insufficient permissions to change confidentiality level',
        );
        throw Exception(
            'Insufficient permissions to change confidentiality level');
      }
    }

    // Record status change if status changed
    if (updatedTask.status != existingTask.status) {
      await _recordStatusChange(
        taskId: updatedTask.id,
        oldStatus: existingTask.status,
        newStatus: updatedTask.status,
        changedBy: userId,
      );
    }

    await db.update(
      'tasks',
      updatedTask.toMap(),
      where: 'id = ?',
      whereArgs: [updatedTask.id],
    );

    // Log successful update
    await _logTaskAccess(
      taskId: updatedTask.id,
      userId: userId,
      actionType: 'update',
      accessGranted: true,
      confidentialityLevel: updatedTask.confidentialityLevel,
      userRole: userRole,
      ipAddress: ipAddress,
      userAgent: userAgent,
      details: 'Task updated successfully',
    );

    await _auditService.logAction(
      actionType: 'task_updated_enhanced',
      description:
          'Updated task with confidentiality controls: ${updatedTask.title}',
      contextData: {
        'task_id': updatedTask.id,
        'changes': _getTaskChanges(existingTask, updatedTask),
      },
      userId: userId,
    );
  }

  /// Delete task with confidentiality checks
  /// Satisfies Requirements: 5.4 (Audit logging for all operations)
  Future<void> deleteTaskWithConfidentiality({
    required String taskId,
    required String userId,
    required String userRole,
    String? ipAddress,
    String? userAgent,
  }) async {
    final db = await _db;

    // Get existing task to check permissions
    final existingTask = await getAuthorizedTask(
      taskId: taskId,
      userId: userId,
      userRole: userRole,
      ipAddress: ipAddress,
      userAgent: userAgent,
    );

    if (existingTask == null) {
      throw Exception('Task not found or access denied');
    }

    // Check if user can delete this task (typically admin or lead developer only)
    if (!_canDeleteTask(userRole)) {
      await _logTaskAccess(
        taskId: taskId,
        userId: userId,
        actionType: 'delete',
        accessGranted: false,
        confidentialityLevel: existingTask.confidentialityLevel,
        userRole: userRole,
        ipAddress: ipAddress,
        userAgent: userAgent,
        details: 'Insufficient permissions to delete task',
      );
      throw Exception('Insufficient permissions to delete task');
    }

    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    );

    // Log successful deletion
    await _logTaskAccess(
      taskId: taskId,
      userId: userId,
      actionType: 'delete',
      accessGranted: true,
      confidentialityLevel: existingTask.confidentialityLevel,
      userRole: userRole,
      ipAddress: ipAddress,
      userAgent: userAgent,
      details: 'Task deleted successfully',
    );

    await _auditService.logAction(
      actionType: 'task_deleted_enhanced',
      description:
          'Deleted task with confidentiality controls: ${existingTask.title}',
      contextData: {
        'task_id': taskId,
        'task_title': existingTask.title,
        'confidentiality_level': existingTask.confidentialityLevel,
      },
      userId: userId,
    );
  }

  /// Get task status history
  /// Satisfies Requirements: 5.3, 5.4 (Progress monitoring with audit trail)
  Future<List<TaskStatusHistory>> getTaskStatusHistory(String taskId) async {
    final db = await _db;
    final maps = await db.query(
      'task_status_history',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'changed_at DESC',
    );
    return maps.map((map) => TaskStatusHistory.fromMap(map)).toList();
  }

  /// Get task access logs
  /// Satisfies Requirements: 5.4, 5.5 (Comprehensive audit logging)
  Future<List<TaskAccessLog>> getTaskAccessLogs({
    String? taskId,
    String? userId,
    String? actionType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _db;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (taskId != null) {
      whereClause += 'task_id = ?';
      whereArgs.add(taskId);
    }

    if (userId != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'user_id = ?';
      whereArgs.add(userId);
    }

    if (actionType != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'action_type = ?';
      whereArgs.add(actionType);
    }

    if (startDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final maps = await db.query(
      'task_access_logs',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => TaskAccessLog.fromMap(map)).toList();
  }

  /// Private helper methods

  /// Check if user can access a task and log the attempt
  Future<bool> _checkTaskAccess({
    required Task task,
    required String userId,
    required String userRole,
    required String actionType,
    String? ipAddress,
    String? userAgent,
  }) async {
    final canAccess =
        _canAccessTaskByConfidentiality(task.confidentialityLevel, userRole) ||
            _isAuthorizedUser(task, userId) ||
            _hasAuthorizedRole(task, userRole);

    await _logTaskAccess(
      taskId: task.id,
      userId: userId,
      actionType: actionType,
      accessGranted: canAccess,
      confidentialityLevel: task.confidentialityLevel,
      userRole: userRole,
      ipAddress: ipAddress,
      userAgent: userAgent,
      details: canAccess
          ? 'Access granted'
          : 'Access denied - insufficient clearance',
    );

    return canAccess;
  }

  /// Log task access attempt
  Future<void> _logTaskAccess({
    required String taskId,
    required String userId,
    required String actionType,
    required bool accessGranted,
    required String confidentialityLevel,
    required String userRole,
    String? ipAddress,
    String? userAgent,
    String? details,
  }) async {
    final db = await _db;
    final accessLog = TaskAccessLog(
      id: _uuid.v4(),
      taskId: taskId,
      userId: userId,
      actionType: actionType,
      accessGranted: accessGranted,
      confidentialityLevel: confidentialityLevel,
      userRole: userRole,
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      userAgent: userAgent,
      details: details,
    );

    await db.insert('task_access_logs', accessLog.toMap());
  }

  /// Record task status change
  Future<void> _recordStatusChange({
    required String taskId,
    required String oldStatus,
    required String newStatus,
    required String changedBy,
    String? notes,
  }) async {
    final db = await _db;
    final statusHistory = TaskStatusHistory(
      id: _uuid.v4(),
      taskId: taskId,
      oldStatus: oldStatus,
      newStatus: newStatus,
      changedBy: changedBy,
      changedAt: DateTime.now(),
      notes: notes,
    );

    await db.insert('task_status_history', statusHistory.toMap());
  }

  /// Check if user can access task based on confidentiality level
  bool _canAccessTaskByConfidentiality(
      String confidentialityLevel, String userRole) {
    switch (confidentialityLevel.toLowerCase()) {
      case 'public':
        return true;
      case 'team':
        return userRole != 'viewer';
      case 'restricted':
        return userRole == 'admin' || userRole == 'lead_developer';
      case 'confidential':
        return userRole == 'admin';
      default:
        return false;
    }
  }

  /// Check if user is explicitly authorized for the task
  bool _isAuthorizedUser(Task task, String userId) {
    return task.authorizedUsers.contains(userId);
  }

  /// Check if user's role is explicitly authorized for the task
  bool _hasAuthorizedRole(Task task, String userRole) {
    return task.authorizedRoles.contains(userRole);
  }

  /// Check if user can set a confidentiality level
  bool _canSetConfidentialityLevel(String level, String userRole) {
    switch (level.toLowerCase()) {
      case 'public':
      case 'team':
        return userRole != 'viewer';
      case 'restricted':
        return userRole == 'admin' || userRole == 'lead_developer';
      case 'confidential':
        return userRole == 'admin';
      default:
        return false;
    }
  }

  /// Check if user can delete tasks
  bool _canDeleteTask(String userRole) {
    return userRole == 'admin' || userRole == 'lead_developer';
  }

  /// Get changes between two task versions
  Map<String, dynamic> _getTaskChanges(Task oldTask, Task newTask) {
    final changes = <String, dynamic>{};

    if (oldTask.title != newTask.title) {
      changes['title'] = {'old': oldTask.title, 'new': newTask.title};
    }
    if (oldTask.description != newTask.description) {
      changes['description'] = {
        'old': oldTask.description,
        'new': newTask.description
      };
    }
    if (oldTask.status != newTask.status) {
      changes['status'] = {'old': oldTask.status, 'new': newTask.status};
    }
    if (oldTask.priority != newTask.priority) {
      changes['priority'] = {'old': oldTask.priority, 'new': newTask.priority};
    }
    if (oldTask.assigneeId != newTask.assigneeId) {
      changes['assignee_id'] = {
        'old': oldTask.assigneeId,
        'new': newTask.assigneeId
      };
    }
    if (oldTask.confidentialityLevel != newTask.confidentialityLevel) {
      changes['confidentiality_level'] = {
        'old': oldTask.confidentialityLevel,
        'new': newTask.confidentialityLevel
      };
    }

    return changes;
  }
}
