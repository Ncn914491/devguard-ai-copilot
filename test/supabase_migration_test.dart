import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import '../lib/core/supabase/migrations/sqlite_to_supabase_migration.dart';
import '../lib/core/supabase/migrations/migration_verification_service.dart';
import '../lib/core/supabase/migrations/migration_rollback_service.dart';
import '../lib/core/supabase/migrations/migration_progress_tracker.dart';
import '../lib/core/supabase/migrations/migration_orchestrator.dart';
import '../lib/core/database/database_service.dart';
import '../lib/core/supabase/supabase_service.dart';

// Generate mocks
@GenerateMocks([
  DatabaseService,
  SupabaseService,
])
import 'supabase_migration_test.mocks.dart';

void main() {
  group('SQLite to Supabase Migration Tests', () {
    late MockDatabaseService mockDatabaseService;
    late MockSupabaseService mockSupabaseService;

    setUp(() {
      mockDatabaseService = MockDatabaseService();
      mockSupabaseService = MockSupabaseService();
    });

    group('Migration Progress Tracker', () {
      late MigrationProgressTracker progressTracker;

      setUp(() {
        progressTracker = MigrationProgressTracker.instance;
      });

      test('should initialize with idle state', () {
        expect(progressTracker.currentPhase, equals(MigrationPhase.idle));
        expect(progressTracker.currentProgress, equals(0.0));
        expect(progressTracker.currentOperation, isEmpty);
      });

      test('should start migration tracking correctly', () {
        const totalOperations = 100;
        progressTracker.startMigration(totalOperations: totalOperations);

        expect(
            progressTracker.currentPhase, equals(MigrationPhase.initializing));
        expect(progressTracker.statistics.totalOperations,
            equals(totalOperations));
        expect(progressTracker.statistics.completedOperations, equals(0));
      });

      test('should update phase correctly', () {
        progressTracker.startMigration(totalOperations: 50);
        progressTracker.updatePhase(MigrationPhase.exporting,
            description: 'Exporting data');

        expect(progressTracker.currentPhase, equals(MigrationPhase.exporting));
        expect(progressTracker.currentOperation, equals('Exporting data'));
      });

      test('should record successful operations', () {
        progressTracker.startMigration(totalOperations: 10);
        progressTracker.recordSuccess('Test operation');

        expect(progressTracker.statistics.completedOperations, equals(1));
        expect(progressTracker.currentProgress, equals(0.1));
      });

      test('should record failed operations', () {
        progressTracker.startMigration(totalOperations: 10);
        progressTracker.recordFailure('Test operation', 'Test error');

        expect(progressTracker.statistics.failedOperations, equals(1));
        expect(progressTracker.statistics.errors,
            contains('Test operation: Test error'));
      });

      test('should complete migration tracking', () {
        progressTracker.startMigration(totalOperations: 10);
        progressTracker.completeMigration(success: true);

        expect(progressTracker.currentPhase, equals(MigrationPhase.completed));
        expect(progressTracker.currentProgress, equals(1.0));
      });

      test('should generate migration statistics', () {
        progressTracker.startMigration(totalOperations: 10);
        progressTracker.recordSuccess('Operation 1');
        progressTracker.recordSuccess('Operation 2');
        progressTracker.recordFailure('Operation 3', 'Error');

        final stats = progressTracker.statistics;
        expect(stats.totalOperations, equals(10));
        expect(stats.completedOperations, equals(2));
        expect(stats.failedOperations, equals(1));
        expect(stats.successRate, equals(0.2));
      });
    });

    group('Migration Data Structures', () {
      test('should create SQLiteExportData correctly', () {
        final exportData = SQLiteExportData(
          teamMembers: [],
          tasks: [],
          securityAlerts: [],
          auditLogs: [],
          deployments: [],
          snapshots: [],
          specifications: [],
        );

        expect(exportData.teamMembers, isEmpty);
        expect(exportData.tasks, isEmpty);
        expect(exportData.securityAlerts, isEmpty);
      });

      test('should create SupabaseImportData correctly', () {
        final importData = SupabaseImportData(
          users: [],
          teamMembers: [],
          tasks: [],
          securityAlerts: [],
          auditLogs: [],
          deployments: [],
          snapshots: [],
          specifications: [],
        );

        expect(importData.users, isEmpty);
        expect(importData.teamMembers, isEmpty);
        expect(importData.tasks, isEmpty);
      });

      test('should create MigrationResult correctly', () {
        final result = MigrationResult(
          success: true,
          recordsMigrated: 100,
          duration: const Duration(seconds: 30),
          log: ['Log entry 1', 'Log entry 2'],
          idMappings: {'old_id': 'new_id'},
        );

        expect(result.success, isTrue);
        expect(result.recordsMigrated, equals(100));
        expect(result.duration.inSeconds, equals(30));
        expect(result.log.length, equals(2));
        expect(result.idMappings['old_id'], equals('new_id'));
      });
    });

    group('Verification Service Data Structures', () {
      test('should create VerificationResult correctly', () {
        final countComparison = RecordCountComparison(success: true);
        final result = VerificationResult(
          success: true,
          duration: const Duration(seconds: 15),
          countComparison: countComparison,
          log: ['Verification log'],
        );

        expect(result.success, isTrue);
        expect(result.duration.inSeconds, equals(15));
        expect(result.countComparison?.success, isTrue);
        expect(result.log.length, equals(1));
      });

      test('should create RecordCountComparison correctly', () {
        final comparison = RecordCountComparison(
          success: false,
          discrepancies: ['Users count mismatch'],
          counts: {
            'users': {'sqlite': 10, 'supabase': 9}
          },
        );

        expect(comparison.success, isFalse);
        expect(comparison.discrepancies.length, equals(1));
        expect(comparison.counts?['users']?['sqlite'], equals(10));
      });

      test('should create DataIntegrityComparison correctly', () {
        final comparison = DataIntegrityComparison(
          success: true,
          samplesChecked: 25,
          discrepancies: [],
        );

        expect(comparison.success, isTrue);
        expect(comparison.samplesChecked, equals(25));
        expect(comparison.discrepancies, isEmpty);
      });
    });

    group('Rollback Service Data Structures', () {
      test('should create RollbackResult correctly', () {
        final deletionResult = DeletionResult(success: true, totalDeleted: 50);
        final result = RollbackResult(
          success: true,
          duration: const Duration(seconds: 20),
          backupId: 'backup_123',
          deletionResult: deletionResult,
          log: ['Rollback log'],
        );

        expect(result.success, isTrue);
        expect(result.duration.inSeconds, equals(20));
        expect(result.backupId, equals('backup_123'));
        expect(result.deletionResult?.totalDeleted, equals(50));
      });

      test('should create DeletionResult correctly', () {
        final result = DeletionResult(
          success: false,
          totalDeleted: 25,
          errors: ['Failed to delete users'],
        );

        expect(result.success, isFalse);
        expect(result.totalDeleted, equals(25));
        expect(result.errors.length, equals(1));
      });

      test('should create RestoreResult correctly', () {
        final result = RestoreResult(
          success: true,
          duration: const Duration(seconds: 45),
          backupId: 'backup_456',
          log: ['Restore log 1', 'Restore log 2'],
        );

        expect(result.success, isTrue);
        expect(result.duration.inSeconds, equals(45));
        expect(result.backupId, equals('backup_456'));
        expect(result.log.length, equals(2));
      });
    });

    group('Migration Orchestrator', () {
      test('should initialize correctly', () {
        final orchestrator = MigrationOrchestrator.instance;

        expect(orchestrator.currentPhase, equals(MigrationPhase.idle));
        expect(orchestrator.currentProgress, equals(0.0));
        expect(orchestrator.isMigrationInProgress, isFalse);
      });

      test('should create status summary correctly', () {
        final orchestrator = MigrationOrchestrator.instance;
        final summary = orchestrator.statusSummary;

        expect(summary.phase, equals(MigrationPhase.idle));
        expect(summary.progress, equals(0.0));
        expect(summary.isInProgress, isFalse);
      });

      test('should create CompleteMigrationResult correctly', () {
        final migrationResult = MigrationResult(
          success: true,
          recordsMigrated: 100,
          duration: const Duration(seconds: 30),
          log: [],
        );

        final result = CompleteMigrationResult(
          success: true,
          migrationResult: migrationResult,
          duration: const Duration(seconds: 60),
        );

        expect(result.success, isTrue);
        expect(result.migrationResult?.recordsMigrated, equals(100));
        expect(result.duration.inSeconds, equals(60));
      });
    });

    group('Progress Update Events', () {
      test('should create ProgressUpdate correctly', () {
        final update = ProgressUpdate(
          phase: MigrationPhase.importing,
          progress: 0.75,
          operation: 'Importing tasks',
          timestamp: DateTime.now(),
        );

        expect(update.phase, equals(MigrationPhase.importing));
        expect(update.progress, equals(0.75));
        expect(update.operation, equals('Importing tasks'));
      });

      test('should serialize ProgressUpdate to JSON', () {
        final timestamp = DateTime.now();
        final update = ProgressUpdate(
          phase: MigrationPhase.verifying,
          progress: 0.9,
          operation: 'Verifying data',
          timestamp: timestamp,
        );

        final json = update.toJson();
        expect(json['phase'], equals('verifying'));
        expect(json['progress'], equals(0.9));
        expect(json['operation'], equals('Verifying data'));
        expect(json['timestamp'], equals(timestamp.toIso8601String()));
      });
    });

    group('Migration Report Generation', () {
      test('should create MigrationStatistics correctly', () {
        final stats = MigrationStatistics(
          totalOperations: 100,
          completedOperations: 95,
          failedOperations: 5,
          successRate: 0.95,
          phaseTimings: {'exporting': const Duration(seconds: 10)},
          errors: ['Error 1'],
          progressHistory: [],
        );

        expect(stats.totalOperations, equals(100));
        expect(stats.completedOperations, equals(95));
        expect(stats.failedOperations, equals(5));
        expect(stats.successRate, equals(0.95));
        expect(stats.phaseTimings['exporting']?.inSeconds, equals(10));
      });

      test('should create PhaseInfo correctly', () {
        final phaseInfo = PhaseInfo(
          duration: const Duration(seconds: 30),
          operationsCount: 20,
          averageOperationTime: const Duration(milliseconds: 1500),
          success: true,
        );

        expect(phaseInfo.duration.inSeconds, equals(30));
        expect(phaseInfo.operationsCount, equals(20));
        expect(phaseInfo.averageOperationTime.inMilliseconds, equals(1500));
        expect(phaseInfo.success, isTrue);
      });

      test('should create ErrorSummary correctly', () {
        final errorSummary = ErrorSummary(
          totalErrors: 3,
          errorsByType: {
            'validation': ['Invalid email', 'Missing field'],
            'network': ['Connection timeout']
          },
          criticalErrors: ['Critical error'],
          recoverableErrors: ['Recoverable error 1', 'Recoverable error 2'],
        );

        expect(errorSummary.totalErrors, equals(3));
        expect(errorSummary.errorsByType['validation']?.length, equals(2));
        expect(errorSummary.criticalErrors.length, equals(1));
        expect(errorSummary.recoverableErrors.length, equals(2));
      });
    });

    group('JSON Serialization', () {
      test('should serialize MigrationResult to JSON', () {
        final result = MigrationResult(
          success: true,
          recordsMigrated: 150,
          duration: const Duration(seconds: 45),
          log: ['Log 1', 'Log 2'],
          idMappings: {'old1': 'new1', 'old2': 'new2'},
        );

        final json = result.toJson();
        expect(json['success'], isTrue);
        expect(json['recordsMigrated'], equals(150));
        expect(json['durationSeconds'], equals(45));
        expect(json['logEntries'], equals(2));
        expect(json['idMappingsCount'], equals(2));
      });

      test('should serialize VerificationResult to JSON', () {
        final countComparison = RecordCountComparison(success: true);
        final result = VerificationResult(
          success: true,
          duration: const Duration(seconds: 20),
          countComparison: countComparison,
          log: ['Verification complete'],
        );

        final json = result.toJson();
        expect(json['success'], isTrue);
        expect(json['durationSeconds'], equals(20));
        expect(json['logEntries'], equals(1));
        expect(json['countComparison'], isNotNull);
      });

      test('should serialize RollbackResult to JSON', () {
        final result = RollbackResult(
          success: true,
          duration: const Duration(seconds: 30),
          backupId: 'backup_789',
          log: ['Rollback started', 'Rollback completed'],
        );

        final json = result.toJson();
        expect(json['success'], isTrue);
        expect(json['durationSeconds'], equals(30));
        expect(json['backupId'], equals('backup_789'));
        expect(json['logEntries'], equals(2));
      });
    });

    group('Error Handling', () {
      test('should handle MigrationResult with error', () {
        final result = MigrationResult(
          success: false,
          recordsMigrated: 0,
          duration: const Duration(seconds: 5),
          log: ['Migration failed'],
          error: 'Database connection failed',
          stackTrace: 'Stack trace here',
        );

        expect(result.success, isFalse);
        expect(result.error, equals('Database connection failed'));
        expect(result.stackTrace, isNotNull);
      });

      test('should handle VerificationResult with error', () {
        final result = VerificationResult(
          success: false,
          duration: const Duration(seconds: 10),
          log: ['Verification failed'],
          error: 'Data mismatch detected',
        );

        expect(result.success, isFalse);
        expect(result.error, equals('Data mismatch detected'));
      });

      test('should handle RollbackResult with error', () {
        final result = RollbackResult(
          success: false,
          duration: const Duration(seconds: 15),
          log: ['Rollback failed'],
          error: 'Failed to delete data',
          stackTrace: 'Stack trace here',
        );

        expect(result.success, isFalse);
        expect(result.error, equals('Failed to delete data'));
        expect(result.stackTrace, isNotNull);
      });
    });
  });
}
