import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../database/services/services.dart';
import '../database/models/models.dart';

/// GitHub API integration service for free tier usage
/// Satisfies Requirements: 10.1, 10.2 (GitHub free tier integration)
class GitHubService {
  static final GitHubService _instance = GitHubService._internal();
  static GitHubService get instance => _instance;
  GitHubService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;
  
  String? _accessToken;
  String? _username;
  String? _repository;
  
  static const String _baseUrl = 'https://api.github.com';
  static const Map<String, String> _headers = {
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'DevGuard-AI-Copilot/1.0',
  };

  /// Initialize GitHub integration with access token
  /// Satisfies Requirements: 11.2 (Authentication and authorization)
  Future<void> initialize(String accessToken, String username, String repository) async {
    _accessToken = accessToken;
    _username = username;
    _repository = repository;
    
    // Verify token and repository access
    final isValid = await _validateCredentials();
    if (!isValid) {
      throw Exception('Invalid GitHub credentials or repository access');
    }
    
    await _auditService.logAction(
      actionType: 'github_integration_initialized',
      description: 'GitHub integration initialized for repository: $username/$repository',
      aiReasoning: 'Established secure connection to GitHub API for repository operations',
      contextData: {
        'username': username,
        'repository': repository,
        'api_version': 'v3',
      },
    );
  }

  /// Validate GitHub credentials and repository access
  Future<bool> _validateCredentials() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/repos/$_username/$_repository'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Clone repository (simulate local clone operation)
  /// Satisfies Requirements: 3.1 (Repository cloning)
  Future<GitHubRepository> cloneRepository() async {
    if (!_isInitialized()) {
      throw Exception('GitHub service not initialized');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/repos/$_username/$_repository'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to access repository: ${response.statusCode}');
      }

      final repoData = jsonDecode(response.body);
      final repository = GitHubRepository.fromJson(repoData);

      await _auditService.logAction(
        actionType: 'repository_cloned',
        description: 'Cloned repository: $_username/$_repository',
        aiReasoning: 'Repository cloned for local development and DevGuard monitoring',
        contextData: {
          'repository_id': repository.id,
          'clone_url': repository.cloneUrl,
          'default_branch': repository.defaultBranch,
          'private': repository.private,
        },
      );

