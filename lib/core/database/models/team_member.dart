class TeamMember {
  final String id;
  final String name;
  final String email;
  final String role; // 'developer', 'admin', 'security_reviewer'
  final String status; // 'active', 'bench', 'offline'
  final List<String> assignments;
  final List<String> expertise;
  final int workload;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.assignments,
    required this.expertise,
    required this.workload,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'status': status,
      'assignments': assignments.join(','),
      'expertise': expertise.join(','),
      'workload': workload,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      status: map['status'] ?? '',
      assignments: map['assignments'] != null && map['assignments'].isNotEmpty 
          ? map['assignments'].split(',').where((String s) => s.isNotEmpty).toList() 
          : <String>[],
      expertise: map['expertise'] != null && map['expertise'].isNotEmpty 
          ? map['expertise'].split(',').where((String s) => s.isNotEmpty).toList() 
          : <String>[],
      workload: map['workload']?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] ?? 0),
    );
  }

  TeamMember copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? status,
    List<String>? assignments,
    List<String>? expertise,
    int? workload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeamMember(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      assignments: assignments ?? this.assignments,
      expertise: expertise ?? this.expertise,
      workload: workload ?? this.workload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}