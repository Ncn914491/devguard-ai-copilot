import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../api/repository_api.dart';
import '../auth/auth_service.dart';
import '../database/services/audit_log_service.dart';
import '../api/websocket_service.dart';
import 'caching_service.dart';
import 'enhanced_file_watcher.dart';

/// Advanced file system service with git integration, search, and collaboration
/// Satisfies Requirements: 8.1, 8.2, 8.3, 8.4, 8.5
class FileSystemService extends ChangeNotifier {
  static final FileSystemService _instance = FileSystemService._internal();
  static FileSystemService get instance => _instance;
  FileSystemService._internal();

  final _repositoryAPI = RepositoryAPI.instance;
  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;
  final _websocketService = WebSocketService.instance;
  final _cachingService = CachingService.instance;
  final _enhancedFileWatcher = EnhancedFileWatcher.instance;

  // File watching
  final Map<String, StreamSubscription> _fileWatchers = {};
  final Map<String, DateTime> _lastChangeTime = {};
  final Duration _debounceDelay = const Duration(milliseconds: 500);

  // File locking for collaboration
  final Map<String, FileLock> _fileLocks = {};

  // Search indexing
  final Map<String, FileSearchIndex> _searchIndexes = {};

  /// Start watching a repository for file changes with enhanced performance
  Future<void> startWatching(String repositoryId) async {
    try {
      final repoResponse = await _repositoryAPI.getRepository(repositoryId);
      if (!repoResponse.success || repoResponse.data == null) {
        return;
      }

      final repository = repoResponse.data!;

      // Use enhanced file watcher with performance optimizations
      await _enhancedFileWatcher.startWatching(
        repositoryId: repositoryId,
        repositoryPath: repository.localPath,
        config: WatcherConfig.defaultConfig(),
      );

      await _auditService.logAction(
        actionType: 'enhanced_file_watching_started',
        description:
            'Started enhanced watching for repository: ${repository.name}',
        contextData: {
          'repository_id': repositoryId,
          'local_path': repository.localPath,
          'enhanced_features': [
            'debouncing',
            'batch_processing',
            'intelligent_filtering'
          ],
        },
        userId: _authService.currentUser?.id,
      );
    } catch (e) {
      debugPrint('Error starting enhanced file watcher: $e');
    }
  }

  /// Stop watching a repository
  Future<void> stopWatching(String repositoryId) async {
    // Use enhanced file watcher
    await _enhancedFileWatcher.stopWatching(repositoryId);

    // Clean up legacy watchers if any
    final watcher = _fileWatchers[repositoryId];
    if (watcher != null) {
      await watcher.cancel();
      _fileWatchers.remove(repositoryId);
    }
  }

  /// Handle file system events with debouncing
  void _handleFileSystemEvent(String repositoryId, FileSystemEvent event) {
    final now = DateTime.now();
    final lastChange = _lastChangeTime[event.path];

    // Debounce rapid changes
    if (lastChange != null && now.difference(lastChange) < _debounceDelay) {
      return;
    }

    _lastChangeTime[event.path] = now;

    // Process the event after debounce delay
    Timer(_debounceDelay, () {
      _processFileSystemEvent(repositoryId, event);
    });
  }

  /// Process file system event
  Future<void> _processFileSystemEvent(
      String repositoryId, FileSystemEvent event) async {
    try {
      final relativePath = _getRelativePath(repositoryId, event.path);
      if (relativePath == null) return;

      String eventType;
      if (event is FileSystemCreateEvent) {
        eventType = 'created';
      } else if (event is FileSystemModifyEvent) {
        eventType = 'modified';
      } else if (event is FileSystemDeleteEvent) {
        eventType = 'deleted';
      } else if (event is FileSystemMoveEvent) {
        eventType = 'moved';
      } else {
        eventType = 'changed';
      }

      // Update search index
      await _updateSearchIndex(repositoryId, relativePath, eventType);

      // Broadcast change via WebSocket
      await _websocketService.broadcastFileChange(
        repositoryId: repositoryId,
        filePath: relativePath,
        change: {
          'action': eventType,
          'file_path': relativePath,
          'timestamp': DateTime.now().toIso8601String(),
          'modified_by': _authService.currentUser?.id,
        },
        targetUsers: await _getRepositoryCollaborators(repositoryId),
      );

      // Notify listeners
      notifyListeners();

      await _auditService.logAction(
        actionType: 'file_system_event',
        description: 'File system event: $eventType - $relativePath',
        contextData: {
          'repository_id': repositoryId,
          'file_path': relativePath,
          'event_type': eventType,
        },
        userId: _authService.currentUser?.id,
      );
    } catch (e) {
      debugPrint('Error processing file system event: $e');
    }
  }