      return repository;
    } catch (e) {
      throw Exception('Failed to clone repository: ${e.toString()}');
    }
  }

  /// Create a new branch
  /// Satisfies Requirements: 3.2 (Branch creation)
  Future<GitHubBranch> createBranch(String branchName, String fromBranch) async {
    if (!_isInitialized()) {
      throw Exception('GitHub service not initialized');
    }

    try {
      // Get the SHA of the source branch
      final refResponse = await http.get(
        Uri.parse('$_baseUrl/repos/$_username/$_repository/git/refs/heads/$fromBranch'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
        },
      );

      if (refResponse.statusCode != 200) {
        throw Exception('Failed to get source branch reference');
      }

      final refData = jsonDecode(refResponse.body);
      final sourceSha = refData['object']['sha'];

      // Create new branch
      final createResponse = await http.post(
        Uri.parse('$_baseUrl/repos/$_username/$_repository/git/refs'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ref': 'refs/heads/$branchName',
          'sha': sourceSha,
        }),
      );

      if (createResponse.statusCode != 201) {
        throw Exception('Failed to create branch: ${createResponse.statusCode}');
      }

      final branchData = jsonDecode(createResponse.body);
      final branch = GitHubBranch(
        name: branchName,
        sha: branchData['object']['sha'],
        url: branchData['url'],
        createdAt: DateTime.now(),
      );

      await _auditService.logAction(
        actionType: 'github_branch_created',
        description: 'Created GitHub branch: $branchName',
        aiReasoning: 'Created feature branch for isolated development work',
        contextData: {
          'branch_name': branchName,
          'source_branch': fromBranch,
          'sha': branch.sha,
        },
      );

      return branch;
    } catch (e) {
      throw Exception('Failed to create branch: ${e.toString()}');
    }
  }

  /// Commit changes to repository
  /// Satisfies Requirements: 3.3 (Committing changes)
  Future<GitHubCommit> createCommit(String branchName, String message, Map<String, String> files) async {
    if (!_isInitialized()) {
      throw Exception('GitHub service not initialized');
    }

    try {
      // Get current branch reference
      final refResponse = await http.get(
        Uri.parse('$_baseUrl/repos/$_username/$_repository/git/refs/heads/$branchName'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
        },
      );

      if (refResponse.statusCode != 200) {
        throw Exception('Branch not found: $branchName');
      }

      final refData = jsonDecode(refResponse.body);
      final currentSha = refData['object']['sha'];

      // Get current tree
      final treeResponse = await http.get(
        Uri.parse('$_baseUrl/repos/$_username/$_repository/git/commits/$currentSha'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
        },
      );

      final treeData = jsonDecode(treeResponse.body);
      final treeSha = treeData['tree']['sha'];

      // Create blobs for each file
      final List<Map<String, dynamic>> treeItems = [];
      for (final entry in files.entries) {
        final blobResponse = await http.post(
          Uri.parse('$_baseUrl/repos/$_username/$_repository/git/blobs'),
          headers: {
            ..._headers,
            'Authorization': 'token $_accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'content': entry.value,
            'encoding': 'utf-8',
          }),
        );

        if (blobResponse.statusCode == 201) {
          final blobData = jsonDecode(blobResponse.body);
          treeItems.add({
            'path': entry.key,
            'mode': '100644',
            'type': 'blob',
            'sha': blobData['sha'],
          });
        }
      }

      // Create new tree
      final newTreeResponse = await http.post(
        Uri.parse('$_baseUrl/repos/$_username/$_repository/git/trees'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'base_tree': treeSha,
          'tree': treeItems,
        }),
      );

      if (newTreeResponse.statusCode != 201) {
        throw Exception('Failed to create tree');
      }

      final newTreeData = jsonDecode(newTreeResponse.body);
      final newTreeSha = newTreeData['sha'];

      // Create commit
      final commitResponse = await http.post(
        Uri.parse('$_baseUrl/repos/$_username/$_repository/git/commits'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
          'tree': newTreeSha,
          'parents': [currentSha],
        }),
      );

      if (commitResponse.statusCode != 201) {
        throw Exception('Failed to create commit');
      }

      final commitData = jsonDecode(commitResponse.body);
      final commitSha = commitData['sha'];

      // Update branch reference
      await http.patch(
        Uri.parse('$_baseUrl/repos/$_username/$_repository/git/refs/heads/$branchName'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sha': commitSha,
        }),
      );

      final commit = GitHubCommit(
        sha: commitSha,
        message: message,
        author: commitData['author']['name'],
        date: DateTime.parse(commitData['author']['date']),
        url: commitData['html_url'],
      );

      await _auditService.logAction(
        actionType: 'github_commit_created',
        description: 'Created GitHub commit: ${commit.sha.substring(0, 7)}',
        aiReasoning: 'Committed changes with structured message for traceability',
        contextData: {
          'commit_sha': commit.sha,
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

  /// Create pull request
  /// Satisfies Requirements: 3.4 (Creating pull requests)
  Future<GitHubPullRequest> createPullRequest(String title, String body, String headBranch, String baseBranch) async {
    if (!_isInitialized()) {
      throw Exception('GitHub service not initialized');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/repos/$_username/$_repository/pulls'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'body': body,
          'head': headBranch,
          'base': baseBranch,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create pull request: ${response.statusCode}');
      }

      final prData = jsonDecode(response.body);
      final pullRequest = GitHubPullRequest.fromJson(prData);

      await _auditService.logAction(
        actionType: 'github_pull_request_created',
        description: 'Created GitHub pull request: #${pullRequest.number}',
        aiReasoning: 'Created pull request for code review and integration',
        contextData: {
          'pr_number': pullRequest.number,
          'title': title,
          'head_branch': headBranch,
          'base_branch': baseBranch,
          'url': pullRequest.htmlUrl,
        },
      );

      return pullRequest;
    } catch (e) {
      throw Exception('Failed to create pull request: ${e.toString()}');
    }
  }

  /// Get repository issues for task integration
  /// Satisfies Requirements: 11.4 (Issue tracking integration)
  Future<List<GitHubIssue>> getRepositoryIssues({String state = 'open'}) async {
    if (!_isInitialized()) {
      throw Exception('GitHub service not initialized');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/repos/$_username/$_repository/issues?state=$state'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch issues: ${response.statusCode}');
      }

      final issuesData = jsonDecode(response.body) as List;
      return issuesData.map((issue) => GitHubIssue.fromJson(issue)).toList();
    } catch (e) {
      throw Exception('Failed to get repository issues: ${e.toString()}');
    }
  }

  /// Create issue from task
  /// Satisfies Requirements: 11.4 (Issue creation for workflow management)
  Future<GitHubIssue> createIssue(String title, String body, {List<String>? labels}) async {
    if (!_isInitialized()) {
      throw Exception('GitHub service not initialized');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/repos/$_username/$_repository/issues'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'body': body,
          if (labels != null) 'labels': labels,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create issue: ${response.statusCode}');
      }

      final issueData = jsonDecode(response.body);
      final issue = GitHubIssue.fromJson(issueData);

      await _auditService.logAction(
        actionType: 'github_issue_created',
        description: 'Created GitHub issue: #${issue.number}',
        aiReasoning: 'Created issue for task tracking and project management',
        contextData: {
          'issue_number': issue.number,
          'title': title,
          'labels': labels ?? [],
          'url': issue.htmlUrl,
        },
      );

      return issue;
    } catch (e) {
      throw Exception('Failed to create issue: ${e.toString()}');
    }
  }

  /// Get integration status
  Future<GitHubIntegrationStatus> getIntegrationStatus() async {
    if (!_isInitialized()) {
      return GitHubIntegrationStatus(
        connected: false,
        repository: null,
        lastSync: null,
        rateLimitRemaining: 0,
        rateLimitReset: null,
      );
    }

    try {
      // Check rate limit
      final rateLimitResponse = await http.get(
        Uri.parse('$_baseUrl/rate_limit'),
        headers: {
          ..._headers,
          'Authorization': 'token $_accessToken',
        },
      );

      int rateLimitRemaining = 0;
      DateTime? rateLimitReset;
      
      if (rateLimitResponse.statusCode == 200) {
        final rateLimitData = jsonDecode(rateLimitResponse.body);
        rateLimitRemaining = rateLimitData['rate']['remaining'];
        rateLimitReset = DateTime.fromMillisecondsSinceEpoch(
          rateLimitData['rate']['reset'] * 1000,
        );
      }

      return GitHubIntegrationStatus(
        connected: true,
        repository: '$_username/$_repository',
        lastSync: DateTime.now(),
        rateLimitRemaining: rateLimitRemaining,
        rateLimitReset: rateLimitReset,
      );
    } catch (e) {
      return GitHubIntegrationStatus(
        connected: false,
        repository: '$_username/$_repository',
        lastSync: null,
        rateLimitRemaining: 0,
        rateLimitReset: null,
      );
    }
  }

  /// Check if service is initialized
  bool _isInitialized() {
    return _accessToken != null && _username != null && _repository != null;
  }

  /// Dispose resources
  void dispose() {
    _accessToken = null;
    _username = null;
    _repository = null;
  }
}

