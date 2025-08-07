import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../supabase/services/supabase_storage_service.dart';
import '../auth/auth_service.dart';
import '../database/services/audit_log_service.dart';
import '../api/websocket_service.dart';
import 'caching_service.dart';

/// Enhanced file system service that uses Supabase Storage instead of local files
/// Replaces local file operations with cloud storage operations
/// Requirements: 5.1, 5.2, 5.3, 5.4 - File storage with proper access controls
class SupabaseFileSystemService extends ChangeNotifier {
  static final SupabaseFileSystemService _instance =
      SupabaseFileSystemService._internal();
  static SupabaseFileSystemService get instance => _instance;
  SupabaseFileSystemService._internal();

  final _storageService = SupabaseStorageService.instance;
  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;
  final _websocketService = WebSocketService.instance;
  final _cachingService = CachingService.instance;

  // File watching and collaboration
  final Map<String, StreamSubscription> _fileWatchers = {};
  final Map<String, FileLock> _fileLocks = {};

  // Search indexing for cloud files
  final Map<String, CloudFileSearchIndex> _searchIndexes = {};

  /// Default bucket for project files
  static const String projectFilesBucket = 'project-files';
  static const String repositoryFilesBucket = 'repository-files';
  static const String userFilesBucket = 'user-files';

  /// Start watching a repository for file changes using Supabase Storage
  Future<void> startWatching(String repositoryId) async {
    try {
      // Initialize search index for this repository
      await _buildSearchIndex(repositoryId);

      await _auditService.logAction(
        actionType: 'supabase_file_watching_started',
        description:
            'Started watching repository files in Supabase Storage: $repositoryId',
        contextData: {
          'repository_id': repositoryId,
          'bucket': repositoryFilesBucket,
          'storage_type': 'supabase',
        },
        userId: _authService.currentUser?.id,
      );
    } catch (e) {
      debugPrint('Error starting Supabase file watcher: $e');
    }
  }

  /// Stop watching a repository
  Future<void> stopWatching(String repositoryId) async {
    final watcher = _fileWatchers[repositoryId];
    if (watcher != null) {
      await watcher.cancel();
      _fileWatchers.remove(repositoryId);
    }

    // Clean up search index
    _searchIndexes.remove(repositoryId);
  }

