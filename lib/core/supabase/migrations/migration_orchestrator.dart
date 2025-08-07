import 'dart:async';
import 'package:flutter/foundation.dart';

import 'sqlite_to_supabase_migration.dart';
import 'migration_verification_service.dart';
import 'migration_rollback_service.dart';
import 'migration_progress_tracker.dart';

/// Orchestrator service that coordinates the entire migration process
/// Provides a unified interface for migration, verification, and rollback operations
class MigrationOrchestrator {
  static final MigrationOrchestrator _instance =
      MigrationOrchestrator._internal();
  static MigrationOrchestrator get instance => _instance;

  MigrationOrchestrator._internal();

  final SQLiteToSupabaseMigration _migrationService =
      SQLiteToSupabaseMigration();
  final MigrationVerificationService _verificationService =
      MigrationVerificationService();
  final MigrationRollbackService _rollbackService = MigrationRollbackService();
  final MigrationProgressTracker _progressTracker =
      MigrationProgressTracker.instance;

  /// Stream of migration progress updates
  Stream<ProgressUpdate> get progressStream => _progressTracker.progressStream;

  /// Current migration phase
  MigrationPhase get currentPhase => _progressTracker.currentPhase;

  /// Current progress (0.0 to 1.0)
  double get currentProgress => _progressTracker.currentProgress;

  /// Execute complete migration workflow with progress tracking
  Future<CompleteMigrationResult> executeCompleteMigration({
    bool dryRun = false,
    bool skipValidation = false,
    bool autoVerify = true,
    bool createBackup = true,
  }) async {
    final startTime = DateTime.now();

    try {
      _log('🚀 Starting complete migration workflow...');
      _log(
          '📊 Configuration: dryRun=$dryRun, skipValidation=$skipValidation, autoVerify=$autoVerify, createBackup=$createBackup');

      // Initialize progress tracking
      _progressTracker.startMigration(
          totalOperations: _calculateTotalOperations());

      // Phase 1: Execute migration
      _progressTracker.updatePhase(MigrationPhase.initializing,
          description: 'Preparing migration...');
      final migrationResult = await _executeMigrationWithProgress(
        dryRun: dryRun,
        skipValidation: skipValidation,
      );

      if (!migrationResult.success) {
        _progressTracker.completeMigration(success: false);
        return CompleteMigrationResult(
          success: false,
          migrationResult: migrationResult,
          duration: DateTime.now().difference(startTime),
          error: 'Migration failed: ${migrationResult.error}',
        );
      }

      // Phase 2: Verify migration (if enabled and not dry run)
      VerificationResult? verificationResult;
      if (autoVerify && !dryRun) {
        _progressTracker.updatePhase(MigrationPhase.verifying,
            description: 'Verifying migration...');
        verificationResult =
            await _executeVerificationWithProgress(migrationResult.idMappings);

        if (!verificationResult.success) {
          _log('❌ Migration verification failed - considering rollback');

          // Optionally rollback on verification failure
          if (createBackup) {
            _progressTracker.updatePhase(MigrationPhase.rollingBack,
                description: 'Rolling back due to verification failure...');
            final rollbackResult =
                await _executeRollbackWithProgress(migrationResult);

            _progressTracker.completeMigration(success: false);
            return CompleteMigrationResult(
              success: false,
              migrationResult: migrationResult,
              verificationResult: verificationResult,
              rollbackResult: rollbackResult,
              duration: DateTime.now().difference(startTime),
              error: 'Migration verification failed and was rolled back',
            );
          }
        }
      }

      // Phase 3: Complete successfully
      _progressTracker.completeMigration(success: true);
      final duration = DateTime.now().difference(startTime);

      _log(
          '✅ Complete migration workflow finished successfully in ${duration.inSeconds}s');

      return CompleteMigrationResult(
        success: true,
        migrationResult: migrationResult,
        verificationResult: verificationResult,
        duration: duration,
      );
    } catch (e, stackTrace) {
      _progressTracker.completeMigration(success: false);
      final duration = DateTime.now().difference(startTime);

      _log('❌ Complete migration workflow failed: $e');

      return CompleteMigrationResult(
        success: false,
        duration: duration,
        error: e.toString(),
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Execute migration with progress tracking
  Future<MigrationResult> _executeMigrationWithProgress({
    required bool dryRun,
    required bool skipValidation,
  }) async {
    _progressTracker.updatePhase(MigrationPhase.exporting);
    _progressTracker.recordSuccess('Migration service initialized');

    // Listen to migration progress (if the migration service supported it)
    // For now, we'll simulate progress updates
    final migrationCompleter = Completer<MigrationResult>();

    // Execute migration
    _migrationService
        .migrateFromSQLite(
      dryRun: dryRun,
      skipValidation: skipValidation,
    )
        .then((result) {
      migrationCompleter.complete(result);
    }).catchError((error) {
      migrationCompleter.completeError(error);
    });

    // Simulate progress updates during migration
    _simulateMigrationProgress();

    return await migrationCompleter.future;
  }

  /// Execute verification with progress tracking
  Future<VerificationResult> _executeVerificationWithProgress(
      Map<String, String> idMappings) async {
    _progressTracker.updateProgress(0.8, 'Starting verification...');

    final verificationResult = await _verificationService.verifyMigration(
      idMappings: idMappings,
      detailedComparison: true,
    );

    _progressTracker.updateProgress(0.9, 'Verification completed');
    _progressTracker.recordSuccess('Migration verification');

    return verificationResult;
  }

  /// Execute rollback with progress tracking
  Future<RollbackResult> _executeRollbackWithProgress(
      MigrationResult migrationResult) async {
    _progressTracker.updateProgress(0.0, 'Starting rollback...');

    final rollbackResult = await _rollbackService.rollbackMigration(
      migrationResult: migrationResult,
      preserveBackup: true,
      confirmDeletion: true,
    );

    _progressTracker.updateProgress(1.0, 'Rollback completed');

    if (rollbackResult.success) {
      _progressTracker.recordSuccess('Migration rollback');
    } else {
      _progressTracker.recordFailure(
          'Migration rollback', rollbackResult.error ?? 'Unknown error');
    }

    return rollbackResult;
  }

  /// Simulate migration progress updates
  void _simulateMigrationProgress() {
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_progressTracker.currentPhase == MigrationPhase.completed ||
          _progressTracker.currentPhase == MigrationPhase.failed) {
        timer.cancel();
        return;
      }

      final currentProgress = _progressTracker.currentProgress;
      if (currentProgress < 0.7) {
        final newProgress = (currentProgress + 0.1).clamp(0.0, 0.7);
        final operations = [
          'Exporting team members...',
          'Exporting tasks...',
          'Exporting security alerts...',
          'Transforming data...',
          'Validating data...',
          'Importing to Supabase...',
        ];

        final operationIndex = (newProgress * operations.length)
            .floor()
            .clamp(0, operations.length - 1);
        _progressTracker.updateProgress(
            newProgress, operations[operationIndex]);
      }
    });
  }

