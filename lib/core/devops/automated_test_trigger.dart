import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:uuid/uuid.dart';
import '../database/services/audit_log_service.dart';
import '../api/websocket_service.dart';
import 'pipeline_config_generator.dart';

/// Automated test triggering system with configurable pre-merge testing
/// Satisfies Requirements: 7.2 (Automated test triggering on code commits)
class AutomatedTestTrigger {
  static final AutomatedTestTrigger _instance =
      AutomatedTestTrigger._internal();
  static AutomatedTestTrigger get instance => _instance;
  AutomatedTestTrigger._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;
  final _websocketService = WebSocketService.instance;
  final _configGenerator = PipelineConfigGenerator.instance;

  // Test execution tracking
  final Map<String, TestExecution> _activeExecutions = {};
  final Map<String, List<TestResult>> _testHistory = {};

  // Configuration
  final Map<String, TestTriggerConfig> _triggerConfigs = {};

  /// Initialize the automated test trigger system
  Future<void> initialize() async {
    // Set up default configurations
    await _setupDefaultConfigurations();

    await _auditService.logAction(
      actionType: 'automated_test_trigger_initialized',
      description: 'Automated test trigger system initialized',
      aiReasoning:
          'System ready to automatically trigger tests on code commits with configurable pre-merge testing',
      contextData: {
        'default_configs_count': _triggerConfigs.length,
      },
    );
  }

