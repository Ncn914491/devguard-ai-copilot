import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';
import 'sqlite_to_supabase_migration.dart';

/// Service for rolling back failed migrations and managing migration state
/// Provides comprehensive rollback procedures and progress tracking
class MigrationRollbackService {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final List<String> _rollbackLog = [];

  /// Get rollback log entries
  List<String> get rollbackLog => List.unmodifiable(_rollbackLog);

  /// Perform complete rollback of migration data
  Future<RollbackResult> rollbackMigration({
    MigrationResult? migrationResult,
    bool preserveBackup = true,
    bool confirmDeletion = false,
  }) async {
    final startTime = DateTime.now();
    _rollbackLog.clear();

    try {
      _log('🔄 Starting migration rollback...');
      _log('💾 Preserve backup: $preserveBackup');
      _log('⚠️  Confirm deletion: $confirmDeletion');

      if (!confirmDeletion) {
        throw Exception(
            'Rollback requires explicit confirmation. Set confirmDeletion=true to proceed.');
      }

      // Initialize Supabase service
      await _initializeService();

      // Step 1: Create backup before rollback (if preserveBackup is true)
      String? backupId;
      if (preserveBackup) {
        _log('💾 Creating backup before rollback...');
        backupId = await _createPreRollbackBackup();
      }

      // Step 2: Delete migrated data in reverse dependency order
      _log('🗑️  Deleting migrated data...');
      final deletionResult = await _deleteMigratedData(migrationResult);

      // Step 3: Reset sequences and constraints
      _log('🔄 Resetting database sequences...');
      await _resetDatabaseSequences();

      // Step 4: Verify rollback completion
      _log('✅ Verifying rollback completion...');
      final verificationResult = await _verifyRollbackCompletion();

      final duration = DateTime.now().difference(startTime);
      final success = deletionResult.success && verificationResult.success;

      if (success) {
        _log('✅ Migration rollback completed successfully');
      } else {
        _log('❌ Migration rollback completed with issues');
      }

      return RollbackResult(
        success: success,
        duration: duration,
        backupId: backupId,
        deletionResult: deletionResult,
        verificationResult: verificationResult,
        log: List.from(_rollbackLog),
      );
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      _log('❌ Migration rollback failed: $e');

      return RollbackResult(
        success: false,
        duration: duration,
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        log: List.from(_rollbackLog),
      );
    }
  }