  /// Search files in repository with caching
  Future<List<FileSearchResult>> searchFiles({
    required String repositoryId,
    required String query,
    List<String>? fileTypes,
    bool caseSensitive = false,
    int maxResults = 100,
  }) async {
    try {
      // Check cache first
      final cachedResults =
          _cachingService.getSearchResults(query, repositoryId);
      if (cachedResults != null) {
        return cachedResults
            .map((result) => FileSearchResult.fromMap(result))
            .toList();
      }

      final index = _searchIndexes[repositoryId];
      if (index == null) {
        await _buildSearchIndex(repositoryId);
      }

      final results = <FileSearchResult>[];
      final searchIndex = _searchIndexes[repositoryId];
      if (searchIndex == null) return results;

      final searchQuery = caseSensitive ? query : query.toLowerCase();

      for (final entry in searchIndex.files.entries) {
        final filePath = entry.key;
        final fileInfo = entry.value;

        // Filter by file type if specified
        if (fileTypes != null && fileTypes.isNotEmpty) {
          final extension = filePath.split('.').last.toLowerCase();
          if (!fileTypes.contains(extension)) continue;
        }

        // Search in file name
        final fileName = filePath.split('/').last;
        final searchFileName =
            caseSensitive ? fileName : fileName.toLowerCase();
        if (searchFileName.contains(searchQuery)) {
          results.add(FileSearchResult(
            filePath: filePath,
            fileName: fileName,
            matchType: FileSearchMatchType.fileName,
            lineNumber: null,
            lineContent: null,
            score: _calculateScore(searchQuery, searchFileName),
          ));
        }

        // Search in file content for text files
        if (fileInfo.isTextFile && fileInfo.content != null) {
          final content = caseSensitive
              ? fileInfo.content!
              : fileInfo.content!.toLowerCase();
          if (content.contains(searchQuery)) {
            final lines = fileInfo.content!.split('\n');
            for (int i = 0; i < lines.length; i++) {
              final line = caseSensitive ? lines[i] : lines[i].toLowerCase();
              if (line.contains(searchQuery)) {
                results.add(FileSearchResult(
                  filePath: filePath,
                  fileName: fileName,
                  matchType: FileSearchMatchType.content,
                  lineNumber: i + 1,
                  lineContent: lines[i].trim(),
                  score: _calculateScore(searchQuery, line),
                ));
              }
            }
          }
        }

        if (results.length >= maxResults) break;
      }

      // Sort by score (relevance)
      results.sort((a, b) => b.score.compareTo(a.score));

      // Cache search results
      _cachingService.putSearchResults(
          query, repositoryId, results.map((r) => r.toMap()).toList());

      await _auditService.logAction(
        actionType: 'file_search_performed',
        description: 'Searched files: $query',
        contextData: {
          'repository_id': repositoryId,
          'query': query,
          'results_count': results.length,
          'file_types': fileTypes,
          'cached': false,
        },
        userId: _authService.currentUser?.id,
      );

      return results;
    } catch (e) {
      debugPrint('Error searching files: $e');
      return [];
    }
  }

