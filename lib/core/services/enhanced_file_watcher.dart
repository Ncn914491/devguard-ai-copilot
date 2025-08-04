import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'caching_service.dart';
import 'optimized_websocket_service.dart';
import '../database/services/audit_log_service.dart';

/// Enhanced file system watcher with debounced change detection and intelligent filtering
/// Satisfies Requirements: 10.4, 10.5 (Responsive file system watching with debounced change detection)
class EnhancedFileWatcher {
  static final EnhancedFileWatcher _instance = EnhancedFileWatcher._internal();
  static EnhancedFileWatcher get instance => _instance;
  EnhancedFileWatcher._internal();

  final _cachingService = CachingService.instance;
  final _websocketService = OptimizedWebSocketService.instance;
  final _auditService = AuditLogService.instance;

  // Watcher management
  final Map<String, RepositoryWatcher> _watchers = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, List<FileChangeEvent>> _pendingChanges = {};

  // Configuration
  static const Duration debounceDelay = Duration(milliseconds: 300);
  static const Duration batchProcessDelay = Duration(milliseconds: 100);
  static const int maxPendingChanges = 1000;

  // File filtering
  static const Set<String> ignoredExtensions = {
    '.tmp',
    '.temp',
    '.log',
    '.cache',
    '.lock',
    '.swp',
    '.swo',
    '~'
  };

  static const Set<String> ignoredDirectories = {
    '.git',
    '.svn',
    '.hg',
    'node_modules',
    '.dart_tool',
    'build',
    '.vscode',
    '.idea',
    'target',
    'dist',
    'out'
  };

  // Statistics
  final WatcherStats _stats = WatcherStats();
  Timer? _statsTimer;