  /// Create a backup of current Supabase data before rollback
  Future<String> _createPreRollbackBackup() async {
    final client = _supabaseService.client;
    final backupId = 'rollback_backup_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Create backup metadata
      final backupMetadata = {
        'id': backupId,
        'created_at': DateTime.now().toIso8601String(),
        'type': 'pre_rollback_backup',
        'description': 'Automatic backup created before migration rollback',
      };

      // Export current data for backup
      final backupData = await _exportCurrentSupabaseData();

      // Store backup in a safe location (could be file system or another table)
      await _storeBackup(backupId, backupData, backupMetadata);

      _log('💾 Pre-rollback backup created: $backupId');
      return backupId;
    } catch (e) {
      _log('❌ Failed to create pre-rollback backup: $e');
      rethrow;
    }
  }

  /// Export current Supabase data for backup
  Future<Map<String, List<Map<String, dynamic>>>>
      _exportCurrentSupabaseData() async {
    final client = _supabaseService.client;
    final backupData = <String, List<Map<String, dynamic>>>{};

    try {
      // Export users
      final users = await client.from('users').select();
      backupData['users'] = List<Map<String, dynamic>>.from(users);
      _log('💾 Backed up ${users.length} users');

      // Export team members
      final teamMembers = await client.from('team_members').select();
      backupData['team_members'] = List<Map<String, dynamic>>.from(teamMembers);
      _log('💾 Backed up ${teamMembers.length} team members');

      // Export tasks
      final tasks = await client.from('tasks').select();
      backupData['tasks'] = List<Map<String, dynamic>>.from(tasks);
      _log('💾 Backed up ${tasks.length} tasks');

      // Export security alerts
      final securityAlerts = await client.from('security_alerts').select();
      backupData['security_alerts'] =
          List<Map<String, dynamic>>.from(securityAlerts);
      _log('💾 Backed up ${securityAlerts.length} security alerts');

      // Export audit logs
      final auditLogs = await client.from('audit_logs').select();
      backupData['audit_logs'] = List<Map<String, dynamic>>.from(auditLogs);
      _log('💾 Backed up ${auditLogs.length} audit logs');

      // Export deployments
      final deployments = await client.from('deployments').select();
      backupData['deployments'] = List<Map<String, dynamic>>.from(deployments);
      _log('💾 Backed up ${deployments.length} deployments');

      // Export snapshots
      final snapshots = await client.from('snapshots').select();
      backupData['snapshots'] = List<Map<String, dynamic>>.from(snapshots);
      _log('💾 Backed up ${snapshots.length} snapshots');

      // Export specifications
      final specifications = await client.from('specifications').select();
      backupData['specifications'] =
          List<Map<String, dynamic>>.from(specifications);
      _log('💾 Backed up ${specifications.length} specifications');

      return backupData;
    } catch (e) {
      _log('❌ Failed to export current Supabase data: $e');
      rethrow;
    }
  }

  /// Store backup data
  Future<void> _storeBackup(
    String backupId,
    Map<String, List<Map<String, dynamic>>> backupData,
    Map<String, dynamic> metadata,
  ) async {
    try {
      // For now, store as JSON file in local directory
      // In production, this could be stored in Supabase Storage or another secure location
      final backupJson = {
        'metadata': metadata,
        'data': backupData,
      };

      final backupFile = File('migration_backups/$backupId.json');
      await backupFile.parent.create(recursive: true);
      await backupFile.writeAsString(jsonEncode(backupJson));

      _log('💾 Backup stored at: ${backupFile.path}');
    } catch (e) {
      _log('❌ Failed to store backup: $e');
      rethrow;
    }
  }

  /// Delete migrated data in reverse dependency order
  Future<DeletionResult> _deleteMigratedData(
      MigrationResult? migrationResult) async {
    final client = _supabaseService.client;
    final deletionErrors = <String>[];
    int totalDeleted = 0;

    try {
      // Delete in reverse dependency order to avoid foreign key constraint violations

      // 1. Delete specifications (no dependencies)
      try {
        final specificationsResult = await client
            .from('specifications')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000');
        _log('🗑️  Deleted specifications');
        totalDeleted += specificationsResult.count ?? 0;
      } catch (e) {
        deletionErrors.add('Failed to delete specifications: $e');
      }

      // 2. Delete snapshots (no dependencies)
      try {
        final snapshotsResult = await client
            .from('snapshots')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000');
        _log('🗑️  Deleted snapshots');
        totalDeleted += snapshotsResult.count ?? 0;
      } catch (e) {
        deletionErrors.add('Failed to delete snapshots: $e');
      }

      // 3. Delete deployments (no dependencies)
      try {
        final deploymentsResult = await client
            .from('deployments')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000');
        _log('🗑️  Deleted deployments');
        totalDeleted += deploymentsResult.count ?? 0;
      } catch (e) {
        deletionErrors.add('Failed to delete deployments: $e');
      }

      // 4. Delete audit logs (references users)
      try {
        final auditLogsResult = await client
            .from('audit_logs')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000');
        _log('🗑️  Deleted audit logs');
        totalDeleted += auditLogsResult.count ?? 0;
      } catch (e) {
        deletionErrors.add('Failed to delete audit logs: $e');
      }

      // 5. Delete security alerts (references users)
      try {
        final securityAlertsResult = await client
            .from('security_alerts')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000');
        _log('🗑️  Deleted security alerts');
        totalDeleted += securityAlertsResult.count ?? 0;
      } catch (e) {
        deletionErrors.add('Failed to delete security alerts: $e');
      }

      // 6. Delete tasks (references team_members and users)
      try {
        final tasksResult = await client
            .from('tasks')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000');
        _log('🗑️  Deleted tasks');
        totalDeleted += tasksResult.count ?? 0;
      } catch (e) {
        deletionErrors.add('Failed to delete tasks: $e');
      }

      // 7. Delete team members (references users)
      try {
        final teamMembersResult = await client
            .from('team_members')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000');
        _log('🗑️  Deleted team members');
        totalDeleted += teamMembersResult.count ?? 0;
      } catch (e) {
        deletionErrors.add('Failed to delete team members: $e');
      }

      // 8. Delete users (but preserve system users if any)
      try {
        // Delete all users except system users (if any exist)
        final usersResult = await client.from('users').delete().neq(
            'email', 'system@devguard.local'); // Preserve system user if exists
        _log('🗑️  Deleted users');
        totalDeleted += usersResult.count ?? 0;
      } catch (e) {
        deletionErrors.add('Failed to delete users: $e');
      }

      final success = deletionErrors.isEmpty;
      if (success) {
        _log(
            '✅ Data deletion completed successfully ($totalDeleted records deleted)');
      } else {
        _log('❌ Data deletion completed with ${deletionErrors.length} errors');
        for (final error in deletionErrors) {
          _log('  - $error');
        }
      }

      return DeletionResult(
        success: success,
        totalDeleted: totalDeleted,
        errors: deletionErrors,
      );
    } catch (e) {
      _log('❌ Data deletion failed: $e');
      return DeletionResult(
        success: false,
        totalDeleted: totalDeleted,
        error: e.toString(),
      );
    }
  }

  /// Reset database sequences after deletion
  Future<void> _resetDatabaseSequences() async {
    try {
      // PostgreSQL sequences are automatically managed for UUID primary keys
      // This method is here for completeness and future extensibility
      _log('✅ Database sequences reset (UUID-based, no action needed)');
    } catch (e) {
      _log('❌ Failed to reset database sequences: $e');
      rethrow;
    }
  }

  /// Verify rollback completion by checking table counts
  Future<RollbackVerificationResult> _verifyRollbackCompletion() async {
    final client = _supabaseService.client;
    final verificationErrors = <String>[];

    try {
      // Check that all tables are empty (or contain only system records)
      final tables = [
        'users',
        'team_members',
        'tasks',
        'security_alerts',
        'audit_logs',
        'deployments',
        'snapshots',
        'specifications'
      ];

      for (final table in tables) {
        final count = await client.from(table).select('count').count();
        if (count > 0) {
          // Allow system users to remain
          if (table == 'users' && count <= 1) {
            _log('✅ $table: $count records remaining (system users allowed)');
          } else {
            verificationErrors.add('$table still contains $count records');
            _log('❌ $table: $count records remaining (should be 0)');
          }
        } else {
          _log('✅ $table: empty');
        }
      }

      final success = verificationErrors.isEmpty;
      if (success) {
        _log('✅ Rollback verification passed');
      } else {
        _log('❌ Rollback verification failed');
      }

      return RollbackVerificationResult(
        success: success,
        errors: verificationErrors,
      );
    } catch (e) {
      _log('❌ Rollback verification error: $e');
      return RollbackVerificationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Restore from backup
  Future<RestoreResult> restoreFromBackup(String backupId) async {
    final startTime = DateTime.now();
    _rollbackLog.clear();

    try {
      _log('🔄 Starting restore from backup: $backupId');

      // Load backup data
      final backupData = await _loadBackup(backupId);

      // Restore data in dependency order
      await _restoreBackupData(backupData);

      final duration = DateTime.now().difference(startTime);
      _log('✅ Restore from backup completed successfully');

      return RestoreResult(
        success: true,
        duration: duration,
        backupId: backupId,
        log: List.from(_rollbackLog),
      );
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      _log('❌ Restore from backup failed: $e');

      return RestoreResult(
        success: false,
        duration: duration,
        backupId: backupId,
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        log: List.from(_rollbackLog),
      );
    }
  }

  /// Load backup data from storage
  Future<Map<String, List<Map<String, dynamic>>>> _loadBackup(
      String backupId) async {
    try {
      final backupFile = File('migration_backups/$backupId.json');
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found: $backupId');
      }

      final backupJson = await backupFile.readAsString();
      final backup = jsonDecode(backupJson) as Map<String, dynamic>;

      _log('💾 Loaded backup: $backupId');
      return Map<String, List<Map<String, dynamic>>>.from(backup['data']);
    } catch (e) {
      _log('❌ Failed to load backup: $e');
      rethrow;
    }
  }

  /// Restore backup data to Supabase
  Future<void> _restoreBackupData(
      Map<String, List<Map<String, dynamic>>> backupData) async {
    final client = _supabaseService.client;

    try {
      // Restore in dependency order

      // 1. Restore users first
      if (backupData['users']?.isNotEmpty == true) {
        await client.from('users').insert(backupData['users']!);
        _log('✅ Restored ${backupData['users']!.length} users');
      }

      // 2. Restore team members
      if (backupData['team_members']?.isNotEmpty == true) {
        await client.from('team_members').insert(backupData['team_members']!);
        _log('✅ Restored ${backupData['team_members']!.length} team members');
      }

      // 3. Restore tasks
      if (backupData['tasks']?.isNotEmpty == true) {
        await client.from('tasks').insert(backupData['tasks']!);
        _log('✅ Restored ${backupData['tasks']!.length} tasks');
      }

      // 4. Restore security alerts
      if (backupData['security_alerts']?.isNotEmpty == true) {
        await client
            .from('security_alerts')
            .insert(backupData['security_alerts']!);
        _log(
            '✅ Restored ${backupData['security_alerts']!.length} security alerts');
      }

      // 5. Restore audit logs
      if (backupData['audit_logs']?.isNotEmpty == true) {
        await client.from('audit_logs').insert(backupData['audit_logs']!);
        _log('✅ Restored ${backupData['audit_logs']!.length} audit logs');
      }

      // 6. Restore deployments
      if (backupData['deployments']?.isNotEmpty == true) {
        await client.from('deployments').insert(backupData['deployments']!);
        _log('✅ Restored ${backupData['deployments']!.length} deployments');
      }

      // 7. Restore snapshots
      if (backupData['snapshots']?.isNotEmpty == true) {
        await client.from('snapshots').insert(backupData['snapshots']!);
        _log('✅ Restored ${backupData['snapshots']!.length} snapshots');
      }

      // 8. Restore specifications
      if (backupData['specifications']?.isNotEmpty == true) {
        await client
            .from('specifications')
            .insert(backupData['specifications']!);
        _log(
            '✅ Restored ${backupData['specifications']!.length} specifications');
      }
    } catch (e) {
      _log('❌ Failed to restore backup data: $e');
      rethrow;
    }
  }

  /// Initialize Supabase service
  Future<void> _initializeService() async {
    if (!_supabaseService.isInitialized) {
      await _supabaseService.initialize();
    }
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    _rollbackLog.add(logEntry);
    if (kDebugMode) {
      debugPrint(logEntry);
    }
  }
}

