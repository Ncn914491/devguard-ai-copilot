import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/models/snapshot.dart';
import '../supabase_error_handler.dart';
import 'supabase_base_service.dart';

/// Supabase implementation of snapshot service
/// Replaces SQLite queries with supabase.from('snapshots') operations
/// Requirements: 1.2, 1.4, 3.7 - Snapshot management and git commit tracking
class SupabaseSnapshotService extends SupabaseBaseService<Snapshot> {
  static final SupabaseSnapshotService _instance =
      SupabaseSnapshotService._internal();
  static SupabaseSnapshotService get instance => _instance;
  SupabaseSnapshotService._internal();

  @override
  String get tableName => 'snapshots';

  @override
  Snapshot fromMap(Map<String, dynamic> map) {
    return Snapshot(
      id: map['id'] ?? '',
      environment: map['environment'] ?? '',
      gitCommit: map['git_commit'] ?? '',
      databaseBackup: map['database_backup'],
      configFiles: _parseStringList(map['config_files']),
      createdAt: _parseDateTime(map['created_at']),
      verified: map['verified'] == true,
    );
  }

  @override
  Map<String, dynamic> toMap(Snapshot item) {
    return {
      'id': item.id,
      'environment': item.environment,
      'git_commit': item.gitCommit,
      'database_backup': item.databaseBackup,
      'config_files': item.configFiles,
      'created_at': item.createdAt.toIso8601String(),
      'verified': item.verified,
    };
  }

  @override
  void validateData(Map<String, dynamic> data) {
    // Validate required fields
    if (data['environment'] == null ||
        data['environment'].toString().trim().isEmpty) {
      throw AppError.validation('Environment is required');
    }

    if (data['git_commit'] == null ||
        data['git_commit'].toString().trim().isEmpty) {
      throw AppError.validation('Git commit is required');
    }

    if (data['created_at'] == null) {
      throw AppError.validation('Creation timestamp is required');
    }

    // Validate environment
    const validEnvironments = ['development', 'staging', 'production'];
    if (!validEnvironments.contains(data['environment'])) {
      throw AppError.validation(
          'Invalid environment. Must be one of: ${validEnvironments.join(', ')}');
    }

    // Validate git commit format (SHA-1 hash)
    final gitCommit = data['git_commit'].toString();
    if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(gitCommit)) {
      throw AppError.validation(
          'Git commit must be a valid 40-character SHA-1 hash');
    }

    // Validate config files is a list
    if (data['config_files'] != null && data['config_files'] is! List) {
      throw AppError.validation('Config files must be a list');
    }