  /// Upload file to repository bucket
  Future<String> uploadRepositoryFile({
    required String repositoryId,
    required String filePath,
    required File file,
    Map<String, String>? metadata,
  }) async {
    try {
      // Generate cloud file path
      final cloudPath = _generateCloudPath(repositoryId, filePath);

      // Upload file to Supabase Storage
      final uploadedPath = await _storageService.uploadFile(
        repositoryFilesBucket,
        cloudPath,
        file,
        metadata: metadata,
      );

      // Update search index
      await _updateSearchIndex(repositoryId, filePath, 'created');

      // Broadcast file change via WebSocket
      await _websocketService.broadcastFileChange(
        repositoryId: repositoryId,
        filePath: filePath,
        change: {
          'action': 'uploaded',
          'file_path': filePath,
          'cloud_path': uploadedPath,
          'timestamp': DateTime.now().toIso8601String(),
          'modified_by': _authService.currentUser?.id,
        },
        targetUsers: await _getRepositoryCollaborators(repositoryId),
      );

      // Notify listeners
      notifyListeners();

      await _auditService.logAction(
        actionType: 'repository_file_uploaded',
        description: 'Uploaded file to repository: $filePath',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'cloud_path': uploadedPath,
          'file_size': await file.length(),
        },
        userId: _authService.currentUser?.id,
      );

      return uploadedPath;
    } catch (e) {
      debugPrint('Error uploading repository file: $e');
      rethrow;
    }
  }

  /// Download file from repository bucket
  Future<Uint8List> downloadRepositoryFile({
    required String repositoryId,
    required String filePath,
  }) async {
    try {
      // Generate cloud file path
      final cloudPath = _generateCloudPath(repositoryId, filePath);

      // Download file from Supabase Storage
      final data = await _storageService.downloadFile(
        repositoryFilesBucket,
        cloudPath,
      );

      await _auditService.logAction(
        actionType: 'repository_file_downloaded',
        description: 'Downloaded file from repository: $filePath',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'cloud_path': cloudPath,
          'file_size': data.length,
        },
        userId: _authService.currentUser?.id,
      );

      return data;
    } catch (e) {
      debugPrint('Error downloading repository file: $e');
      rethrow;
    }
  }

  /// Update file content in repository bucket
  Future<void> updateRepositoryFile({
    required String repositoryId,
    required String filePath,
    required String content,
  }) async {
    try {
      // Create temporary file with content
      final tempFile = File(
          '${Directory.systemTemp.path}/temp_${DateTime.now().millisecondsSinceEpoch}.txt');
      await tempFile.writeAsString(content);

      try {
        // Upload updated file
        await uploadRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
          file: tempFile,
        );

        // Update search index
        await _updateSearchIndex(repositoryId, filePath, 'modified');

        // Broadcast file change via WebSocket
        await _websocketService.broadcastFileChange(
          repositoryId: repositoryId,
          filePath: filePath,
          change: {
            'action': 'modified',
            'file_path': filePath,
            'content_length': content.length,
            'modified_by': _authService.currentUser?.id,
          },
          targetUsers: await _getRepositoryCollaborators(repositoryId),
        );

        await _auditService.logAction(
          actionType: 'repository_file_updated',
          description: 'Updated file content: $filePath',
          contextData: {
            'repository_id': repositoryId,
            'file_path': filePath,
            'content_length': content.length,
          },
          userId: _authService.currentUser?.id,
        );
      } finally {
        // Clean up temporary file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      debugPrint('Error updating repository file: $e');
      rethrow;
    }
  }

  /// Delete file from repository bucket
  Future<void> deleteRepositoryFile({
    required String repositoryId,
    required String filePath,
  }) async {
    try {
      // Generate cloud file path
      final cloudPath = _generateCloudPath(repositoryId, filePath);

      // Delete file from Supabase Storage
      await _storageService.deleteFile(repositoryFilesBucket, cloudPath);

      // Update search index
      await _updateSearchIndex(repositoryId, filePath, 'deleted');

      // Broadcast file change via WebSocket
      await _websocketService.broadcastFileChange(
        repositoryId: repositoryId,
        filePath: filePath,
        change: {
          'action': 'deleted',
          'file_path': filePath,
          'timestamp': DateTime.now().toIso8601String(),
          'modified_by': _authService.currentUser?.id,
        },
        targetUsers: await _getRepositoryCollaborators(repositoryId),
      );

      // Notify listeners
      notifyListeners();

      await _auditService.logAction(
        actionType: 'repository_file_deleted',
        description: 'Deleted file from repository: $filePath',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'cloud_path': cloudPath,
        },
        userId: _authService.currentUser?.id,
      );
    } catch (e) {
      debugPrint('Error deleting repository file: $e');
      rethrow;
    }
  }

  /// List files in repository bucket
  Future<List<CloudFileInfo>> listRepositoryFiles({
    required String repositoryId,
    String? pathPrefix,
  }) async {
    try {
      final repositoryPrefix = '$repositoryId/';
      final fullPrefix = pathPrefix != null
          ? '$repositoryPrefix$pathPrefix'
          : repositoryPrefix;

      final files = await _storageService.listFiles(
        repositoryFilesBucket,
        prefix: fullPrefix,
      );

      final cloudFiles = files.map((file) {
        // Remove repository prefix from file name to get relative path
        final relativePath = file.name.startsWith(repositoryPrefix)
            ? file.name.substring(repositoryPrefix.length)
            : file.name;

        return CloudFileInfo(
          name: relativePath.split('/').last,
          path: relativePath,
          cloudPath: file.name,
          size: file.metadata?['size'] ?? 0,
          contentType: file.metadata?['mimetype'] ?? 'application/octet-stream',
          lastModified: file.updatedAt ?? DateTime.now(),
          bucket: repositoryFilesBucket,
        );
      }).toList();

      await _auditService.logAction(
        actionType: 'repository_files_listed',
        description: 'Listed repository files',
        contextData: {
          'repository_id': repositoryId,
          'file_count': cloudFiles.length,
          'path_prefix': pathPrefix,
        },
        userId: _authService.currentUser?.id,
      );

      return cloudFiles;
    } catch (e) {
      debugPrint('Error listing repository files: $e');
      rethrow;
    }
  }

  /// Search files in repository with caching
  Future<List<CloudFileSearchResult>> searchFiles({
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
            .map((result) => CloudFileSearchResult.fromMap(result))
            .toList();
      }

      final index = _searchIndexes[repositoryId];
      if (index == null) {
        await _buildSearchIndex(repositoryId);
      }

      final results = <CloudFileSearchResult>[];
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
          results.add(CloudFileSearchResult(
            filePath: filePath,
            fileName: fileName,
            matchType: CloudFileSearchMatchType.fileName,
            lineNumber: null,
            lineContent: null,
            score: _calculateScore(searchQuery, searchFileName),
            cloudPath: fileInfo.cloudPath,
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
                results.add(CloudFileSearchResult(
                  filePath: filePath,
                  fileName: fileName,
                  matchType: CloudFileSearchMatchType.content,
                  lineNumber: i + 1,
                  lineContent: lines[i].trim(),
                  score: _calculateScore(searchQuery, line),
                  cloudPath: fileInfo.cloudPath,
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
        actionType: 'cloud_file_search_performed',
        description: 'Searched cloud files: $query',
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
      debugPrint('Error searching cloud files: $e');
      return [];
    }
  }

  /// Lock file for editing (same as original implementation)
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
        actionType: 'cloud_file_locked',
        description: 'Locked cloud file for editing: $filePath',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'lock_duration': lockDuration?.inMinutes,
        },
        userId: _authService.currentUser?.id,
      );

      return true;
    } catch (e) {
      debugPrint('Error locking cloud file: $e');
      return false;
    }
  }

  /// Unlock file (same as original implementation)
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
          actionType: 'cloud_file_unlocked',
          description: 'Unlocked cloud file: $filePath',
          contextData: {
            'repository_id': repositoryId,
            'file_path': filePath,
          },
          userId: _authService.currentUser?.id,
        );
      }
    } catch (e) {
      debugPrint('Error unlocking cloud file: $e');
    }
  }

  /// Check if file is locked (same as original implementation)
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

  /// Helper methods

  /// Generate cloud path for repository file
  String _generateCloudPath(String repositoryId, String filePath) {
    return '$repositoryId/$filePath';
  }

  /// Get repository collaborators (mock implementation)
  Future<List<String>> _getRepositoryCollaborators(String repositoryId) async {
    // In a real implementation, this would fetch from the database
    final currentUser = _authService.currentUser;
    return currentUser != null ? [currentUser.id] : [];
  }

  /// Build search index for repository
  Future<void> _buildSearchIndex(String repositoryId) async {
    try {
      final files = await listRepositoryFiles(repositoryId: repositoryId);
      final index = CloudFileSearchIndex(repositoryId: repositoryId);

      for (final file in files) {
        final fileInfo = CloudFileIndexInfo(
          path: file.path,
          name: file.name,
          cloudPath: file.cloudPath,
          size: file.size,
          modifiedAt: file.lastModified,
          isTextFile: _isTextFile(file.name),
        );

        // Index text file content
        if (fileInfo.isTextFile && file.size < 1024 * 1024) {
          // Max 1MB
          try {
            final content = await downloadRepositoryFile(
              repositoryId: repositoryId,
              filePath: file.path,
            );
            fileInfo.content = String.fromCharCodes(content);
          } catch (e) {
            debugPrint('Error indexing file content: $e');
          }
        }

        index.files[file.path] = fileInfo;
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
        final files = await listRepositoryFiles(repositoryId: repositoryId);
        final file = files.firstWhere(
          (f) => f.path == filePath,
          orElse: () => throw Exception('File not found'),
        );

        final fileInfo = CloudFileIndexInfo(
          path: file.path,
          name: file.name,
          cloudPath: file.cloudPath,
          size: file.size,
          modifiedAt: file.lastModified,
          isTextFile: _isTextFile(file.name),
        );

        if (fileInfo.isTextFile && file.size < 1024 * 1024) {
          try {
            final content = await downloadRepositoryFile(
              repositoryId: repositoryId,
              filePath: filePath,
            );
            fileInfo.content = String.fromCharCodes(content);
          } catch (e) {
            debugPrint('Error updating file content in index: $e');
          }
        }

        index.files[filePath] = fileInfo;
      } catch (e) {
        debugPrint('Error updating search index: $e');
      }
    }
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

/// Data models for cloud file operations

class CloudFileInfo {
  final String name;
  final String path;
  final String cloudPath;
  final int size;
  final String contentType;
  final DateTime lastModified;
  final String bucket;

  CloudFileInfo({
    required this.name,
    required this.path,
    required this.cloudPath,
    required this.size,
    required this.contentType,
    required this.lastModified,
    required this.bucket,
  });
}

class CloudFileSearchIndex {
  final String repositoryId;
  final Map<String, CloudFileIndexInfo> files = {};

  CloudFileSearchIndex({required this.repositoryId});
}

class CloudFileIndexInfo {
  final String path;
  final String name;
  final String cloudPath;
  final int size;
  final DateTime modifiedAt;
  final bool isTextFile;
  String? content;

  CloudFileIndexInfo({
    required this.path,
    required this.name,
    required this.cloudPath,
    required this.size,
    required this.modifiedAt,
    required this.isTextFile,
    this.content,
  });
}

class CloudFileSearchResult {
  final String filePath;
  final String fileName;
  final CloudFileSearchMatchType matchType;
  final int? lineNumber;
  final String? lineContent;
  final double score;
  final String cloudPath;

  CloudFileSearchResult({
    required this.filePath,
    required this.fileName,
    required this.matchType,
    this.lineNumber,
    this.lineContent,
    required this.score,
    required this.cloudPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'file_path': filePath,
      'file_name': fileName,
      'match_type': matchType.toString().split('.').last,
      'line_number': lineNumber,
      'line_content': lineContent,
      'score': score,
      'cloud_path': cloudPath,
    };
  }

  factory CloudFileSearchResult.fromMap(Map<String, dynamic> map) {
    return CloudFileSearchResult(
      filePath: map['file_path'],
      fileName: map['file_name'],
      matchType: CloudFileSearchMatchType.values.firstWhere(
        (e) => e.toString().split('.').last == map['match_type'],
        orElse: () => CloudFileSearchMatchType.fileName,
      ),
      lineNumber: map['line_number'],
      lineContent: map['line_content'],
      score: map['score']?.toDouble() ?? 0.0,
      cloudPath: map['cloud_path'],
    );
  }
}

enum CloudFileSearchMatchType {
  fileName,
  content,
}

/// File lock model (same as original)
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
