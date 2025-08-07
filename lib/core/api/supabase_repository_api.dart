import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../auth/auth_service.dart';
import '../database/services/audit_log_service.dart';
import '../api/websocket_service.dart';
import '../services/supabase_file_system_service.dart';
import 'repository_api.dart';

/// Repository Management API using Supabase Storage for file operations
/// Replaces local file operations with cloud storage operations
/// Requirements: 5.1, 5.2, 5.3, 5.4 - File operations with proper access controls
class SupabaseRepositoryAPI {
  static final SupabaseRepositoryAPI _instance =
      SupabaseRepositoryAPI._internal();
  static SupabaseRepositoryAPI get instance => _instance;
  SupabaseRepositoryAPI._internal();

  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;
  final _websocketService = WebSocketService.instance;
  final _fileSystemService = SupabaseFileSystemService.instance;

  // In-memory repository storage (in production, this would be a database)
  final Map<String, Repository> _repositories = {};

  /// Get all repositories accessible to current user
  /// GET /api/repositories
  Future<APIResponse<List<Repository>>> getRepositories() async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<List<Repository>>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      final currentUser = _authService.currentUser!;

      // Filter repositories based on user permissions
      final accessibleRepos = _repositories.values.where((repo) {
        return _canAccessRepository(repo, currentUser);
      }).toList();

      await _auditService.logAction(
        actionType: 'supabase_repositories_retrieved',
        description: 'Retrieved accessible repositories from Supabase',
        contextData: {
          'total_repositories': _repositories.length,
          'accessible_repositories': accessibleRepos.length,
          'user_role': currentUser.role,
          'storage_type': 'supabase',
        },
        userId: currentUser.id,
      );

