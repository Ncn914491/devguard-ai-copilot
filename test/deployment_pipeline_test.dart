import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/deployment/deployment_pipeline.dart';
import '../lib/core/database/services/services.dart';
import '../lib/core/database/database_service.dart';
import '../lib/core/database/models/models.dart';

void main() {
  group('Deployment Pipeline Tests', () {
    late DeploymentPipeline pipeline;
    late SpecService specService;
    late DeploymentService deploymentService;
    late DatabaseService databaseService;

    setUpAll(() async {
      // Initialize FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      // Initialize database service
      databaseService = DatabaseService.instance;
      await databaseService.initialize(':memory:');
      
      pipeline = DeploymentPipeline.instance;
      specService = SpecService.instance;
      deploymentService = DeploymentService.instance;
    });

    tearDownAll(() async {
      await databaseService.close();
    });

    test('should generate CI/CD pipeline configuration from specification', () async {
      // Create a test specification
      final spec = Specification(
        id: 'test-spec-1',
        originalText: 'Create a secure login system with authentication',
        aiInterpretation: 'Security-focused login system with authentication and validation',
        suggestedBranchName: 'feature/secure-login',
        status: 'approved',
        createdAt: DateTime.now(),
      );
      
      await specService.createSpecification(spec);

      // Generate pipeline configuration
      final config = await pipeline.generatePipelineConfig(spec.id);

      // Verify pipeline configuration
      expect(config.id, isNotNull);
      expect(config.specId, equals(spec.id));
      expect(config.branchName, equals(spec.suggestedBranchName));
      expect(config.environment, equals('staging'));
      expect(config.stages.isNotEmpty, isTrue);

      // Verify standard stages are included
      final stageNames = config.stages.map((s) => s.name).toList();
      expect(stageNames, contains('build'));
      expect(stageNames, contains('test'));
      expect(stageNames, contains('package'));
      expect(stageNames, contains('deploy'));

      // Verify security scan is included for security-related specs
      expect(stageNames, contains('security_scan'));
    });

    test('should create deployment snapshots before execution', () async {
      // Create test specification and pipeline config
      final spec = Specification(
        id: 'test-spec-2',
        originalText: 'Add user dashboard',
        aiInterpretation: 'User dashboard with analytics and settings',
        suggestedBranchName: 'feature/user-dashboard',
        status: 'approved',
        createdAt: DateTime.now(),
      );
      
      await specService.createSpecification(spec);
      final config = await pipeline.generatePipelineConfig(spec.id);

      // Execute pipeline
      final result = await pipeline.executePipeline(config, 'staging');

      // Verify snapshot was created
      expect(result.snapshotId, isNotNull);
      
      // Verify deployment record was created
      final deployment = await pipeline.getDeployment(result.deploymentId);
      expect(deployment, isNotNull);
      expect(deployment!.snapshotId, equals(result.snapshotId));
      expect(deployment.rollbackAvailable, isTrue);
    });

    test('should execute pipeline stages in sequence', () async {
      // Create test specification
      final spec = Specification(
        id: 'test-spec-3',
        originalText: 'Implement file upload feature',
        aiInterpretation: 'File upload with validation and storage',
        suggestedBranchName: 'feature/file-upload',
        status: 'approved',
        createdAt: DateTime.now(),
      );
      
      await specService.createSpecification(spec);
      final config = await pipeline.generatePipelineConfig(spec.id);

      // Execute pipeline
      final result = await pipeline.executePipeline(config, 'staging');

      // Verify all stages were executed
      expect(result.stageResults.length, equals(config.stages.length));
      
      // Verify stage execution order
      for (int i = 0; i < config.stages.length; i++) {
        expect(result.stageResults[i].stageName, equals(config.stages[i].name));
      }

      // Verify deployment status
      final deployment = await pipeline.getDeployment(result.deploymentId);
      expect(deployment?.status, equals(result.success ? 'success' : 'failed'));
    });

    test('should handle pipeline stage failures', () async {
      // Create test specification
      final spec = Specification(
        id: 'test-spec-4',
        originalText: 'Add notification system',
        aiInterpretation: 'Real-time notification system',
        suggestedBranchName: 'feature/notifications',
        status: 'approved',
        createdAt: DateTime.now(),
      );
      
      await specService.createSpecification(spec);
      final config = await pipeline.generatePipelineConfig(spec.id);

      // Execute pipeline multiple times to potentially trigger failure
      DeploymentResult? failedResult;
      for (int i = 0; i < 10; i++) {
        final result = await pipeline.executePipeline(config, 'staging');
        if (!result.success) {
          failedResult = result;
          break;
        }
      }

      // If we got a failure, verify it was handled correctly
      if (failedResult != null) {
        expect(failedResult.success, isFalse);
        expect(failedResult.error, isNotNull);
        expect(failedResult.stageResults.isNotEmpty, isTrue);

        // Verify deployment was marked as failed
        final deployment = await pipeline.getDeployment(failedResult.deploymentId);
        expect(deployment?.status, equals('failed'));
      }
    });

    test('should track deployment status and history', () async {
      // Create multiple deployments
      final specs = [
        Specification(
          id: 'test-spec-5',
          originalText: 'Add search functionality',
          aiInterpretation: 'Search with filters and sorting',
          suggestedBranchName: 'feature/search',
          status: 'approved',
          createdAt: DateTime.now(),
        ),
        Specification(
          id: 'test-spec-6',
          originalText: 'Implement user profiles',
          aiInterpretation: 'User profile management system',
          suggestedBranchName: 'feature/profiles',
          status: 'approved',
          createdAt: DateTime.now(),
        ),
      ];

      for (final spec in specs) {
        await specService.createSpecification(spec);
        final config = await pipeline.generatePipelineConfig(spec.id);
        await pipeline.executePipeline(config, 'staging');
      }

      // Get recent deployments
      final recentDeployments = await pipeline.getRecentDeployments(limit: 5);
      expect(recentDeployments.length, greaterThanOrEqualTo(2));

      // Verify deployment properties
      for (final deployment in recentDeployments) {
        expect(deployment.id, isNotNull);
        expect(deployment.environment, isNotNull);
        expect(deployment.version, isNotNull);
        expect(deployment.deployedAt, isNotNull);
        expect(deployment.snapshotId, isNotNull);
        expect(['in_progress', 'success', 'failed'], contains(deployment.status));
      }
    });

    test('should generate appropriate pipeline stages based on specification content', () async {
      // Test security-focused specification
      final securitySpec = Specification(
        id: 'security-spec',
        originalText: 'Implement security monitoring and threat detection',
        aiInterpretation: 'Security monitoring system with threat detection and alerting',
        suggestedBranchName: 'feature/security-monitoring',
        status: 'approved',
        createdAt: DateTime.now(),
      );
      
      await specService.createSpecification(securitySpec);
      final securityConfig = await pipeline.generatePipelineConfig(securitySpec.id);
      
      // Should include security scan stage
      final securityStageNames = securityConfig.stages.map((s) => s.name).toList();
      expect(securityStageNames, contains('security_scan'));

      // Test non-security specification
      final regularSpec = Specification(
        id: 'regular-spec',
        originalText: 'Add user preferences page',
        aiInterpretation: 'User preferences and settings management',
        suggestedBranchName: 'feature/user-preferences',
        status: 'approved',
        createdAt: DateTime.now(),
      );
      
      await specService.createSpecification(regularSpec);
      final regularConfig = await pipeline.generatePipelineConfig(regularSpec.id);
      
      // Should not include security scan stage
      final regularStageNames = regularConfig.stages.map((s) => s.name).toList();
      expect(regularStageNames, isNot(contains('security_scan')));
    });

    test('should provide detailed stage execution results', () async {
      // Create test specification
      final spec = Specification(
        id: 'test-spec-7',
        originalText: 'Add data export feature',
        aiInterpretation: 'Data export with multiple formats',
        suggestedBranchName: 'feature/data-export',
        status: 'approved',
        createdAt: DateTime.now(),
      );
      
      await specService.createSpecification(spec);
      final config = await pipeline.generatePipelineConfig(spec.id);

      // Execute pipeline
      final result = await pipeline.executePipeline(config, 'staging');

      // Verify stage results contain detailed information
      for (final stageResult in result.stageResults) {
        expect(stageResult.stageName, isNotNull);
        expect(stageResult.duration, isNotNull);
        expect(stageResult.duration.inMilliseconds, greaterThan(0));
        
        if (stageResult.success) {
          expect(stageResult.output, isNotNull);
        } else {
          expect(stageResult.error, isNotNull);
        }
      }
    });

    test('should handle concurrent pipeline executions', () async {
      // Create multiple specifications
      final specs = List.generate(3, (i) => Specification(
        id: 'concurrent-spec-$i',
        originalText: 'Feature $i implementation',
        aiInterpretation: 'Implementation of feature $i',
        suggestedBranchName: 'feature/concurrent-$i',
        status: 'approved',
        createdAt: DateTime.now(),
      ));

      // Create specifications
      for (final spec in specs) {
        await specService.createSpecification(spec);
      }

      // Execute pipelines concurrently
      final futures = <Future<DeploymentResult>>[];
      for (final spec in specs) {
        final config = await pipeline.generatePipelineConfig(spec.id);
        futures.add(pipeline.executePipeline(config, 'staging'));
      }

      final results = await Future.wait(futures);

      // Verify all pipelines executed
      expect(results.length, equals(3));
      
      // Verify each result has unique deployment ID
      final deploymentIds = results.map((r) => r.deploymentId).toSet();
      expect(deploymentIds.length, equals(3));

      // Verify all deployments are tracked
      final recentDeployments = await pipeline.getRecentDeployments(limit: 10);
      final concurrentDeployments = recentDeployments.where((d) => 
        deploymentIds.contains(d.id)
      ).toList();
      expect(concurrentDeployments.length, equals(3));
    });
  });
}