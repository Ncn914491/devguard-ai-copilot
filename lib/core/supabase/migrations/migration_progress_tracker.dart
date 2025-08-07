import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service for tracking migration progress and generating reports
/// Provides real-time progress updates and comprehensive reporting
class MigrationProgressTracker {
  static final MigrationProgressTracker _instance =
      MigrationProgressTracker._internal();
  static MigrationProgressTracker get instance => _instance;

  MigrationProgressTracker._internal();

  // Progress tracking state
  MigrationPhase _currentPhase = MigrationPhase.idle;
  double _currentProgress = 0.0;
  String _currentOperation = '';
  final List<ProgressEvent> _progressHistory = [];
  final StreamController<ProgressUpdate> _progressController =
      StreamController<ProgressUpdate>.broadcast();
  DateTime? _migrationStartTime;
  DateTime? _migrationEndTime;

  // Progress statistics
  int _totalOperations = 0;
  int _completedOperations = 0;
  int _failedOperations = 0;
  final Map<String, Duration> _phaseTimings = {};
  final List<String> _errors = [];

  /// Stream of progress updates
  Stream<ProgressUpdate> get progressStream => _progressController.stream;

  /// Current migration phase
  MigrationPhase get currentPhase => _currentPhase;

  /// Current progress (0.0 to 1.0)
  double get currentProgress => _currentProgress;

  /// Current operation description
  String get currentOperation => _currentOperation;

  /// Migration duration (if completed)
  Duration? get migrationDuration =>
      _migrationStartTime != null && _migrationEndTime != null
          ? _migrationEndTime!.difference(_migrationStartTime!)
          : null;

  /// Progress statistics
  MigrationStatistics get statistics => MigrationStatistics(
        totalOperations: _totalOperations,
        completedOperations: _completedOperations,
        failedOperations: _failedOperations,
        successRate: _totalOperations > 0
            ? _completedOperations / _totalOperations
            : 0.0,
        phaseTimings: Map.from(_phaseTimings),
        errors: List.from(_errors),
        progressHistory: List.from(_progressHistory),
      );

  /// Start tracking a new migration
  void startMigration({required int totalOperations}) {
    _reset();
    _migrationStartTime = DateTime.now();
    _totalOperations = totalOperations;
    _currentPhase = MigrationPhase.initializing;
    _updateProgress(0.0, 'Starting migration...');

    _log('🚀 Migration tracking started');
    _log('📊 Total operations: $totalOperations');
  }

  /// Update current phase
  void updatePhase(MigrationPhase phase, {String? description}) {
    final previousPhase = _currentPhase;
    final now = DateTime.now();

    // Record timing for previous phase
    if (_migrationStartTime != null && previousPhase != MigrationPhase.idle) {
      final phaseStart = _progressHistory.isNotEmpty
          ? _progressHistory.last.timestamp
          : _migrationStartTime!;
      _phaseTimings[previousPhase.toString()] = now.difference(phaseStart);
    }

    _currentPhase = phase;
    final phaseDescription = description ?? _getPhaseDescription(phase);
    _updateProgress(_currentProgress, phaseDescription);

    _log('📍 Phase changed: ${previousPhase.name} → ${phase.name}');
  }

  /// Update progress within current phase
  void updateProgress(double progress, String operation) {
    _currentProgress = progress.clamp(0.0, 1.0);
    _currentOperation = operation;

    final update = ProgressUpdate(
      phase: _currentPhase,
      progress: _currentProgress,
      operation: operation,
      timestamp: DateTime.now(),
    );

    _progressHistory.add(ProgressEvent(
      phase: _currentPhase,
      progress: _currentProgress,
      operation: operation,
      timestamp: DateTime.now(),
    ));

    _progressController.add(update);

    if (kDebugMode && _progressHistory.length % 10 == 0) {
      _log(
          '📊 Progress: ${(_currentProgress * 100).toStringAsFixed(1)}% - $operation');
    }
  }

  /// Record successful operation
  void recordSuccess(String operation) {
    _completedOperations++;
    _updateProgress(_completedOperations / _totalOperations, operation);

    if (kDebugMode) {
      _log('✅ Completed: $operation');
    }
  }

  /// Record failed operation
  void recordFailure(String operation, String error) {
    _failedOperations++;
    _errors.add('$operation: $error');
    _updateProgress(
        _completedOperations / _totalOperations, 'Failed: $operation');

    _log('❌ Failed: $operation - $error');
  }

