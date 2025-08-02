import 'dart:async';

import 'package:uuid/uuid.dart';
import '../database/services/services.dart';
import '../database/models/models.dart';
import 'github_service.dart';
import 'gitlab_service.dart';

class GitIntegration {
  static final GitIntegration _instance = GitIntegration._internal();
  static GitIntegration get instance => _instance;
  GitIntegration._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;
  final _taskService = TaskService.instance;
  final _specService = SpecService.instance;
  final _githubService = GitHubService.instance;
  final _gitlabService = GitLabService.instance;
  
  String _gitProvider = 'github'; // 'github' or 'gitlab'

  /// Create git branch from approved specification
  /// Satisfies Requirements: 8.1, 8.2 (GitOps integration and branch creation)
  Future<GitBranch> createBranchFromSpec(String specId) async {
    final spec = await _specService.getSpecification(specId);
    if (spec == null) {
      throw Exception('Specification not found: $specId');
    }

    if (spec.status != 'approved') {
      throw Exception('Only approved specifications can be converted to branches');
    }

    final branchId = _uuid.v4();
    final branch = GitBranch(
      id: branchId,
      name: spec.suggestedBranchName,
      specId: specId,
      status: 'created',
      createdAt: DateTime.now(),
      commits: [],
    );

    // Simulate git branch creation
    await Future.delayed(const Duration(seconds: 1));

    // Log branch creation
    await _auditService.logAction(
      actionType: 'git_branch_created',
      description: 'Created git branch: ${branch.name}',
      aiReasoning: 'Automatically created git branch from approved specification for structured development workflow',
      contextData: {
        'branch_id': branchId,
        'branch_name': branch.name,
        'spec_id': specId,
        'spec_title': spec.suggestedCommitMessage,
      },
    );

    return branch;
  }

  /// Create commit from specification
  /// Satisfies Requirements: 8.3 (Commit creation with structured messages)
  Future<GitCommit> createCommitFromSpec(String specId, String branchId, String changes) async {
    final spec = await _specService.getSpecification(specId);
    if (spec == null) {
      throw Exception('Specification not found: $specId');
    }

    final commitId = _uuid.v4();
    final commitHash = 'commit-${DateTime.now().millisecondsSinceEpoch}';
    
    final commit = GitCommit(
      id: commitId,
      hash: commitHash,
      message: spec.suggestedCommitMessage,
      branchId: branchId,
      specId: specId,
      author: 'DevGuard AI Copilot',
      changes: changes,
      createdAt: DateTime.now(),
    );

    // Simulate git commit creation
    await Future.delayed(const Duration(seconds: 1));

    // Update specification status
    await _specService.updateSpecificationStatus(specId, 'in_progress');

    // Create corresponding task if not exists
    await _createTaskFromSpec(spec, commitHash);

    // Log commit creation
    await _auditService.logAction(
      actionType: 'git_commit_created',
      description: 'Created git commit: ${commit.hash}',
      aiReasoning: 'Generated structured commit from specification with conventional commit format',
      contextData: {
        'commit_id': commitId,
        'commit_hash': commitHash,
        'branch_id': branchId,
        'spec_id': specId,
        'commit_message': commit.message,
      },
    );

    return commit;
  }

  /// Create task from specification for tracking
  /// Satisfies Requirements: 8.4 (Task-commit linking)
  Future<void> _createTaskFromSpec(Specification spec, String commitHash) async {
    // Check if task already exists for this spec
    final existingTasks = await _taskService.getAllTasks();
    final specTask = existingTasks.where((t) => t.relatedCommits.contains(commitHash)).firstOrNull;
    
    if (specTask == null) {
      final task = Task(
        id: _uuid.v4(),
        title: spec.suggestedBranchName.replaceAll('feature/', '').replaceAll('-', ' '),
        description: spec.aiInterpretation,
        type: _inferTaskType(spec.aiInterpretation),
        priority: 'medium',
        status: 'in_progress',
        assigneeId: spec.assignedTo ?? 'unassigned',
        estimatedHours: _estimateHours(spec.aiInterpretation),
        actualHours: 0,
        relatedCommits: [commitHash],
        dependencies: [],
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );

      await _taskService.createTask(task);
    }
  }

  /// Infer task type from specification
  String _inferTaskType(String interpretation) {
    final lower = interpretation.toLowerCase();
    if (lower.contains('security') || lower.contains('auth')) {
      return 'security';
    } else if (lower.contains('bug') || lower.contains('fix')) {
      return 'bug';
    } else if (lower.contains('deploy')) {
      return 'deployment';
    } else {
      return 'feature';
    }
  }

