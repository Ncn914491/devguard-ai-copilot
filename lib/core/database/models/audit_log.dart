class AuditLog {
  final String id;
  final String actionType;
  final String description;
  final String? aiReasoning;
  final String? contextData;
  final String? userId;
  final DateTime timestamp;
  final bool requiresApproval;
  final bool approved;
  final String? approvedBy;
  final DateTime? approvedAt;

  AuditLog({
    required this.id,
    required this.actionType,
    required this.description,
    this.aiReasoning,
    this.contextData,
    this.userId,
    required this.timestamp,
    required this.requiresApproval,
    required this.approved,
    this.approvedBy,
    this.approvedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action_type': actionType,
      'description': description,
      'ai_reasoning': aiReasoning,
      'context_data': contextData,
      'user_id': userId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'requires_approval': requiresApproval ? 1 : 0,
      'approved': approved ? 1 : 0,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.millisecondsSinceEpoch,
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] ?? '',
      actionType: map['action_type'] ?? '',
      description: map['description'] ?? '',
      aiReasoning: map['ai_reasoning'],
      contextData: map['context_data'],
      userId: map['user_id'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      requiresApproval: (map['requires_approval'] ?? 0) == 1,
      approved: (map['approved'] ?? 0) == 1,
      approvedBy: map['approved_by'],
      approvedAt: map['approved_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['approved_at']) 
          : null,
    );
  }

  AuditLog copyWith({
    String? id,
    String? actionType,
    String? description,
    String? aiReasoning,
    String? contextData,
    String? userId,
    DateTime? timestamp,
    bool? requiresApproval,
    bool? approved,
    String? approvedBy,
    DateTime? approvedAt,
  }) {
    return AuditLog(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      description: description ?? this.description,
      aiReasoning: aiReasoning ?? this.aiReasoning,
      contextData: contextData ?? this.contextData,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      approved: approved ?? this.approved,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}