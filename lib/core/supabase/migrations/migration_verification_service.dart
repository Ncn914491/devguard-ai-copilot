import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../database/database_service.dart';
import '../supabase_service.dart';
import 'sqlite_to_supabase_migration.dart';

/// Service for verifying data migration between SQLite and Supabase
/// Provides comprehensive data comparison and integrity checks
class MigrationVerificationService {
  final DatabaseService _sqliteDb = DatabaseService.instance;
  final SupabaseService _supabaseService = SupabaseService.instance;
  final List<String> _verificationLog = [];

  /// Get verification log entries
  List<String> get verificationLog => List.unmodifiable(_verificationLog);

  /// Perform comprehensive data comparison between SQLite and Supabase
  Future<VerificationResult> verifyMigration({
    Map<String, String>? idMappings,
    bool detailedComparison = true,
  }) async {
    final startTime = DateTime.now();
    _verificationLog.clear();

    try {
      _log('🔍 Starting migration verification...');
      _log('📊 Detailed comparison: $detailedComparison');

      // Initialize services
      await _initializeServices();

      // Step 1: Compare record counts
      _log('📊 Comparing record counts...');
      final countComparison = await _compareRecordCounts();

      // Step 2: Compare data integrity (if detailed comparison enabled)
      DataIntegrityComparison? dataComparison;
      if (detailedComparison) {
        _log('🔍 Performing detailed data comparison...');
        dataComparison = await _compareDataIntegrity(idMappings);
      }

      // Step 3: Verify foreign key relationships
      _log('🔗 Verifying foreign key relationships...');
      final relationshipVerification = await _verifyRelationships();

      // Step 4: Check data consistency
      _log('✅ Checking data consistency...');
      final consistencyCheck = await _checkDataConsistency();

      final duration = DateTime.now().difference(startTime);
      final success = countComparison.success &&
          relationshipVerification.success &&
          consistencyCheck.success &&
          (dataComparison?.success ?? true);

      if (success) {
        _log('✅ Migration verification completed successfully');
      } else {
        _log('❌ Migration verification found issues');
      }

      return VerificationResult(
        success: success,
        duration: duration,
        countComparison: countComparison,
        dataComparison: dataComparison,
        relationshipVerification: relationshipVerification,
        consistencyCheck: consistencyCheck,
        log: List.from(_verificationLog),
      );
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      _log('❌ Migration verification failed: $e');

      return VerificationResult(
        success: false,
        duration: duration,
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        log: List.from(_verificationLog),
      );
    }
  }