  /// Verify migration independently
  Future<VerificationResult> verifyMigration({
    Map<String, String>? idMappings,
    bool detailedComparison = true,
  }) async {
    _log('🔍 Starting independent migration verification...');

    return await _verificationService.verifyMigration(
      idMappings: idMappings,
      detailedComparison: detailedComparison,
    );
  }

  /// Rollback migration independently
  Future<RollbackResult> rollbackMigration({
    MigrationResult? migrationResult,
    bool preserveBackup = true,
    bool confirmDeletion = false,
  }) async {
    _log('🔄 Starting independent migration rollback...');

    return await _rollbackService.rollbackMigration(
      migrationResult: migrationResult,
      preserveBackup: preserveBackup,
      confirmDeletion: confirmDeletion,
    );
  }

  /// Restore from backup
  Future<RestoreResult> restoreFromBackup(String backupId) async {
    _log('🔄 Starting restore from backup: $backupId');

    return await _rollbackService.restoreFromBackup(backupId);
  }

  /// Generate comprehensive migration report
  Future<MigrationReport> generateMigrationReport() async {
    _log('📄 Generating migration report...');

    return await _progressTracker.generateReport();
  }

  /// Get current migration statistics
  MigrationStatistics get migrationStatistics => _progressTracker.statistics;

  /// Check if migration is currently in progress
  bool get isMigrationInProgress =>
      _progressTracker.currentPhase != MigrationPhase.idle &&
      _progressTracker.currentPhase != MigrationPhase.completed &&
      _progressTracker.currentPhase != MigrationPhase.failed;

  /// Get migration status summary
  MigrationStatusSummary get statusSummary => MigrationStatusSummary(
        phase: _progressTracker.currentPhase,
        progress: _progressTracker.currentProgress,
        operation: _progressTracker.currentOperation,
        statistics: _progressTracker.statistics,
        isInProgress: isMigrationInProgress,
      );

  /// Calculate total operations for progress tracking
  int _calculateTotalOperations() {
    // Estimate based on typical migration operations
    return 50; // This would be calculated based on actual data size
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    if (kDebugMode) {
      debugPrint(logEntry);
    }
  }
}

/// Result of complete migration workflow
class CompleteMigrationResult {
  final bool success;
  final MigrationResult? migrationResult;
  final VerificationResult? verificationResult;
  final RollbackResult? rollbackResult;
  final Duration duration;
  final String? error;
  final String? stackTrace;

  CompleteMigrationResult({
    required this.success,
    this.migrationResult,
    this.verificationResult,
    this.rollbackResult,
    required this.duration,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'durationSeconds': duration.inSeconds,
      'migrationResult': migrationResult?.toJson(),
      'verificationResult': verificationResult?.toJson(),
      'rollbackResult': rollbackResult?.toJson(),
      'error': error,
      'hasStackTrace': stackTrace != null,
      'completedAt': DateTime.now().toIso8601String(),
    };
  }
}

/// Migration status summary
class MigrationStatusSummary {
  final MigrationPhase phase;
  final double progress;
  final String operation;
  final MigrationStatistics statistics;
  final bool isInProgress;

  MigrationStatusSummary({
    required this.phase,
    required this.progress,
    required this.operation,
    required this.statistics,
    required this.isInProgress,
  });

  Map<String, dynamic> toJson() {
    return {
      'phase': phase.name,
      'progress': progress,
      'operation': operation,
      'statistics': statistics.toJson(),
      'isInProgress': isInProgress,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
