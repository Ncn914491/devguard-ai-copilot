import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../database/services/services.dart';
import '../database/models/models.dart';

class DeploymentPipeline {
  static final DeploymentPipeline _instance = DeploymentPipeline._internal();
  static DeploymentPipeline get instance => _instance;
  DeploymentPipeline._internal();

  final _uuid = const Uuid();
  final _deploymentService = DeploymentService.instance;
  final _snapshotService = SnapshotService.instance;
  final _auditService = AuditLogService.instance;
  final _specService = SpecService.instance;

  /// Generate CI/CD pipeline configuration from specification
  /// Satisfies Requirements: 2.1, 2.2 (Pipeline scaffolding and configuration)
  Future<PipelineConfig> generatePipelineConfig(String specId) async {
    final spec = await _specService.getSpecification(specId);
    if (spec == null) {
      throw Exception('Specification not found: $specId');
    }

    final config = PipelineConfig(
      id: _uuid.v4(),
      specId: specId,
      branchName: spec.suggestedBranchName,
      stages: _generatePipelineStages(spec),
      environment: 'staging', // Default to staging first
      createdAt: DateTime.now(),
    );

    // Log pipeline generation
    await _auditService.logAction(
      actionType: 'pipeline_generated',
      description: 'Generated CI/CD pipeline for specification: ${spec.suggestedBranchName}',
      aiReasoning: 'Automatically generated pipeline configuration based on specification requirements and best practices',
      contextData: {
        'spec_id': specId,
        'pipeline_id': config.id,
        'branch_name': spec.suggestedBranchName,
        'stages_count': config.stages.length,
      },
    );

    return config;
  }

  /// Generate pipeline stages based on specification
  List<PipelineStage> _generatePipelineStages(Specification spec) {
    final stages = <PipelineStage>[];
    
    // Build stage
    stages.add(PipelineStage(
      name: 'build',
      description: 'Build application and dependencies',
      commands: [
        'flutter pub get',
        'flutter analyze',
        'flutter build windows --release',
      ],
      timeout: const Duration(minutes: 10),
    ));

    // Test stage
    stages.add(PipelineStage(
      name: 'test',
      description: 'Run automated tests',
      commands: [
        'flutter test',
        'flutter test integration_test/',
      ],
      timeout: const Duration(minutes: 15),
    ));

    // Security scan stage
    if (spec.aiInterpretation.toLowerCase().contains('security')) {
      stages.add(PipelineStage(
        name: 'security_scan',
        description: 'Run security vulnerability scan',
        commands: [
          'dart pub deps',
          'flutter analyze --fatal-infos',
        ],
        timeout: const Duration(minutes: 5),
      ));
    }

    // Package stage
    stages.add(PipelineStage(
      name: 'package',
      description: 'Package application for deployment',
      commands: [
        'flutter build windows --release',
        'tar -czf app-${DateTime.now().millisecondsSinceEpoch}.tar.gz build/',
      ],
      timeout: const Duration(minutes: 5),
    ));

    // Deploy stage
    stages.add(PipelineStage(
      name: 'deploy',
      description: 'Deploy to target environment',
      commands: [
        'echo "Deploying to staging environment"',
        'echo "Application deployed successfully"',
      ],
      timeout: const Duration(minutes: 10),
    ));

    return stages;
  }

  /// Execute deployment pipeline
  /// Satisfies Requirements: 2.3 (Snapshot creation before deployment)
  Future<DeploymentResult> executePipeline(PipelineConfig config, String environment) async {
    final deploymentId = _uuid.v4();
    
    try {
      // Create pre-deployment snapshot
      final snapshotId = await _snapshotService.createPreDeploymentSnapshot(
        environment,
        'commit-${DateTime.now().millisecondsSinceEpoch}',
        ['pubspec.yaml', 'lib/main.dart'],
      );

      // Create deployment record
      final deployment = Deployment(
        id: deploymentId,
        environment: environment,
        version: 'v${DateTime.now().millisecondsSinceEpoch}',
        status: 'in_progress',
        pipelineConfig: jsonEncode(config.toMap()),
        snapshotId: snapshotId,
        deployedBy: 'system',
        deployedAt: DateTime.now(),
        rollbackAvailable: true,
      );

      await _deploymentService.createDeployment(deployment);

      // Execute pipeline stages
      final results = <StageResult>[];
      for (final stage in config.stages) {
        final result = await _executeStage(stage, deploymentId);
        results.add(result);
        
        if (!result.success) {
          // Mark deployment as failed
          await _deploymentService.markDeploymentFailed(
            deploymentId,
            'Pipeline failed at stage: ${stage.name}. Error: ${result.error}',
          );
          
          return DeploymentResult(
            deploymentId: deploymentId,
            success: false,
            error: 'Pipeline failed at stage: ${stage.name}',
            stageResults: results,
            snapshotId: snapshotId,
          );
        }
      }

      // Mark deployment as successful
      await _deploymentService.updateDeploymentStatus(deploymentId, 'success');

      return DeploymentResult(
        deploymentId: deploymentId,
        success: true,
        stageResults: results,
        snapshotId: snapshotId,
      );

    } catch (e) {
      await _deploymentService.markDeploymentFailed(deploymentId, e.toString());
      
      return DeploymentResult(
        deploymentId: deploymentId,
        success: false,
        error: e.toString(),
        stageResults: [],
      );
    }
  }

