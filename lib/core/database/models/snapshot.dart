class Snapshot {
  final String id;
  final String environment;
  final String gitCommit;
  final String? databaseBackup;
  final List<String> configFiles;
  final DateTime createdAt;
  final bool verified;

  Snapshot({
    required this.id,
    required this.environment,
    required this.gitCommit,
    this.databaseBackup,
    required this.configFiles,
    required this.createdAt,
    required this.verified,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'environment': environment,
      'git_commit': gitCommit,
      'database_backup': databaseBackup,
      'config_files': configFiles.join(','),
      'created_at': createdAt.millisecondsSinceEpoch,
      'verified': verified ? 1 : 0,
    };
  }

  factory Snapshot.fromMap(Map<String, dynamic> map) {
    return Snapshot(
      id: map['id'] ?? '',
      environment: map['environment'] ?? '',
      gitCommit: map['git_commit'] ?? '',
      databaseBackup: map['database_backup'],
      configFiles: map['config_files'] != null && map['config_files'].isNotEmpty 
          ? map['config_files'].split(',').where((String s) => s.isNotEmpty).toList() 
          : <String>[],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      verified: (map['verified'] ?? 0) == 1,
    );
  }

  Snapshot copyWith({
    String? id,
    String? environment,
    String? gitCommit,
    String? databaseBackup,
    List<String>? configFiles,
    DateTime? createdAt,
    bool? verified,
  }) {
    return Snapshot(
      id: id ?? this.id,
      environment: environment ?? this.environment,
      gitCommit: gitCommit ?? this.gitCommit,
      databaseBackup: databaseBackup ?? this.databaseBackup,
      configFiles: configFiles ?? this.configFiles,
      createdAt: createdAt ?? this.createdAt,
      verified: verified ?? this.verified,
    );
  }
}