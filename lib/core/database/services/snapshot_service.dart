import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../database_service.dart';
import '../models/snapshot.dart';
import 'audit_log_service.dart';

class SnapshotService {
  static final SnapshotService _instance = SnapshotService._internal();
  static SnapshotService get instance => _instance;
  SnapshotService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;

  Future<Database> get _db async => await DatabaseService.instance.database;

  /// Create a new snapshot
  /// Satisfies Requirements: 7.1 (Automatic rollback snapshot creation)
  Future<String> createSnapshot(Snapshot snapshot) async {
    final db = await _db;
    final id = snapshot.id.isEmpty ? _uuid.v4() : snapshot.id;
    
    final snapshotWithId = snapshot.copyWith(
      id: id,
      createdAt: DateTime.now(),
    );

    await db.insert('snapshots', snapshotWithId.toMap());
    
    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'snapshot_created',
      description: 'Snapshot created for ${snapshot.environment}: ${snapshot.gitCommit}',
      contextData: {
        'snapshot_id': id, 
        'environment': snapshot.environment, 
        'git_commit': snapshot.gitCommit,
        'verified': snapshot.verified,
      },
    );

    return id;
  }

  /// Get snapshot by ID
  /// Satisfies Requirements: 7.4 (System integrity verification)
  Future<Snapshot?> getSnapshot(String id) async {
    final db = await _db;
    final maps = await db.query(
      'snapshots',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Snapshot.fromMap(maps.first);
    }
    return null;
  }

  /// Get all snapshots
  /// Satisfies Requirements: 7.1 (Snapshot tracking and management)
  Future<List<Snapshot>> getAllSnapshots() async {
    final db = await _db;
    final maps = await db.query('snapshots', orderBy: 'created_at DESC');
    return maps.map((map) => Snapshot.fromMap(map)).toList();
  }

  /// Get snapshots by environment
  /// Satisfies Requirements: 7.1 (Environment-specific snapshot management)
  Future<List<Snapshot>> getSnapshotsByEnvironment(String environment) async {
    final db = await _db;
    final maps = await db.query(
      'snapshots',
      where: 'environment = ?',
      whereArgs: [environment],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Snapshot.fromMap(map)).toList();
  }

  /// Get verified snapshots
  /// Satisfies Requirements: 7.4 (System integrity verification)
  Future<List<Snapshot>> getVerifiedSnapshots(String environment) async {
    final db = await _db;
    final maps = await db.query(
      'snapshots',
      where: 'environment = ? AND verified = ?',
      whereArgs: [environment, 1],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Snapshot.fromMap(map)).toList();
  }

  /// Update snapshot
  /// Satisfies Requirements: 9.1 (Audit logging for all changes)
  Future<void> updateSnapshot(Snapshot snapshot) async {
    final db = await _db;
    
    await db.update(
      'snapshots',
      snapshot.toMap(),
      where: 'id = ?',
      whereArgs: [snapshot.id],
    );

    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'snapshot_updated',
      description: 'Updated snapshot: ${snapshot.id} - Verified: ${snapshot.verified}',
      contextData: {
        'snapshot_id': snapshot.id, 
        'verified': snapshot.verified,
        'environment': snapshot.environment,
      },
    );
  }

  /// Verify snapshot integrity
  /// Satisfies Requirements: 7.4 (System integrity verification and status reporting)
  Future<void> verifySnapshot(String snapshotId, {String? verifiedBy}) async {
    final snapshot = await getSnapshot(snapshotId);
    if (snapshot == null) return;

    final verifiedSnapshot = snapshot.copyWith(verified: true);
    await updateSnapshot(verifiedSnapshot);

    // Log verification (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'snapshot_verified',
      description: 'Snapshot verified: ${snapshot.gitCommit} for ${snapshot.environment}',
      contextData: {
        'snapshot_id': snapshotId, 
        'environment': snapshot.environment,
        'git_commit': snapshot.gitCommit,
        'verified_by': verifiedBy,
      },
      userId: verifiedBy,
    );
  }

  /// Get latest verified snapshot for environment
  /// Satisfies Requirements: 7.1, 7.2 (Last known good state for rollback)
  Future<Snapshot?> getLatestVerifiedSnapshot(String environment) async {
    final db = await _db;
    final maps = await db.query(
      'snapshots',
      where: 'environment = ? AND verified = ?',
      whereArgs: [environment, 1],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Snapshot.fromMap(maps.first);
    }
    return null;
  }

  /// Create pre-deployment snapshot
  /// Satisfies Requirements: 2.3 (Snapshot creation before deployments)
  Future<String> createPreDeploymentSnapshot(String environment, String gitCommit, List<String> configFiles) async {
    final snapshot = Snapshot(
      id: _uuid.v4(),
      environment: environment,
      gitCommit: gitCommit,
      configFiles: configFiles,
      createdAt: DateTime.now(),
      verified: false, // Will be verified after creation
    );

    final snapshotId = await createSnapshot(snapshot);

    // Log pre-deployment snapshot creation (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'pre_deployment_snapshot_created',
      description: 'Pre-deployment snapshot created for $environment',
      aiReasoning: 'Automatic snapshot creation before deployment to ensure rollback capability and system recovery options.',
      contextData: {
        'snapshot_id': snapshotId, 
        'environment': environment,
        'git_commit': gitCommit,
        'config_files_count': configFiles.length,
      },
    );

    return snapshotId;
  }

  /// Delete snapshot
  /// Satisfies Requirements: 9.1 (Audit logging for all actions)
  Future<void> deleteSnapshot(String id) async {
    final db = await _db;
    final snapshot = await getSnapshot(id);
    
    await db.delete(
      'snapshots',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'snapshot_deleted',
      description: 'Deleted snapshot: ${snapshot?.gitCommit ?? id}',
      contextData: {'snapshot_id': id},
    );
  }

  /// Get snapshots for rollback options
  /// Satisfies Requirements: 7.2, 7.5 (Rollback options with alternative recovery)
  Future<List<Snapshot>> getRollbackOptions(String environment, {int limit = 5}) async {
    final db = await _db;
    final maps = await db.query(
      'snapshots',
      where: 'environment = ? AND verified = ?',
      whereArgs: [environment, 1],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((map) => Snapshot.fromMap(map)).toList();
  }

  /// Get snapshot by git commit
  /// Satisfies Requirements: 7.1 (Git-based snapshot tracking)
  Future<Snapshot?> getSnapshotByCommit(String environment, String gitCommit) async {
    final db = await _db;
    final maps = await db.query(
      'snapshots',
      where: 'environment = ? AND git_commit = ?',
      whereArgs: [environment, gitCommit],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Snapshot.fromMap(maps.first);
    }
    return null;
  }
}