/// Result of migration rollback
class RollbackResult {
  final bool success;
  final Duration duration;
  final String? backupId;
  final DeletionResult? deletionResult;
  final RollbackVerificationResult? verificationResult;
  final List<String> log;
  final String? error;
  final String? stackTrace;

  RollbackResult({
    required this.success,
    required this.duration,
    this.backupId,
    this.deletionResult,
    this.verificationResult,
    required this.log,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'durationSeconds': duration.inSeconds,
      'backupId': backupId,
      'deletionResult': deletionResult?.toJson(),
      'verificationResult': verificationResult?.toJson(),
      'logEntries': log.length,
      'error': error,
      'hasStackTrace': stackTrace != null,
    };
  }
}

/// Result of data deletion during rollback
class DeletionResult {
  final bool success;
  final int totalDeleted;
  final List<String> errors;
  final String? error;

  DeletionResult({
    required this.success,
    required this.totalDeleted,
    this.errors = const [],
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'totalDeleted': totalDeleted,
      'errors': errors,
      'error': error,
    };
  }
}

/// Result of rollback verification
class RollbackVerificationResult {
  final bool success;
  final List<String> errors;
  final String? error;

  RollbackVerificationResult({
    required this.success,
    this.errors = const [],
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'errors': errors,
      'error': error,
    };
  }
}

/// Result of backup restoration
class RestoreResult {
  final bool success;
  final Duration duration;
  final String backupId;
  final List<String> log;
  final String? error;
  final String? stackTrace;

  RestoreResult({
    required this.success,
    required this.duration,
    required this.backupId,
    required this.log,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'durationSeconds': duration.inSeconds,
      'backupId': backupId,
      'logEntries': log.length,
      'error': error,
      'hasStackTrace': stackTrace != null,
    };
  }
}