  /// Compare record counts between SQLite and Supabase
  Future<RecordCountComparison> _compareRecordCounts() async {
    final sqliteDb = await _sqliteDb.database;
    final supabaseClient = _supabaseService.client;
    final discrepancies = <String>[];

    try {
      // Compare team members
      final sqliteTeamMembers =
          await sqliteDb.rawQuery('SELECT COUNT(*) as count FROM team_members');
      final supabaseTeamMembers =
          await supabaseClient.from('team_members').select('count').count();
      final sqliteTeamMembersCount = sqliteTeamMembers.first['count'] as int;

      if (sqliteTeamMembersCount != supabaseTeamMembers) {
        discrepancies.add(
            'Team members: SQLite($sqliteTeamMembersCount) != Supabase($supabaseTeamMembers)');
      }
      _log(
          '📊 Team members: SQLite($sqliteTeamMembersCount) vs Supabase($supabaseTeamMembers)');

      // Compare tasks
      final sqliteTasks =
          await sqliteDb.rawQuery('SELECT COUNT(*) as count FROM tasks');
      final supabaseTasks =
          await supabaseClient.from('tasks').select('count').count();
      final sqliteTasksCount = sqliteTasks.first['count'] as int;

      if (sqliteTasksCount != supabaseTasks) {
        discrepancies.add(
            'Tasks: SQLite($sqliteTasksCount) != Supabase($supabaseTasks)');
      }
      _log('📊 Tasks: SQLite($sqliteTasksCount) vs Supabase($supabaseTasks)');

      // Compare security alerts
      final sqliteAlerts = await sqliteDb
          .rawQuery('SELECT COUNT(*) as count FROM security_alerts');
      final supabaseAlerts =
          await supabaseClient.from('security_alerts').select('count').count();
      final sqliteAlertsCount = sqliteAlerts.first['count'] as int;

      if (sqliteAlertsCount != supabaseAlerts) {
        discrepancies.add(
            'Security alerts: SQLite($sqliteAlertsCount) != Supabase($supabaseAlerts)');
      }
      _log(
          '📊 Security alerts: SQLite($sqliteAlertsCount) vs Supabase($supabaseAlerts)');

      // Compare audit logs
      final sqliteAuditLogs =
          await sqliteDb.rawQuery('SELECT COUNT(*) as count FROM audit_logs');
      final supabaseAuditLogs =
          await supabaseClient.from('audit_logs').select('count').count();
      final sqliteAuditLogsCount = sqliteAuditLogs.first['count'] as int;

      if (sqliteAuditLogsCount != supabaseAuditLogs) {
        discrepancies.add(
            'Audit logs: SQLite($sqliteAuditLogsCount) != Supabase($supabaseAuditLogs)');
      }
      _log(
          '📊 Audit logs: SQLite($sqliteAuditLogsCount) vs Supabase($supabaseAuditLogs)');

      // Compare deployments
      final sqliteDeployments =
          await sqliteDb.rawQuery('SELECT COUNT(*) as count FROM deployments');
      final supabaseDeployments =
          await supabaseClient.from('deployments').select('count').count();
      final sqliteDeploymentsCount = sqliteDeployments.first['count'] as int;

      if (sqliteDeploymentsCount != supabaseDeployments) {
        discrepancies.add(
            'Deployments: SQLite($sqliteDeploymentsCount) != Supabase($supabaseDeployments)');
      }
      _log(
          '📊 Deployments: SQLite($sqliteDeploymentsCount) vs Supabase($supabaseDeployments)');

      // Compare snapshots
      final sqliteSnapshots =
          await sqliteDb.rawQuery('SELECT COUNT(*) as count FROM snapshots');
      final supabaseSnapshots =
          await supabaseClient.from('snapshots').select('count').count();
      final sqliteSnapshotsCount = sqliteSnapshots.first['count'] as int;

      if (sqliteSnapshotsCount != supabaseSnapshots) {
        discrepancies.add(
            'Snapshots: SQLite($sqliteSnapshotsCount) != Supabase($supabaseSnapshots)');
      }
      _log(
          '📊 Snapshots: SQLite($sqliteSnapshotsCount) vs Supabase($supabaseSnapshots)');

      // Compare specifications
      final sqliteSpecs = await sqliteDb
          .rawQuery('SELECT COUNT(*) as count FROM specifications');
      final supabaseSpecs =
          await supabaseClient.from('specifications').select('count').count();
      final sqliteSpecsCount = sqliteSpecs.first['count'] as int;

      if (sqliteSpecsCount != supabaseSpecs) {
        discrepancies.add(
            'Specifications: SQLite($sqliteSpecsCount) != Supabase($supabaseSpecs)');
      }
      _log(
          '📊 Specifications: SQLite($sqliteSpecsCount) vs Supabase($supabaseSpecs)');

      final success = discrepancies.isEmpty;
      if (success) {
        _log('✅ Record count comparison passed');
      } else {
        _log(
            '❌ Record count comparison failed with ${discrepancies.length} discrepancies');
      }

      return RecordCountComparison(
        success: success,
        discrepancies: discrepancies,
        counts: {
          'team_members': {
            'sqlite': sqliteTeamMembersCount,
            'supabase': supabaseTeamMembers
          },
          'tasks': {'sqlite': sqliteTasksCount, 'supabase': supabaseTasks},
          'security_alerts': {
            'sqlite': sqliteAlertsCount,
            'supabase': supabaseAlerts
          },
          'audit_logs': {
            'sqlite': sqliteAuditLogsCount,
            'supabase': supabaseAuditLogs
          },
          'deployments': {
            'sqlite': sqliteDeploymentsCount,
            'supabase': supabaseDeployments
          },
          'snapshots': {
            'sqlite': sqliteSnapshotsCount,
            'supabase': supabaseSnapshots
          },
          'specifications': {
            'sqlite': sqliteSpecsCount,
            'supabase': supabaseSpecs
          },
        },
      );
    } catch (e) {
      _log('❌ Record count comparison error: $e');
      return RecordCountComparison(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Perform detailed data integrity comparison
  Future<DataIntegrityComparison> _compareDataIntegrity(
      Map<String, String>? idMappings) async {
    final sqliteDb = await _sqliteDb.database;
    final supabaseClient = _supabaseService.client;
    final dataDiscrepancies = <String>[];
    int samplesChecked = 0;

    try {
      // Sample and compare team members
      final sqliteTeamMembers = await sqliteDb.query('team_members', limit: 10);
      for (final sqliteRecord in sqliteTeamMembers) {
        final mappedId = idMappings?[sqliteRecord['id']];
        if (mappedId != null) {
          final supabaseRecord = await supabaseClient
              .from('team_members')
              .select()
              .eq('user_id', mappedId)
              .maybeSingle();

          if (supabaseRecord != null) {
            // Compare key fields
            if (sqliteRecord['name'] != supabaseRecord['name']) {
              dataDiscrepancies.add(
                  'Team member name mismatch for ID ${sqliteRecord['id']}');
            }
            if (sqliteRecord['email'] != supabaseRecord['email']) {
              dataDiscrepancies.add(
                  'Team member email mismatch for ID ${sqliteRecord['id']}');
            }
            samplesChecked++;
          }
        }
      }

      // Sample and compare tasks
      final sqliteTasks = await sqliteDb.query('tasks', limit: 10);
      for (final sqliteRecord in sqliteTasks) {
        final mappedId = idMappings?[sqliteRecord['id']];
        if (mappedId != null) {
          final supabaseRecord = await supabaseClient
              .from('tasks')
              .select()
              .eq('id', mappedId)
              .maybeSingle();

          if (supabaseRecord != null) {
            // Compare key fields
            if (sqliteRecord['title'] != supabaseRecord['title']) {
              dataDiscrepancies
                  .add('Task title mismatch for ID ${sqliteRecord['id']}');
            }
            if (sqliteRecord['description'] != supabaseRecord['description']) {
              dataDiscrepancies.add(
                  'Task description mismatch for ID ${sqliteRecord['id']}');
            }
            samplesChecked++;
          }
        }
      }

      // Sample and compare security alerts
      final sqliteAlerts = await sqliteDb.query('security_alerts', limit: 10);
      for (final sqliteRecord in sqliteAlerts) {
        final mappedId = idMappings?[sqliteRecord['id']];
        if (mappedId != null) {
          final supabaseRecord = await supabaseClient
              .from('security_alerts')
              .select()
              .eq('id', mappedId)
              .maybeSingle();

          if (supabaseRecord != null) {
            // Compare key fields
            if (sqliteRecord['title'] != supabaseRecord['title']) {
              dataDiscrepancies.add(
                  'Security alert title mismatch for ID ${sqliteRecord['id']}');
            }
            if (sqliteRecord['severity'] != supabaseRecord['severity']) {
              dataDiscrepancies.add(
                  'Security alert severity mismatch for ID ${sqliteRecord['id']}');
            }
            samplesChecked++;
          }
        }
      }

      final success = dataDiscrepancies.isEmpty;
      if (success) {
        _log(
            '✅ Data integrity comparison passed ($samplesChecked samples checked)');
      } else {
        _log(
            '❌ Data integrity comparison failed with ${dataDiscrepancies.length} discrepancies');
      }

      return DataIntegrityComparison(
        success: success,
        samplesChecked: samplesChecked,
        discrepancies: dataDiscrepancies,
      );
    } catch (e) {
      _log('❌ Data integrity comparison error: $e');
      return DataIntegrityComparison(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Verify foreign key relationships in Supabase
  Future<RelationshipVerification> _verifyRelationships() async {
    final supabaseClient = _supabaseService.client;
    final relationshipErrors = <String>[];

    try {
      // Verify team_members -> users relationship
      final orphanedTeamMembers = await supabaseClient
          .from('team_members')
          .select('id, user_id')
          .not('user_id', 'in', '(SELECT id FROM users)');

      if (orphanedTeamMembers.isNotEmpty) {
        relationshipErrors.add(
            'Found ${orphanedTeamMembers.length} team members with invalid user_id references');
      }

      // Verify tasks -> team_members relationship
      final orphanedTasks = await supabaseClient
          .from('tasks')
          .select('id, assignee_id')
          .not('assignee_id', 'is', null)
          .not('assignee_id', 'in', '(SELECT id FROM team_members)');

      if (orphanedTasks.isNotEmpty) {
        relationshipErrors.add(
            'Found ${orphanedTasks.length} tasks with invalid assignee_id references');
      }

      // Verify tasks -> users relationship (reporter_id)
      final orphanedTaskReporters = await supabaseClient
          .from('tasks')
          .select('id, reporter_id')
          .not('reporter_id', 'is', null)
          .not('reporter_id', 'in', '(SELECT id FROM users)');

      if (orphanedTaskReporters.isNotEmpty) {
        relationshipErrors.add(
            'Found ${orphanedTaskReporters.length} tasks with invalid reporter_id references');
      }

      // Verify security_alerts -> users relationship
      final orphanedAlerts = await supabaseClient
          .from('security_alerts')
          .select('id, assigned_to')
          .not('assigned_to', 'is', null)
          .not('assigned_to', 'in', '(SELECT id FROM users)');

      if (orphanedAlerts.isNotEmpty) {
        relationshipErrors.add(
            'Found ${orphanedAlerts.length} security alerts with invalid assigned_to references');
      }

      final success = relationshipErrors.isEmpty;
      if (success) {
        _log('✅ Foreign key relationship verification passed');
      } else {
        _log('❌ Foreign key relationship verification failed');
        for (final error in relationshipErrors) {
          _log('  - $error');
        }
      }

      return RelationshipVerification(
        success: success,
        errors: relationshipErrors,
      );
    } catch (e) {
      _log('❌ Relationship verification error: $e');
      return RelationshipVerification(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Check data consistency and constraints
  Future<ConsistencyCheck> _checkDataConsistency() async {
    final supabaseClient = _supabaseService.client;
    final consistencyErrors = <String>[];

    try {
      // Check for duplicate emails in users
      final duplicateEmails = await supabaseClient
          .from('users')
          .select('email')
          .group('email')
          .having('COUNT(*) > 1');

      if (duplicateEmails.isNotEmpty) {
        consistencyErrors.add(
            'Found ${duplicateEmails.length} duplicate email addresses in users table');
      }

      // Check for invalid email formats
      final invalidEmails = await supabaseClient
          .from('users')
          .select('id, email')
          .not('email', 'like', '%@%.%');

      if (invalidEmails.isNotEmpty) {
        consistencyErrors.add(
            'Found ${invalidEmails.length} users with invalid email formats');
      }

      // Check for tasks with invalid date ranges
      final invalidTaskDates = await supabaseClient
          .from('tasks')
          .select('id, created_at, due_date, completed_at')
          .or('due_date.lt.created_at,completed_at.lt.created_at');

      if (invalidTaskDates.isNotEmpty) {
        consistencyErrors.add(
            'Found ${invalidTaskDates.length} tasks with invalid date ranges');
      }

      // Check for security alerts with invalid severity levels
      final invalidSeverities = await supabaseClient
          .from('security_alerts')
          .select('id, severity')
          .not('severity', 'in', '(low,medium,high,critical)');

      if (invalidSeverities.isNotEmpty) {
        consistencyErrors.add(
            'Found ${invalidSeverities.length} security alerts with invalid severity levels');
      }

      // Check for deployments with invalid status
      final invalidDeploymentStatus = await supabaseClient
          .from('deployments')
          .select('id, status')
          .not('status', 'in',
              '(pending,in_progress,success,failed,rolled_back)');

      if (invalidDeploymentStatus.isNotEmpty) {
        consistencyErrors.add(
            'Found ${invalidDeploymentStatus.length} deployments with invalid status values');
      }

      final success = consistencyErrors.isEmpty;
      if (success) {
        _log('✅ Data consistency check passed');
      } else {
        _log('❌ Data consistency check failed');
        for (final error in consistencyErrors) {
          _log('  - $error');
        }
      }

      return ConsistencyCheck(
        success: success,
        errors: consistencyErrors,
      );
    } catch (e) {
      _log('❌ Consistency check error: $e');
      return ConsistencyCheck(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Initialize required services
  Future<void> _initializeServices() async {
    await _sqliteDb.initialize();
    if (!_supabaseService.isInitialized) {
      await _supabaseService.initialize();
    }
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    _verificationLog.add(logEntry);
    if (kDebugMode) {
      debugPrint(logEntry);
    }
  }
}

/// Result of migration verification
class VerificationResult {
  final bool success;
  final Duration duration;
  final RecordCountComparison? countComparison;
  final DataIntegrityComparison? dataComparison;
  final RelationshipVerification? relationshipVerification;
  final ConsistencyCheck? consistencyCheck;
  final List<String> log;
  final String? error;
  final String? stackTrace;

  VerificationResult({
    required this.success,
    required this.duration,
    this.countComparison,
    this.dataComparison,
    this.relationshipVerification,
    this.consistencyCheck,
    required this.log,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'durationSeconds': duration.inSeconds,
      'countComparison': countComparison?.toJson(),
      'dataComparison': dataComparison?.toJson(),
      'relationshipVerification': relationshipVerification?.toJson(),
      'consistencyCheck': consistencyCheck?.toJson(),
      'logEntries': log.length,
      'error': error,
      'hasStackTrace': stackTrace != null,
    };
  }
}

/// Record count comparison result
class RecordCountComparison {
  final bool success;
  final List<String> discrepancies;
  final Map<String, Map<String, int>>? counts;
  final String? error;

  RecordCountComparison({
    required this.success,
    this.discrepancies = const [],
    this.counts,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'discrepancies': discrepancies,
      'counts': counts,
      'error': error,
    };
  }
}

/// Data integrity comparison result
class DataIntegrityComparison {
  final bool success;
  final int samplesChecked;
  final List<String> discrepancies;
  final String? error;

  DataIntegrityComparison({
    required this.success,
    this.samplesChecked = 0,
    this.discrepancies = const [],
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'samplesChecked': samplesChecked,
      'discrepancies': discrepancies,
      'error': error,
    };
  }
}

/// Foreign key relationship verification result
class RelationshipVerification {
  final bool success;
  final List<String> errors;
  final String? error;

  RelationshipVerification({
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

/// Data consistency check result
class ConsistencyCheck {
  final bool success;
  final List<String> errors;
  final String? error;

  ConsistencyCheck({
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
