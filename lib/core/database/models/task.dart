class Task {
  final String id;
  final String title;
  final String description;
  final String type; // 'feature', 'bug', 'security', 'deployment', 'research'
  final String priority; // 'low', 'medium', 'high', 'critical'
  final String
      status; // 'pending', 'in_progress', 'review', 'testing', 'completed', 'blocked'
  final String assigneeId;
  final String reporterId; // User who created the task
  final int estimatedHours;
  final int actualHours;
  final List<String> relatedCommits;
  final List<String> relatedPullRequests;
  final List<String> dependencies;
  final List<String> blockedBy;
  final DateTime createdAt;
  final DateTime dueDate;
  final DateTime? completedAt;

  // Confidentiality controls
  final String
      confidentialityLevel; // 'public', 'team', 'restricted', 'confidential'
  final List<String> authorizedUsers; // User IDs with explicit access
  final List<String> authorizedRoles; // Roles with access

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.status,
    required this.assigneeId,
    required this.reporterId,
    required this.estimatedHours,
    required this.actualHours,
    required this.relatedCommits,
    required this.relatedPullRequests,
    required this.dependencies,
    required this.blockedBy,
    required this.createdAt,
    required this.dueDate,
    this.completedAt,
    this.confidentialityLevel = 'team',
    this.authorizedUsers = const [],
    this.authorizedRoles = const [],
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
      'reporter_id': reporterId,
      'estimated_hours': estimatedHours,
      'actual_hours': actualHours,
      'related_commits': relatedCommits.join(','),
      'related_pull_requests': relatedPullRequests.join(','),
      'dependencies': dependencies.join(','),
      'blocked_by': blockedBy.join(','),
      'created_at': createdAt.millisecondsSinceEpoch,
      'due_date': dueDate.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'confidentiality_level': confidentialityLevel,
      'authorized_users': authorizedUsers.join(','),
      'authorized_roles': authorizedRoles.join(','),
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
      reporterId: map['reporter_id'] ?? '',
      estimatedHours: map['estimated_hours']?.toInt() ?? 0,
      actualHours: map['actual_hours']?.toInt() ?? 0,
      relatedCommits:
          map['related_commits'] != null && map['related_commits'].isNotEmpty
              ? map['related_commits']
                  .split(',')
                  .where((String s) => s.isNotEmpty)
                  .toList()
              : <String>[],
      relatedPullRequests: map['related_pull_requests'] != null &&
              map['related_pull_requests'].isNotEmpty
          ? map['related_pull_requests']
              .split(',')
              .where((String s) => s.isNotEmpty)
              .toList()
          : <String>[],
      dependencies:
          map['dependencies'] != null && map['dependencies'].isNotEmpty
              ? map['dependencies']
                  .split(',')
                  .where((String s) => s.isNotEmpty)
                  .toList()
              : <String>[],
      blockedBy: map['blocked_by'] != null && map['blocked_by'].isNotEmpty
          ? map['blocked_by']
              .split(',')
              .where((String s) => s.isNotEmpty)
              .toList()
          : <String>[],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['due_date'] ?? 0),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'])
          : null,
      confidentialityLevel: map['confidentiality_level'] ?? 'team',
      authorizedUsers:
          map['authorized_users'] != null && map['authorized_users'].isNotEmpty
              ? map['authorized_users']
                  .split(',')
                  .where((String s) => s.isNotEmpty)
                  .toList()
              : <String>[],
      authorizedRoles:
          map['authorized_roles'] != null && map['authorized_roles'].isNotEmpty
              ? map['authorized_roles']
                  .split(',')
                  .where((String s) => s.isNotEmpty)
                  .toList()
              : <String>[],
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
    String? reporterId,
    int? estimatedHours,
    int? actualHours,
    List<String>? relatedCommits,
    List<String>? relatedPullRequests,
    List<String>? dependencies,
    List<String>? blockedBy,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? completedAt,
    String? confidentialityLevel,
    List<String>? authorizedUsers,
    List<String>? authorizedRoles,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assigneeId: assigneeId ?? this.assigneeId,
      reporterId: reporterId ?? this.reporterId,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      relatedCommits: relatedCommits ?? this.relatedCommits,
      relatedPullRequests: relatedPullRequests ?? this.relatedPullRequests,
      dependencies: dependencies ?? this.dependencies,
      blockedBy: blockedBy ?? this.blockedBy,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      confidentialityLevel: confidentialityLevel ?? this.confidentialityLevel,
      authorizedUsers: authorizedUsers ?? this.authorizedUsers,
      authorizedRoles: authorizedRoles ?? this.authorizedRoles,
    );
  }
}