  /// Lock file for editing
  Future<bool> lockFile({
    required String repositoryId,
    required String filePath,
    Duration? lockDuration,
  }) async {
    try {
      final lockKey = '$repositoryId:$filePath';
      final existingLock = _fileLocks[lockKey];

      // Check if file is already locked by another user
      if (existingLock != null &&
          existingLock.userId != _authService.currentUser?.id &&
          !existingLock.isExpired) {
        return false;
      }

      final lock = FileLock(
        repositoryId: repositoryId,
        filePath: filePath,
        userId: _authService.currentUser!.id,
        lockedAt: DateTime.now(),
        expiresAt:
            DateTime.now().add(lockDuration ?? const Duration(minutes: 30)),
      );

      _fileLocks[lockKey] = lock;

      // Broadcast lock via WebSocket
      await _websocketService.broadcastFileLock(
        repositoryId: repositoryId,
        filePath: filePath,
        lock: {
          'action': 'locked',
          'user_id': lock.userId,
          'locked_at': lock.lockedAt.toIso8601String(),
          'expires_at': lock.expiresAt.toIso8601String(),
        },
        targetUsers: await _getRepositoryCollaborators(repositoryId),
      );

      await _auditService.logAction(
        actionType: 'file_locked',
        description: 'Locked file for editing: $filePath',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'lock_duration': lockDuration?.inMinutes,
        },
        userId: _authService.currentUser?.id,
      );

      return true;
    } catch (e) {
      debugPrint('Error locking file: $e');
      return false;
    }
  }

  /// Unlock file
  Future<void> unlockFile({
    required String repositoryId,
    required String filePath,
  }) async {
    try {
      final lockKey = '$repositoryId:$filePath';
      final lock = _fileLocks[lockKey];

      if (lock != null && lock.userId == _authService.currentUser?.id) {
        _fileLocks.remove(lockKey);

        // Broadcast unlock via WebSocket
        await _websocketService.broadcastFileLock(
          repositoryId: repositoryId,
          filePath: filePath,
          lock: {
            'action': 'unlocked',
            'user_id': lock.userId,
            'unlocked_at': DateTime.now().toIso8601String(),
          },
          targetUsers: await _getRepositoryCollaborators(repositoryId),
        );

        await _auditService.logAction(
          actionType: 'file_unlocked',
          description: 'Unlocked file: $filePath',
          contextData: {
            'repository_id': repositoryId,
            'file_path': filePath,
          },
          userId: _authService.currentUser?.id,
        );
      }
    } catch (e) {
      debugPrint('Error unlocking file: $e');
    }
  }

  /// Check if file is locked
  FileLock? getFileLock({
    required String repositoryId,
    required String filePath,
  }) {
    final lockKey = '$repositoryId:$filePath';
    final lock = _fileLocks[lockKey];

    if (lock != null && lock.isExpired) {
      _fileLocks.remove(lockKey);
      return null;
    }

    return lock;
  }

  /// Build search index for repository
  Future<void> _buildSearchIndex(String repositoryId) async {
    try {
      final filesResponse =
          await _repositoryAPI.getRepositoryFiles(repositoryId);
      if (!filesResponse.success || filesResponse.data == null) {
        return;
      }

      final index = FileSearchIndex(repositoryId: repositoryId);

      for (final file in filesResponse.data!) {
        if (file.type == 'file') {
          final fileInfo = FileIndexInfo(
            path: file.path,
            name: file.name,
            size: file.size,
            modifiedAt: file.modifiedAt,
            isTextFile: _isTextFile(file.name),
          );

          // Index text file content
          if (fileInfo.isTextFile && file.size < 1024 * 1024) {
            // Max 1MB
            try {
              final contentResponse = await _repositoryAPI.getFileContent(
                repoId: repositoryId,
                filePath: file.path,
              );
              if (contentResponse.success && contentResponse.data != null) {
                fileInfo.content = contentResponse.data;
              }
            } catch (e) {
              debugPrint('Error indexing file content: $e');
            }
          }

          index.files[file.path] = fileInfo;
        }
      }

      _searchIndexes[repositoryId] = index;
    } catch (e) {
      debugPrint('Error building search index: $e');
    }
  }

  /// Update search index for a specific file
  Future<void> _updateSearchIndex(
      String repositoryId, String filePath, String eventType) async {
    final index = _searchIndexes[repositoryId];
    if (index == null) return;

    if (eventType == 'deleted') {
      index.files.remove(filePath);
    } else {
      // Update or add file to index
      try {
        final contentResponse = await _repositoryAPI.getFileContent(
          repoId: repositoryId,
          filePath: filePath,
        );

        if (contentResponse.success && contentResponse.data != null) {
          final fileName = filePath.split('/').last;
          final fileInfo = FileIndexInfo(
            path: filePath,
            name: fileName,
            size: contentResponse.data!.length,
            modifiedAt: DateTime.now(),
            isTextFile: _isTextFile(fileName),
            content: _isTextFile(fileName) ? contentResponse.data : null,
          );

          index.files[filePath] = fileInfo;
        }
      } catch (e) {
        debugPrint('Error updating search index: $e');
      }
    }
  }

  /// Helper methods
  String? _getRelativePath(String repositoryId, String absolutePath) {
    // Implementation would convert absolute path to relative path
    // This is a simplified version
    return absolutePath.split('/').last;
  }

  Future<List<String>> _getRepositoryCollaborators(String repositoryId) async {
    final repoResponse = await _repositoryAPI.getRepository(repositoryId);
    if (!repoResponse.success || repoResponse.data == null) {
      return [];
    }

    final repository = repoResponse.data!;
    final collaborators = [repository.ownerId];
    collaborators.addAll(repository.collaborators.map((c) => c.userId));
    return collaborators;
  }

  bool _isTextFile(String fileName) {
    final textExtensions = {
      'dart',
      'js',
      'ts',
      'html',
      'css',
      'json',
      'yaml',
      'yml',
      'md',
      'txt',
      'py',
      'java',
      'cpp',
      'c',
      'h',
      'xml',
      'sql',
      'sh',
      'bat',
      'ps1'
    };
    final extension = fileName.split('.').last.toLowerCase();
    return textExtensions.contains(extension);
  }

  double _calculateScore(String query, String text) {
    if (text.startsWith(query)) return 1.0;
    if (text.contains(query)) return 0.8;
    return 0.5;
  }

  /// Cleanup resources
  @override
  void dispose() {
    for (final watcher in _fileWatchers.values) {
      watcher.cancel();
    }
    _fileWatchers.clear();
    super.dispose();
  }
}

