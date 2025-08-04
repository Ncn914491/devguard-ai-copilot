/// Task Access Log model for audit logging
/// Satisfies Requirements: 5.4, 5.5 (Task audit logging for all operations and access attempts)
class TaskAccessLog {
  final String id;
  final String taskId;
  final String userId;
  final String
      actionType; // 'view', 'create', 'update', 'delete', 'assign', 'status_change', 'access_denied'
  final bool accessGranted;
  final String confidentialityLevel;
  final String userRole;
  final DateTime timestamp;
  final String? ipAddress;
  final String? userAgent;
  final String? details; // JSON string with additional context

  TaskAccessLog({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.actionType,
    required this.accessGranted,
    required this.confidentialityLevel,
    required this.userRole,
    required this.timestamp,
    this.ipAddress,
    this.userAgent,
    this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'user_id': userId,
      'action_type': actionType,
      'access_granted': accessGranted ? 1 : 0,
      'confidentiality_level': confidentialityLevel,
      'user_role': userRole,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'details': details,
    };
  }

  factory TaskAccessLog.fromMap(Map<String, dynamic> map) {
    return TaskAccessLog(
      id: map['id'] ?? '',
      taskId: map['task_id'] ?? '',
      userId: map['user_id'] ?? '',
      actionType: map['action_type'] ?? '',
      accessGranted: (map['access_granted'] ?? 1) == 1,
      confidentialityLevel: map['confidentiality_level'] ?? '',
      userRole: map['user_role'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      ipAddress: map['ip_address'],
      userAgent: map['user_agent'],
      details: map['details'],
    );
  }

  TaskAccessLog copyWith({
    String? id,
    String? taskId,
    String? userId,
    String? actionType,
    bool? accessGranted,
    String? confidentialityLevel,
    String? userRole,
    DateTime? timestamp,
    String? ipAddress,
    String? userAgent,
    String? details,
  }) {
    return TaskAccessLog(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      actionType: actionType ?? this.actionType,
      accessGranted: accessGranted ?? this.accessGranted,
      confidentialityLevel: confidentialityLevel ?? this.confidentialityLevel,
      userRole: userRole ?? this.userRole,
      timestamp: timestamp ?? this.timestamp,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      details: details ?? this.details,
    );
  }
}