  /// Complete migration tracking
  void completeMigration({bool success = true}) {
    _migrationEndTime = DateTime.now();
    _currentPhase = success ? MigrationPhase.completed : MigrationPhase.failed;
    _updateProgress(
        1.0, success ? 'Migration completed successfully' : 'Migration failed');

    // Record final phase timing
    if (_migrationStartTime != null) {
      final phaseStart = _progressHistory.isNotEmpty
          ? _progressHistory.last.timestamp
          : _migrationStartTime!;
      _phaseTimings[_currentPhase.toString()] =
          _migrationEndTime!.difference(phaseStart);
    }

    final duration = migrationDuration;
    if (success) {
      _log('✅ Migration completed successfully in ${duration?.inSeconds}s');
    } else {
      _log('❌ Migration failed after ${duration?.inSeconds}s');
    }

    _log(
        '📊 Final statistics: ${_completedOperations}/${_totalOperations} operations completed');
    if (_failedOperations > 0) {
      _log('❌ Failed operations: $_failedOperations');
    }
  }

  /// Generate comprehensive migration report
  Future<MigrationReport> generateReport() async {
    final report = MigrationReport(
      migrationId:
          'migration_${_migrationStartTime?.millisecondsSinceEpoch ?? 0}',
      startTime: _migrationStartTime,
      endTime: _migrationEndTime,
      duration: migrationDuration,
      finalPhase: _currentPhase,
      statistics: statistics,
      phaseBreakdown: _generatePhaseBreakdown(),
      errorSummary: _generateErrorSummary(),
      recommendations: _generateRecommendations(),
    );

    // Save report to file
    await _saveReportToFile(report);

    return report;
  }

  /// Generate phase breakdown for report
  Map<String, PhaseInfo> _generatePhaseBreakdown() {
    final breakdown = <String, PhaseInfo>{};

    for (final entry in _phaseTimings.entries) {
      final phaseName = entry.key;
      final duration = entry.value;
      final phaseEvents = _progressHistory
          .where((event) => event.phase.toString() == phaseName)
          .toList();

      breakdown[phaseName] = PhaseInfo(
        duration: duration,
        operationsCount: phaseEvents.length,
        averageOperationTime: phaseEvents.isNotEmpty
            ? Duration(
                milliseconds: duration.inMilliseconds ~/ phaseEvents.length)
            : Duration.zero,
        success: !_errors.any((error) => error.contains(phaseName)),
      );
    }

    return breakdown;
  }

  /// Generate error summary for report
  ErrorSummary _generateErrorSummary() {
    final errorsByType = <String, List<String>>{};

    for (final error in _errors) {
      final parts = error.split(':');
      final type = parts.isNotEmpty ? parts[0].trim() : 'Unknown';
      final message =
          parts.length > 1 ? parts.sublist(1).join(':').trim() : error;

      errorsByType.putIfAbsent(type, () => []).add(message);
    }

    return ErrorSummary(
      totalErrors: _errors.length,
      errorsByType: errorsByType,
      criticalErrors:
          _errors.where((e) => e.toLowerCase().contains('critical')).toList(),
      recoverableErrors:
          _errors.where((e) => !e.toLowerCase().contains('critical')).toList(),
    );
  }

  /// Generate recommendations based on migration results
  List<String> _generateRecommendations() {
    final recommendations = <String>[];

    // Performance recommendations
    final totalDuration = migrationDuration?.inSeconds ?? 0;
    if (totalDuration > 300) {
      // 5 minutes
      recommendations.add(
          'Consider breaking large migrations into smaller batches for better performance');
    }

    // Error rate recommendations
    final errorRate =
        _totalOperations > 0 ? _failedOperations / _totalOperations : 0.0;
    if (errorRate > 0.1) {
      // 10% error rate
      recommendations.add(
          'High error rate detected. Review data validation and error handling');
    }

    // Phase timing recommendations
    for (final entry in _phaseTimings.entries) {
      if (entry.value.inSeconds > 120) {
        // 2 minutes per phase
        recommendations.add(
            'Phase ${entry.key} took ${entry.value.inSeconds}s. Consider optimization');
      }
    }

    // Success recommendations
    if (_currentPhase == MigrationPhase.completed && _failedOperations == 0) {
      recommendations.add('Migration completed successfully with no errors');
      recommendations
          .add('Consider running verification tests to ensure data integrity');
    }

    return recommendations;
  }

  /// Save migration report to file
  Future<void> _saveReportToFile(MigrationReport report) async {
    try {
      final reportsDir = Directory('migration_reports');
      await reportsDir.create(recursive: true);

      final reportFile =
          File('${reportsDir.path}/${report.migrationId}_report.json');
      await reportFile.writeAsString(jsonEncode(report.toJson()));

      _log('📄 Migration report saved: ${reportFile.path}');
    } catch (e) {
      _log('❌ Failed to save migration report: $e');
    }
  }

  /// Reset tracking state
  void _reset() {
    _currentPhase = MigrationPhase.idle;
    _currentProgress = 0.0;
    _currentOperation = '';
    _progressHistory.clear();
    _migrationStartTime = null;
    _migrationEndTime = null;
    _totalOperations = 0;
    _completedOperations = 0;
    _failedOperations = 0;
    _phaseTimings.clear();
    _errors.clear();
  }