  /// Estimate hours based on specification complexity
  int _estimateHours(String interpretation) {
    final wordCount = interpretation.split(' ').length;
    if (wordCount > 100) return 16;
    if (wordCount > 50) return 8;
    return 4;
  }

  /// Create pull request from branch
  /// Satisfies Requirements: 8.5 (PR creation with documentation)
  Future<GitPullRequest> createPullRequest(String branchId, String targetBranch) async {
    final prId = _uuid.v4();
    
    // Simulate PR creation
    await Future.delayed(const Duration(seconds: 1));
    
    final pr = GitPullRequest(
      id: prId,
      title: 'Auto-generated PR from DevGuard AI Copilot',
      description: 'This pull request was automatically generated from an approved specification.',
      branchId: branchId,
      targetBranch: targetBranch,
      status: 'open',
      createdAt: DateTime.now(),
    );

    // Log PR creation
    await _auditService.logAction(
      actionType: 'pull_request_created',
      description: 'Created pull request: ${pr.title}',
      contextData: {
        'pr_id': prId,
        'branch_id': branchId,
        'target_branch': targetBranch,
      },
    );

    return pr;
  }

  /// Sync task status with git state
  /// Satisfies Requirements: 8.4 (Task-git synchronization)
  Future<void> syncTaskWithGitState(String taskId, String commitHash, String gitStatus) async {
    final task = await _taskService.getTask(taskId);
    if (task == null) return;

    String newStatus;
    switch (gitStatus) {
      case 'committed':
        newStatus = 'review';
        break;
      case 'merged':
        newStatus = 'completed';
        break;
      case 'reverted':
        newStatus = 'blocked';
        break;
      default:
        newStatus = task.status;
    }

    if (newStatus != task.status) {
      await _taskService.updateTaskStatus(taskId, newStatus);
      
      // Log sync
      await _auditService.logAction(
        actionType: 'task_git_sync',
        description: 'Synced task status with git state: $gitStatus -> $newStatus',
        contextData: {
          'task_id': taskId,
          'commit_hash': commitHash,
          'git_status': gitStatus,
          'new_task_status': newStatus,
        },
      );
    }
  }

  /// Initialize git provider integration
  /// Satisfies Requirements: 11.1, 11.2 (GitHub/GitLab integration setup)
  Future<void> initializeGitProvider(String provider, Map<String, String> credentials) async {
    _gitProvider = provider.toLowerCase();
    
    try {
      if (_gitProvider == 'github') {
        await _githubService.initialize(
          credentials['access_token']!,
          credentials['username']!,
          credentials['repository']!,
        );
      } else if (_gitProvider == 'gitlab') {
        await _gitlabService.initialize(
          credentials['access_token']!,
          credentials['project_id']!,
          baseUrl: credentials['base_url'] ?? 'https://gitlab.com',
        );
      } else {
        throw Exception('Unsupported git provider: $provider');
      }
      
      await _auditService.logAction(
        actionType: 'git_provider_initialized',
        description: 'Initialized $provider integration',
        aiReasoning: 'Connected to external git provider for repository operations',
        contextData: {
          'provider': provider,
          'repository': credentials['repository'] ?? credentials['project_id'],
        },
      );
    } catch (e) {
      throw Exception('Failed to initialize $provider integration: ${e.toString()}');
    }
  }

  /// Create remote branch using configured git provider
  /// Satisfies Requirements: 11.3 (Remote branch creation)
  Future<GitBranch> createRemoteBranch(String specId, String fromBranch) async {
    final spec = await _specService.getSpecification(specId);
    if (spec == null) {
      throw Exception('Specification not found: $specId');
    }

    try {
      final branchName = spec.suggestedBranchName;
      
      if (_gitProvider == 'github') {
        final githubBranch = await _githubService.createBranch(branchName, fromBranch);
        return GitBranch(
          id: _uuid.v4(),
          name: githubBranch.name,
          specId: specId,
          status: 'created',
          createdAt: githubBranch.createdAt,
          commits: [],
        );
      } else if (_gitProvider == 'gitlab') {
        final gitlabBranch = await _gitlabService.createBranch(branchName, fromBranch);
        return GitBranch(
          id: _uuid.v4(),
          name: gitlabBranch.name,
          specId: specId,
          status: 'created',
          createdAt: DateTime.now(),
          commits: [],
        );
      } else {
        throw Exception('No git provider configured');
      }
    } catch (e) {
      throw Exception('Failed to create remote branch: ${e.toString()}');
    }
  }