/// File lock model
class FileLock {
  final String repositoryId;
  final String filePath;
  final String userId;
  final DateTime lockedAt;
  final DateTime expiresAt;

  FileLock({
    required this.repositoryId,
    required this.filePath,
    required this.userId,
    required this.lockedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Search index models
class FileSearchIndex {
  final String repositoryId;
  final Map<String, FileIndexInfo> files = {};

  FileSearchIndex({required this.repositoryId});
}

class FileIndexInfo {
  final String path;
  final String name;
  final int size;
  final DateTime modifiedAt;
  final bool isTextFile;
  String? content;

  FileIndexInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.modifiedAt,
    required this.isTextFile,
    this.content,
  });
}

/// Search result models
class FileSearchResult {
  final String filePath;
  final String fileName;
  final FileSearchMatchType matchType;
  final int? lineNumber;
  final String? lineContent;
  final double score;

  FileSearchResult({
    required this.filePath,
    required this.fileName,
    required this.matchType,
    this.lineNumber,
    this.lineContent,
    required this.score,
  });

  Map<String, dynamic> toMap() {
    return {
      'file_path': filePath,
      'file_name': fileName,
      'match_type': matchType.toString().split('.').last,
      'line_number': lineNumber,
      'line_content': lineContent,
      'score': score,
    };
  }

  factory FileSearchResult.fromMap(Map<String, dynamic> map) {
    return FileSearchResult(
      filePath: map['file_path'],
      fileName: map['file_name'],
      matchType: FileSearchMatchType.values.firstWhere(
        (e) => e.toString().split('.').last == map['match_type'],
        orElse: () => FileSearchMatchType.fileName,
      ),
      lineNumber: map['line_number'],
      lineContent: map['line_content'],
      score: map['score']?.toDouble() ?? 0.0,
    );
  }
}

enum FileSearchMatchType {
  fileName,
  content,
}