      return APIResponse<List<Repository>>(
        success: true,
        message: 'Repositories retrieved successfully',
        data: accessibleRepos,
        statusCode: 200,
        metadata: {
          'total_count': accessibleRepos.length,
          'user_role': currentUser.role,
          'storage_type': 'supabase',
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_repositories_retrieval_error',
        description:
            'Error retrieving repositories from Supabase: ${e.toString()}',
        contextData: {'error': e.toString()},
        userId: _authService.currentUser?.id,
      );

      return APIResponse<List<Repository>>(
        success: false,
        message: 'Failed to retrieve repositories: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Get repository by ID
  /// GET /api/repositories/{id}
  Future<APIResponse<Repository>> getRepository(String repoId) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<Repository>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Validate repository ID
      if (repoId.trim().isEmpty) {
        return APIResponse<Repository>(
          success: false,
          message: 'Repository ID is required',
          statusCode: 400,
        );
      }

      final repository = _repositories[repoId];
      if (repository == null) {
        return APIResponse<Repository>(
          success: false,
          message: 'Repository not found',
          statusCode: 404,
        );
      }

      final currentUser = _authService.currentUser!;

      // Check access permissions
      if (!_canAccessRepository(repository, currentUser)) {
        await _auditService.logAction(
          actionType: 'supabase_repository_access_denied',
          description:
              'Access denied to Supabase repository: ${repository.name}',
          contextData: {
            'repository_id': repoId,
            'repository_name': repository.name,
            'user_role': currentUser.role,
            'access_level': repository.accessLevel,
          },
          userId: currentUser.id,
        );

        return APIResponse<Repository>(
          success: false,
          message:
              'Access denied: insufficient permissions for this repository',
          statusCode: 403,
        );
      }

      await _auditService.logAction(
        actionType: 'supabase_repository_retrieved',
        description: 'Retrieved Supabase repository: ${repository.name}',
        contextData: {
          'repository_id': repoId,
          'repository_name': repository.name,
          'access_level': repository.accessLevel,
          'storage_type': 'supabase',
        },
        userId: currentUser.id,
      );

      return APIResponse<Repository>(
        success: true,
        message: 'Repository retrieved successfully',
        data: repository,
        statusCode: 200,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_repository_retrieval_error',
        description: 'Error retrieving Supabase repository: ${e.toString()}',
        contextData: {
          'repository_id': repoId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<Repository>(
        success: false,
        message: 'Failed to retrieve repository: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Get repository file structure from Supabase Storage
  /// GET /api/repositories/{id}/files
  Future<APIResponse<List<CloudFileSystemNode>>> getRepositoryFiles(
    String repoId, {
    String? path,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<List<CloudFileSystemNode>>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      final repository = _repositories[repoId];
      if (repository == null) {
        return APIResponse<List<CloudFileSystemNode>>(
          success: false,
          message: 'Repository not found',
          statusCode: 404,
        );
      }

      final currentUser = _authService.currentUser!;

      // Check access permissions
      if (!_canAccessRepository(repository, currentUser)) {
        return APIResponse<List<CloudFileSystemNode>>(
          success: false,
          message:
              'Access denied: insufficient permissions for this repository',
          statusCode: 403,
        );
      }

      // Get file structure from Supabase Storage
      final cloudFiles = await _fileSystemService.listRepositoryFiles(
        repositoryId: repoId,
        pathPrefix: path,
      );

      // Convert to FileSystemNode format for compatibility
      final fileNodes = cloudFiles
          .map((file) => CloudFileSystemNode(
                path: file.path,
                name: file.name,
                type: 'file',
                size: file.size,
                gitStatus: 'clean', // Default status
                lastCommit: null,
                language: _detectLanguage(file.name),
                encoding: 'utf-8',
                permissions: CloudFilePermissions(
                    read: true, write: true, execute: false),
                createdAt: file.lastModified,
                modifiedAt: file.lastModified,
                accessedAt: file.lastModified,
                cloudPath: file.cloudPath,
                bucket: file.bucket,
                contentType: file.contentType,
              ))
          .toList();

      await _auditService.logAction(
        actionType: 'supabase_repository_files_retrieved',
        description:
            'Retrieved file structure from Supabase for repository: ${repository.name}',
        contextData: {
          'repository_id': repoId,
          'path_filter': path,
          'file_count': fileNodes.length,
          'storage_type': 'supabase',
        },
        userId: currentUser.id,
      );

      return APIResponse<List<CloudFileSystemNode>>(
        success: true,
        message: 'Repository files retrieved successfully',
        data: fileNodes,
        statusCode: 200,
        metadata: {
          'repository_id': repoId,
          'file_count': fileNodes.length,
          'path_filter': path,
          'storage_type': 'supabase',
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_repository_files_error',
        description:
            'Error retrieving repository files from Supabase: ${e.toString()}',
        contextData: {
          'repository_id': repoId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<List<CloudFileSystemNode>>(
        success: false,
        message: 'Failed to retrieve repository files: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Get file content from Supabase Storage
  /// GET /api/repositories/{id}/files/{path}/content
  Future<APIResponse<String>> getFileContent({
    required String repoId,
    required String filePath,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<String>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      final repository = _repositories[repoId];
      if (repository == null) {
        return APIResponse<String>(
          success: false,
          message: 'Repository not found',
          statusCode: 404,
        );
      }

      final currentUser = _authService.currentUser!;

      // Check access permissions
      if (!_canAccessRepository(repository, currentUser)) {
        return APIResponse<String>(
          success: false,
          message:
              'Access denied: insufficient permissions for this repository',
          statusCode: 403,
        );
      }

      // Download file content from Supabase Storage
      final fileData = await _fileSystemService.downloadRepositoryFile(
        repositoryId: repoId,
        filePath: filePath,
      );

      final content = String.fromCharCodes(fileData);

      await _auditService.logAction(
        actionType: 'supabase_file_content_retrieved',
        description: 'Retrieved file content from Supabase: $filePath',
        contextData: {
          'repository_id': repoId,
          'file_path': filePath,
          'file_size': content.length,
          'storage_type': 'supabase',
        },
        userId: currentUser.id,
      );

      return APIResponse<String>(
        success: true,
        message: 'File content retrieved successfully',
        data: content,
        statusCode: 200,
        metadata: {
          'file_path': filePath,
          'file_size': content.length,
          'storage_type': 'supabase',
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_file_content_error',
        description:
            'Error retrieving file content from Supabase: ${e.toString()}',
        contextData: {
          'repository_id': repoId,
          'file_path': filePath,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<String>(
        success: false,
        message: 'Failed to retrieve file content: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Update file content in Supabase Storage
  /// PUT /api/repositories/{id}/files/{path}/content
  Future<APIResponse<void>> updateFileContent({
    required String repoId,
    required String filePath,
    required String content,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<void>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('commit_code')) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions to modify files',
          statusCode: 403,
        );
      }

      final repository = _repositories[repoId];
      if (repository == null) {
        return APIResponse<void>(
          success: false,
          message: 'Repository not found',
          statusCode: 404,
        );
      }

      final currentUser = _authService.currentUser!;

      // Check access permissions
      if (!_canAccessRepository(repository, currentUser)) {
        return APIResponse<void>(
          success: false,
          message:
              'Access denied: insufficient permissions for this repository',
          statusCode: 403,
        );
      }

      // Update file content in Supabase Storage
      await _fileSystemService.updateRepositoryFile(
        repositoryId: repoId,
        filePath: filePath,
        content: content,
      );

      await _auditService.logAction(
        actionType: 'supabase_file_content_updated',
        description: 'Updated file content in Supabase: $filePath',
        contextData: {
          'repository_id': repoId,
          'file_path': filePath,
          'content_length': content.length,
          'storage_type': 'supabase',
        },
        userId: currentUser.id,
      );

      return APIResponse<void>(
        success: true,
        message: 'File content updated successfully',
        statusCode: 200,
        metadata: {
          'file_path': filePath,
          'content_length': content.length,
          'storage_type': 'supabase',
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_file_content_update_error',
        description: 'Error updating file content in Supabase: ${e.toString()}',
        contextData: {
          'repository_id': repoId,
          'file_path': filePath,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<void>(
        success: false,
        message: 'Failed to update file content: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Upload file to repository in Supabase Storage
  /// POST /api/repositories/{id}/files
  Future<APIResponse<String>> uploadFile({
    required String repoId,
    required String filePath,
    required File file,
    Map<String, String>? metadata,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<String>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('commit_code')) {
        return APIResponse<String>(
          success: false,
          message: 'Insufficient permissions to upload files',
          statusCode: 403,
        );
      }

      final repository = _repositories[repoId];
      if (repository == null) {
        return APIResponse<String>(
          success: false,
          message: 'Repository not found',
          statusCode: 404,
        );
      }

      final currentUser = _authService.currentUser!;

      // Check access permissions
      if (!_canAccessRepository(repository, currentUser)) {
        return APIResponse<String>(
          success: false,
          message:
              'Access denied: insufficient permissions for this repository',
          statusCode: 403,
        );
      }

      // Upload file to Supabase Storage
      final uploadedPath = await _fileSystemService.uploadRepositoryFile(
        repositoryId: repoId,
        filePath: filePath,
        file: file,
        metadata: metadata,
      );

      await _auditService.logAction(
        actionType: 'supabase_file_uploaded',
        description: 'Uploaded file to Supabase repository: $filePath',
        contextData: {
          'repository_id': repoId,
          'file_path': filePath,
          'uploaded_path': uploadedPath,
          'file_size': await file.length(),
          'storage_type': 'supabase',
        },
        userId: currentUser.id,
      );

      return APIResponse<String>(
        success: true,
        message: 'File uploaded successfully',
        data: uploadedPath,
        statusCode: 201,
        metadata: {
          'file_path': filePath,
          'uploaded_path': uploadedPath,
          'storage_type': 'supabase',
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_file_upload_error',
        description: 'Error uploading file to Supabase: ${e.toString()}',
        contextData: {
          'repository_id': repoId,
          'file_path': filePath,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<String>(
        success: false,
        message: 'Failed to upload file: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Delete file from repository in Supabase Storage
  /// DELETE /api/repositories/{id}/files/{path}
  Future<APIResponse<void>> deleteFile({
    required String repoId,
    required String filePath,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<void>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('commit_code')) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions to delete files',
          statusCode: 403,
        );
      }

      final repository = _repositories[repoId];
      if (repository == null) {
        return APIResponse<void>(
          success: false,
          message: 'Repository not found',
          statusCode: 404,
        );
      }

      final currentUser = _authService.currentUser!;

      // Check access permissions
      if (!_canAccessRepository(repository, currentUser)) {
        return APIResponse<void>(
          success: false,
          message:
              'Access denied: insufficient permissions for this repository',
          statusCode: 403,
        );
      }

      // Delete file from Supabase Storage
      await _fileSystemService.deleteRepositoryFile(
        repositoryId: repoId,
        filePath: filePath,
      );

      await _auditService.logAction(
        actionType: 'supabase_file_deleted',
        description: 'Deleted file from Supabase repository: $filePath',
        contextData: {
          'repository_id': repoId,
          'file_path': filePath,
          'storage_type': 'supabase',
        },
        userId: currentUser.id,
      );

      return APIResponse<void>(
        success: true,
        message: 'File deleted successfully',
        statusCode: 200,
        metadata: {
          'file_path': filePath,
          'storage_type': 'supabase',
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_file_delete_error',
        description: 'Error deleting file from Supabase: ${e.toString()}',
        contextData: {
          'repository_id': repoId,
          'file_path': filePath,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<void>(
        success: false,
        message: 'Failed to delete file: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Helper methods

  /// Check if user can access repository
  bool _canAccessRepository(Repository repository, User user) {
    // Owner can always access
    if (repository.ownerId == user.id) return true;

    // Check collaborators
    if (repository.collaborators.any((c) => c.userId == user.id)) return true;

    // Check access level and user role
    switch (repository.accessLevel) {
      case 'public':
        return true;
      case 'team':
        return user.role != 'viewer';
      case 'private':
        return user.role == 'admin';
      default:
        return false;
    }
  }

  /// Detect programming language from file extension
  String? _detectLanguage(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'dart':
        return 'dart';
      case 'js':
        return 'javascript';
      case 'ts':
        return 'typescript';
      case 'py':
        return 'python';
      case 'java':
        return 'java';
      case 'cpp':
      case 'cc':
      case 'cxx':
        return 'cpp';
      case 'c':
        return 'c';
      case 'h':
        return 'c';
      case 'html':
        return 'html';
      case 'css':
        return 'css';
      case 'json':
        return 'json';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'md':
        return 'markdown';
      case 'xml':
        return 'xml';
      case 'sql':
        return 'sql';
      case 'sh':
        return 'shell';
      default:
        return null;
    }
  }
}

/// Extended FileSystemNode for cloud storage
class CloudFileSystemNode {
  final String path;
  final String name;
  final String type;
  final int size;
  final String gitStatus;
  final String? lastCommit;
  final String? language;
  final String encoding;
  final CloudFilePermissions permissions;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final DateTime accessedAt;
  final String cloudPath;
  final String bucket;
  final String contentType;

  CloudFileSystemNode({
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.gitStatus,
    this.lastCommit,
    this.language,
    required this.encoding,
    required this.permissions,
    required this.createdAt,
    required this.modifiedAt,
    required this.accessedAt,
    required this.cloudPath,
    required this.bucket,
    required this.contentType,
  });
}

class CloudFilePermissions {
  final bool read;
  final bool write;
  final bool execute;

  CloudFilePermissions({
    required this.read,
    required this.write,
    required this.execute,
  });
}