  /// Initialize enhanced file watcher
  Future<void> initialize() async {
    // Start statistics collection
    _statsTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateStats();
    });

    await _auditService.logAction(
      actionType: 'enhanced_file_watcher_initialized',
      description:
          'Enhanced file watcher initialized with debounced change detection',
      aiReasoning:
          'File watcher provides intelligent change detection with debouncing and filtering',
      contextData: {
        'debounce_delay_ms': debounceDelay.inMilliseconds,
        'batch_process_delay_ms': batchProcessDelay.inMilliseconds,
        'max_pending_changes': maxPendingChanges,
      },
    );
  }

  /// Start watching a repository with enhanced features
  Future<void> startWatching({
    required String repositoryId,
    required String repositoryPath,
    WatcherConfig? config,
  }) async {
    try {
      // Stop existing watcher if any
      await stopWatching(repositoryId);

      final directory = Directory(repositoryPath);
      if (!await directory.exists()) {
        throw Exception('Repository directory does not exist: $repositoryPath');
      }

      final watcherConfig = config ?? WatcherConfig.defaultConfig();
      final watcher = RepositoryWatcher(
        repositoryId: repositoryId,
        repositoryPath: repositoryPath,
        config: watcherConfig,
        startedAt: DateTime.now(),
      );

      // Start file system watcher
      final stream = directory.watch(recursive: true);
      watcher.subscription = stream.listen(
        (event) => _handleFileSystemEvent(repositoryId, event, watcherConfig),
        onError: (error) => _handleWatcherError(repositoryId, error),
        onDone: () => _handleWatcherDone(repositoryId),
      );

      _watchers[repositoryId] = watcher;
      _stats.activeWatchers++;

      // Cache watcher info
      _cachingService.put(
        'file_watcher:$repositoryId',
        {
          'repository_path': repositoryPath,
          'started_at': watcher.startedAt.toIso8601String(),
          'config': watcherConfig.toMap(),
        },
        ttl: const Duration(hours: 1),
      );

      await _auditService.logAction(
        actionType: 'file_watcher_started',
        description: 'Started watching repository: $repositoryId',
        contextData: {
          'repository_id': repositoryId,
          'repository_path': repositoryPath,
          'recursive': true,
          'debounce_enabled': watcherConfig.enableDebouncing,
        },
      );
    } catch (e) {
      _stats.watcherErrors++;
      await _auditService.logAction(
        actionType: 'file_watcher_start_error',
        description: 'Error starting file watcher: ${e.toString()}',
        contextData: {
          'repository_id': repositoryId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Stop watching a repository
  Future<void> stopWatching(String repositoryId) async {
    final watcher = _watchers[repositoryId];
    if (watcher != null) {
      await watcher.subscription?.cancel();
      _watchers.remove(repositoryId);
      _stats.activeWatchers--;

      // Cancel any pending debounce timers
      _debounceTimers[repositoryId]?.cancel();
      _debounceTimers.remove(repositoryId);
      _pendingChanges.remove(repositoryId);

      // Remove from cache
      _cachingService.remove('file_watcher:$repositoryId');

      await _auditService.logAction(
        actionType: 'file_watcher_stopped',
        description: 'Stopped watching repository: $repositoryId',
        contextData: {
          'repository_id': repositoryId,
          'duration_seconds':
              DateTime.now().difference(watcher.startedAt).inSeconds,
        },
      );
    }
  }

  /// Get watcher status for a repository
  WatcherStatus? getWatcherStatus(String repositoryId) {
    final watcher = _watchers[repositoryId];
    if (watcher == null) return null;

    return WatcherStatus(
      repositoryId: repositoryId,
      isActive: true,
      startedAt: watcher.startedAt,
      eventsProcessed: watcher.eventsProcessed,
      lastEventAt: watcher.lastEventAt,
      pendingChanges: _pendingChanges[repositoryId]?.length ?? 0,
    );
  }

  /// Get all watcher statuses
  List<WatcherStatus> getAllWatcherStatuses() {
    return _watchers.keys
        .map((id) => getWatcherStatus(id))
        .where((status) => status != null)
        .cast<WatcherStatus>()
        .toList();
  }

  /// Get watcher statistics
  Map<String, dynamic> getWatcherStats() {
    return {
      'active_watchers': _stats.activeWatchers,
      'total_events_processed': _stats.totalEventsProcessed,
      'debounced_events': _stats.debouncedEvents,
      'filtered_events': _stats.filteredEvents,
      'batch_processed_events': _stats.batchProcessedEvents,
      'watcher_errors': _stats.watcherErrors,
      'average_debounce_time_ms': _stats.averageDebounceTime.inMilliseconds,
      'pending_changes_total':
          _pendingChanges.values.fold(0, (sum, list) => sum + list.length),
    };
  }

  /// Handle file system events with debouncing and filtering
  void _handleFileSystemEvent(
    String repositoryId,
    FileSystemEvent event,
    WatcherConfig config,
  ) {
    try {
      _stats.totalEventsProcessed++;

      final watcher = _watchers[repositoryId];
      if (watcher == null) return;

      watcher.eventsProcessed++;
      watcher.lastEventAt = DateTime.now();

      // Apply filtering
      if (!_shouldProcessEvent(event, config)) {
        _stats.filteredEvents++;
        return;
      }

      final changeEvent = FileChangeEvent(
        repositoryId: repositoryId,
        filePath: _getRelativePath(watcher.repositoryPath, event.path),
        eventType: _getEventType(event),
        timestamp: DateTime.now(),
        fileSize: _getFileSize(event.path),
      );

      if (config.enableDebouncing) {
        _handleDebouncedEvent(repositoryId, changeEvent, config);
      } else {
        _processFileChangeEvent(changeEvent);
      }
    } catch (e) {
      _stats.watcherErrors++;
      debugPrint('Error handling file system event: $e');
    }
  }

  /// Handle debounced file change events
  void _handleDebouncedEvent(
    String repositoryId,
    FileChangeEvent changeEvent,
    WatcherConfig config,
  ) {
    // Add to pending changes
    _pendingChanges.putIfAbsent(repositoryId, () => []).add(changeEvent);

    // Limit pending changes to prevent memory issues
    final pendingList = _pendingChanges[repositoryId]!;
    if (pendingList.length > maxPendingChanges) {
      pendingList.removeRange(0, pendingList.length - maxPendingChanges);
    }

    // Cancel existing timer and start new one
    _debounceTimers[repositoryId]?.cancel();
    _debounceTimers[repositoryId] = Timer(debounceDelay, () {
      _processPendingChanges(repositoryId, config);
    });
  }

  /// Process pending changes after debounce period
  void _processPendingChanges(String repositoryId, WatcherConfig config) {
    final pendingChanges = _pendingChanges[repositoryId];
    if (pendingChanges == null || pendingChanges.isEmpty) return;

    _stats.debouncedEvents += pendingChanges.length;

    // Group changes by file path to merge duplicate events
    final groupedChanges = <String, FileChangeEvent>{};
    for (final change in pendingChanges) {
      // Keep the latest change for each file
      groupedChanges[change.filePath] = change;
    }

    // Process grouped changes
    if (config.enableBatchProcessing) {
      _processBatchChanges(repositoryId, groupedChanges.values.toList());
    } else {
      for (final change in groupedChanges.values) {
        _processFileChangeEvent(change);
      }
    }

    // Clear pending changes
    _pendingChanges[repositoryId]?.clear();
    _debounceTimers.remove(repositoryId);
  }

  /// Process batch of file changes
  void _processBatchChanges(
      String repositoryId, List<FileChangeEvent> changes) {
    _stats.batchProcessedEvents += changes.length;

    // Create batch change event
    final batchEvent = FileBatchChangeEvent(
      repositoryId: repositoryId,
      changes: changes,
      timestamp: DateTime.now(),
    );

    // Broadcast batch change
    _websocketService.broadcastToRooms(
      roomIds: ['repo_$repositoryId', 'role_developer', 'role_lead_developer'],
      event: WebSocketEvent(
        type: 'file_batch_change',
        timestamp: batchEvent.timestamp,
        data: {
          'repository_id': repositoryId,
          'changes': changes.map((c) => c.toMap()).toList(),
          'change_count': changes.length,
        },
      ),
    );

    // Update cache with batch changes
    _updateCacheForBatchChanges(batchEvent);
  }

  /// Process individual file change event
  void _processFileChangeEvent(FileChangeEvent changeEvent) {
    // Broadcast individual change
    _websocketService.broadcastToRooms(
      roomIds: [
        'repo_${changeEvent.repositoryId}',
        'role_developer',
        'role_lead_developer'
      ],
      event: WebSocketEvent(
        type: 'file_change',
        timestamp: changeEvent.timestamp,
        data: changeEvent.toMap(),
      ),
    );

    // Update cache
    _updateCacheForFileChange(changeEvent);
  }

  /// Check if event should be processed based on filters
  bool _shouldProcessEvent(FileSystemEvent event, WatcherConfig config) {
    final filePath = event.path;
    final fileName = path.basename(filePath);
    final extension = path.extension(fileName).toLowerCase();

    // Check ignored extensions
    if (ignoredExtensions.contains(extension)) {
      return false;
    }

    // Check ignored directories
    final pathParts = path.split(filePath);
    for (final part in pathParts) {
      if (ignoredDirectories.contains(part)) {
        return false;
      }
    }

    // Check custom filters
    if (config.customFilters != null) {
      for (final filter in config.customFilters!) {
        if (!filter(filePath)) {
          return false;
        }
      }
    }

    // Check file size limits
    if (config.maxFileSizeBytes != null) {
      final fileSize = _getFileSize(filePath);
      if (fileSize > config.maxFileSizeBytes!) {
        return false;
      }
    }

    return true;
  }

  /// Get relative path from repository root
  String _getRelativePath(String repositoryPath, String absolutePath) {
    try {
      return path.relative(absolutePath, from: repositoryPath);
    } catch (e) {
      return path.basename(absolutePath);
    }
  }

  /// Get event type from FileSystemEvent
  FileChangeType _getEventType(FileSystemEvent event) {
    if (event is FileSystemCreateEvent) {
      return FileChangeType.created;
    } else if (event is FileSystemModifyEvent) {
      return FileChangeType.modified;
    } else if (event is FileSystemDeleteEvent) {
      return FileChangeType.deleted;
    } else if (event is FileSystemMoveEvent) {
      return FileChangeType.moved;
    } else {
      return FileChangeType.modified;
    }
  }

  /// Get file size safely
  int _getFileSize(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        return file.lengthSync();
      }
    } catch (e) {
      // Ignore errors
    }
    return 0;
  }

  /// Update cache for individual file change
  void _updateCacheForFileChange(FileChangeEvent changeEvent) {
    // Invalidate related cache entries
    final repoId = changeEvent.repositoryId;
    _cachingService.remove('repo_files:$repoId');
    _cachingService.remove('file:$repoId:${changeEvent.filePath}');
    _cachingService.remove('git_status:$repoId');

    // Update file change history
    final historyKey = 'file_history:$repoId:${changeEvent.filePath}';
    final history =
        _cachingService.get<List<Map<String, dynamic>>>(historyKey) ?? [];
    history.add(changeEvent.toMap());

    // Keep only last 10 changes
    if (history.length > 10) {
      history.removeRange(0, history.length - 10);
    }

    _cachingService.put(historyKey, history, ttl: const Duration(hours: 1));
  }

  /// Update cache for batch changes
  void _updateCacheForBatchChanges(FileBatchChangeEvent batchEvent) {
    final repoId = batchEvent.repositoryId;

    // Invalidate repository-level cache
    _cachingService.remove('repo_files:$repoId');
    _cachingService.remove('git_status:$repoId');

    // Update individual file caches
    for (final change in batchEvent.changes) {
      _cachingService.remove('file:$repoId:${change.filePath}');
    }

    // Store batch change summary
    _cachingService.put(
      'batch_change:$repoId:${batchEvent.timestamp.millisecondsSinceEpoch}',
      batchEvent.toMap(),
      ttl: const Duration(minutes: 30),
    );
  }

  /// Handle watcher errors
  void _handleWatcherError(String repositoryId, dynamic error) {
    _stats.watcherErrors++;
    debugPrint('File watcher error for $repositoryId: $error');

    _auditService.logAction(
      actionType: 'file_watcher_error',
      description: 'File watcher error: ${error.toString()}',
      contextData: {
        'repository_id': repositoryId,
        'error': error.toString(),
      },
    );
  }

  /// Handle watcher completion
  void _handleWatcherDone(String repositoryId) {
    debugPrint('File watcher completed for $repositoryId');

    _auditService.logAction(
      actionType: 'file_watcher_completed',
      description: 'File watcher completed for repository',
      contextData: {
        'repository_id': repositoryId,
      },
    );
  }

  /// Update statistics
  void _updateStats() {
    // Calculate average debounce time
    final totalDebounceTime = _debounceTimers.values
        .map((timer) => debounceDelay)
        .fold(Duration.zero, (sum, duration) => sum + duration);

    if (_debounceTimers.isNotEmpty) {
      _stats.averageDebounceTime = Duration(
        milliseconds:
            totalDebounceTime.inMilliseconds ~/ _debounceTimers.length,
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _statsTimer?.cancel();

    // Stop all watchers
    for (final repositoryId in _watchers.keys.toList()) {
      stopWatching(repositoryId);
    }

    // Cancel all timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }

    _watchers.clear();
    _debounceTimers.clear();
    _pendingChanges.clear();
  }
}

/// Repository watcher configuration
class WatcherConfig {
  final bool enableDebouncing;
  final bool enableBatchProcessing;
  final Duration? customDebounceDelay;
  final int? maxFileSizeBytes;
  final List<bool Function(String)>? customFilters;

  WatcherConfig({
    this.enableDebouncing = true,
    this.enableBatchProcessing = true,
    this.customDebounceDelay,
    this.maxFileSizeBytes,
    this.customFilters,
  });

  static WatcherConfig defaultConfig() {
    return WatcherConfig(
      enableDebouncing: true,
      enableBatchProcessing: true,
      maxFileSizeBytes: 10 * 1024 * 1024, // 10MB
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enable_debouncing': enableDebouncing,
      'enable_batch_processing': enableBatchProcessing,
      'custom_debounce_delay_ms': customDebounceDelay?.inMilliseconds,
      'max_file_size_bytes': maxFileSizeBytes,
      'has_custom_filters': customFilters != null,
    };
  }
}

/// Repository watcher instance
class RepositoryWatcher {
  final String repositoryId;
  final String repositoryPath;
  final WatcherConfig config;
  final DateTime startedAt;
  StreamSubscription<FileSystemEvent>? subscription;
  int eventsProcessed = 0;
  DateTime? lastEventAt;

  RepositoryWatcher({
    required this.repositoryId,
    required this.repositoryPath,
    required this.config,
    required this.startedAt,
  });
}

/// Watcher status information
class WatcherStatus {
  final String repositoryId;
  final bool isActive;
  final DateTime startedAt;
  final int eventsProcessed;
  final DateTime? lastEventAt;
  final int pendingChanges;

  WatcherStatus({
    required this.repositoryId,
    required this.isActive,
    required this.startedAt,
    required this.eventsProcessed,
    this.lastEventAt,
    required this.pendingChanges,
  });

  Map<String, dynamic> toMap() {
    return {
      'repository_id': repositoryId,
      'is_active': isActive,
      'started_at': startedAt.toIso8601String(),
      'events_processed': eventsProcessed,
      'last_event_at': lastEventAt?.toIso8601String(),
      'pending_changes': pendingChanges,
    };
  }
}

/// File change event
class FileChangeEvent {
  final String repositoryId;
  final String filePath;
  final FileChangeType eventType;
  final DateTime timestamp;
  final int fileSize;

  FileChangeEvent({
    required this.repositoryId,
    required this.filePath,
    required this.eventType,
    required this.timestamp,
    required this.fileSize,
  });

  Map<String, dynamic> toMap() {
    return {
      'repository_id': repositoryId,
      'file_path': filePath,
      'event_type': eventType.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'file_size': fileSize,
    };
  }
}

/// Batch file change event
class FileBatchChangeEvent {
  final String repositoryId;
  final List<FileChangeEvent> changes;
  final DateTime timestamp;

  FileBatchChangeEvent({
    required this.repositoryId,
    required this.changes,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'repository_id': repositoryId,
      'changes': changes.map((c) => c.toMap()).toList(),
      'change_count': changes.length,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// File change types
enum FileChangeType {
  created,
  modified,
  deleted,
  moved,
}

/// Watcher statistics
class WatcherStats {
  int activeWatchers = 0;
  int totalEventsProcessed = 0;
  int debouncedEvents = 0;
  int filteredEvents = 0;
  int batchProcessedEvents = 0;
  int watcherErrors = 0;
  Duration averageDebounceTime = Duration.zero;
}
