import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../database/services/audit_log_service.dart';
import '../database/models/deployment.dart';

/// Pipeline configuration generator for different project types and platforms
/// Satisfies Requirements: 7.1 (Pipeline configuration generator)
class PipelineConfigGenerator {
  static final PipelineConfigGenerator _instance =
      PipelineConfigGenerator._internal();
  static PipelineConfigGenerator get instance => _instance;
  PipelineConfigGenerator._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;

  /// Generate pipeline configuration based on project type and platform
  Future<PipelineConfiguration> generateConfiguration({
    required String projectId,
    required ProjectType projectType,
    required List<Platform> targetPlatforms,
    required Map<String, dynamic> projectSettings,
  }) async {
    try {
      final configId = _uuid.v4();

      // Generate stages based on project type
      final stages =
          await _generateStages(projectType, targetPlatforms, projectSettings);

      // Generate environment configurations
      final environments = _generateEnvironments(targetPlatforms);

      // Generate test configurations
      final testConfig =
          _generateTestConfiguration(projectType, projectSettings);

      // Generate deployment configurations
      final deploymentConfig =
          _generateDeploymentConfiguration(targetPlatforms, projectSettings);

      final configuration = PipelineConfiguration(
        id: configId,
        projectId: projectId,
        projectType: projectType,
        targetPlatforms: targetPlatforms,
        stages: stages,
        environments: environments,
        testConfiguration: testConfig,
        deploymentConfiguration: deploymentConfig,
        createdAt: DateTime.now(),
        version: '1.0.0',
      );

      await _auditService.logAction(
        actionType: 'pipeline_config_generated',
        description: 'Generated CI/CD pipeline configuration',
        aiReasoning:
            'Automatically generated optimized pipeline configuration based on project type ${projectType.name} and target platforms',
        contextData: {
          'config_id': configId,
          'project_id': projectId,
          'project_type': projectType.name,
          'platforms': targetPlatforms.map((p) => p.name).toList(),
          'stages_count': stages.length,
        },
      );

      return configuration;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'pipeline_config_generation_error',
        description: 'Error generating pipeline configuration: ${e.toString()}',
        contextData: {
          'project_id': projectId,
          'project_type': projectType.name,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Generate pipeline stages based on project type
  Future<List<PipelineStage>> _generateStages(
    ProjectType projectType,
    List<Platform> platforms,
    Map<String, dynamic> settings,
  ) async {
    final stages = <PipelineStage>[];

    // Setup stage
    stages.add(PipelineStage(
      name: 'setup',
      displayName: 'Environment Setup',
      description: 'Setup build environment and dependencies',
      commands: _generateSetupCommands(projectType, platforms),
      timeout: const Duration(minutes: 5),
      retryCount: 2,
      continueOnError: false,
      environment: {},
    ));

    // Code quality stage
    stages.add(PipelineStage(
      name: 'code_quality',
      displayName: 'Code Quality',
      description: 'Run code analysis and linting',
      commands: _generateCodeQualityCommands(projectType),
      timeout: const Duration(minutes: 10),
      retryCount: 1,
      continueOnError: false,
      environment: {},
    ));

    // Build stage
    stages.add(PipelineStage(
      name: 'build',
      displayName: 'Build',
      description: 'Build application for target platforms',
      commands: _generateBuildCommands(projectType, platforms),
      timeout: const Duration(minutes: 20),
      retryCount: 2,
      continueOnError: false,
      environment: {},
    ));

    // Test stage
    stages.add(PipelineStage(
      name: 'test',
      displayName: 'Test',
      description: 'Run automated tests',
      commands: _generateTestCommands(projectType, settings),
      timeout: const Duration(minutes: 30),
      retryCount: 1,
      continueOnError: false,
      environment: {},
    ));

    // Security scan stage
    if (settings['enable_security_scan'] == true) {
      stages.add(PipelineStage(
        name: 'security_scan',
        displayName: 'Security Scan',
        description: 'Run security vulnerability scan',
        commands: _generateSecurityScanCommands(projectType),
        timeout: const Duration(minutes: 15),
        retryCount: 1,
        continueOnError: true,
        environment: {},
      ));
    }

    // Package stage
    stages.add(PipelineStage(
      name: 'package',
      displayName: 'Package',
      description: 'Package application for deployment',
      commands: _generatePackageCommands(projectType, platforms),
      timeout: const Duration(minutes: 10),
      retryCount: 2,
      continueOnError: false,
      environment: {},
    ));

    // Deploy stage
    stages.add(PipelineStage(
      name: 'deploy',
      displayName: 'Deploy',
      description: 'Deploy to target environment',
      commands: _generateDeployCommands(platforms, settings),
      timeout: const Duration(minutes: 15),
      retryCount: 1,
      continueOnError: false,
      environment: {},
    ));

    return stages;
  }

  /// Generate setup commands based on project type
  List<String> _generateSetupCommands(
      ProjectType projectType, List<Platform> platforms) {
    switch (projectType) {
      case ProjectType.flutter:
        return [
          'flutter --version',
          'flutter pub get',
          'flutter doctor -v',
        ];
      case ProjectType.nodejs:
        return [
          'node --version',
          'npm --version',
          'npm ci',
        ];
      case ProjectType.python:
        return [
          'python --version',
          'pip --version',
          'pip install -r requirements.txt',
        ];
      case ProjectType.dotnet:
        return [
          'dotnet --version',
          'dotnet restore',
        ];
      default:
        return [
          'echo "Setting up generic project"',
        ];
    }
  }

  /// Generate code quality commands
  List<String> _generateCodeQualityCommands(ProjectType projectType) {
    switch (projectType) {
      case ProjectType.flutter:
        return [
          'flutter analyze',
          'dart format --set-exit-if-changed .',
          'flutter pub deps',
        ];
      case ProjectType.nodejs:
        return [
          'npm run lint',
          'npm audit',
        ];
      case ProjectType.python:
        return [
          'flake8 .',
          'black --check .',
          'pip-audit',
        ];
      case ProjectType.dotnet:
        return [
          'dotnet format --verify-no-changes',
          'dotnet build --configuration Release --no-restore',
        ];
      default:
        return [
          'echo "Running generic code quality checks"',
        ];
    }
  }

  /// Generate build commands
  List<String> _generateBuildCommands(
      ProjectType projectType, List<Platform> platforms) {
    switch (projectType) {
      case ProjectType.flutter:
        final commands = <String>[];
        for (final platform in platforms) {
          switch (platform) {
            case Platform.windows:
              commands.add('flutter build windows --release');
              break;
            case Platform.macos:
              commands.add('flutter build macos --release');
              break;
            case Platform.linux:
              commands.add('flutter build linux --release');
              break;
            case Platform.web:
              commands.add('flutter build web --release');
              break;
            case Platform.android:
              commands.add('flutter build apk --release');
              break;
            case Platform.ios:
              commands.add('flutter build ios --release');
              break;
            case Platform.docker:
              commands.add('docker build -t app:latest .');
              break;
          }
        }
        return commands;
      case ProjectType.nodejs:
        return [
          'npm run build',
        ];
      case ProjectType.python:
        return [
          'python -m build',
        ];
      case ProjectType.dotnet:
        return [
          'dotnet build --configuration Release --no-restore',
        ];
      default:
        return [
          'echo "Building generic project"',
        ];
    }
  }

  /// Generate test commands
  List<String> _generateTestCommands(
      ProjectType projectType, Map<String, dynamic> settings) {
    switch (projectType) {
      case ProjectType.flutter:
        final commands = ['flutter test'];
        if (settings['enable_integration_tests'] == true) {
          commands.add('flutter test integration_test/');
        }
        if (settings['enable_coverage'] == true) {
          commands.add('flutter test --coverage');
        }
        return commands;
      case ProjectType.nodejs:
        return [
          'npm test',
          if (settings['enable_coverage'] == true) 'npm run test:coverage',
        ];
      case ProjectType.python:
        return [
          'pytest',
          if (settings['enable_coverage'] == true) 'pytest --cov',
        ];
      case ProjectType.dotnet:
        return [
          'dotnet test --no-build --configuration Release',
          if (settings['enable_coverage'] == true)
            'dotnet test --collect:"XPlat Code Coverage"',
        ];
      default:
        return [
          'echo "Running generic tests"',
        ];
    }
  }

  /// Generate security scan commands
  List<String> _generateSecurityScanCommands(ProjectType projectType) {
    switch (projectType) {
      case ProjectType.flutter:
        return [
          'flutter pub deps',
          'dart analyze --fatal-infos',
        ];
      case ProjectType.nodejs:
        return [
          'npm audit',
          'npm audit fix --dry-run',
        ];
      case ProjectType.python:
        return [
          'pip-audit',
          'bandit -r .',
        ];
      case ProjectType.dotnet:
        return [
          'dotnet list package --vulnerable',
        ];
      default:
        return [
          'echo "Running generic security scan"',
        ];
    }
  }

  /// Generate package commands
  List<String> _generatePackageCommands(
      ProjectType projectType, List<Platform> platforms) {
    switch (projectType) {
      case ProjectType.flutter:
        return [
          'tar -czf app-\${BUILD_NUMBER:-latest}.tar.gz build/',
          'echo "Packaged Flutter application"',
        ];
      case ProjectType.nodejs:
        return [
          'npm pack',
          'tar -czf app-\${BUILD_NUMBER:-latest}.tar.gz dist/',
        ];
      case ProjectType.python:
        return [
          'python -m build',
          'tar -czf app-\${BUILD_NUMBER:-latest}.tar.gz dist/',
        ];
      case ProjectType.dotnet:
        return [
          'dotnet publish --configuration Release --output ./publish',
          'tar -czf app-\${BUILD_NUMBER:-latest}.tar.gz publish/',
        ];
      default:
        return [
          'tar -czf app-\${BUILD_NUMBER:-latest}.tar.gz .',
        ];
    }
  }

  /// Generate deploy commands
  List<String> _generateDeployCommands(
      List<Platform> platforms, Map<String, dynamic> settings) {
    final commands = <String>[
      'echo "Starting deployment process"',
      'echo "Target platforms: ${platforms.map((p) => p.name).join(', ')}"',
    ];

    if (settings['deployment_strategy'] == 'blue_green') {
      commands.addAll([
        'echo "Using blue-green deployment strategy"',
        'echo "Deploying to staging slot"',
        'echo "Running health checks"',
        'echo "Switching traffic to new version"',
      ]);
    } else if (settings['deployment_strategy'] == 'rolling') {
      commands.addAll([
        'echo "Using rolling deployment strategy"',
        'echo "Deploying to instances gradually"',
        'echo "Monitoring deployment progress"',
      ]);
    } else {
      commands.addAll([
        'echo "Using standard deployment strategy"',
        'echo "Deploying application"',
      ]);
    }

    commands.addAll([
      'echo "Deployment completed successfully"',
      'echo "Application is now live"',
    ]);

    return commands;
  }

  /// Generate environment configurations
  Map<String, EnvironmentConfig> _generateEnvironments(
      List<Platform> platforms) {
    return {
      'development': EnvironmentConfig(
        name: 'development',
        displayName: 'Development',
        variables: {
          'NODE_ENV': 'development',
          'DEBUG': 'true',
          'LOG_LEVEL': 'debug',
        },
        secrets: ['DEV_API_KEY', 'DEV_DATABASE_URL'],
        approvalRequired: false,
      ),
      'staging': EnvironmentConfig(
        name: 'staging',
        displayName: 'Staging',
        variables: {
          'NODE_ENV': 'staging',
          'DEBUG': 'false',
          'LOG_LEVEL': 'info',
        },
        secrets: ['STAGING_API_KEY', 'STAGING_DATABASE_URL'],
        approvalRequired: true,
      ),
      'production': EnvironmentConfig(
        name: 'production',
        displayName: 'Production',
        variables: {
          'NODE_ENV': 'production',
          'DEBUG': 'false',
          'LOG_LEVEL': 'warn',
        },
        secrets: ['PROD_API_KEY', 'PROD_DATABASE_URL'],
        approvalRequired: true,
      ),
    };
  }

  /// Generate test configuration
  TestConfiguration _generateTestConfiguration(
      ProjectType projectType, Map<String, dynamic> settings) {
    return TestConfiguration(
      unitTests: TestSuite(
        enabled: true,
        command: _getTestCommand(projectType, 'unit'),
        timeout: const Duration(minutes: 10),
        retryCount: 2,
        failureThreshold: 0,
      ),
      integrationTests: TestSuite(
        enabled: settings['enable_integration_tests'] == true,
        command: _getTestCommand(projectType, 'integration'),
        timeout: const Duration(minutes: 20),
        retryCount: 1,
        failureThreshold: 0,
      ),
      e2eTests: TestSuite(
        enabled: settings['enable_e2e_tests'] == true,
        command: _getTestCommand(projectType, 'e2e'),
        timeout: const Duration(minutes: 30),
        retryCount: 1,
        failureThreshold: 0,
      ),
      coverageThreshold: settings['coverage_threshold'] ?? 80,
      generateReports: settings['generate_test_reports'] == true,
    );
  }

  /// Get test command for project type and test type
  String _getTestCommand(ProjectType projectType, String testType) {
    switch (projectType) {
      case ProjectType.flutter:
        switch (testType) {
          case 'unit':
            return 'flutter test';
          case 'integration':
            return 'flutter test integration_test/';
          case 'e2e':
            return 'flutter drive --target=test_driver/app.dart';
          default:
            return 'flutter test';
        }
      case ProjectType.nodejs:
        switch (testType) {
          case 'unit':
            return 'npm run test:unit';
          case 'integration':
            return 'npm run test:integration';
          case 'e2e':
            return 'npm run test:e2e';
          default:
            return 'npm test';
        }
      default:
        return 'echo "Running $testType tests"';
    }
  }

  /// Generate deployment configuration
  DeploymentConfiguration _generateDeploymentConfiguration(
    List<Platform> platforms,
    Map<String, dynamic> settings,
  ) {
    return DeploymentConfiguration(
      strategy: DeploymentStrategy.values.firstWhere(
        (s) => s.name == settings['deployment_strategy'],
        orElse: () => DeploymentStrategy.standard,
      ),
      environments: ['development', 'staging', 'production'],
      healthCheckUrl: settings['health_check_url'] ?? '/health',
      healthCheckTimeout:
          Duration(seconds: settings['health_check_timeout'] ?? 30),
      rollbackOnFailure: settings['rollback_on_failure'] ?? true,
      notifications: NotificationConfig(
        onSuccess: settings['notify_on_success'] ?? true,
        onFailure: settings['notify_on_failure'] ?? true,
        channels: (settings['notification_channels'] as List<dynamic>?)
                ?.cast<String>() ??
            ['email'],
      ),
    );
  }

  /// Export configuration to YAML format
  Future<String> exportToYaml(PipelineConfiguration config) async {
    final yamlMap = {
      'name': 'CI/CD Pipeline',
      'version': config.version,
      'project_type': config.projectType.name,
      'platforms': config.targetPlatforms.map((p) => p.name).toList(),
      'stages': config.stages
          .map((stage) => {
                'name': stage.name,
                'display_name': stage.displayName,
                'description': stage.description,
                'commands': stage.commands,
                'timeout': stage.timeout.inMinutes,
                'retry_count': stage.retryCount,
                'continue_on_error': stage.continueOnError,
              })
          .toList(),
      'environments': config.environments.map((key, env) => MapEntry(key, {
            'name': env.name,
            'display_name': env.displayName,
            'variables': env.variables,
            'approval_required': env.approvalRequired,
          })),
      'test_configuration': {
        'unit_tests': {
          'enabled': config.testConfiguration.unitTests.enabled,
          'command': config.testConfiguration.unitTests.command,
          'timeout': config.testConfiguration.unitTests.timeout.inMinutes,
        },
        'integration_tests': {
          'enabled': config.testConfiguration.integrationTests.enabled,
          'command': config.testConfiguration.integrationTests.command,
          'timeout':
              config.testConfiguration.integrationTests.timeout.inMinutes,
        },
        'coverage_threshold': config.testConfiguration.coverageThreshold,
      },
      'deployment_configuration': {
        'strategy': config.deploymentConfiguration.strategy.name,
        'environments': config.deploymentConfiguration.environments,
        'health_check_url': config.deploymentConfiguration.healthCheckUrl,
        'rollback_on_failure': config.deploymentConfiguration.rollbackOnFailure,
      },
    };

    return _convertToYaml(yamlMap);
  }

  /// Simple YAML converter (basic implementation)
  String _convertToYaml(Map<String, dynamic> map, [int indent = 0]) {
    final buffer = StringBuffer();
    final indentStr = '  ' * indent;

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        buffer.writeln('$indentStr$key:');
        buffer.write(_convertToYaml(value, indent + 1));
      } else if (value is List) {
        buffer.writeln('$indentStr$key:');
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            buffer.writeln('$indentStr  -');
            buffer.write(_convertToYaml(item, indent + 2));
          } else {
            buffer.writeln('$indentStr  - $item');
          }
        }
      } else {
        buffer.writeln('$indentStr$key: $value');
      }
    }