    // Validate verified is boolean
    if (data['verified'] != null && data['verified'] is! bool) {
      throw AppError.validation('Verified must be a boolean value');
    }
  }

  /// Create a new snapshot
  /// Satisfies Requirements: 3.7 (Snapshot creation)
  Future<String> createSnapshot(Snapshot snapshot) async {
    try {
      // Check for duplicate git commit in same environment
      final existing =
          await getSnapshotByCommit(snapshot.gitCommit, snapshot.environment);
      if (existing != null) {
        throw AppError.validation(
            'A snapshot for this git commit already exists in this environment');
      }

      return await create(snapshot);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get snapshot by ID
  /// Satisfies Requirements: 3.7 (Snapshot retrieval)
  Future<Snapshot?> getSnapshot(String id) async {
    return await getById(id);
  }

  /// Get all snapshots
  /// Satisfies Requirements: 3.7 (Snapshot listing)
  Future<List<Snapshot>> getAllSnapshots() async {
    return await getAll(orderBy: 'created_at', ascending: false);
  }

  /// Get snapshots by environment
  /// Satisfies Requirements: 3.7 (Environment-based filtering)
  Future<List<Snapshot>> getSnapshotsByEnvironment(String environment) async {
    try {
      return await getWhere(
        column: 'environment',
        value: environment,
        orderBy: 'created_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get snapshot by git commit and environment
  Future<Snapshot?> getSnapshotByCommit(
      String gitCommit, String environment) async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .eq('git_commit', gitCommit)
            .eq('environment', environment)
            .limit(1),
      );

      return response.isNotEmpty ? fromMap(response.first) : null;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get verified snapshots
  Future<List<Snapshot>> getVerifiedSnapshots({String? environment}) async {
    try {
      if (environment != null) {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .eq('verified', true)
              .eq('environment', environment)
              .order('created_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      } else {
        return await getWhere(
          column: 'verified',
          value: true,
          orderBy: 'created_at',
          ascending: false,
        );
      }
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get unverified snapshots
  Future<List<Snapshot>> getUnverifiedSnapshots({String? environment}) async {
    try {
      if (environment != null) {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .eq('verified', false)
              .eq('environment', environment)
              .order('created_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      } else {
        return await getWhere(
          column: 'verified',
          value: false,
          orderBy: 'created_at',
          ascending: false,
        );
      }
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get snapshots with database backup
  Future<List<Snapshot>> getSnapshotsWithBackup({String? environment}) async {
    try {
      if (environment != null) {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .not('database_backup', 'is', null)
              .eq('environment', environment)
              .order('created_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      } else {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .not('database_backup', 'is', null)
              .order('created_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      }
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get latest snapshot for environment
  Future<Snapshot?> getLatestSnapshot(String environment) async {
    try {
      final snapshots = await getWhere(
        column: 'environment',
        value: environment,
        orderBy: 'created_at',
        ascending: false,
        limit: 1,
      );

      return snapshots.isNotEmpty ? snapshots.first : null;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get latest verified snapshot for environment
  Future<Snapshot?> getLatestVerifiedSnapshot(String environment) async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .eq('environment', environment)
            .eq('verified', true)
            .order('created_at', ascending: false)
            .limit(1),
      );

      return response.isNotEmpty ? fromMap(response.first) : null;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get recent snapshots (last N days)
  Future<List<Snapshot>> getRecentSnapshots(
      {int days = 7, String? environment}) async {
    try {
      final cutoffDate =
          DateTime.now().subtract(Duration(days: days)).toIso8601String();

      if (environment != null) {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .gte('created_at', cutoffDate)
              .eq('environment', environment)
              .order('created_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      } else {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .gte('created_at', cutoffDate)
              .order('created_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      }
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update snapshot
  /// Satisfies Requirements: 3.7 (Snapshot updates)
  Future<void> updateSnapshot(Snapshot snapshot) async {
    try {
      // Check if snapshot exists
      final existing = await getById(snapshot.id);
      if (existing == null) {
        throw AppError.notFound('Snapshot not found');
      }

      await update(snapshot.id, snapshot);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Verify snapshot
  Future<void> verifySnapshot(String snapshotId) async {
    try {
      final snapshot = await getSnapshot(snapshotId);
      if (snapshot == null) {
        throw AppError.notFound('Snapshot not found');
      }

      final updatedSnapshot = snapshot.copyWith(verified: true);
      await updateSnapshot(updatedSnapshot);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Add database backup to snapshot
  Future<void> addDatabaseBackup(String snapshotId, String backupPath) async {
    try {
      final snapshot = await getSnapshot(snapshotId);
      if (snapshot == null) {
        throw AppError.notFound('Snapshot not found');
      }

      final updatedSnapshot = snapshot.copyWith(databaseBackup: backupPath);
      await updateSnapshot(updatedSnapshot);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Add config files to snapshot
  Future<void> addConfigFiles(
      String snapshotId, List<String> configFiles) async {
    try {
      final snapshot = await getSnapshot(snapshotId);
      if (snapshot == null) {
        throw AppError.notFound('Snapshot not found');
      }

      // Merge with existing config files
      final allConfigFiles = [...snapshot.configFiles, ...configFiles];
      final uniqueConfigFiles = allConfigFiles.toSet().toList();

      final updatedSnapshot = snapshot.copyWith(configFiles: uniqueConfigFiles);
      await updateSnapshot(updatedSnapshot);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Delete snapshot
  /// Satisfies Requirements: 3.7 (Snapshot management)
  Future<void> deleteSnapshot(String id) async {
    try {
      // Check if snapshot exists
      final existing = await getById(id);
      if (existing == null) {
        throw AppError.notFound('Snapshot not found');
      }

      await delete(id);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch all snapshots for real-time updates
  /// Satisfies Requirements: 3.7 (Real-time snapshot monitoring)
  Stream<List<Snapshot>> watchAllSnapshots() {
    return watchAll(orderBy: 'created_at', ascending: false);
  }

  /// Watch snapshots by environment for real-time updates
  Stream<List<Snapshot>> watchSnapshotsByEnvironment(String environment) {
    try {
      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('environment', environment)
          .order('created_at', ascending: false)
          .map((data) => data
              .map((item) => fromMap(item as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch a specific snapshot for real-time updates
  Stream<Snapshot?> watchSnapshot(String id) {
    return watchById(id);
  }

  /// Get snapshot statistics
  Future<Map<String, dynamic>> getSnapshotStatistics() async {
    try {
      final allSnapshots = await getAllSnapshots();

      final stats = <String, dynamic>{
        'total': allSnapshots.length,
        'verified': allSnapshots.where((s) => s.verified).length,
        'unverified': allSnapshots.where((s) => !s.verified).length,
        'with_backup': allSnapshots
            .where(
                (s) => s.databaseBackup != null && s.databaseBackup!.isNotEmpty)
            .length,
        'environmentDistribution': <String, int>{},
        'averageConfigFiles': 0.0,
        'verificationRate': 0.0,
        'snapshotsPerDay': 0.0,
      };

      // Calculate environment distribution
      for (final snapshot in allSnapshots) {
        final envStats = stats['environmentDistribution'] as Map<String, int>;
        envStats[snapshot.environment] =
            (envStats[snapshot.environment] ?? 0) + 1;
      }

      // Calculate average config files per snapshot
      if (allSnapshots.isNotEmpty) {
        final totalConfigFiles = allSnapshots
            .map((s) => s.configFiles.length)
            .reduce((a, b) => a + b);
        stats['averageConfigFiles'] = totalConfigFiles / allSnapshots.length;
      }

      // Calculate verification rate
      final verifiedCount = stats['verified'] as int;
      final totalCount = stats['total'] as int;
      stats['verificationRate'] =
          totalCount > 0 ? (verifiedCount / totalCount) * 100 : 0.0;

      // Calculate snapshots per day over last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentSnapshots =
          allSnapshots.where((s) => s.createdAt.isAfter(thirtyDaysAgo)).length;
      stats['snapshotsPerDay'] = recentSnapshots / 30.0;

      return stats;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Search snapshots by git commit
  Future<List<Snapshot>> searchSnapshotsByCommit(String commitPattern) async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .ilike('git_commit', '%$commitPattern%')
            .order('created_at', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get snapshots in date range
  Future<List<Snapshot>> getSnapshotsInDateRange(
      DateTime startDate, DateTime endDate,
      {String? environment}) async {
    try {
      if (environment != null) {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .gte('created_at', startDate.toIso8601String())
              .lte('created_at', endDate.toIso8601String())
              .eq('environment', environment)
              .order('created_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      } else {
        final response = await executeQuery(
          _client
              .from(tableName)
              .select()
              .gte('created_at', startDate.toIso8601String())
              .lte('created_at', endDate.toIso8601String())
              .order('created_at', ascending: false),
        );
        return response.map((item) => fromMap(item)).toList();
      }
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Compare snapshots (get differences)
  Future<Map<String, dynamic>> compareSnapshots(
      String snapshot1Id, String snapshot2Id) async {
    try {
      final snapshot1 = await getSnapshot(snapshot1Id);
      final snapshot2 = await getSnapshot(snapshot2Id);

      if (snapshot1 == null || snapshot2 == null) {
        throw AppError.notFound('One or both snapshots not found');
      }

      return {
        'snapshot1': {
          'id': snapshot1.id,
          'environment': snapshot1.environment,
          'git_commit': snapshot1.gitCommit,
          'created_at': snapshot1.createdAt.toIso8601String(),
          'verified': snapshot1.verified,
          'config_files': snapshot1.configFiles,
        },
        'snapshot2': {
          'id': snapshot2.id,
          'environment': snapshot2.environment,
          'git_commit': snapshot2.gitCommit,
          'created_at': snapshot2.createdAt.toIso8601String(),
          'verified': snapshot2.verified,
          'config_files': snapshot2.configFiles,
        },
        'differences': {
          'environment_changed': snapshot1.environment != snapshot2.environment,
          'git_commit_changed': snapshot1.gitCommit != snapshot2.gitCommit,
          'verification_changed': snapshot1.verified != snapshot2.verified,
          'config_files_added': snapshot2.configFiles
              .where((f) => !snapshot1.configFiles.contains(f))
              .toList(),
          'config_files_removed': snapshot1.configFiles
              .where((f) => !snapshot2.configFiles.contains(f))
              .toList(),
          'time_difference_hours':
              snapshot2.createdAt.difference(snapshot1.createdAt).inHours,
        },
      };
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Helper method to parse string lists from database
  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    if (value is String && value.isNotEmpty) {
      return value.split(',').where((s) => s.trim().isNotEmpty).toList();
    }
    return [];
  }

  /// Helper method to parse DateTime from database
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
