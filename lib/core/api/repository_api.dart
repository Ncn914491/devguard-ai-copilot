import 'dart:async';
import 'dart:io';
import '../auth/auth_service.dart';
import '../database/services/audit_log_service.dart';
import 'websocket_service.dart';

/// Repository Management API with git operations and remote integration
/// Satisfies Requirements: 3.1, 3.2, 3.3, 3.4, 3.5 (Repository operations with RBAC)
class RepositoryAPI {
  static final RepositoryAPI _instance = RepositoryAPI._internal();
  static RepositoryAPI get instance => _instance;
  RepositoryAPI._internal();

  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;
  final _websocketService = WebSocketService.instance;
  // GitHub and GitLab services are accessed directly when needed

  // In-memory repository storage (in production, this would be a database)
  final Map<String, Repository> _repositories = {};
  final Map<String, List<FileSystemNode>> _repositoryFiles = {};

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
        actionType: 'repositories_retrieved',
        description: 'Retrieved accessible repositories',
        contextData: {
          'total_repositories': _repositories.length,
          'accessible_repositories': accessibleRepos.length,
          'user_role': currentUser.role,
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
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'repositories_retrieval_error',
        description: 'Error retrieving repositories: ${e.toString()}',
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
          actionType: 'repository_access_denied',
          description: 'Access denied to repository: ${repository.name}',
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
        actionType: 'repository_retrieved',
        description: 'Retrieved repository: ${repository.name}',
        contextData: {
          'repository_id': repoId,
          'repository_name': repository.name,
          'access_level': repository.accessLevel,
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
        actionType: 'repository_retrieval_error',
        description: 'Error retrieving repository: ${e.toString()}',
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

  /// Clone repository from remote URL
  /// POST /api/repositories/clone
  Future<APIResponse<String>> cloneRepository({
    required String repoUrl,
    required String localPath,
    String? accessToken,
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
      if (!_authService.hasPermission('manage_repositories')) {
        return APIResponse<String>(
          success: false,
          message: 'Insufficient permissions to clone repositories',
          statusCode: 403,
        );
      }

      // Validate input
      if (repoUrl.trim().isEmpty) {
        return APIResponse<String>(
          success: false,
          message: 'Repository URL is required',
          statusCode: 400,
        );
      }

      if (localPath.trim().isEmpty) {
        return APIResponse<String>(
          success: false,
          message: 'Local path is required',
          statusCode: 400,
        );
      }

      final currentUser = _authService.currentUser!;

      // Perform git clone operation
      final cloneResult = await _performGitClone(
        repoUrl: repoUrl,
        localPath: localPath,
        accessToken: accessToken,
      );

      if (!cloneResult.success) {
        return APIResponse<String>(
          success: false,
          message: cloneResult.message,
          statusCode: 400,
        );
      }

      // Create repository record
      final repoId = _generateRepositoryId();
      final repository = Repository(
        id: repoId,
        name: _extractRepoName(repoUrl),
        description: 'Cloned from $repoUrl',
        localPath: localPath,
        remoteUrl: repoUrl,
        currentBranch: 'main',
        branches: ['main'],
        lastCommit: null,
        status: GitStatus(
          modified: [],
          added: [],
          deleted: [],
          untracked: [],
        ),
        ownerId: currentUser.id,
        collaborators: [],
        accessLevel: 'private',
        connectedTasks: [],
        deploymentConfig: null,
        language: 'unknown',
        framework: 'unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastActivity: DateTime.now(),
      );

      _repositories[repoId] = repository;

      // Initialize file structure
      await _initializeRepositoryFiles(repoId, localPath);

      // Broadcast repository creation via WebSocket
      await _websocketService.broadcastRepositoryUpdate(
        repositoryId: repoId,
        update: {
          'action': 'cloned',
          'repository': _repositoryToMap(repository),
          'cloned_from': repoUrl,
        },
        targetUsers: [currentUser.id],
      );

      await _auditService.logAction(
        actionType: 'repository_cloned',
        description: 'Cloned repository: ${repository.name}',
        contextData: {
          'repository_id': repoId,
          'repository_name': repository.name,
          'remote_url': repoUrl,
          'local_path': localPath,
        },
        userId: currentUser.id,
      );

      return APIResponse<String>(
        success: true,
        message: 'Repository cloned successfully',
        data: repoId,
        statusCode: 201,
        metadata: {
          'repository_id': repoId,
          'repository_name': repository.name,
          'local_path': localPath,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'repository_clone_error',
        description: 'Error cloning repository: ${e.toString()}',
        contextData: {
          'repository_url': repoUrl,
          'local_path': localPath,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<String>(
        success: false,
        message: 'Failed to clone repository: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Get repository file structure
  /// GET /api/repositories/{id}/files
  Future<APIResponse<List<FileSystemNode>>> getRepositoryFiles(
    String repoId, {
    String? path,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<List<FileSystemNode>>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      final repository = _repositories[repoId];
      if (repository == null) {
        return APIResponse<List<FileSystemNode>>(
          success: false,
          message: 'Repository not found',
          statusCode: 404,
        );
      }

      final currentUser = _authService.currentUser!;

      // Check access permissions
      if (!_canAccessRepository(repository, currentUser)) {
        return APIResponse<List<FileSystemNode>>(
          success: false,
          message:
              'Access denied: insufficient permissions for this repository',
          statusCode: 403,
        );
      }

      // Get file structure
      final files = _repositoryFiles[repoId] ?? [];
      final filteredFiles = path != null
          ? files.where((file) => file.path.startsWith(path)).toList()
          : files;

      await _auditService.logAction(
        actionType: 'repository_files_retrieved',
        description:
            'Retrieved file structure for repository: ${repository.name}',
        contextData: {
          'repository_id': repoId,
          'path_filter': path,
          'file_count': filteredFiles.length,
        },
        userId: currentUser.id,
      );

      return APIResponse<List<FileSystemNode>>(
        success: true,
        message: 'Repository files retrieved successfully',
        data: filteredFiles,
        statusCode: 200,
        metadata: {
          'repository_id': repoId,
          'file_count': filteredFiles.length,
          'path_filter': path,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'repository_files_error',
        description: 'Error retrieving repository files: ${e.toString()}',
        contextData: {
          'repository_id': repoId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<List<FileSystemNode>>(
        success: false,
        message: 'Failed to retrieve repository files: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Get file content
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

      // Read file content
      final fullPath = '${repository.localPath}/$filePath';
      final file = File(fullPath);

      if (!await file.exists()) {
        return APIResponse<String>(
          success: false,
          message: 'File not found',
          statusCode: 404,
        );
      }

      final content = await file.readAsString();

      await _auditService.logAction(
        actionType: 'file_content_retrieved',
        description: 'Retrieved file content: $filePath',
        contextData: {
          'repository_id': repoId,
          'file_path': filePath,
          'file_size': content.length,
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
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'file_content_error',
        description: 'Error retrieving file content: ${e.toString()}',
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

  /// Update file content
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

      // Write file content
      final fullPath = '${repository.localPath}/$filePath';
      final file = File(fullPath);

      // Create directory if it doesn't exist
      await file.parent.create(recursive: true);
      await file.writeAsString(content);

      // Update git status
      await _updateGitStatus(repoId);

      // Broadcast file change via WebSocket
      await _websocketService.broadcastFileChange(
        repositoryId: repoId,
        filePath: filePath,
        change: {
          'action': 'modified',
          'file_path': filePath,
          'content_length': content.length,
          'modified_by': currentUser.id,
        },
        targetUsers: _getRepositoryCollaborators(repository),
      );

      await _auditService.logAction(
        actionType: 'file_content_updated',
        description: 'Updated file content: $filePath',
        contextData: {
          'repository_id': repoId,
          'file_path': filePath,
          'content_length': content.length,
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
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'file_content_update_error',
        description: 'Error updating file content: ${e.toString()}',
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

  /// Perform git commit
  /// POST /api/repositories/{id}/commits
  Future<APIResponse<String>> commitChanges({
    required String repoId,
    required String message,
    required List<String> files,
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
          message: 'Insufficient permissions to commit changes',
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

      // Validate input
      if (message.trim().isEmpty) {
        return APIResponse<String>(
          success: false,
          message: 'Commit message is required',
          statusCode: 400,
        );
      }

      if (files.isEmpty) {
        return APIResponse<String>(
          success: false,
          message: 'At least one file must be selected for commit',
          statusCode: 400,
        );
      }

      // Perform git commit
      final commitResult = await _performGitCommit(
        repository: repository,
        message: message,
        files: files,
        author: currentUser,
      );

      if (!commitResult.success) {
        return APIResponse<String>(
          success: false,
          message: commitResult.message,
          statusCode: 400,
        );
      }

      // Update repository last activity
      final updatedRepo = repository.copyWith(
        lastActivity: DateTime.now(),
        lastCommit: Commit(
          hash: commitResult.commitHash!,
          message: message,
          author: currentUser.name,
          timestamp: DateTime.now(),
        ),
      );
      _repositories[repoId] = updatedRepo;

      // Broadcast commit via WebSocket
      await _websocketService.broadcastRepositoryUpdate(
        repositoryId: repoId,
        update: {
          'action': 'commit_created',
          'commit_hash': commitResult.commitHash,
          'commit_message': message,
          'files': files,
          'author': currentUser.name,
        },
        targetUsers: _getRepositoryCollaborators(repository),
      );

      await _auditService.logAction(
        actionType: 'git_commit_created',
        description: 'Created git commit: $message',
        contextData: {
          'repository_id': repoId,
          'commit_hash': commitResult.commitHash,
          'commit_message': message,
          'files': files,
        },
        userId: currentUser.id,
      );

      return APIResponse<String>(
        success: true,
        message: 'Changes committed successfully',
        data: commitResult.commitHash!,
        statusCode: 201,
        metadata: {
          'commit_hash': commitResult.commitHash,
          'files_committed': files.length,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'git_commit_error',
        description: 'Error creating git commit: ${e.toString()}',
        contextData: {
          'repository_id': repoId,
          'commit_message': message,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<String>(
        success: false,
        message: 'Failed to commit changes: ${e.toString()}',
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

  /// Get repository collaborators
  List<String> _getRepositoryCollaborators(Repository repository) {
    final collaborators = [repository.ownerId];
    collaborators.addAll(repository.collaborators.map((c) => c.userId));
    return collaborators;
  }

  /// Generate unique repository ID
  String _generateRepositoryId() {
    return 'repo_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Extract repository name from URL
  String _extractRepoName(String repoUrl) {
    final uri = Uri.parse(repoUrl);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final name = pathSegments.last;
      return name.endsWith('.git') ? name.substring(0, name.length - 4) : name;
    }
    return 'unknown';
  }

  /// Convert repository to map for WebSocket broadcasting
  Map<String, dynamic> _repositoryToMap(Repository repository) {
    return {
      'id': repository.id,
      'name': repository.name,
      'description': repository.description,
      'local_path': repository.localPath,
      'remote_url': repository.remoteUrl,
      'current_branch': repository.currentBranch,
      'access_level': repository.accessLevel,
      'created_at': repository.createdAt.toIso8601String(),
      'updated_at': repository.updatedAt.toIso8601String(),
    };
  }

  /// Mock git operations (in production, these would use actual git commands)

  Future<GitOperationResult> _performGitClone({
    required String repoUrl,
    required String localPath,
    String? accessToken,
  }) async {
    // Mock implementation - in production, this would use git clone
    await Future.delayed(const Duration(seconds: 2)); // Simulate clone time

    // Create directory structure
    final directory = Directory(localPath);
    await directory.create(recursive: true);

    return GitOperationResult(
      success: true,
      message: 'Repository cloned successfully',
    );
  }

  Future<void> _initializeRepositoryFiles(
      String repoId, String localPath) async {
    // Mock file structure - in production, this would scan the actual directory
    final files = [
      FileSystemNode(
        path: 'README.md',
        name: 'README.md',
        type: 'file',
        size: 1024,
        gitStatus: 'clean',
        lastCommit: 'abc123',
        language: 'markdown',
        encoding: 'utf-8',
        permissions: FilePermissions(read: true, write: true, execute: false),
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        accessedAt: DateTime.now(),
      ),
      FileSystemNode(
        path: 'src',
        name: 'src',
        type: 'directory',
        size: 0,
        gitStatus: 'clean',
        lastCommit: 'abc123',
        encoding: 'utf-8',
        permissions: FilePermissions(read: true, write: true, execute: true),
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        accessedAt: DateTime.now(),
      ),
    ];

    _repositoryFiles[repoId] = files;
  }

  Future<void> _updateGitStatus(String repoId) async {
    // Mock git status update - in production, this would run git status
    final repository = _repositories[repoId];
    if (repository != null) {
      final updatedRepo = repository.copyWith(
        status: GitStatus(
          modified: ['file1.dart'],
          added: [],
          deleted: [],
          untracked: [],
        ),
        lastActivity: DateTime.now(),
      );
      _repositories[repoId] = updatedRepo;
    }
  }

  Future<GitOperationResult> _performGitCommit({
    required Repository repository,
    required String message,
    required List<String> files,
    required User author,
  }) async {
    // Mock git commit - in production, this would use git commands
    await Future.delayed(const Duration(seconds: 1)); // Simulate commit time

    final commitHash = 'commit_${DateTime.now().millisecondsSinceEpoch}';

    return GitOperationResult(
      success: true,
      message: 'Commit created successfully',
      commitHash: commitHash,
    );
  }
}

/// Data models

class Repository {
  final String id;
  final String name;
  final String description;
  final String localPath;
  final String? remoteUrl;
  final String currentBranch;
  final List<String> branches;
  final Commit? lastCommit;
  final GitStatus status;
  final String ownerId;
  final List<Collaborator> collaborators;
  final String accessLevel;
  final List<String> connectedTasks;
  final DeploymentConfig? deploymentConfig;
  final String language;
  final String framework;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastActivity;

  Repository({
    required this.id,
    required this.name,
    required this.description,
    required this.localPath,
    this.remoteUrl,
    required this.currentBranch,
    required this.branches,
    this.lastCommit,
    required this.status,
    required this.ownerId,
    required this.collaborators,
    required this.accessLevel,
    required this.connectedTasks,
    this.deploymentConfig,
    required this.language,
    required this.framework,
    required this.createdAt,
    required this.updatedAt,
    required this.lastActivity,
  });

  Repository copyWith({
    String? id,
    String? name,
    String? description,
    String? localPath,
    String? remoteUrl,
    String? currentBranch,
    List<String>? branches,
    Commit? lastCommit,
    GitStatus? status,
    String? ownerId,
    List<Collaborator>? collaborators,
    String? accessLevel,
    List<String>? connectedTasks,
    DeploymentConfig? deploymentConfig,
    String? language,
    String? framework,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActivity,
  }) {
    return Repository(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      currentBranch: currentBranch ?? this.currentBranch,
      branches: branches ?? this.branches,
      lastCommit: lastCommit ?? this.lastCommit,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      collaborators: collaborators ?? this.collaborators,
      accessLevel: accessLevel ?? this.accessLevel,
      connectedTasks: connectedTasks ?? this.connectedTasks,
      deploymentConfig: deploymentConfig ?? this.deploymentConfig,
      language: language ?? this.language,
      framework: framework ?? this.framework,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}

class FileSystemNode {
  final String path;
  final String name;
  final String type;
  final int size;
  final String gitStatus;
  final String lastCommit;
  final String? language;
  final String encoding;
  final FilePermissions permissions;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final DateTime accessedAt;
  final String? parent;
  final List<FileSystemNode>? children;

  FileSystemNode({
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.gitStatus,
    required this.lastCommit,
    this.language,
    required this.encoding,
    required this.permissions,
    required this.createdAt,
    required this.modifiedAt,
    required this.accessedAt,
    this.parent,
    this.children,
  });
}

class GitStatus {
  final List<String> modified;
  final List<String> added;
  final List<String> deleted;
  final List<String> untracked;

  GitStatus({
    required this.modified,
    required this.added,
    required this.deleted,
    required this.untracked,
  });
}

class Commit {
  final String hash;
  final String message;
  final String author;
  final DateTime timestamp;

  Commit({
    required this.hash,
    required this.message,
    required this.author,
    required this.timestamp,
  });
}

class Collaborator {
  final String userId;
  final String role;
  final DateTime addedAt;

  Collaborator({
    required this.userId,
    required this.role,
    required this.addedAt,
  });
}

class FilePermissions {
  final bool read;
  final bool write;
  final bool execute;

  FilePermissions({
    required this.read,
    required this.write,
    required this.execute,
  });
}

class DeploymentConfig {
  final String platform;
  final Map<String, dynamic> settings;

  DeploymentConfig({
    required this.platform,
    required this.settings,
  });
}

class GitOperationResult {
  final bool success;
  final String message;
  final String? commitHash;

  GitOperationResult({
    required this.success,
    required this.message,
    this.commitHash,
  });
}

/// Generic API response wrapper
class APIResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int statusCode;
  final Map<String, dynamic>? metadata;

  APIResponse({
    required this.success,
    required this.message,
    this.data,
    required this.statusCode,
    this.metadata,
  });
}

// User model is imported from auth_service.dart
