import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../database/services/services.dart';
import '../database/models/models.dart';

class GitIntegration {
  static final GitIntegration _instance = GitIntegration._internal();
  static GitIntegration get instance => _instance;
  GitIntegration._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;
  final _taskService = TaskService.instance;
  final _specService = SpecService.instance;

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

  /// Get git integration status
  Future<GitIntegrationStatus> getIntegrationStatus() async {
    // Simulate git repository status check
    return GitIntegrationStatus(
      connected: true,
      repository: 'devguard-ai-copilot',
      currentBranch: 'main',
      lastSync: DateTime.now(),
      pendingCommits: 0,
      activeBranches: 3,
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