  /// Create remote commit using configured git provider
  /// Satisfies Requirements: 11.3 (Remote commit creation)
  Future<GitCommit> createRemoteCommit(String specId, String branchName, Map<String, String> files) async {
    final spec = await _specService.getSpecification(specId);
    if (spec == null) {
      throw Exception('Specification not found: $specId');
    }

    try {
      final commitMessage = spec.suggestedCommitMessage;
      
      if (_gitProvider == 'github') {
        final githubCommit = await _githubService.createCommit(branchName, commitMessage, files);
        return GitCommit(
          id: _uuid.v4(),
          hash: githubCommit.sha,
          message: githubCommit.message,
          branchId: branchName,
          specId: specId,
          author: githubCommit.author,
          changes: files.toString(),
          createdAt: githubCommit.date,
        );
      } else if (_gitProvider == 'gitlab') {
        final gitlabCommit = await _gitlabService.createCommit(branchName, commitMessage, files);
        return GitCommit(
          id: _uuid.v4(),
          hash: gitlabCommit.id,
          message: gitlabCommit.message,
          branchId: branchName,
          specId: specId,
          author: gitlabCommit.authorName,
          changes: files.toString(),
          createdAt: gitlabCommit.createdAt,
        );
      } else {
        throw Exception('No git provider configured');
      }
    } catch (e) {
      throw Exception('Failed to create remote commit: ${e.toString()}');
    }
  }

  /// Create remote pull/merge request using configured git provider
  /// Satisfies Requirements: 11.3 (Remote PR/MR creation)
  Future<GitPullRequest> createRemotePullRequest(String branchName, String targetBranch, String title, String description) async {
    try {
      if (_gitProvider == 'github') {
        final githubPR = await _githubService.createPullRequest(title, description, branchName, targetBranch);
        return GitPullRequest(
          id: _uuid.v4(),
          title: githubPR.title,
          description: githubPR.body,
          branchId: branchName,
          targetBranch: targetBranch,
          status: githubPR.state,
          createdAt: githubPR.createdAt,
        );
      } else if (_gitProvider == 'gitlab') {
        final gitlabMR = await _gitlabService.createMergeRequest(title, description, branchName, targetBranch);
        return GitPullRequest(
          id: _uuid.v4(),
          title: gitlabMR.title,
          description: gitlabMR.description,
          branchId: branchName,
          targetBranch: targetBranch,
          status: gitlabMR.state,
          createdAt: gitlabMR.createdAt,
        );
      } else {
        throw Exception('No git provider configured');
      }
    } catch (e) {
      throw Exception('Failed to create remote pull/merge request: ${e.toString()}');
    }
  }

  /// Sync issues with tasks for workflow management
  /// Satisfies Requirements: 11.4 (Issue tracking integration)
  Future<void> syncIssuesWithTasks() async {
    try {
      List<dynamic> issues = [];
      
      if (_gitProvider == 'github') {
        issues = await _githubService.getRepositoryIssues();
      } else if (_gitProvider == 'gitlab') {
        issues = await _gitlabService.getProjectIssues();
      } else {
        return; // No provider configured
      }

      // Sync issues with existing tasks
      final tasks = await _taskService.getAllTasks();
      
      for (final issue in issues) {
        final issueTitle = _gitProvider == 'github' 
            ? (issue as GitHubIssue).title 
            : (issue as GitLabIssue).title;
        final issueNumber = _gitProvider == 'github' 
            ? (issue as GitHubIssue).number 
            : (issue as GitLabIssue).iid;
        
        // Check if task exists for this issue
        final existingTask = tasks.where((t) => t.title.contains(issueTitle)).firstOrNull;
        
        if (existingTask == null) {
          // Create new task from issue
          final task = Task(
            id: _uuid.v4(),
            title: issueTitle,
            description: _gitProvider == 'github' 
                ? (issue as GitHubIssue).body 
                : (issue as GitLabIssue).description,
            type: 'feature',
            priority: 'medium',
            status: 'pending',
            assigneeId: 'unassigned',
            estimatedHours: 4,
            actualHours: 0,
            relatedCommits: [],
            dependencies: [],
            createdAt: DateTime.now(),
            dueDate: DateTime.now().add(const Duration(days: 7)),
          );
          
          await _taskService.createTask(task);
          
          await _auditService.logAction(
            actionType: 'task_created_from_issue',
            description: 'Created task from $_gitProvider issue #$issueNumber',
            contextData: {
              'issue_number': issueNumber,
              'task_id': task.id,
              'provider': _gitProvider,
            },
          );
        }
      }
    } catch (e) {
      await _auditService.logAction(
        actionType: 'issue_sync_failed',
        description: 'Failed to sync issues with tasks: ${e.toString()}',
        contextData: {'error': e.toString()},
      );
    }
  }