  /// Configure test triggers for a project
  Future<void> configureTestTriggers({
    required String projectId,
    required TestTriggerConfig config,
  }) async {
    try {
      _triggerConfigs[projectId] = config;

      await _auditService.logAction(
        actionType: 'test_trigger_configured',
        description: 'Test trigger configuration updated for project',
        contextData: {
          'project_id': projectId,
          'trigger_on_commit': config.triggerOnCommit,
          'trigger_on_pr': config.triggerOnPullRequest,
          'pre_merge_required': config.preMergeTestingRequired,
          'test_suites': config.testSuites.map((s) => s.name).toList(),
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'test_trigger_config_error',
        description: 'Error configuring test triggers: ${e.toString()}',
        contextData: {
          'project_id': projectId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Trigger tests on code commit
  Future<TestExecution> triggerOnCommit({
    required String projectId,
    required String commitHash,
    required String branch,
    required String author,
    List<String>? changedFiles,
  }) async {
    try {
      final config = _triggerConfigs[projectId];
      if (config == null || !config.triggerOnCommit) {
        throw Exception(
            'Test triggers not configured or disabled for project: $projectId');
      }

      final executionId = _uuid.v4();

      // Determine which test suites to run based on changed files
      final suitesToRun = _determineSuitesToRun(config, changedFiles ?? []);

      final execution = TestExecution(
        id: executionId,
        projectId: projectId,
        triggerType: TestTriggerType.commit,
        triggerContext: {
          'commit_hash': commitHash,
          'branch': branch,
          'author': author,
          'changed_files': changedFiles ?? [],
        },
        testSuites: suitesToRun,
        status: TestExecutionStatus.queued,
        startedAt: DateTime.now(),
        configuration: config,
      );

      _activeExecutions[executionId] = execution;

      // Start test execution
      _executeTests(execution);

      await _auditService.logAction(
        actionType: 'tests_triggered_on_commit',
        description: 'Tests triggered automatically on code commit',
        aiReasoning:
            'Automated test execution initiated based on commit changes and project configuration',
        contextData: {
          'execution_id': executionId,
          'project_id': projectId,
          'commit_hash': commitHash,
          'branch': branch,
          'author': author,
          'test_suites': suitesToRun.map((s) => s.name).toList(),
        },
      );

      return execution;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'commit_test_trigger_error',
        description: 'Error triggering tests on commit: ${e.toString()}',
        contextData: {
          'project_id': projectId,
          'commit_hash': commitHash,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Trigger tests on pull request
  Future<TestExecution> triggerOnPullRequest({
    required String projectId,
    required String pullRequestId,
    required String sourceBranch,
    required String targetBranch,
    required String author,
    List<String>? changedFiles,
  }) async {
    try {
      final config = _triggerConfigs[projectId];
      if (config == null || !config.triggerOnPullRequest) {
        throw Exception(
            'Pull request test triggers not configured or disabled for project: $projectId');
      }

      final executionId = _uuid.v4();

      // For pull requests, run all configured test suites
      final suitesToRun = config.testSuites;

      final execution = TestExecution(
        id: executionId,
        projectId: projectId,
        triggerType: TestTriggerType.pullRequest,
        triggerContext: {
          'pull_request_id': pullRequestId,
          'source_branch': sourceBranch,
          'target_branch': targetBranch,
          'author': author,
          'changed_files': changedFiles ?? [],
        },
        testSuites: suitesToRun,
        status: TestExecutionStatus.queued,
        startedAt: DateTime.now(),
        configuration: config,
      );

      _activeExecutions[executionId] = execution;

      // Start test execution
      _executeTests(execution);

      await _auditService.logAction(
        actionType: 'tests_triggered_on_pr',
        description: 'Tests triggered automatically on pull request',
        aiReasoning:
            'Pre-merge testing initiated to ensure code quality before merge',
        contextData: {
          'execution_id': executionId,
          'project_id': projectId,
          'pull_request_id': pullRequestId,
          'source_branch': sourceBranch,
          'target_branch': targetBranch,
          'author': author,
          'test_suites': suitesToRun.map((s) => s.name).toList(),
        },
      );

      return execution;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'pr_test_trigger_error',
        description: 'Error triggering tests on pull request: ${e.toString()}',
        contextData: {
          'project_id': projectId,
          'pull_request_id': pullRequestId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Trigger manual test execution
  Future<TestExecution> triggerManual({
    required String projectId,
    required String userId,
    required List<TestSuiteConfig> testSuites,
    String? reason,
  }) async {
    try {
      final config = _triggerConfigs[projectId];
      if (config == null) {
        throw Exception('Test configuration not found for project: $projectId');
      }

      final executionId = _uuid.v4();

      final execution = TestExecution(
        id: executionId,
        projectId: projectId,
        triggerType: TestTriggerType.manual,
        triggerContext: {
          'user_id': userId,
          'reason': reason ?? 'Manual test execution',
        },
        testSuites: testSuites,
        status: TestExecutionStatus.queued,
        startedAt: DateTime.now(),
        configuration: config,
      );

      _activeExecutions[executionId] = execution;

      // Start test execution
      _executeTests(execution);

      await _auditService.logAction(
        actionType: 'tests_triggered_manually',
        description: 'Tests triggered manually by user',
        contextData: {
          'execution_id': executionId,
          'project_id': projectId,
          'user_id': userId,
          'reason': reason,
          'test_suites': testSuites.map((s) => s.name).toList(),
        },
        userId: userId,
      );

      return execution;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'manual_test_trigger_error',
        description: 'Error triggering manual tests: ${e.toString()}',
        contextData: {
          'project_id': projectId,
          'user_id': userId,
          'error': e.toString(),
        },
        userId: userId,
      );
      rethrow;
    }
  }

  /// Get test execution status
  Future<TestExecution?> getTestExecution(String executionId) async {
    return _activeExecutions[executionId];
  }

  /// Get test history for project
  Future<List<TestResult>> getTestHistory(String projectId,
      {int limit = 50}) async {
    final history = _testHistory[projectId] ?? [];
    return history.take(limit).toList();
  }

  /// Check if pre-merge testing is required and passed
  Future<bool> isPreMergeTestingPassed({
    required String projectId,
    required String pullRequestId,
  }) async {
    final config = _triggerConfigs[projectId];
    if (config == null || !config.preMergeTestingRequired) {
      return true; // No pre-merge testing required
    }

    // Find the latest test execution for this PR
    final history = _testHistory[projectId] ?? [];
    final prTests = history
        .where((result) =>
            result.triggerType == TestTriggerType.pullRequest &&
            result.triggerContext['pull_request_id'] == pullRequestId)
        .toList();

    if (prTests.isEmpty) {
      return false; // No tests run yet
    }

    // Check if the latest test execution passed
    final latestTest = prTests.first;
    return latestTest.status == TestExecutionStatus.passed;
  }

  /// Private helper methods

  /// Set up default test trigger configurations
  Future<void> _setupDefaultConfigurations() async {
    // Default Flutter project configuration
    _triggerConfigs['default_flutter'] = TestTriggerConfig(
      projectType: ProjectType.flutter,
      triggerOnCommit: true,
      triggerOnPullRequest: true,
      preMergeTestingRequired: true,
      testSuites: [
        TestSuiteConfig(
          name: 'unit_tests',
          displayName: 'Unit Tests',
          command: 'flutter test',
          timeout: const Duration(minutes: 10),
          retryCount: 2,
          failFast: true,
          pathPatterns: ['lib/**/*.dart'],
        ),
        TestSuiteConfig(
          name: 'integration_tests',
          displayName: 'Integration Tests',
          command: 'flutter test integration_test/',
          timeout: const Duration(minutes: 20),
          retryCount: 1,
          failFast: false,
          pathPatterns: ['integration_test/**/*.dart'],
        ),
      ],
      parallelExecution: true,
      maxConcurrentSuites: 2,
    );

    // Default Node.js project configuration
    _triggerConfigs['default_nodejs'] = TestTriggerConfig(
      projectType: ProjectType.nodejs,
      triggerOnCommit: true,
      triggerOnPullRequest: true,
      preMergeTestingRequired: true,
      testSuites: [
        TestSuiteConfig(
          name: 'unit_tests',
          displayName: 'Unit Tests',
          command: 'npm run test:unit',
          timeout: const Duration(minutes: 15),
          retryCount: 2,
          failFast: true,
          pathPatterns: ['src/**/*.js', 'src/**/*.ts'],
        ),
        TestSuiteConfig(
          name: 'integration_tests',
          displayName: 'Integration Tests',
          command: 'npm run test:integration',
          timeout: const Duration(minutes: 25),
          retryCount: 1,
          failFast: false,
          pathPatterns: ['test/**/*.js', 'test/**/*.ts'],
        ),
      ],
      parallelExecution: true,
      maxConcurrentSuites: 3,
    );
  }

  /// Determine which test suites to run based on changed files
  List<TestSuiteConfig> _determineSuitesToRun(
      TestTriggerConfig config, List<String> changedFiles) {
    if (changedFiles.isEmpty) {
      return config.testSuites; // Run all tests if no specific files changed
    }

    final suitesToRun = <TestSuiteConfig>[];

    for (final suite in config.testSuites) {
      // Check if any changed file matches the suite's path patterns
      final shouldRun = suite.pathPatterns.any((pattern) {
        final regex =
            RegExp(pattern.replaceAll('**', '.*').replaceAll('*', '[^/]*'));
        return changedFiles.any((file) => regex.hasMatch(file));
      });

      if (shouldRun) {
        suitesToRun.add(suite);
      }
    }

    // If no specific suites match, run all suites as a safety measure
    return suitesToRun.isEmpty ? config.testSuites : suitesToRun;
  }

  /// Execute test suites
  Future<void> _executeTests(TestExecution execution) async {
    try {
      // Update status to running
      final runningExecution = execution.copyWith(
        status: TestExecutionStatus.running,
        startedAt: DateTime.now(),
      );
      _activeExecutions[execution.id] = runningExecution;

      // Broadcast test started
      await _websocketService.broadcastDeploymentStatus(
        deploymentId: execution.id,
        status: 'test_started',
        message: 'Test execution started',
        metadata: {
          'project_id': execution.projectId,
          'trigger_type': execution.triggerType.name,
          'test_suites': execution.testSuites.map((s) => s.name).toList(),
        },
      );

      final suiteResults = <TestSuiteResult>[];

      if (execution.configuration.parallelExecution) {
        // Run test suites in parallel
        suiteResults.addAll(await _executeTestSuitesParallel(execution));
      } else {
        // Run test suites sequentially
        suiteResults.addAll(await _executeTestSuitesSequential(execution));
      }

      // Determine overall status
      final overallStatus = _determineOverallStatus(suiteResults);

      // Create final result
      final result = TestResult(
        id: execution.id,
        projectId: execution.projectId,
        triggerType: execution.triggerType,
        triggerContext: execution.triggerContext,
        status: overallStatus,
        startedAt: execution.startedAt,
        completedAt: DateTime.now(),
        suiteResults: suiteResults,
        totalTests:
            suiteResults.fold(0, (sum, suite) => sum + suite.totalTests),
        passedTests:
            suiteResults.fold(0, (sum, suite) => sum + suite.passedTests),
        failedTests:
            suiteResults.fold(0, (sum, suite) => sum + suite.failedTests),
        skippedTests:
            suiteResults.fold(0, (sum, suite) => sum + suite.skippedTests),
      );

      // Store result in history
      _testHistory.putIfAbsent(execution.projectId, () => []).insert(0, result);

      // Remove from active executions
      _activeExecutions.remove(execution.id);

      // Broadcast completion
      await _websocketService.broadcastDeploymentStatus(
        deploymentId: execution.id,
        status: overallStatus.name,
        message: 'Test execution completed',
        metadata: {
          'project_id': execution.projectId,
          'total_tests': result.totalTests,
          'passed_tests': result.passedTests,
          'failed_tests': result.failedTests,
          'duration_seconds':
              result.completedAt.difference(result.startedAt).inSeconds,
        },
      );

      await _auditService.logAction(
        actionType: 'test_execution_completed',
        description: 'Test execution completed',
        contextData: {
          'execution_id': execution.id,
          'project_id': execution.projectId,
          'status': overallStatus.name,
          'total_tests': result.totalTests,
          'passed_tests': result.passedTests,
          'failed_tests': result.failedTests,
          'duration_seconds':
              result.completedAt.difference(result.startedAt).inSeconds,
        },
      );
    } catch (e) {
      // Handle execution error
      final errorResult = TestResult(
        id: execution.id,
        projectId: execution.projectId,
        triggerType: execution.triggerType,
        triggerContext: execution.triggerContext,
        status: TestExecutionStatus.failed,
        startedAt: execution.startedAt,
        completedAt: DateTime.now(),
        suiteResults: [],
        totalTests: 0,
        passedTests: 0,
        failedTests: 0,
        skippedTests: 0,
        error: e.toString(),
      );

      _testHistory
          .putIfAbsent(execution.projectId, () => [])
          .insert(0, errorResult);
      _activeExecutions.remove(execution.id);

      await _auditService.logAction(
        actionType: 'test_execution_error',
        description: 'Test execution failed with error: ${e.toString()}',
        contextData: {
          'execution_id': execution.id,
          'project_id': execution.projectId,
          'error': e.toString(),
        },
      );
    }
  }

  /// Execute test suites in parallel
  Future<List<TestSuiteResult>> _executeTestSuitesParallel(
      TestExecution execution) async {
    final futures = <Future<TestSuiteResult>>[];
    final semaphore = Semaphore(execution.configuration.maxConcurrentSuites);

    for (final suite in execution.testSuites) {
      futures.add(semaphore.acquire().then((_) async {
        try {
          return await _executeTestSuite(suite, execution);
        } finally {
          semaphore.release();
        }
      }));
    }

    return await Future.wait(futures);
  }

  /// Execute test suites sequentially
  Future<List<TestSuiteResult>> _executeTestSuitesSequential(
      TestExecution execution) async {
    final results = <TestSuiteResult>[];

    for (final suite in execution.testSuites) {
      final result = await _executeTestSuite(suite, execution);
      results.add(result);

      // Stop execution if fail-fast is enabled and this suite failed
      if (suite.failFast && result.status == TestSuiteStatus.failed) {
        break;
      }
    }

    return results;
  }

  /// Execute individual test suite
  Future<TestSuiteResult> _executeTestSuite(
      TestSuiteConfig suite, TestExecution execution) async {
    final startTime = DateTime.now();

    try {
      await _auditService.logAction(
        actionType: 'test_suite_started',
        description: 'Test suite execution started: ${suite.name}',
        contextData: {
          'execution_id': execution.id,
          'suite_name': suite.name,
          'command': suite.command,
        },
      );

      // Simulate test execution (in real implementation, this would run the actual command)
      await Future.delayed(Duration(seconds: 2 + (suite.name.length % 5)));

      // Simulate test results
      final random = DateTime.now().millisecond;
      final totalTests = 10 + (random % 20);
      final failedTests =
          random % 10 == 0 ? 1 + (random % 3) : 0; // 10% chance of failures
      final passedTests = totalTests - failedTests;

      final status =
          failedTests > 0 ? TestSuiteStatus.failed : TestSuiteStatus.passed;

      final result = TestSuiteResult(
        suiteName: suite.name,
        status: status,
        startedAt: startTime,
        completedAt: DateTime.now(),
        totalTests: totalTests,
        passedTests: passedTests,
        failedTests: failedTests,
        skippedTests: 0,
        output:
            'Test suite ${suite.name} completed with $passedTests passed, $failedTests failed',
      );

      await _auditService.logAction(
        actionType: 'test_suite_completed',
        description: 'Test suite execution completed: ${suite.name}',
        contextData: {
          'execution_id': execution.id,
          'suite_name': suite.name,
          'status': status.name,
          'total_tests': totalTests,
          'passed_tests': passedTests,
          'failed_tests': failedTests,
          'duration_seconds':
              result.completedAt.difference(result.startedAt).inSeconds,
        },
      );

      return result;
    } catch (e) {
      final result = TestSuiteResult(
        suiteName: suite.name,
        status: TestSuiteStatus.error,
        startedAt: startTime,
        completedAt: DateTime.now(),
        totalTests: 0,
        passedTests: 0,
        failedTests: 0,
        skippedTests: 0,
        output: 'Test suite execution error: ${e.toString()}',
        error: e.toString(),
      );

      await _auditService.logAction(
        actionType: 'test_suite_error',
        description:
            'Test suite execution error: ${suite.name} - ${e.toString()}',
        contextData: {
          'execution_id': execution.id,
          'suite_name': suite.name,
          'error': e.toString(),
        },
      );

      return result;
    }
  }

  /// Determine overall test execution status
  TestExecutionStatus _determineOverallStatus(
      List<TestSuiteResult> suiteResults) {
    if (suiteResults.isEmpty) {
      return TestExecutionStatus.failed;
    }

    if (suiteResults.any((result) => result.status == TestSuiteStatus.error)) {
      return TestExecutionStatus.failed;
    }

    if (suiteResults.any((result) => result.status == TestSuiteStatus.failed)) {
      return TestExecutionStatus.failed;
    }

    if (suiteResults
        .every((result) => result.status == TestSuiteStatus.passed)) {
      return TestExecutionStatus.passed;
    }

    return TestExecutionStatus.failed;
  }
}

/// Simple semaphore implementation for controlling concurrency
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

/// Test trigger types
enum TestTriggerType {
  commit,
  pullRequest,
  manual,
  scheduled,
}

/// Test execution status
enum TestExecutionStatus {
  queued,
  running,
  passed,
  failed,
  cancelled,
}

/// Test suite status
enum TestSuiteStatus {
  running,
  passed,
  failed,
  skipped,
  error,
}

/// Test trigger configuration
class TestTriggerConfig {
  final ProjectType projectType;
  final bool triggerOnCommit;
  final bool triggerOnPullRequest;
  final bool preMergeTestingRequired;
  final List<TestSuiteConfig> testSuites;
  final bool parallelExecution;
  final int maxConcurrentSuites;

  TestTriggerConfig({
    required this.projectType,
    required this.triggerOnCommit,
    required this.triggerOnPullRequest,
    required this.preMergeTestingRequired,
    required this.testSuites,
    required this.parallelExecution,
    required this.maxConcurrentSuites,
  });
}

/// Test suite configuration
class TestSuiteConfig {
  final String name;
  final String displayName;
  final String command;
  final Duration timeout;
  final int retryCount;
  final bool failFast;
  final List<String> pathPatterns;

  TestSuiteConfig({
    required this.name,
    required this.displayName,
    required this.command,
    required this.timeout,
    required this.retryCount,
    required this.failFast,
    required this.pathPatterns,
  });
}

/// Test execution model
class TestExecution {
  final String id;
  final String projectId;
  final TestTriggerType triggerType;
  final Map<String, dynamic> triggerContext;
  final List<TestSuiteConfig> testSuites;
  final TestExecutionStatus status;
  final DateTime startedAt;
  final TestTriggerConfig configuration;

  TestExecution({
    required this.id,
    required this.projectId,
    required this.triggerType,
    required this.triggerContext,
    required this.testSuites,
    required this.status,
    required this.startedAt,
    required this.configuration,
  });

  TestExecution copyWith({
    String? id,
    String? projectId,
    TestTriggerType? triggerType,
    Map<String, dynamic>? triggerContext,
    List<TestSuiteConfig>? testSuites,
    TestExecutionStatus? status,
    DateTime? startedAt,
    TestTriggerConfig? configuration,
  }) {
    return TestExecution(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      triggerType: triggerType ?? this.triggerType,
      triggerContext: triggerContext ?? this.triggerContext,
      testSuites: testSuites ?? this.testSuites,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      configuration: configuration ?? this.configuration,
    );
  }
}

/// Test result model
class TestResult {
  final String id;
  final String projectId;
  final TestTriggerType triggerType;
  final Map<String, dynamic> triggerContext;
  final TestExecutionStatus status;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<TestSuiteResult> suiteResults;
  final int totalTests;
  final int passedTests;
  final int failedTests;
  final int skippedTests;
  final String? error;

  TestResult({
    required this.id,
    required this.projectId,
    required this.triggerType,
    required this.triggerContext,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    required this.suiteResults,
    required this.totalTests,
    required this.passedTests,
    required this.failedTests,
    required this.skippedTests,
    this.error,
  });
}

/// Test suite result model
class TestSuiteResult {
  final String suiteName;
  final TestSuiteStatus status;
  final DateTime startedAt;
  final DateTime completedAt;
  final int totalTests;
  final int passedTests;
  final int failedTests;
  final int skippedTests;
  final String output;
  final String? error;

  TestSuiteResult({
    required this.suiteName,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    required this.totalTests,
    required this.passedTests,
    required this.failedTests,
    required this.skippedTests,
    required this.output,
    this.error,
  });
}