  /// Execute individual pipeline stage
  Future<StageResult> _executeStage(PipelineStage stage, String deploymentId) async {
    final startTime = DateTime.now();
    
    try {
      // Log stage start
      await _auditService.logAction(
        actionType: 'pipeline_stage_started',
        description: 'Started pipeline stage: ${stage.name}',
        contextData: {
          'deployment_id': deploymentId,
          'stage_name': stage.name,
          'commands_count': stage.commands.length,
        },
      );

      // Simulate stage execution
      await Future.delayed(Duration(seconds: 2 + (stage.commands.length * 1)));
      
      // Simulate occasional failures for demo
      final random = DateTime.now().millisecond;
      if (random % 20 == 0) { // 5% failure rate
        throw Exception('Simulated stage failure for demo purposes');
      }

      final duration = DateTime.now().difference(startTime);
      
      // Log stage completion
      await _auditService.logAction(
        actionType: 'pipeline_stage_completed',
        description: 'Completed pipeline stage: ${stage.name}',
        contextData: {
          'deployment_id': deploymentId,
          'stage_name': stage.name,
          'duration_ms': duration.inMilliseconds,
        },
      );

      return StageResult(
        stageName: stage.name,
        success: true,
        duration: duration,
        output: 'Stage ${stage.name} completed successfully',
      );

    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      // Log stage failure
      await _auditService.logAction(
        actionType: 'pipeline_stage_failed',
        description: 'Failed pipeline stage: ${stage.name}',
        contextData: {
          'deployment_id': deploymentId,
          'stage_name': stage.name,
          'error': e.toString(),
          'duration_ms': duration.inMilliseconds,
        },
      );

      return StageResult(
        stageName: stage.name,
        success: false,
        duration: duration,
        error: e.toString(),
      );
    }
  }

  /// Get deployment status
  /// Satisfies Requirements: 2.5 (Deployment status monitoring)
  Future<List<Deployment>> getRecentDeployments({int limit = 10}) async {
    final deployments = await _deploymentService.getAllDeployments();
    return deployments.take(limit).toList();
  }

  /// Get deployment by ID
  Future<Deployment?> getDeployment(String deploymentId) async {
    return await _deploymentService.getDeployment(deploymentId);
  }
}

/// Pipeline configuration
class PipelineConfig {
  final String id;
  final String specId;
  final String branchName;
  final List<PipelineStage> stages;
  final String environment;
  final DateTime createdAt;

  PipelineConfig({
    required this.id,
    required this.specId,
    required this.branchName,
    required this.stages,
    required this.environment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'spec_id': specId,
      'branch_name': branchName,
      'stages': stages.map((s) => s.toMap()).toList(),
      'environment': environment,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}

/// Pipeline stage
class PipelineStage {
  final String name;
  final String description;
  final List<String> commands;
  final Duration timeout;

  PipelineStage({
    required this.name,
    required this.description,
    required this.commands,
    required this.timeout,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'commands': commands,
      'timeout_ms': timeout.inMilliseconds,
    };
  }
}

/// Deployment result
class DeploymentResult {
  final String deploymentId;
  final bool success;
  final String? error;
  final List<StageResult> stageResults;
  final String? snapshotId;

  DeploymentResult({
    required this.deploymentId,
    required this.success,
    this.error,
    required this.stageResults,
    this.snapshotId,
  });
}

/// Stage execution result
class StageResult {
  final String stageName;
  final bool success;
  final Duration duration;
  final String? output;
  final String? error;

  StageResult({
    required this.stageName,
    required this.success,
    required this.duration,
    this.output,
    this.error,
  });
}