/// GitHub repository model
class GitHubRepository {
  final int id;
  final String name;
  final String fullName;
  final String cloneUrl;
  final String defaultBranch;
  final bool private;
  final String description;

  GitHubRepository({
    required this.id,
    required this.name,
    required this.fullName,
    required this.cloneUrl,
    required this.defaultBranch,
    required this.private,
    required this.description,
  });

  factory GitHubRepository.fromJson(Map<String, dynamic> json) {
    return GitHubRepository(
      id: json['id'],
      name: json['name'],
      fullName: json['full_name'],
      cloneUrl: json['clone_url'],
      defaultBranch: json['default_branch'],
      private: json['private'],
      description: json['description'] ?? '',
    );
  }
}

/// GitHub branch model
class GitHubBranch {
  final String name;
  final String sha;
  final String url;
  final DateTime createdAt;

  GitHubBranch({
    required this.name,
    required this.sha,
    required this.url,
    required this.createdAt,
  });
}

/// GitHub commit model
class GitHubCommit {
  final String sha;
  final String message;
  final String author;
  final DateTime date;
  final String url;

  GitHubCommit({
    required this.sha,
    required this.message,
    required this.author,
    required this.date,
    required this.url,
  });
}

/// GitHub pull request model
class GitHubPullRequest {
  final int number;
  final String title;
  final String body;
  final String state;
  final String htmlUrl;
  final DateTime createdAt;

  GitHubPullRequest({
    required this.number,
    required this.title,
    required this.body,
    required this.state,
    required this.htmlUrl,
    required this.createdAt,
  });

  factory GitHubPullRequest.fromJson(Map<String, dynamic> json) {
    return GitHubPullRequest(
      number: json['number'],
      title: json['title'],
      body: json['body'] ?? '',
      state: json['state'],
      htmlUrl: json['html_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// GitHub issue model
class GitHubIssue {
  final int number;
  final String title;
  final String body;
  final String state;
  final String htmlUrl;
  final List<String> labels;
  final DateTime createdAt;

  GitHubIssue({
    required this.number,
    required this.title,
    required this.body,
    required this.state,
    required this.htmlUrl,
    required this.labels,
    required this.createdAt,
  });

  factory GitHubIssue.fromJson(Map<String, dynamic> json) {
    final labelsList = (json['labels'] as List?)
        ?.map((label) => label['name'] as String)
        .toList() ?? [];
    
    return GitHubIssue(
      number: json['number'],
      title: json['title'],
      body: json['body'] ?? '',
      state: json['state'],
      htmlUrl: json['html_url'],
      labels: labelsList,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// GitHub integration status
class GitHubIntegrationStatus {
  final bool connected;
  final String? repository;
  final DateTime? lastSync;
  final int rateLimitRemaining;
  final DateTime? rateLimitReset;

  GitHubIntegrationStatus({
    required this.connected,
    required this.repository,
    required this.lastSync,
    required this.rateLimitRemaining,
    required this.rateLimitReset,
  });
}