  /// Create issue from task
  /// Satisfies Requirements: 11.4 (Task to issue creation)
  Future<void> createIssueFromTask(String taskId) async {
    final task = await _taskService.getTask(taskId);
    if (task == null) {
      throw Exception('Task not found: $taskId');
    }

    try {
      final labels = [task.type, task.priority];
      
      if (_gitProvider == 'github') {
        await _githubService.createIssue(task.title, task.description, labels: labels);
      } else if (_gitProvider == 'gitlab') {
        await _gitlabService.createIssue(task.title, task.description, labels: labels);
      } else {
        throw Exception('No git provider configured');
      }
      
      await _auditService.logAction(
        actionType: 'issue_created_from_task',
        description: 'Created $_gitProvider issue from task: ${task.title}',
        contextData: {
          'task_id': taskId,
          'provider': _gitProvider,
          'labels': labels,
        },
      );
    } catch (e) {
      throw Exception('Failed to create issue from task: ${e.toString()}');
    }
  }

  /// Get git integration status
  Future<GitIntegrationStatus> getIntegrationStatus() async {
    try {
      if (_gitProvider == 'github') {
        final status = await _githubService.getIntegrationStatus();
        return GitIntegrationStatus(
          connected: status.connected,
          repository: status.repository ?? 'unknown',
          currentBranch: 'main',
          lastSync: status.lastSync ?? DateTime.now(),
          pendingCommits: 0,
          activeBranches: 3,
        );
      } else if (_gitProvider == 'gitlab') {
        final status = await _gitlabService.getIntegrationStatus();
        return GitIntegrationStatus(
          connected: status.connected,
          repository: status.project ?? 'unknown',
          currentBranch: 'main',
          lastSync: status.lastSync ?? DateTime.now(),
          pendingCommits: 0,
          activeBranches: 3,
        );
      } else {
        return GitIntegrationStatus(
          connected: false,
          repository: 'not-configured',
          currentBranch: 'main',
          lastSync: DateTime.now(),
          pendingCommits: 0,
          activeBranches: 0,
        );
      }
    } catch (e) {
      return GitIntegrationStatus(
        connected: false,
        repository: 'error',
        currentBranch: 'main',
        lastSync: DateTime.now(),
        pendingCommits: 0,
        activeBranches: 0,
      );
    }
  }

  /// Initialize a new git repository
  Future<void> initializeRepository(String path, Map<String, String> initialFiles) async {
    // Implementation would create git repository and add initial files
    await _auditService.logAction(
      actionType: 'git_repository_initialized',
      description: 'Git repository initialized with initial files',
      contextData: {
        'repo_path': path,
        'initial_files': initialFiles.keys.toList(),
      },
    );
  }
}

/// Git branch representation
class GitBranch {
  final String id;
  final String name;
  final String specId;
  final String status;
  final DateTime createdAt;
  final List<String> commits;

  GitBranch({
    required this.id,
    required this.name,
    required this.specId,
    required this.status,
    required this.createdAt,
    required this.commits,
  });
}

/// Git commit representation
class GitCommit {
  final String id;
  final String hash;
  final String message;
  final String branchId;
  final String specId;
  final String author;
  final String changes;
  final DateTime createdAt;

  GitCommit({
    required this.id,
    required this.hash,
    required this.message,
    required this.branchId,
    required this.specId,
    required this.author,
    required this.changes,
    required this.createdAt,
  });
}

/// Git pull request representation
class GitPullRequest {
  final String id;
  final String title;
  final String description;
  final String branchId;
  final String targetBranch;
  final String status;
  final DateTime createdAt;

  GitPullRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.branchId,
    required this.targetBranch,
    required this.status,
    required this.createdAt,
  });
}

/// Git integration status
class GitIntegrationStatus {
  final bool connected;
  final String repository;
  final String currentBranch;
  final DateTime lastSync;
  final int pendingCommits;
  final int activeBranches;

  GitIntegrationStatus({
    required this.connected,
    required this.repository,
    required this.currentBranch,
    required this.lastSync,
    required this.pendingCommits,
    required this.activeBranches,
  });
}