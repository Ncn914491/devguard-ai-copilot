import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';
import '../supabase_error_handler.dart';

/// Service for managing file uploads and downloads using Supabase Storage
/// Provides file upload with progress tracking, download with caching, and bucket management
/// Requirements: 5.1, 5.2, 5.3, 5.4 - File storage with proper access controls
class SupabaseStorageService {
  static final SupabaseStorageService _instance =
      SupabaseStorageService._internal();
  static SupabaseStorageService get instance => _instance;

  SupabaseStorageService._internal();

  /// Get the Supabase client instance
  SupabaseClient get _client => SupabaseService.instance.client;

  /// Cache for downloaded files to improve performance
  final Map<String, Uint8List> _fileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Cache duration (1 hour)
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Default bucket names for different file types
  static const String projectFilesBucket = 'project-files';
  static const String userAvatarsBucket = 'user-avatars';
  static const String documentsBucket = 'documents';
  static const String tempFilesBucket = 'temp-files';

  /// Upload a file to Supabase Storage with progress tracking
  /// Returns the file path in the bucket
  Future<String> uploadFile(
    String bucket,
    String path,
    File file, {
    Map<String, String>? metadata,
  }) async {
    try {
      // Validate inputs
      if (bucket.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }
      if (path.isEmpty) {
        throw AppError.validation('File path cannot be empty');
      }
      if (!await file.exists()) {
        throw AppError.validation('File does not exist');
      }

      // Check file size (limit to 50MB)
      final fileSize = await file.length();
      if (fileSize > 50 * 1024 * 1024) {
        throw AppError.validation('File size cannot exceed 50MB');
      }

      debugPrint('📤 Uploading file: $path to bucket: $bucket');
      debugPrint(
          '📊 File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Read file bytes
      final fileBytes = await file.readAsBytes();

      // Upload file
      final response = await RetryPolicy.withRetry(
        () => _client.storage.from(bucket).uploadBinary(
              path,
              fileBytes,
              fileOptions: FileOptions(
                cacheControl: '3600',
                upsert: true,
                contentType: _getContentType(path),
              ),
            ),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      debugPrint('✅ File uploaded successfully: $response');

      // Clear cache for this file if it exists
      _clearFileFromCache(bucket, path);

      return path;
    } catch (e) {
      debugPrint('❌ File upload failed: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Upload file with progress tracking
  /// Returns a stream of upload progress (0.0 to 1.0)
  Stream<double> uploadWithProgress(
    String bucket,
    String path,
    File file, {
    Map<String, String>? metadata,
  }) async* {
    try {
      // Validate inputs
      if (bucket.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }
      if (path.isEmpty) {
        throw AppError.validation('File path cannot be empty');
      }
      if (!await file.exists()) {
        throw AppError.validation('File does not exist');
      }

      final fileSize = await file.length();
      if (fileSize > 50 * 1024 * 1024) {
        throw AppError.validation('File size cannot exceed 50MB');
      }

      debugPrint('📤 Starting upload with progress: $path');

      // Simulate progress for now (Supabase doesn't provide native progress tracking)
      // In a real implementation, you might chunk the file and upload in parts
      yield 0.0;

      await Future.delayed(const Duration(milliseconds: 100));
      yield 0.1;

      final fileBytes = await file.readAsBytes();
      yield 0.3;

      await Future.delayed(const Duration(milliseconds: 100));
      yield 0.5;

      // Upload file
      await _client.storage.from(bucket).uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: _getContentType(path),
            ),
          );

      yield 0.9;
      await Future.delayed(const Duration(milliseconds: 100));
      yield 1.0;

      debugPrint('✅ File uploaded with progress tracking: $path');

      // Clear cache for this file if it exists
      _clearFileFromCache(bucket, path);
    } catch (e) {
      debugPrint('❌ File upload with progress failed: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Download a file from Supabase Storage with caching
  Future<Uint8List> downloadFile(String bucket, String path) async {
    try {
      // Validate inputs
      if (bucket.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }
      if (path.isEmpty) {
        throw AppError.validation('File path cannot be empty');
      }

      final cacheKey = '$bucket/$path';

      // Check cache first
      if (_fileCache.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey];
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime) < _cacheDuration) {
          debugPrint('📋 Returning cached file: $path');
          return _fileCache[cacheKey]!;
        } else {
          // Remove expired cache entry
          _fileCache.remove(cacheKey);
          _cacheTimestamps.remove(cacheKey);
        }
      }

      debugPrint('📥 Downloading file: $path from bucket: $bucket');

      // Download file
      final response = await RetryPolicy.withRetry(
        () => _client.storage.from(bucket).download(path),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      debugPrint('✅ File downloaded: ${response.length} bytes');

      // Cache the file
      _fileCache[cacheKey] = response;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return response;
    } catch (e) {
      debugPrint('❌ File download failed: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get public URL for a file
  String getPublicUrl(String bucket, String path) {
    try {
      if (bucket.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }
      if (path.isEmpty) {
        throw AppError.validation('File path cannot be empty');
      }

      final url = _client.storage.from(bucket).getPublicUrl(path);
      debugPrint('🔗 Generated public URL for: $path');
      return url;
    } catch (e) {
      debugPrint('❌ Failed to get public URL: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Delete a file from Supabase Storage
  Future<void> deleteFile(String bucket, String path) async {
    try {
      // Validate inputs
      if (bucket.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }
      if (path.isEmpty) {
        throw AppError.validation('File path cannot be empty');
      }

      debugPrint('🗑️ Deleting file: $path from bucket: $bucket');

      await RetryPolicy.withRetry(
        () => _client.storage.from(bucket).remove([path]),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      debugPrint('✅ File deleted successfully: $path');

      // Remove from cache
      _clearFileFromCache(bucket, path);
    } catch (e) {
      debugPrint('❌ File deletion failed: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// List files in a bucket with optional prefix filter
  Future<List<FileObject>> listFiles(
    String bucket, {
    String? prefix,
  }) async {
    try {
      if (bucket.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }

      debugPrint('📋 Listing files in bucket: $bucket');
      if (prefix != null) {
        debugPrint('🔍 With prefix: $prefix');
      }

      final response = await RetryPolicy.withRetry(
        () => _client.storage.from(bucket).list(
              path: prefix,
            ),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      debugPrint('✅ Found ${response.length} files');
      return response;
    } catch (e) {
      debugPrint('❌ Failed to list files: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Create a signed URL for temporary access to a private file
  Future<String> createSignedUrl(
    String bucket,
    String path, {
    Duration expiresIn = const Duration(hours: 1),
  }) async {
    try {
      if (bucket.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }
      if (path.isEmpty) {
        throw AppError.validation('File path cannot be empty');
      }

      debugPrint('🔐 Creating signed URL for: $path');
      debugPrint('⏰ Expires in: ${expiresIn.inMinutes} minutes');

      final response = await RetryPolicy.withRetry(
        () => _client.storage.from(bucket).createSignedUrl(
              path,
              expiresIn.inSeconds,
            ),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      debugPrint('✅ Signed URL created');
      return response;
    } catch (e) {
      debugPrint('❌ Failed to create signed URL: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Move a file from one location to another within the same bucket
  Future<void> moveFile(
    String bucket,
    String fromPath,
    String toPath,
  ) async {
    try {
      if (bucket.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }
      if (fromPath.isEmpty || toPath.isEmpty) {
        throw AppError.validation('File paths cannot be empty');
      }

      debugPrint('📦 Moving file from: $fromPath to: $toPath');

      await RetryPolicy.withRetry(
        () => _client.storage.from(bucket).move(fromPath, toPath),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      debugPrint('✅ File moved successfully');

      // Update cache keys
      final oldCacheKey = '$bucket/$fromPath';
      final newCacheKey = '$bucket/$toPath';

      if (_fileCache.containsKey(oldCacheKey)) {
        _fileCache[newCacheKey] = _fileCache[oldCacheKey]!;
        _cacheTimestamps[newCacheKey] = _cacheTimestamps[oldCacheKey]!;
        _fileCache.remove(oldCacheKey);
        _cacheTimestamps.remove(oldCacheKey);
      }
    } catch (e) {
      debugPrint('❌ Failed to move file: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Copy a file within the same bucket
  Future<void> copyFile(
    String bucket,
    String fromPath,
    String toPath,
  ) async {
    try {
      if (bucket.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }
      if (fromPath.isEmpty || toPath.isEmpty) {
        throw AppError.validation('File paths cannot be empty');
      }

      debugPrint('📋 Copying file from: $fromPath to: $toPath');

      await RetryPolicy.withRetry(
        () => _client.storage.from(bucket).copy(fromPath, toPath),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      debugPrint('✅ File copied successfully');
    } catch (e) {
      debugPrint('❌ Failed to copy file: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get file metadata
  Future<Map<String, dynamic>> getFileInfo(String bucket, String path) async {
    try {
      if (bucket.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }
      if (path.isEmpty) {
        throw AppError.validation('File path cannot be empty');
      }

      debugPrint('ℹ️ Getting file info for: $path');

      // List files to get metadata (Supabase doesn't have a direct getInfo method)
      final files = await listFiles(bucket, prefix: path);
      final file = files.firstWhere(
        (f) => f.name == path.split('/').last,
        orElse: () => throw AppError.notFound('File not found: $path'),
      );

      final info = {
        'name': file.name,
        'size': file.metadata?['size'] ?? 0,
        'lastModified': file.updatedAt,
        'contentType': file.metadata?['mimetype'] ?? _getContentType(path),
        'bucket': bucket,
        'path': path,
      };

      debugPrint('✅ File info retrieved');
      return info;
    } catch (e) {
      debugPrint('❌ Failed to get file info: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Clear file cache
  void clearCache() {
    _fileCache.clear();
    _cacheTimestamps.clear();
    debugPrint('🧹 File cache cleared');
  }

  /// Clear specific file from cache
  void _clearFileFromCache(String bucket, String path) {
    final cacheKey = '$bucket/$path';
    _fileCache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_files': _fileCache.length,
      'cache_size_bytes':
          _fileCache.values.fold<int>(0, (sum, bytes) => sum + bytes.length),
      'oldest_cache_entry': _cacheTimestamps.values.isEmpty
          ? null
          : _cacheTimestamps.values
              .reduce((a, b) => a.isBefore(b) ? a : b)
              .toIso8601String(),
    };
  }

  /// Determine content type based on file extension
  String _getContentType(String path) {
    final extension = path.split('.').last.toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'zip':
        return 'application/zip';
      case 'tar':
        return 'application/x-tar';
      case 'gz':
        return 'application/gzip';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.ms-powerpoint';
      default:
        return 'application/octet-stream';
    }
  }

  /// Create bucket if it doesn't exist (admin operation)
  Future<void> createBucket(String bucketName, {bool isPublic = false}) async {
    try {
      if (bucketName.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }

      debugPrint('🪣 Creating bucket: $bucketName');

      await RetryPolicy.withRetry(
        () => _client.storage.createBucket(
          bucketName,
          BucketOptions(public: isPublic),
        ),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      debugPrint('✅ Bucket created successfully: $bucketName');
    } catch (e) {
      // Ignore error if bucket already exists
      if (e.toString().contains('already exists')) {
        debugPrint('ℹ️ Bucket already exists: $bucketName');
        return;
      }
      debugPrint('❌ Failed to create bucket: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// List all buckets (admin operation)
  Future<List<Bucket>> listBuckets() async {
    try {
      debugPrint('📋 Listing all buckets');

      final response = await RetryPolicy.withRetry(
        () => _client.storage.listBuckets(),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      debugPrint('✅ Found ${response.length} buckets');
      return response;
    } catch (e) {
      debugPrint('❌ Failed to list buckets: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Delete a bucket (admin operation)
  Future<void> deleteBucket(String bucketName) async {
    try {
      if (bucketName.isEmpty) {
        throw AppError.validation('Bucket name cannot be empty');
      }

      debugPrint('🗑️ Deleting bucket: $bucketName');

      await RetryPolicy.withRetry(
        () => _client.storage.deleteBucket(bucketName),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      debugPrint('✅ Bucket deleted successfully: $bucketName');

      // Clear cache for this bucket
      final keysToRemove = _fileCache.keys
          .where((key) => key.startsWith('$bucketName/'))
          .toList();

      for (final key in keysToRemove) {
        _fileCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    } catch (e) {
      debugPrint('❌ Failed to delete bucket: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }
}
