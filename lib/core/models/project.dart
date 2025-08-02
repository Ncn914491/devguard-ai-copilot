/// Project model for managing development projects
class Project {
  final String id;
  final String name;
  final String description;
  final String adminId;
  final String adminEmail;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> memberIds;
  final ProjectSettings settings;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.adminId,
    required this.adminEmail,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.memberIds,
    required this.settings,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      adminId: json['admin_id'],
      adminEmail: json['admin_email'],
      status: ProjectStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
      ),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      memberIds: List<String>.from(json['member_ids'] ?? []),
      settings: ProjectSettings.fromJson(json['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'admin_id': adminId,
      'admin_email': adminEmail,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'member_ids': memberIds,
      'settings': settings.toJson(),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? adminId,
    String? adminEmail,
    ProjectStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? memberIds,
    ProjectSettings? settings,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      adminId: adminId ?? this.adminId,
      adminEmail: adminEmail ?? this.adminEmail,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberIds: memberIds ?? this.memberIds,
      settings: settings ?? this.settings,
    );
  }
}

enum ProjectStatus {
  active,
  inactive,
  archived,
}

/// Project settings and configuration
class ProjectSettings {
  final bool allowJoinRequests;
  final bool requireApprovalForJoining;
  final List<String> allowedRoles;
  final Map<String, dynamic> gitSettings;
  final Map<String, dynamic> deploymentSettings;
  final Map<String, dynamic> securitySettings;

  ProjectSettings({
    required this.allowJoinRequests,
    required this.requireApprovalForJoining,
    required this.allowedRoles,
    required this.gitSettings,
    required this.deploymentSettings,
    required this.securitySettings,
  });

  factory ProjectSettings.fromJson(Map<String, dynamic> json) {
    return ProjectSettings(
      allowJoinRequests: json['allow_join_requests'] ?? true,
      requireApprovalForJoining: json['require_approval_for_joining'] ?? true,
      allowedRoles: List<String>.from(json['allowed_roles'] ?? ['developer', 'lead_developer', 'viewer']),
      gitSettings: Map<String, dynamic>.from(json['git_settings'] ?? {}),
      deploymentSettings: Map<String, dynamic>.from(json['deployment_settings'] ?? {}),
      securitySettings: Map<String, dynamic>.from(json['security_settings'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allow_join_requests': allowJoinRequests,
      'require_approval_for_joining': requireApprovalForJoining,
      'allowed_roles': allowedRoles,
      'git_settings': gitSettings,
      'deployment_settings': deploymentSettings,
      'security_settings': securitySettings,
    };
  }

  ProjectSettings copyWith({
    bool? allowJoinRequests,
    bool? requireApprovalForJoining,
    List<String>? allowedRoles,
    Map<String, dynamic>? gitSettings,
    Map<String, dynamic>? deploymentSettings,
    Map<String, dynamic>? securitySettings,
  }) {
    return ProjectSettings(
      allowJoinRequests: allowJoinRequests ?? this.allowJoinRequests,
      requireApprovalForJoining: requireApprovalForJoining ?? this.requireApprovalForJoining,
      allowedRoles: allowedRoles ?? this.allowedRoles,
      gitSettings: gitSettings ?? this.gitSettings,
      deploymentSettings: deploymentSettings ?? this.deploymentSettings,
      securitySettings: securitySettings ?? this.securitySettings,
    );
  }

  static ProjectSettings defaultSettings() {
    return ProjectSettings(
      allowJoinRequests: true,
      requireApprovalForJoining: true,
      allowedRoles: ['developer', 'lead_developer', 'viewer'],
      gitSettings: {
        'default_branch': 'main',
        'require_pull_requests': true,
        'require_code_review': true,
      },
      deploymentSettings: {
        'auto_deploy_enabled': false,
        'require_approval': true,
        'environments': ['development', 'staging', 'production'],
      },
      securitySettings: {
        'enable_monitoring': true,
        'alert_threshold': 'medium',
        'auto_rollback_enabled': false,
      },
    );
  }
}