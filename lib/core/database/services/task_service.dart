import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../database_service.dart';
import '../models/task.dart';
import '../models/task_status_history.dart';
import '../models/task_access_log.dart';
import 'audit_log_service.dart';

class TaskService {
  static final TaskService _instance = TaskService._internal();
  static TaskService get instance => _instance;
  TaskService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;

  Future<Database> get _db async => await DatabaseService.instance.database;

  /// Create a new task
  /// Satisfies Requirements: 5.4 (Git issues/tasks sync and progress tracking)
  Future<String> createTask(Task task) async {
    final db = await _db;
    final id = task.id.isEmpty ? _uuid.v4() : task.id;

    final taskWithId = task.copyWith(
      id: id,
      createdAt: DateTime.now(),
    );

    await db.insert('tasks', taskWithId.toMap());

    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'task_created',
      description: 'Created task: ${task.title} (${task.type})',
      contextData: {
        'task_id': id,
        'type': task.type,
        'priority': task.priority,
        'assignee_id': task.assigneeId,
      },
    );

    return id;
  }

  /// Get task by ID
  /// Satisfies Requirements: 5.4 (Task progress tracking)
  Future<Task?> getTask(String id) async {
    final db = await _db;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  /// Get all tasks
  /// Satisfies Requirements: 5.1 (Team dashboard with active tasks)
  Future<List<Task>> getAllTasks() async {
    final db = await _db;
    final maps = await db.query('tasks', orderBy: 'created_at DESC');
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Get tasks by assignee
  /// Satisfies Requirements: 5.1 (Team dashboard showing member's active tasks)
  Future<List<Task>> getTasksByAssignee(String assigneeId) async {
    final db = await _db;
    final maps = await db.query(
      'tasks',
      where: 'assignee_id = ?',
      whereArgs: [assigneeId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Get tasks by status
  /// Satisfies Requirements: 5.4 (Progress tracking with status updates)
  Future<List<Task>> getTasksByStatus(String status) async {
    final db = await _db;
    final maps = await db.query(
      'tasks',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Get tasks by priority
  /// Satisfies Requirements: 5.2 (Task assignment based on priority)
  Future<List<Task>> getTasksByPriority(String priority) async {
    final db = await _db;
    final maps = await db.query(
      'tasks',
      where: 'priority = ?',
      whereArgs: [priority],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Update task
  /// Satisfies Requirements: 5.4 (Git issues/tasks sync with automatic updates)
  Future<void> updateTask(Task task) async {
    final db = await _db;

    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );

    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'task_updated',
      description: 'Updated task: ${task.title} - Status: ${task.status}',
      contextData: {
        'task_id': task.id,
        'status': task.status,
        'assignee_id': task.assigneeId,
      },
    );
  }

  /// Update task status
  /// Satisfies Requirements: 5.4 (Automatic progress tracking)
  Future<void> updateTaskStatus(String taskId, String status,
      {String? userId}) async {
    final task = await getTask(taskId);
    if (task == null) return;

    final updatedTask = task.copyWith(
      status: status,
      completedAt: status == 'completed' ? DateTime.now() : null,
    );

    await updateTask(updatedTask);

    // Log status change with user context (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'task_status_updated',
      description: 'Task status changed: ${task.title} -> $status',
      contextData: {
        'task_id': taskId,
        'old_status': task.status,
        'new_status': status
      },
      userId: userId,
    );
  }

  /// Add related commit to task
  /// Satisfies Requirements: 5.4 (Git issues sync with commit tracking)
  Future<void> addRelatedCommit(String taskId, String commitHash) async {
    final task = await getTask(taskId);
    if (task == null) return;

    final updatedCommits = [...task.relatedCommits, commitHash];
    final updatedTask = task.copyWith(relatedCommits: updatedCommits);

    await updateTask(updatedTask);

    // Log commit association (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'task_commit_linked',
      description: 'Linked commit $commitHash to task: ${task.title}',
      contextData: {'task_id': taskId, 'commit_hash': commitHash},
    );
  }

  /// Update task assignment
  /// Satisfies Requirements: 5.2, 5.3 (Assignment updates with human approval)
  Future<void> updateTaskAssignment(String taskId, String newAssigneeId,
      {String? approvedBy}) async {
    final task = await getTask(taskId);
    if (task == null) return;

    final oldAssigneeId = task.assigneeId;
    final updatedTask = task.copyWith(assigneeId: newAssigneeId);

    await updateTask(updatedTask);

    // Log assignment change with approval tracking (Requirement 9.4)
    await _auditService.logAction(
      actionType: 'task_reassigned',
      description: 'Reassigned task: ${task.title}',
      contextData: {
        'task_id': taskId,
        'old_assignee': oldAssigneeId,
        'new_assignee': newAssigneeId,
      },
      requiresApproval: true,
      approvedBy: approvedBy,
    );
  }

  /// Delete task
  /// Satisfies Requirements: 9.1 (Audit logging for all actions)
  Future<void> deleteTask(String id) async {
    final db = await _db;
    final task = await getTask(id);

    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'task_deleted',
      description: 'Deleted task: ${task?.title ?? id}',
      contextData: {'task_id': id},
    );
  }

  /// Get overdue tasks
  /// Satisfies Requirements: 5.1 (Team dashboard with task status visibility)
  Future<List<Task>> getOverdueTasks() async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      'tasks',
      where: 'due_date < ? AND status NOT IN (?, ?)',
      whereArgs: [now, 'completed', 'blocked'],
      orderBy: 'due_date ASC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Get tasks by type
  /// Satisfies Requirements: 3.5, 4.5 (Security and system task categorization)
  Future<List<Task>> getTasksByType(String type) async {
    final db = await _db;
    final maps = await db.query(
      'tasks',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }
}
