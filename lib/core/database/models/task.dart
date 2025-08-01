class Task {
  final String id;
  final String title;
  final String description;
  final String type; // 'feature', 'bug', 'security', 'deployment'
  final String priority; // 'low', 'medium', 'high', 'critical'
  final String status; // 'pending', 'in_progress', 'review', 'completed', 'blocked'
  final String assigneeId;
  final int estimatedHours;
  final int actualHours;
  final List<String> relatedCommits;
  final List<String> dependencies;
  final DateTime createdAt;
  final DateTime dueDate;
  final DateTime? completedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.status,
    required this.assigneeId,
    required this.estimatedHours,
    required this.actualHours,
    required this.relatedCommits,
    required this.dependencies,
    required this.createdAt,
    required this.dueDate,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'priority': priority,
      'status': status,
      'assignee_id': assigneeId,
      'estimated_hours': estimatedHours,
      'actual_hours': actualHours,
      'related_commits': relatedCommits.join(','),
      'dependencies': dependencies.join(','),
      'created_at': createdAt.millisecondsSinceEpoch,
      'due_date': dueDate.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? '',
      priority: map['priority'] ?? '',
      status: map['status'] ?? '',
      assigneeId: map['assignee_id'] ?? '',
      estimatedHours: map['estimated_hours']?.toInt() ?? 0,
      actualHours: map['actual_hours']?.toInt() ?? 0,
      relatedCommits: map['related_commits'] != null && map['related_commits'].isNotEmpty 
          ? map['related_commits'].split(',').where((String s) => s.isNotEmpty).toList() 
          : <String>[],
      dependencies: map['dependencies'] != null && map['dependencies'].isNotEmpty 
          ? map['dependencies'].split(',').where((String s) => s.isNotEmpty).toList() 
          : <String>[],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['due_date'] ?? 0),
      completedAt: map['completed_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at']) 
          : null,
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    String? priority,
    String? status,
    String? assigneeId,
    int? estimatedHours,
    int? actualHours,
    List<String>? relatedCommits,
    List<String>? dependencies,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? completedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assigneeId: assigneeId ?? this.assigneeId,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      relatedCommits: relatedCommits ?? this.relatedCommits,
      dependencies: dependencies ?? this.dependencies,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}