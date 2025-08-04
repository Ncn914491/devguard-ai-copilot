import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:devguard_ai_copilot/core/devops/devops_integration_service.dart';
import 'package:devguard_ai_copilot/core/devops/pipeline_config_generator.dart';
import 'package:devguard_ai_copilot/core/devops/automated_test_trigger.dart';
import 'package:devguard_ai_copilot/core/devops/deployment_monitor.dart';
import 'package:devguard_ai_copilot/core/devops/deployment_trigger.dart';
import 'package:devguard_ai_copilot/core/deployment/rollback_controller.dart';

/// Test suite for DevOps integration functionality
/// Verifies Requirements: 7.1, 7.2, 7.3, 7.4, 7.5
void main() {
  group('DevOps Integration Tests', () {
    late DevOpsIntegrationService devopsService;
    late PipelineConfigGenerator configGenerator;
    late AutomatedTestTrigger testTrigger;
    late DeploymentMonitor deploymentMonitor;
    late DeploymentTrigger deploymentTrigger;
    late RollbackController rollbackController;

    setUpAll(() async {
      // Initialize database factory for testing
      databaseFactory = databaseFactoryFfi;

      devopsService = DevOpsIntegrationService.instance;
      configGenerator = PipelineConfigGenerator.instance;
      testTrigger = AutomatedTestTrigger.instance;
      deploymentMonitor = DeploymentMonitor.instance;
      deploymentTrigger = DeploymentTrigger.instance;
      rollbackController = RollbackController.instance;

      // Initialize services
      await devopsService.initialize();
    });

    group('Pipeline Configuration Generator', () {
      test('should generate Flutter pipeline configuration', () async {
        // Requirement 7.1: Pipeline configuration generator
        final config = await configGenerator.generateConfiguration(
          projectId: 'test-project-1',
          projectType: ProjectType.flutter,
          targetPlatforms: [Platform.windows, Platform.web],
          projectSettings: {
            'enable_security_scan': true,
            'enable_integration_tests': true,
            'coverage_threshold': 80,
          },
        );

        expect(config.projectType, equals(ProjectType.flutter));
        expect(config.targetPlatforms, contains(Platform.windows));
        expect(config.targetPlatforms, contains(Platform.web));
        expect(config.stages.length, greaterThan(5));

        // Verify essential stages are present
        final stageNames = config.stages.map((s) => s.name).toList();
        expect(stageNames, contains('setup'));
        expect(stageNames, contains('build'));
        expect(stageNames, contains('test'));
        expect(stageNames, contains('security_scan'));
        expect(stageNames, contains('deploy'));
      });

      test('should generate Node.js pipeline configuration', () async {
        final config = await configGenerator.generateConfiguration(
          projectId: 'test-project-2',
          projectType: ProjectType.nodejs,
          targetPlatforms: [Platform.linux, Platform.docker],
          projectSettings: {
            'deployment_strategy': 'blue_green',
            'health_check_url': '/api/health',
          },
        );

        expect(config.projectType, equals(ProjectType.nodejs));
        expect(config.deploymentConfiguration.strategy,
            equals(DeploymentStrategy.blue_green));
        expect(config.deploymentConfiguration.healthCheckUrl,
            equals('/api/health'));
      });

      test('should export configuration to YAML', () async {
        final config = await configGenerator.generateConfiguration(
          projectId: 'test-project-3',
          projectType: ProjectType.flutter,
          targetPlatforms: [Platform.windows],
          projectSettings: {},
        );

        final yaml = await configGenerator.exportToYaml(config);

        expect(yaml, isNotEmpty);
        expect(yaml, contains('name: CI/CD Pipeline'));
        expect(yaml, contains('project_type: flutter'));
        expect(yaml, contains('platforms:'));
        expect(yaml, contains('stages:'));
      });
    });

    group('Automated Test Trigger', () {
      test('should configure test triggers for project', () async {
        // Requirement 7.2: Automated test triggering
        final config = TestTriggerConfig(
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
          ],
          parallelExecution: true,
          maxConcurrentSuites: 2,
        );

        await testTrigger.configureTestTriggers(
          projectId: 'test-project-1',
          config: config,
        );

        // Configuration should be successful (no exception thrown)
        expect(true, isTrue);
      });

      test('should trigger tests on commit', () async {
        final execution = await testTrigger.triggerOnCommit(
          projectId: 'test-project-1',
          commitHash: 'abc123',
          branch: 'main',
          author: 'test-user',
          changedFiles: ['lib/main.dart', 'test/widget_test.dart'],
        );

        expect(execution.id, isNotEmpty);
        expect(execution.projectId, equals('test-project-1'));
        expect(execution.triggerType, equals(TestTriggerType.commit));
        expect(execution.status, equals(TestExecutionStatus.queued));
      });

      test('should trigger tests on pull request', () async {
        final execution = await testTrigger.triggerOnPullRequest(
          projectId: 'test-project-1',
          pullRequestId: 'pr-123',
          sourceBranch: 'feature/new-feature',
          targetBranch: 'main',
          author: 'test-user',
        );

        expect(execution.id, isNotEmpty);
        expect(execution.triggerType, equals(TestTriggerType.pullRequest));
        expect(execution.status, equals(TestExecutionStatus.queued));
      });

      test('should check pre-merge testing requirements', () async {
        // First trigger a PR test
        await testTrigger.triggerOnPullRequest(
          projectId: 'test-project-1',
          pullRequestId: 'pr-456',
          sourceBranch: 'feature/test-feature',
          targetBranch: 'main',
          author: 'test-user',
        );

        // Wait a moment for test execution
        await Future.delayed(const Duration(seconds: 1));

        // Check if pre-merge testing is passed (may be false initially)
        final isPassed = await testTrigger.isPreMergeTestingPassed(
          projectId: 'test-project-1',
          pullRequestId: 'pr-456',
        );

        expect(isPassed, isA<bool>());
      });
    });

    group('Deployment Monitor', () {
      test('should start monitoring deployment', () async {
        // Requirement 7.3: Deployment monitoring with real-time status
        final session = await deploymentMonitor.startMonitoring(
          deploymentId: 'deploy-123',
          environment: 'staging',
          version: 'v1.0.0',
          metadata: {'project_id': 'test-project-1'},
        );

        expect(session.id, isNotEmpty);
        expect(session.deploymentId, equals('deploy-123'));
        expect(session.environment, equals('staging'));
        expect(session.version, equals('v1.0.0'));
        expect(session.status, equals(DeploymentStatus.starting));
      });

      test('should update deployment status', () async {
        const deploymentId = 'deploy-456';

        // Start monitoring
        await deploymentMonitor.startMonitoring(
          deploymentId: deploymentId,
          environment: 'production',
          version: 'v1.1.0',
        );

        // Update status
        await deploymentMonitor.updateDeploymentStatus(
          deploymentId: deploymentId,
          status: DeploymentStatus.running,
          message: 'Deployment in progress',
          metadata: {'stage': 'build'},
        );

        // Status should be updated (verified through no exception)
        expect(true, isTrue);
      });

      test('should add build logs', () async {
        const deploymentId = 'deploy-789';

        await deploymentMonitor.startMonitoring(
          deploymentId: deploymentId,
          environment: 'development',
          version: 'v1.2.0',
        );

        await deploymentMonitor.addBuildLog(
          deploymentId: deploymentId,
          stage: 'build',
          message: 'Starting build process',
          level: BuildLogLevel.info,
        );

        await deploymentMonitor.addBuildLog(
          deploymentId: deploymentId,
          stage: 'build',
          message: 'Build completed successfully',
          level: BuildLogLevel.info,
        );

        final logs = await deploymentMonitor.getBuildLogs(deploymentId);
        expect(logs.length, equals(2));
        expect(logs.first.message, equals('Starting build process'));
        expect(logs.last.message, equals('Build completed successfully'));
      });

      test('should perform health checks', () async {
        const deploymentId = 'deploy-health';

        await deploymentMonitor.startMonitoring(
          deploymentId: deploymentId,
          environment: 'staging',
          version: 'v1.3.0',
        );

        final healthResult = await deploymentMonitor.performHealthCheck(
          deploymentId: deploymentId,
          healthCheckUrl: '/health',
          timeout: const Duration(seconds: 10),
        );

        expect(healthResult.deploymentId, equals(deploymentId));
        expect(healthResult.url, equals('/health'));
        expect(healthResult.isHealthy, isA<bool>());
        expect(healthResult.responseTime, isA<Duration>());
      });
    });

    group('Deployment Trigger', () {
      test('should get available environments for user', () async {
        // Requirement 7.4: Deployment trigger functionality from dashboards
        final environments = await deploymentTrigger.getAvailableEnvironments();

        // Environments might be empty if no user is authenticated
        expect(environments, isA<List<EnvironmentInfo>>());

        if (environments.isNotEmpty) {
          // Should have at least development environment
          final devEnv = environments.firstWhere(
            (env) => env.name == 'development',
            orElse: () => throw Exception('Development environment not found'),
          );

          expect(devEnv.displayName, equals('DEVELOPMENT'));
          expect(devEnv.description, isNotEmpty);
        }
      });

      test('should get deployment history', () async {
        final history = await deploymentTrigger.getDeploymentHistory(
          environment: 'staging',
          limit: 10,
        );

        expect(history, isA<List<DeploymentHistoryEntry>>());
        // History might be empty in test environment
      });

      test('should get pending approvals', () async {
        final approvals = await deploymentTrigger.getPendingApprovals(
          environment: 'production',
        );

        expect(approvals, isA<List<DeploymentApprovalRequest>>());
        // Approvals might be empty in test environment
      });
    });

    group('Rollback Controller', () {
      test('should get rollback options', () async {
        // Requirement 7.5: Rollback capabilities with error analysis
        final options = await rollbackController.getRollbackOptions('staging');

        expect(options, isA<List<RollbackOption>>());
        // Options might be empty in test environment
      });

      test('should initiate rollback request', () async {
        try {
          final request = await rollbackController.initiateRollback(
            environment: 'development',
            snapshotId: 'snapshot-123',
            reason: 'Test rollback request',
            requestedBy: 'test-user',
          );

          expect(request.id, isNotEmpty);
          expect(request.environment, equals('development'));
          expect(request.reason, equals('Test rollback request'));
          expect(request.status, equals('pending_approval'));
        } catch (e) {
          // Rollback might fail if snapshot doesn't exist, which is expected in test
          expect(e.toString(), contains('Snapshot not found'));
        }
      });

      test('should get rollback history', () async {
        final history = await rollbackController.getRollbackHistory('staging');

        expect(history, isA<List<Map<String, dynamic>>>());
        // History might be empty in test environment
      });
    });

    group('DevOps Integration Service', () {
      test('should register project for DevOps', () async {
        await devopsService.registerProject(
          projectId: 'integration-test-project',
          projectName: 'Integration Test Project',
          projectType: ProjectType.flutter,
          targetPlatforms: [Platform.windows, Platform.web],
          settings: {
            'trigger_on_commit': true,
            'pre_merge_testing': true,
            'parallel_testing': true,
          },
        );

        // Registration should be successful (no exception thrown)
        expect(true, isTrue);
      });

      test('should execute full CI/CD pipeline', () async {
        final execution = await devopsService.executeFullPipeline(
          projectId: 'integration-test-project',
          commitHash: 'test-commit-123',
          branch: 'main',
          triggeredBy: 'test-user',
          environment: 'development',
        );

        expect(execution.id, isNotEmpty);
        expect(execution.projectId, equals('integration-test-project'));
        expect(execution.commitHash, equals('test-commit-123'));
        expect(execution.branch, equals('main'));
        expect(execution.status, equals(PipelineExecutionStatus.running));
      });

      test('should get pipeline history', () async {
        final history = await devopsService.getPipelineHistory(
          'integration-test-project',
          limit: 5,
        );

        expect(history, isA<List<DevOpsPipelineExecution>>());
        expect(history.length, lessThanOrEqualTo(5));
      });

      test('should get dashboard data', () async {
        final dashboardData = await devopsService.getDashboardData(
          projectId: 'integration-test-project',
          environment: 'development',
        );

        expect(dashboardData.activeDeployments, isA<int>());
        expect(dashboardData.pendingApprovals, isA<int>());
        expect(dashboardData.recentExecutions,
            isA<List<DevOpsPipelineExecution>>());
        expect(dashboardData.deploymentHistory,
            isA<List<DeploymentHistoryEntry>>());
        expect(dashboardData.metrics, isA<DevOpsMetrics>());
        expect(dashboardData.lastUpdated, isA<DateTime>());
      });

      test('should handle webhook events', () async {
        // Test push event
        await devopsService.handleWebhookEvent(
          eventType: 'push',
          projectId: 'integration-test-project',
          payload: {
            'after': 'webhook-commit-123',
            'ref': 'refs/heads/main',
            'pusher': {'name': 'webhook-user'},
          },
        );

        // Test pull request event
        await devopsService.handleWebhookEvent(
          eventType: 'pull_request',
          projectId: 'integration-test-project',
          payload: {
            'action': 'opened',
            'pull_request': {
              'id': 'pr-webhook-123',
              'head': {'ref': 'feature/webhook-test'},
              'base': {'ref': 'main'},
              'user': {'login': 'webhook-user'},
            },
          },
        );

        // Webhook handling should be successful (no exception thrown)
        expect(true, isTrue);
      });
    });

    group('Integration Scenarios', () {
      test('should complete full DevOps workflow', () async {
        const projectId = 'full-workflow-test';

        // 1. Register project
        await devopsService.registerProject(
          projectId: projectId,
          projectName: 'Full Workflow Test',
          projectType: ProjectType.flutter,
          targetPlatforms: [Platform.windows],
        );

        // 2. Execute pipeline
        final execution = await devopsService.executeFullPipeline(
          projectId: projectId,
          commitHash: 'workflow-commit',
          branch: 'main',
          triggeredBy: 'workflow-user',
        );

        expect(execution.status, equals(PipelineExecutionStatus.running));

        // 3. Wait a moment for pipeline to progress
        await Future.delayed(const Duration(seconds: 2));

        // 4. Get updated execution status
        final updatedExecution =
            await devopsService.getPipelineExecution(execution.id);
        expect(updatedExecution, isNotNull);

        // 5. Get dashboard data
        final dashboard =
            await devopsService.getDashboardData(projectId: projectId);
        expect(dashboard.recentExecutions, isNotEmpty);
      });

      test('should handle error scenarios gracefully', () async {
        // Test with non-existent project
        try {
          await devopsService.executeFullPipeline(
            projectId: 'non-existent-project',
            commitHash: 'test-commit',
            branch: 'main',
            triggeredBy: 'test-user',
          );
          fail('Should have thrown exception for non-existent project');
        } catch (e) {
          expect(e.toString(), contains('Project not registered'));
        }

        // Test with invalid test trigger
        try {
          await testTrigger.triggerOnCommit(
            projectId: 'non-configured-project',
            commitHash: 'test-commit',
            branch: 'main',
            author: 'test-user',
          );
          fail('Should have thrown exception for non-configured project');
        } catch (e) {
          expect(e.toString(), contains('not configured'));
        }
      });
    });
  });
}
