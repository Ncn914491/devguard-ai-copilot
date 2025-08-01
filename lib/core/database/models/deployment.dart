class Deployment {
  final String id;
  final String environment; // 'development', 'staging', 'production'
  final String version;
  final String status; // 'pending', 'in_progress', 'success', 'failed', 'rolled_back'
  final String? pipelineConfig;
  final String? snapshotId;
  final String deployedBy;
  final DateTime deployedAt;
  final bool rollbackAvailable;
  final String? healthChecks;
  final String? logs;

  Deployment({
    required this.id,
    required this.environment,
    required this.version,
    required this.status,
    this.pipelineConfig,
    this.snapshotId,
    required this.deployedBy,
    required this.deployedAt,
    required this.rollbackAvailable,
    this.healthChecks,
    this.logs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'environment': environment,
      'version': version,
      'status': status,
      'pipeline_config': pipelineConfig,
      'snapshot_id': snapshotId,
      'deployed_by': deployedBy,
      'deployed_at': deployedAt.millisecondsSinceEpoch,
      'rollback_available': rollbackAvailable ? 1 : 0,
      'health_checks': healthChecks,
      'logs': logs,
    };
  }

  factory Deployment.fromMap(Map<String, dynamic> map) {
    return Deployment(
      id: map['id'] ?? '',
      environment: map['environment'] ?? '',
      version: map['version'] ?? '',
      status: map['status'] ?? '',
      pipelineConfig: map['pipeline_config'],
      snapshotId: map['snapshot_id'],
      deployedBy: map['deployed_by'] ?? '',
      deployedAt: DateTime.fromMillisecondsSinceEpoch(map['deployed_at'] ?? 0),
      rollbackAvailable: (map['rollback_available'] ?? 1) == 1,
      healthChecks: map['health_checks'],
      logs: map['logs'],
    );
  }

  Deployment copyWith({
    String? id,
    String? environment,
    String? version,
    String? status,
    String? pipelineConfig,
    String? snapshotId,
    String? deployedBy,
    DateTime? deployedAt,
    bool? rollbackAvailable,
    String? healthChecks,
    String? logs,
  }) {
    return Deployment(
      id: id ?? this.id,
      environment: environment ?? this.environment,
      version: version ?? this.version,
      status: status ?? this.status,
      pipelineConfig: pipelineConfig ?? this.pipelineConfig,
      snapshotId: snapshotId ?? this.snapshotId,
      deployedBy: deployedBy ?? this.deployedBy,
      deployedAt: deployedAt ?? this.deployedAt,
      rollbackAvailable: rollbackAvailable ?? this.rollbackAvailable,
      healthChecks: healthChecks ?? this.healthChecks,
      logs: logs ?? this.logs,
    );
  }
}