/// Task Status History model for tracking status changes
/// Satisfies Requirements: 5.3, 5.4 (Task status tracking and progress monitoring)
class TaskStatusHistory {
  final String id;
  final String taskId;
  final String oldStatus;
  final String newStatus;
  final String changedBy;
  final DateTime changedAt;
  final String? notes;

  TaskStatusHistory({
    required this.id,
    required this.taskId,
    required this.oldStatus,
    required this.newStatus,
    required this.changedBy,
    required this.changedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'old_status': oldStatus,
      'new_status': newStatus,
      'changed_by': changedBy,
      'changed_at': changedAt.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  factory TaskStatusHistory.fromMap(Map<String, dynamic> map) {
    return TaskStatusHistory(
      id: map['id'] ?? '',
      taskId: map['task_id'] ?? '',
      oldStatus: map['old_status'] ?? '',
      newStatus: map['new_status'] ?? '',
      changedBy: map['changed_by'] ?? '',
      changedAt: DateTime.fromMillisecondsSinceEpoch(map['changed_at'] ?? 0),
      notes: map['notes'],
    );
  }

  TaskStatusHistory copyWith({
    String? id,
    String? taskId,
    String? oldStatus,
    String? newStatus,
    String? changedBy,
    DateTime? changedAt,
    String? notes,
  }) {
    return TaskStatusHistory(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      oldStatus: oldStatus ?? this.oldStatus,
      newStatus: newStatus ?? this.newStatus,
      changedBy: changedBy ?? this.changedBy,
      changedAt: changedAt ?? this.changedAt,
      notes: notes ?? this.notes,
    );
  }
}
