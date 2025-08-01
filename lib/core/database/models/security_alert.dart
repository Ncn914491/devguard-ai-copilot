class SecurityAlert {
  final String id;
  final String type; // 'database_breach', 'system_anomaly', 'network_anomaly', 'auth_flood'
  final String severity; // 'low', 'medium', 'high', 'critical'
  final String title;
  final String description;
  final String aiExplanation;
  final String? triggerData;
  final String status; // 'new', 'investigating', 'resolved', 'false_positive'
  final String? assignedTo;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final bool rollbackSuggested;
  final String? evidence;

  SecurityAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.aiExplanation,
    this.triggerData,
    required this.status,
    this.assignedTo,
    required this.detectedAt,
    this.resolvedAt,
    required this.rollbackSuggested,
    this.evidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'severity': severity,
      'title': title,
      'description': description,
      'ai_explanation': aiExplanation,
      'trigger_data': triggerData,
      'status': status,
      'assigned_to': assignedTo,
      'detected_at': detectedAt.millisecondsSinceEpoch,
      'resolved_at': resolvedAt?.millisecondsSinceEpoch,
      'rollback_suggested': rollbackSuggested ? 1 : 0,
      'evidence': evidence,
    };
  }

  factory SecurityAlert.fromMap(Map<String, dynamic> map) {
    return SecurityAlert(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      severity: map['severity'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      aiExplanation: map['ai_explanation'] ?? '',
      triggerData: map['trigger_data'],
      status: map['status'] ?? 'new',
      assignedTo: map['assigned_to'],
      detectedAt: DateTime.fromMillisecondsSinceEpoch(map['detected_at'] ?? 0),
      resolvedAt: map['resolved_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['resolved_at']) 
          : null,
      rollbackSuggested: (map['rollback_suggested'] ?? 0) == 1,
      evidence: map['evidence'],
    );
  }

  SecurityAlert copyWith({
    String? id,
    String? type,
    String? severity,
    String? title,
    String? description,
    String? aiExplanation,
    String? triggerData,
    String? status,
    String? assignedTo,
    DateTime? detectedAt,
    DateTime? resolvedAt,
    bool? rollbackSuggested,
    String? evidence,
  }) {
    return SecurityAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      aiExplanation: aiExplanation ?? this.aiExplanation,
      triggerData: triggerData ?? this.triggerData,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      detectedAt: detectedAt ?? this.detectedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rollbackSuggested: rollbackSuggested ?? this.rollbackSuggested,
      evidence: evidence ?? this.evidence,
    );
  }
}