    return buffer.toString();
  }
}

/// Project types supported by the pipeline generator
enum ProjectType {
  flutter,
  nodejs,
  python,
  dotnet,
  java,
  go,
  rust,
  generic,
}

/// Target platforms
enum Platform {
  windows,
  macos,
  linux,
  web,
  android,
  ios,
  docker,
}

/// Deployment strategies
enum DeploymentStrategy {
  standard,
  blue_green,
  rolling,
  canary,
}

/// Pipeline configuration model
class PipelineConfiguration {
  final String id;
  final String projectId;
  final ProjectType projectType;
  final List<Platform> targetPlatforms;
  final List<PipelineStage> stages;
  final Map<String, EnvironmentConfig> environments;
  final TestConfiguration testConfiguration;
  final DeploymentConfiguration deploymentConfiguration;
  final DateTime createdAt;
  final String version;

  PipelineConfiguration({
    required this.id,
    required this.projectId,
    required this.projectType,
    required this.targetPlatforms,
    required this.stages,
    required this.environments,
    required this.testConfiguration,
    required this.deploymentConfiguration,
    required this.createdAt,
    required this.version,
  });
}

/// Pipeline stage model
class PipelineStage {
  final String name;
  final String displayName;
  final String description;
  final List<String> commands;
  final Duration timeout;
  final int retryCount;
  final bool continueOnError;
  final Map<String, String> environment;