  /// Update progress and emit event
  void _updateProgress(double progress, String operation) {
    _currentProgress = progress;
    _currentOperation = operation;

    final update = ProgressUpdate(
      phase: _currentPhase,
      progress: progress,
      operation: operation,
      timestamp: DateTime.now(),
    );

    _progressController.add(update);
  }

  /// Get description for migration phase
  String _getPhaseDescription(MigrationPhase phase) {
    switch (phase) {
      case MigrationPhase.idle:
        return 'Ready to start migration';
      case MigrationPhase.initializing:
        return 'Initializing migration services';
      case MigrationPhase.exporting:
        return 'Exporting data from SQLite';
      case MigrationPhase.transforming:
        return 'Transforming data for Supabase';
      case MigrationPhase.validating:
        return 'Validating data integrity';
      case MigrationPhase.importing:
        return 'Importing data to Supabase';
      case MigrationPhase.verifying:
        return 'Verifying migration results';
      case MigrationPhase.completed:
        return 'Migration completed successfully';
      case MigrationPhase.failed:
        return 'Migration failed';
      case MigrationPhase.rollingBack:
        return 'Rolling back migration';
    }
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    if (kDebugMode) {
      debugPrint(logEntry);
    }
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }
}

/// Migration phases
enum MigrationPhase {
  idle,
  initializing,
  exporting,
  transforming,
  validating,
  importing,
  verifying,
  completed,
  failed,
  rollingBack,
}

/// Progress update event
class ProgressUpdate {
  final MigrationPhase phase;
  final double progress;
  final String operation;
  final DateTime timestamp;

  ProgressUpdate({
    required this.phase,
    required this.progress,
    required this.operation,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'phase': phase.name,
      'progress': progress,
      'operation': operation,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Progress event for history tracking
class ProgressEvent {
  final MigrationPhase phase;
  final double progress;
  final String operation;
  final DateTime timestamp;

  ProgressEvent({
    required this.phase,
    required this.progress,
    required this.operation,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'phase': phase.name,
      'progress': progress,
      'operation': operation,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Migration statistics
class MigrationStatistics {
  final int totalOperations;
  final int completedOperations;
  final int failedOperations;
  final double successRate;
  final Map<String, Duration> phaseTimings;
  final List<String> errors;
  final List<ProgressEvent> progressHistory;

  MigrationStatistics({
    required this.totalOperations,
    required this.completedOperations,
    required this.failedOperations,
    required this.successRate,
    required this.phaseTimings,
    required this.errors,
    required this.progressHistory,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalOperations': totalOperations,
      'completedOperations': completedOperations,
      'failedOperations': failedOperations,
      'successRate': successRate,
      'phaseTimings': phaseTimings.map((k, v) => MapEntry(k, v.inMilliseconds)),
      'errors': errors,
      'progressHistoryCount': progressHistory.length,
    };
  }
}

/// Phase information for reporting
class PhaseInfo {
  final Duration duration;
  final int operationsCount;
  final Duration averageOperationTime;
  final bool success;

  PhaseInfo({
    required this.duration,
    required this.operationsCount,
    required this.averageOperationTime,
    required this.success,
  });

  Map<String, dynamic> toJson() {
    return {
      'durationMs': duration.inMilliseconds,
      'operationsCount': operationsCount,
      'averageOperationTimeMs': averageOperationTime.inMilliseconds,
      'success': success,
    };
  }
}

/// Error summary for reporting
class ErrorSummary {
  final int totalErrors;
  final Map<String, List<String>> errorsByType;
  final List<String> criticalErrors;
  final List<String> recoverableErrors;

  ErrorSummary({
    required this.totalErrors,
    required this.errorsByType,
    required this.criticalErrors,
    required this.recoverableErrors,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalErrors': totalErrors,
      'errorsByType': errorsByType,
      'criticalErrors': criticalErrors,
      'recoverableErrors': recoverableErrors,
    };
  }
}

/// Comprehensive migration report
class MigrationReport {
  final String migrationId;
  final DateTime? startTime;
  final DateTime? endTime;
  final Duration? duration;
  final MigrationPhase finalPhase;
  final MigrationStatistics statistics;
  final Map<String, PhaseInfo> phaseBreakdown;
  final ErrorSummary errorSummary;
  final List<String> recommendations;

  MigrationReport({
    required this.migrationId,
    this.startTime,
    this.endTime,
    this.duration,
    required this.finalPhase,
    required this.statistics,
    required this.phaseBreakdown,
    required this.errorSummary,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() {
    return {
      'migrationId': migrationId,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationSeconds': duration?.inSeconds,
      'finalPhase': finalPhase.name,
      'statistics': statistics.toJson(),
      'phaseBreakdown': phaseBreakdown.map((k, v) => MapEntry(k, v.toJson())),
      'errorSummary': errorSummary.toJson(),
      'recommendations': recommendations,
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }
}
