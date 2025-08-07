import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/models/task.dart';
import '../supabase_service.dart';
import '../supabase_error_handler.dart';
import 'supabase_base_service.dart';

/// Supabase implementation of task service
/// Replaces SQLite queries with supabase.from('tasks') operations
/// Requirements: 1.2, 1.4, 3.3 - Task management with confidentiality filtering
class SupabaseTaskService extends SupabaseBaseService<Task> {
  static final SupabaseTaskService _instance = SupabaseTaskService._internal();
  static SupabaseTaskService get instance => _instance;
  SupabaseTaskService._internal();

  @override
  String get tableName => 'tasks';

  @override
  Task fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? '',
      priority: map['priority'] ?? '',
      status: map['status'] ?? '',
      assigneeId: map['assignee_id'] ?? '',
      reporterId: map['reporter_id'] ?? '',
      estimatedHours: map['estimated_hours']?.toInt() ?? 0,
      actualHours: map['actual_hours']?.toInt() ?? 0,
      relatedCommits: _parseStringList(map['related_commits']),
      relatedPullRequests: _parseStringList(map['related_pull_requests']),
      dependencies: _parseStringList(map['dependencies']),
      blockedBy: _parseStringList(map['blocked_by']),
      createdAt: _parseDateTime(map['created_at']),
      dueDate: _parseDateTime(map['due_date']),
      completedAt: map['completed_at'] != null
          ? _parseDateTime(map['completed_at'])
          : null,
      confidentialityLevel: map['confidentiality_level'] ?? 'team',
      authorizedUsers: _parseStringList(map['authorized_users']),
      authorizedRoles: _parseStringList(map['authorized_roles']),
    );
  }

  @override
  Map<String, dynamic> toMap(Task item) {
    return {
      'id': item.id,
      'title': item.title,
      'description': item.description,
      'type': item.type,
      'priority': item.priority,
      'status': item.status,
      'assignee_id': item.assigneeId,
      'reporter_id': item.reporterId,
      'estimated_hours': item.estimatedHours,
      'actual_hours': item.actualHours,
      'related_commits': item.relatedCommits,
      'related_pull_requests': item.relatedPullRequests,
      'dependencies': item.dependencies,
      'blocked_by': item.blockedBy,
      'created_at': item.createdAt.toIso8601String(),
      'due_date': item.dueDate.toIso8601String(),
      'completed_at': item.completedAt?.toIso8601String(),
      'confidentiality_level': item.confidentialityLevel,
      'authorized_users': item.authorizedUsers,
      'authorized_roles': item.authorizedRoles,
    };
  }

  @override
  void validateData(Map<String, dynamic> data) {
    // Validate required fields
    if (data['title'] == null || data['title'].toString().trim().isEmpty) {
      throw AppError.validation('Task title is required');
    }

    if (data['description'] == null ||
        data['description'].toString().trim().isEmpty) {
      throw AppError.validation('Task description is required');
    }

    if (data['type'] == null || data['type'].toString().trim().isEmpty) {
      throw AppError.validation('Task type is required');
    }

    if (data['priority'] == null ||
        data['priority'].toString().trim().isEmpty) {
      throw AppError.validation('Task priority is required');
    }

    if (data['status'] == null || data['status'].toString().trim().isEmpty) {
      throw AppError.validation('Task status is required');
    }

    if (data['due_date'] == null) {
      throw AppError.validation('Task due date is required');
    }

    // Validate type
    const validTypes = ['feature', 'bug', 'security', 'deployment', 'research'];
    if (!validTypes.contains(data['type'])) {
      throw AppError.validation(
          'Invalid type. Must be one of: ${validTypes.join(', ')}');
    }

    // Validate priority
    const validPriorities = ['low', 'medium', 'high', 'critical'];
    if (!validPriorities.contains(data['priority'])) {
      throw AppError.validation(
          'Invalid priority. Must be one of: ${validPriorities.join(', ')}');
    }

    // Validate status
    const validStatuses = [
      'pending',
      'in_progress',
      'review',
      'testing',
      'completed',
      'blocked'
    ];
    if (!validStatuses.contains(data['status'])) {
      throw AppError.validation(
          'Invalid status. Must be one of: ${validStatuses.join(', ')}');
    }

    // Validate confidentiality level
    const validLevels = ['public', 'team', 'restricted', 'confidential'];
    final confidentialityLevel = data['confidentiality_level'] ?? 'team';
    if (!validLevels.contains(confidentialityLevel)) {
      throw AppError.validation(
          'Invalid confidentiality level. Must be one of: ${validLevels.join(', ')}');
    }

    // Validate hours
    if (data['estimated_hours'] != null) {
      final hours = data['estimated_hours'];
      if (hours is! int || hours < 0) {
        throw AppError.validation(
            'Estimated hours must be a non-negative integer');
      }
    }

    if (data['actual_hours'] != null) {
      final hours = data['actual_hours'];
      if (hours is! int || hours < 0) {
        throw AppError.validation(
            'Actual hours must be a non-negative integer');
      }
    }
  }

  /// Create a new task
  /// Satisfies Requirements: 3.3 (Task data model with confidentiality)
  Future<String> createTask(Task task) async {
    try {
      return await create(task);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get task by ID with authorization check
  /// Satisfies Requirements: 3.3 (Confidentiality-level filtering)
  Future<Task?> getTask(String id, {String? userId, String? userRole}) async {
    try {
      final task = await getById(id);
      if (task == null) return null;

      // Check authorization
      if (!_isAuthorizedToView(task, userId, userRole)) {
        throw AppError.authorization(
            'You do not have permission to view this task');
      }

      return task;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get all tasks with authorization filtering
  /// Satisfies Requirements: 3.3 (Authorization checks)
  Future<List<Task>> getAllTasks({String? userId, String? userRole}) async {
    try {
      final allTasks = await getAll(orderBy: 'created_at', ascending: false);

      // Filter based on authorization
      return allTasks
          .where((task) => _isAuthorizedToView(task, userId, userRole))
          .toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get tasks by assignee with authorization
  /// Satisfies Requirements: 3.3 (Task assignment tracking)
  Future<List<Task>> getTasksByAssignee(String assigneeId,
      {String? userId, String? userRole}) async {
    try {
      final tasks = await getWhere(
        column: 'assignee_id',
        value: assigneeId,
        orderBy: 'created_at',
        ascending: false,
      );

      // Filter based on authorization
      return tasks
          .where((task) => _isAuthorizedToView(task, userId, userRole))
          .toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get tasks by status with authorization
  /// Satisfies Requirements: 3.3 (Status-based filtering)
  Future<List<Task>> getTasksByStatus(String status,
      {String? userId, String? userRole}) async {
    try {
      final tasks = await getWhere(
        column: 'status',
        value: status,
        orderBy: 'created_at',
        ascending: false,
      );

      // Filter based on authorization
      return tasks
          .where((task) => _isAuthorizedToView(task, userId, userRole))
          .toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get tasks by priority with authorization
  Future<List<Task>> getTasksByPriority(String priority,
      {String? userId, String? userRole}) async {
    try {
      final tasks = await getWhere(
        column: 'priority',
        value: priority,
        orderBy: 'created_at',
        ascending: false,
      );

      // Filter based on authorization
      return tasks
          .where((task) => _isAuthorizedToView(task, userId, userRole))
          .toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get tasks by type with authorization
  Future<List<Task>> getTasksByType(String type,
      {String? userId, String? userRole}) async {
    try {
      final tasks = await getWhere(
        column: 'type',
        value: type,
        orderBy: 'created_at',
        ascending: false,
      );

      // Filter based on authorization
      return tasks
          .where((task) => _isAuthorizedToView(task, userId, userRole))
          .toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update task with authorization check
  /// Satisfies Requirements: 3.3 (Task updates with authorization)
  Future<void> updateTask(Task task, {String? userId, String? userRole}) async {
    try {
      // Check if task exists and user is authorized
      final existing = await getById(task.id);
      if (existing == null) {
        throw AppError.notFound('Task not found');
      }

      if (!_isAuthorizedToModify(existing, userId, userRole)) {
        throw AppError.authorization(
            'You do not have permission to modify this task');
      }

      await update(task.id, task);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update task status
  /// Satisfies Requirements: 3.3 (Status tracking)
  Future<void> updateTaskStatus(String taskId, String status,
      {String? userId, String? userRole}) async {
    try {
      final task = await getById(taskId);
      if (task == null) {
        throw AppError.notFound('Task not found');
      }

      if (!_isAuthorizedToModify(task, userId, userRole)) {
        throw AppError.authorization(
            'You do not have permission to modify this task');
      }

      final updatedTask = task.copyWith(
        status: status,
        completedAt: status == 'completed' ? DateTime.now() : null,
      );

      await update(taskId, updatedTask);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Add related commit to task
  /// Satisfies Requirements: 3.3 (Git integration)
  Future<void> addRelatedCommit(String taskId, String commitHash,
      {String? userId, String? userRole}) async {
    try {
      final task = await getById(taskId);
      if (task == null) {
        throw AppError.notFound('Task not found');
      }

      if (!_isAuthorizedToModify(task, userId, userRole)) {
        throw AppError.authorization(
            'You do not have permission to modify this task');
      }

      final updatedCommits = [...task.relatedCommits];
      if (!updatedCommits.contains(commitHash)) {
        updatedCommits.add(commitHash);
      }

      final updatedTask = task.copyWith(relatedCommits: updatedCommits);
      await update(taskId, updatedTask);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update task assignment
  /// Satisfies Requirements: 3.3 (Assignment management)
  Future<void> updateTaskAssignment(String taskId, String newAssigneeId,
      {String? userId, String? userRole}) async {
    try {
      final task = await getById(taskId);
      if (task == null) {
        throw AppError.notFound('Task not found');
      }

      if (!_isAuthorizedToModify(task, userId, userRole)) {
        throw AppError.authorization(
            'You do not have permission to modify this task');
      }

      final updatedTask = task.copyWith(assigneeId: newAssigneeId);
      await update(taskId, updatedTask);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Delete task with authorization check
  /// Satisfies Requirements: 3.3 (Task management)
  Future<void> deleteTask(String id, {String? userId, String? userRole}) async {
    try {
      final task = await getById(id);
      if (task == null) {
        throw AppError.notFound('Task not found');
      }

      if (!_isAuthorizedToModify(task, userId, userRole)) {
        throw AppError.authorization(
            'You do not have permission to delete this task');
      }

      await delete(id);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get overdue tasks with authorization
  Future<List<Task>> getOverdueTasks({String? userId, String? userRole}) async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .lt('due_date', now)
            .not('status', 'in', ['completed', 'blocked']).order('due_date',
                ascending: true),
      );

      final tasks = response.map((item) => fromMap(item)).toList();

      // Filter based on authorization
      return tasks
          .where((task) => _isAuthorizedToView(task, userId, userRole))
          .toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get tasks by confidentiality level (admin only)
  Future<List<Task>> getTasksByConfidentialityLevel(String level,
      {String? userRole}) async {
    try {
      if (userRole != 'admin') {
        throw AppError.authorization(
            'Only administrators can filter by confidentiality level');
      }

      return await getWhere(
        column: 'confidentiality_level',
        value: level,
        orderBy: 'created_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch all tasks for real-time updates (with authorization)
  /// Satisfies Requirements: 3.3 (Real-time task updates)
  Stream<List<Task>> watchAllTasks({String? userId, String? userRole}) {
    try {
      return watchAll(orderBy: 'created_at', ascending: false).map((tasks) =>
          tasks
              .where((task) => _isAuthorizedToView(task, userId, userRole))
              .toList());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch tasks by assignee for real-time updates
  Stream<List<Task>> watchTasksByAssignee(String assigneeId,
      {String? userId, String? userRole}) {
    try {
      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('assignee_id', assigneeId)
          .order('created_at', ascending: false)
          .map((data) {
            final tasks = data
                .map((item) => fromMap(item as Map<String, dynamic>))
                .toList();
            return tasks
                .where((task) => _isAuthorizedToView(task, userId, userRole))
                .toList();
          });
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch a specific task for real-time updates
  Stream<Task?> watchTask(String id, {String? userId, String? userRole}) {
    try {
      return watchById(id).map((task) {
        if (task == null) return null;
        return _isAuthorizedToView(task, userId, userRole) ? task : null;
      });
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get task statistics with authorization
  Future<Map<String, dynamic>> getTaskStatistics(
      {String? userId, String? userRole}) async {
    try {
      final allTasks = await getAllTasks(userId: userId, userRole: userRole);

      final stats = <String, dynamic>{
        'total': allTasks.length,
        'pending': allTasks.where((t) => t.status == 'pending').length,
        'in_progress': allTasks.where((t) => t.status == 'in_progress').length,
        'review': allTasks.where((t) => t.status == 'review').length,
        'testing': allTasks.where((t) => t.status == 'testing').length,
        'completed': allTasks.where((t) => t.status == 'completed').length,
        'blocked': allTasks.where((t) => t.status == 'blocked').length,
        'overdue': allTasks
            .where((t) =>
                t.dueDate.isBefore(DateTime.now()) &&
                !['completed', 'blocked'].contains(t.status))
            .length,
        'typeDistribution': <String, int>{},
        'priorityDistribution': <String, int>{},
        'averageEstimatedHours': allTasks.isNotEmpty
            ? allTasks.map((t) => t.estimatedHours).reduce((a, b) => a + b) /
                allTasks.length
            : 0.0,
        'averageActualHours': allTasks.isNotEmpty
            ? allTasks.map((t) => t.actualHours).reduce((a, b) => a + b) /
                allTasks.length
            : 0.0,
      };

      // Calculate type distribution
      for (final task in allTasks) {
        final typeStats = stats['typeDistribution'] as Map<String, int>;
        typeStats[task.type] = (typeStats[task.type] ?? 0) + 1;
      }

      // Calculate priority distribution
      for (final task in allTasks) {
        final priorityStats = stats['priorityDistribution'] as Map<String, int>;
        priorityStats[task.priority] = (priorityStats[task.priority] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Check if user is authorized to view a task
  /// Satisfies Requirements: 3.3 (Confidentiality-level filtering)
  bool _isAuthorizedToView(Task task, String? userId, String? userRole) {
    // Admin can view all tasks
    if (userRole == 'admin') return true;

    // Public tasks can be viewed by anyone
    if (task.confidentialityLevel == 'public') return true;

    // Team tasks can be viewed by team members
    if (task.confidentialityLevel == 'team' &&
        ['lead_developer', 'developer'].contains(userRole)) {
      return true;
    }

    // Check if user is explicitly authorized
    if (userId != null && task.authorizedUsers.contains(userId)) {
      return true;
    }

    // Check if user's role is explicitly authorized
    if (userRole != null && task.authorizedRoles.contains(userRole)) {
      return true;
    }

    // Check if user is the assignee or reporter
    if (userId != null &&
        (task.assigneeId == userId || task.reporterId == userId)) {
      return true;
    }

    return false;
  }

  /// Check if user is authorized to modify a task
  bool _isAuthorizedToModify(Task task, String? userId, String? userRole) {
    // Admin can modify all tasks
    if (userRole == 'admin') return true;

    // Lead developers can modify team tasks
    if (userRole == 'lead_developer' &&
        ['public', 'team'].contains(task.confidentialityLevel)) {
      return true;
    }

    // Users can modify their own tasks
    if (userId != null &&
        (task.assigneeId == userId || task.reporterId == userId)) {
      return true;
    }

    // Check if user is explicitly authorized
    if (userId != null && task.authorizedUsers.contains(userId)) {
      return true;
    }

    return false;
  }

  /// Helper method to parse string lists from database
  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    if (value is String && value.isNotEmpty) {
      return value.split(',').where((s) => s.trim().isNotEmpty).toList();
    }
    return [];
  }

  /// Helper method to parse DateTime from database
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