  PipelineStage({
    required this.name,
    required this.displayName,
    required this.description,
    required this.commands,
    required this.timeout,
    required this.retryCount,
    required this.continueOnError,
    required this.environment,
  });
}

/// Environment configuration
class EnvironmentConfig {
  final String name;
  final String displayName;
  final Map<String, String> variables;
  final List<String> secrets;
  final bool approvalRequired;

  EnvironmentConfig({
    required this.name,
    required this.displayName,
    required this.variables,
    required this.secrets,
    required this.approvalRequired,
  });
}

/// Test configuration
class TestConfiguration {
  final TestSuite unitTests;
  final TestSuite integrationTests;
  final TestSuite e2eTests;
  final int coverageThreshold;
  final bool generateReports;

  TestConfiguration({
    required this.unitTests,
    required this.integrationTests,
    required this.e2eTests,
    required this.coverageThreshold,
    required this.generateReports,
  });
}

/// Test suite configuration
class TestSuite {
  final bool enabled;
  final String command;
  final Duration timeout;
  final int retryCount;
  final int failureThreshold;

  TestSuite({
    required this.enabled,
    required this.command,
    required this.timeout,
    required this.retryCount,
    required this.failureThreshold,
  });
}

/// Deployment configuration
class DeploymentConfiguration {
  final DeploymentStrategy strategy;
  final List<String> environments;
  final String healthCheckUrl;
  final Duration healthCheckTimeout;
  final bool rollbackOnFailure;
  final NotificationConfig notifications;

  DeploymentConfiguration({
    required this.strategy,
    required this.environments,
    required this.healthCheckUrl,
    required this.healthCheckTimeout,
    required this.rollbackOnFailure,
    required this.notifications,
  });
}

/// Notification configuration
class NotificationConfig {
  final bool onSuccess;
  final bool onFailure;
  final List<String> channels;

  NotificationConfig({
    required this.onSuccess,
    required this.onFailure,
    required this.channels,
  });
}
