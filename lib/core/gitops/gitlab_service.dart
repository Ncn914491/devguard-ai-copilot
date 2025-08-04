import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../database/services/services.dart';

/// GitLab API integration service for free tier usage
/// Satisfies Requirements: 10.1, 10.2 (GitLab free tier integration)
class GitLabService {
  static final GitLabService _instance = GitLabService._internal();
  static GitLabService get instance => _instance;
  GitLabService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;

  String? _accessToken;
  String? _projectId;
  String? _baseUrl;

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'DevGuard-AI-Copilot/1.0',
  };

  /// Initialize GitLab integration with access token
  /// Satisfies Requirements: 11.2 (Authentication and authorization)
  Future<void> initialize(String accessToken, String projectId,
      {String baseUrl = 'https://gitlab.com'}) async {
    _accessToken = accessToken;
    _projectId = projectId;
    _baseUrl = baseUrl;

    // Verify token and project access
    final isValid = await _validateCredentials();
    if (!isValid) {
      throw Exception('Invalid GitLab credentials or project access');
    }

    await _auditService.logAction(
      actionType: 'gitlab_integration_initialized',
      description: 'GitLab integration initialized for project: $projectId',
      aiReasoning:
          'Established secure connection to GitLab API for repository operations',
      contextData: {
        'project_id': projectId,
        'base_url': baseUrl,
        'api_version': 'v4',
      },
    );
  }

  /// Validate GitLab credentials and project access
  Future<bool> _validateCredentials() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v4/projects/$_projectId'),
        headers: {
          ..._headers,
          'PRIVATE-TOKEN': _accessToken!,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get project information (equivalent to cloning)
  /// Satisfies Requirements: 3.1 (Repository access)
  Future<GitLabProject> getProject() async {
    if (!_isInitialized()) {
      throw Exception('GitLab service not initialized');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v4/projects/$_projectId'),
        headers: {
          ..._headers,
          'PRIVATE-TOKEN': _accessToken!,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to access project: ${response.statusCode}');
      }

      final projectData = jsonDecode(response.body);
      final project = GitLabProject.fromJson(projectData);

      await _auditService.logAction(
        actionType: 'gitlab_project_accessed',
        description: 'Accessed GitLab project: ${project.name}',
        aiReasoning:
            'Project accessed for DevGuard monitoring and development workflow',
        contextData: {
          'project_id': project.id,
          'project_name': project.name,
          'clone_url': project.httpUrlToRepo,
          'default_branch': project.defaultBranch,
          'visibility': project.visibility,
        },
      );

      return project;
    } catch (e) {
      throw Exception('Failed to get project: ${e.toString()}');
    }
  }

  /// Create a new branch
  /// Satisfies Requirements: 3.2 (Branch creation)
  Future<GitLabBranch> createBranch(
      String branchName, String fromBranch) async {
    if (!_isInitialized()) {
      throw Exception('GitLab service not initialized');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v4/projects/$_projectId/repository/branches'),
        headers: {
          ..._headers,
          'PRIVATE-TOKEN': _accessToken!,
        },
        body: jsonEncode({
          'branch': branchName,
          'ref': fromBranch,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create branch: ${response.statusCode}');
      }

      final branchData = jsonDecode(response.body);
      final branch = GitLabBranch.fromJson(branchData);

      await _auditService.logAction(
        actionType: 'gitlab_branch_created',
        description: 'Created GitLab branch: $branchName',
        aiReasoning: 'Created feature branch for isolated development work',
        contextData: {
          'branch_name': branchName,
          'source_branch': fromBranch,
          'commit_id': branch.commit.id,
        },
      );

      return branch;
    } catch (e) {
      throw Exception('Failed to create branch: ${e.toString()}');
    }
  }

  /// Create commit with file changes
  /// Satisfies Requirements: 3.3 (Committing changes)
  Future<GitLabCommit> createCommit(
      String branchName, String message, Map<String, String> files) async {
    if (!_isInitialized()) {
      throw Exception('GitLab service not initialized');
    }

    try {
      final actions = files.entries
          .map((entry) => {
                'action': 'create',
                'file_path': entry.key,
                'content': entry.value,
              })
          .toList();

      final response = await http.post(
        Uri.parse('$_baseUrl/api/v4/projects/$_projectId/repository/commits'),
        headers: {
          ..._headers,
          'PRIVATE-TOKEN': _accessToken!,
        },
        body: jsonEncode({
          'branch': branchName,
          'commit_message': message,
          'actions': actions,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create commit: ${response.statusCode}');
      }

      final commitData = jsonDecode(response.body);
      final commit = GitLabCommit.fromJson(commitData);

      await _auditService.logAction(
        actionType: 'gitlab_commit_created',
        description: 'Created GitLab commit: ${commit.shortId}',
        aiReasoning:
            'Committed changes with structured message for traceability',
        contextData: {
          'commit_id': commit.id,
          'branch_name': branchName,
          'message': message,
          'files_changed': files.keys.toList(),
        },
      );

      return commit;
    } catch (e) {
      throw Exception('Failed to create commit: ${e.toString()}');
    }
  }

  /// Create merge request (GitLab's equivalent of pull request)
  /// Satisfies Requirements: 3.4 (Creating merge requests)
  Future<GitLabMergeRequest> createMergeRequest(String title,
      String description, String sourceBranch, String targetBranch) async {
    if (!_isInitialized()) {
      throw Exception('GitLab service not initialized');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v4/projects/$_projectId/merge_requests'),
        headers: {
          ..._headers,
          'PRIVATE-TOKEN': _accessToken!,
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'source_branch': sourceBranch,
          'target_branch': targetBranch,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception(
            'Failed to create merge request: ${response.statusCode}');
      }

      final mrData = jsonDecode(response.body);
      final mergeRequest = GitLabMergeRequest.fromJson(mrData);

      await _auditService.logAction(
        actionType: 'gitlab_merge_request_created',
        description: 'Created GitLab merge request: !${mergeRequest.iid}',
        aiReasoning: 'Created merge request for code review and integration',
        contextData: {
          'mr_iid': mergeRequest.iid,
          'title': title,
          'source_branch': sourceBranch,
          'target_branch': targetBranch,
          'url': mergeRequest.webUrl,
        },
      );

      return mergeRequest;
    } catch (e) {
      throw Exception('Failed to create merge request: ${e.toString()}');
    }
  }

  /// Get project issues for task integration
  /// Satisfies Requirements: 11.4 (Issue tracking integration)
  Future<List<GitLabIssue>> getProjectIssues({String state = 'opened'}) async {
    if (!_isInitialized()) {
      throw Exception('GitLab service not initialized');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v4/projects/$_projectId/issues?state=$state'),
        headers: {
          ..._headers,
          'PRIVATE-TOKEN': _accessToken!,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch issues: ${response.statusCode}');
      }

      final issuesData = jsonDecode(response.body) as List;
      return issuesData.map((issue) => GitLabIssue.fromJson(issue)).toList();
    } catch (e) {
      throw Exception('Failed to get project issues: ${e.toString()}');
    }
  }

  /// Create issue from task
  /// Satisfies Requirements: 11.4 (Issue creation for workflow management)
  Future<GitLabIssue> createIssue(String title, String description,
      {List<String>? labels}) async {
    if (!_isInitialized()) {
      throw Exception('GitLab service not initialized');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v4/projects/$_projectId/issues'),
        headers: {
          ..._headers,
          'PRIVATE-TOKEN': _accessToken!,
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          if (labels != null) 'labels': labels.join(','),
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create issue: ${response.statusCode}');
      }

      final issueData = jsonDecode(response.body);
      final issue = GitLabIssue.fromJson(issueData);

      await _auditService.logAction(
        actionType: 'gitlab_issue_created',
        description: 'Created GitLab issue: #${issue.iid}',
        aiReasoning: 'Created issue for task tracking and project management',
        contextData: {
          'issue_iid': issue.iid,
          'title': title,
          'labels': labels ?? [],
          'url': issue.webUrl,
        },
      );

      return issue;
    } catch (e) {
      throw Exception('Failed to create issue: ${e.toString()}');
    }
  }

  /// Get integration status
  Future<GitLabIntegrationStatus> getIntegrationStatus() async {
    if (!_isInitialized()) {
      return GitLabIntegrationStatus(
        connected: false,
        project: null,
        lastSync: null,
        rateLimitRemaining: 0,
      );
    }

    try {
      // GitLab doesn't have a specific rate limit endpoint like GitHub
      // We'll check project access as a health check
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v4/projects/$_projectId'),
        headers: {
          ..._headers,
          'PRIVATE-TOKEN': _accessToken!,
        },
      );

      final connected = response.statusCode == 200;
      String? projectName;

      if (connected) {
        final projectData = jsonDecode(response.body);
        projectName = projectData['path_with_namespace'];
      }

      return GitLabIntegrationStatus(
        connected: connected,
        project: projectName,
        lastSync: DateTime.now(),
        rateLimitRemaining: 1000, // GitLab has generous rate limits
      );
    } catch (e) {
      return GitLabIntegrationStatus(
        connected: false,
        project: null,
        lastSync: null,
        rateLimitRemaining: 0,
      );
    }
  }

  /// Check if service is initialized
  bool _isInitialized() {
    return _accessToken != null && _projectId != null && _baseUrl != null;
  }

  /// Dispose resources
  void dispose() {
    _accessToken = null;
    _projectId = null;
    _baseUrl = null;
  }
}

/// GitLab project model
class GitLabProject {
  final int id;
  final String name;
  final String pathWithNamespace;
  final String httpUrlToRepo;
  final String defaultBranch;
  final String visibility;
  final String description;

  GitLabProject({
    required this.id,
    required this.name,
    required this.pathWithNamespace,
    required this.httpUrlToRepo,
    required this.defaultBranch,
    required this.visibility,
    required this.description,
  });

  factory GitLabProject.fromJson(Map<String, dynamic> json) {
    return GitLabProject(
      id: json['id'],
      name: json['name'],
      pathWithNamespace: json['path_with_namespace'],
      httpUrlToRepo: json['http_url_to_repo'],
      defaultBranch: json['default_branch'],
      visibility: json['visibility'],
      description: json['description'] ?? '',
    );
  }
}

/// GitLab branch model
class GitLabBranch {
  final String name;
  final GitLabCommit commit;
  final bool merged;
  final bool protected;

  GitLabBranch({
    required this.name,
    required this.commit,
    required this.merged,
    required this.protected,
  });

  factory GitLabBranch.fromJson(Map<String, dynamic> json) {
    return GitLabBranch(
      name: json['name'],
      commit: GitLabCommit.fromJson(json['commit']),
      merged: json['merged'] ?? false,
      protected: json['protected'] ?? false,
    );
  }
}

/// GitLab commit model
class GitLabCommit {
  final String id;
  final String shortId;
  final String title;
  final String message;
  final String authorName;
  final DateTime createdAt;

  GitLabCommit({
    required this.id,
    required this.shortId,
    required this.title,
    required this.message,
    required this.authorName,
    required this.createdAt,
  });

  factory GitLabCommit.fromJson(Map<String, dynamic> json) {
    return GitLabCommit(
      id: json['id'],
      shortId: json['short_id'],
      title: json['title'],
      message: json['message'],
      authorName: json['author_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// GitLab merge request model
class GitLabMergeRequest {
  final int id;
  final int iid;
  final String title;
  final String description;
  final String state;
  final String webUrl;
  final String sourceBranch;
  final String targetBranch;
  final DateTime createdAt;

  GitLabMergeRequest({
    required this.id,
    required this.iid,
    required this.title,
    required this.description,
    required this.state,
    required this.webUrl,
    required this.sourceBranch,
    required this.targetBranch,
    required this.createdAt,
  });

  factory GitLabMergeRequest.fromJson(Map<String, dynamic> json) {
    return GitLabMergeRequest(
      id: json['id'],
      iid: json['iid'],
      title: json['title'],
      description: json['description'] ?? '',
      state: json['state'],
      webUrl: json['web_url'],
      sourceBranch: json['source_branch'],
      targetBranch: json['target_branch'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// GitLab issue model
class GitLabIssue {
  final int id;
  final int iid;
  final String title;
  final String description;
  final String state;
  final String webUrl;
  final List<String> labels;
  final DateTime createdAt;

  GitLabIssue({
    required this.id,
    required this.iid,
    required this.title,
    required this.description,
    required this.state,
    required this.webUrl,
    required this.labels,
    required this.createdAt,
  });

  factory GitLabIssue.fromJson(Map<String, dynamic> json) {
    final labelsList =
        (json['labels'] as List?)?.map((label) => label.toString()).toList() ??
            [];

    return GitLabIssue(
      id: json['id'],
      iid: json['iid'],
      title: json['title'],
      description: json['description'] ?? '',
      state: json['state'],
      webUrl: json['web_url'],
      labels: labelsList,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// GitLab integration status
class GitLabIntegrationStatus {
  final bool connected;
  final String? project;
  final DateTime? lastSync;
  final int rateLimitRemaining;

  GitLabIntegrationStatus({
    required this.connected,
    required this.project,
    required this.lastSync,
    required this.rateLimitRemaining,
  });
}
