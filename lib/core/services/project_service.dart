import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import '../database/services/audit_log_service.dart';
import '../database/services/snapshot_service.dart';
import '../database/models/snapshot.dart';
import '../auth/auth_service.dart';
import '../security/security_monitor.dart';
import '../gitops/git_integration.dart';

/// Project service for managing project creation and lifecycle
class ProjectService {
  static final ProjectService _instance = ProjectService._internal();
  static ProjectService get instance => _instance;
  ProjectService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;
  final _snapshotService = SnapshotService.instance;
  final _authService = AuthService.instance;
  final _securityMonitor = SecurityMonitor.instance;
  final _gitIntegration = GitIntegration.instance;

  // In-memory storage for demo purposes
  // In production, this would be stored in database
  final List<Project> _projects = [];

  final StreamController<List<Project>> _projectsController =
      StreamController<List<Project>>.broadcast();

  /// Stream of projects for real-time updates
  Stream<List<Project>> get projectsStream => _projectsController.stream;

  /// Initialize project service
  Future<void> initialize() async {
    await _auditService.logAction(
      actionType: 'project_service_initialized',
      description: 'Project service initialized',
      aiReasoning:
          'Project service manages project lifecycle and bootstrapping',
      contextData: {
        'existing_projects': _projects.length,
      },
    );
  }

  /// Create a new project with initial admin
  Future<ProjectCreationResult> createProjectWithAdmin({
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    required String projectName,
    required String projectDescription,
  }) async {
    try {
      // Validate input
      if (adminName.trim().isEmpty ||
          adminEmail.trim().isEmpty ||
          adminPassword.isEmpty ||
          projectName.trim().isEmpty ||
          projectDescription.trim().isEmpty) {
        return ProjectCreationResult(
          success: false,
          message: 'All fields are required',
        );
      }

      // Check if admin email already exists
      final existingUser = await _authService.findUserByEmail(adminEmail);
      if (existingUser != null) {
        return ProjectCreationResult(
          success: false,
          message: 'A user with this email already exists',
        );
      }

      // Check if project name already exists
      if (_projects
          .any((p) => p.name.toLowerCase() == projectName.toLowerCase())) {
        return ProjectCreationResult(
          success: false,
          message: 'A project with this name already exists',
        );
      }

      // Create admin user first
      final adminUser = await _authService.createUser(
        email: adminEmail.trim().toLowerCase(),
        name: adminName.trim(),
        password: adminPassword,
        role: 'admin',
      );

      // Create project
      final project = Project(
        id: _uuid.v4(),
        name: projectName.trim(),
        description: projectDescription.trim(),
        adminId: adminUser.id,
        adminEmail: adminUser.email,
        status: ProjectStatus.active,
        createdAt: DateTime.now(),
        memberIds: [adminUser.id],
        settings: ProjectSettings.defaultSettings(),
      );

      // Store project
      _projects.add(project);
      _projectsController.add(List.from(_projects));

      // Auto-login the new admin first (for immediate UI response)
      await _authService.authenticateUser(adminUser);

      // Log project creation
      await _auditService.logAction(
        actionType: 'project_created',
        description: 'New project created with initial admin',
        aiReasoning:
            'User created new project and became initial administrator',
        contextData: {
          'project_id': project.id,
          'project_name': project.name,
          'admin_id': adminUser.id,
          'admin_email': adminUser.email,
        },
        userId: adminUser.id,
      );

      // Initialize project infrastructure asynchronously (don't wait)
      _initializeProjectInfrastructureAsync(project);

      return ProjectCreationResult(
        success: true,
        message:
            'Project created successfully! You are now logged in as the administrator.',
        project: project,
        adminUser: adminUser,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'project_creation_error',
        description: 'Error creating project: ${e.toString()}',
        contextData: {
          'project_name': projectName,
          'admin_email': adminEmail,
          'error': e.toString(),
        },
      );

      return ProjectCreationResult(
        success: false,
        message: 'Failed to create project. Please try again.',
      );
    }
  }

  /// Initialize project infrastructure
  Future<void> _initializeProjectInfrastructure(Project project) async {
    try {
      // 1. Initialize Git repository
      await _initializeGitRepository(project);

      // 2. Create initial security baseline
      await _initializeSecurityBaseline(project);

      // 3. Create initial snapshot
      await _createInitialSnapshot(project);

      // 4. Set up default monitoring
      await _setupDefaultMonitoring(project);

      await _auditService.logAction(
        actionType: 'project_infrastructure_initialized',
        description: 'Project infrastructure initialized successfully',
        aiReasoning:
            'System initialized git repository, security baseline, and monitoring for new project',
        contextData: {
          'project_id': project.id,
          'components_initialized': [
            'git',
            'security',
            'snapshot',
            'monitoring'
          ],
        },
        userId: project.adminId,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'project_infrastructure_error',
        description:
            'Error initializing project infrastructure: ${e.toString()}',
        contextData: {
          'project_id': project.id,
          'error': e.toString(),
        },
        userId: project.adminId,
      );

      // Don't throw - project creation should still succeed
      print('Warning: Failed to initialize some project infrastructure: $e');
    }
  }

  /// Initialize Git repository for project
  Future<void> _initializeGitRepository(Project project) async {
    try {
      // Create local git repository
      final repoPath = 'projects/${project.id}';

      // Initialize repository with README
      final readmeContent = '''# ${project.name}

${project.description}

## Getting Started

This project was created using DevGuard AI Copilot.

### Project Information
- **Created**: ${project.createdAt.toIso8601String()}
- **Administrator**: ${project.adminEmail}
- **Status**: ${project.status.toString().split('.').last}

### Features Enabled
- ✅ Security monitoring
- ✅ Audit logging
- ✅ Deployment pipelines
- ✅ AI-powered development assistance

## Development Workflow

1. Clone this repository
2. Create feature branches for new work
3. Submit pull requests for code review
4. Deploy through the integrated pipeline

## Security

This project includes automated security monitoring:
- Database breach detection
- System anomaly monitoring
- Audit trail logging
- Automated rollback capabilities

For security concerns, contact the project administrator.
''';

      await _gitIntegration.initializeRepository(
        repoPath,
        {
          'README.md': readmeContent,
          '.gitignore': _getDefaultGitignore(),
        },
      );

      await _auditService.logAction(
        actionType: 'git_repository_initialized',
        description: 'Git repository initialized for project',
        contextData: {
          'project_id': project.id,
          'repo_path': repoPath,
        },
        userId: project.adminId,
      );
    } catch (e) {
      throw Exception('Failed to initialize git repository: $e');
    }
  }

  /// Initialize security baseline for project
  Future<void> _initializeSecurityBaseline(Project project) async {
    try {
      // Deploy honeytokens for the project
      await _securityMonitor.deployProjectHoneytokens(project.id);

      // Set up configuration monitoring
      await _securityMonitor.setupConfigurationMonitoring(project.id);

      // Initialize audit logging for project
      await _auditService.initializeProjectAuditing(project.id);

      await _auditService.logAction(
        actionType: 'security_baseline_initialized',
        description: 'Security baseline established for project',
        contextData: {
          'project_id': project.id,
          'security_features': [
            'honeytokens',
            'config_monitoring',
            'audit_logging'
          ],
        },
        userId: project.adminId,
      );
    } catch (e) {
      throw Exception('Failed to initialize security baseline: $e');
    }
  }

  /// Create initial snapshot for rollback capability
  Future<void> _createInitialSnapshot(Project project) async {
    try {
      await _snapshotService.createSnapshot(
        Snapshot(
          id: '',
          environment: 'initial',
          gitCommit: 'initial',
          databaseBackup: '',
          configFiles: [
            'project_id: ${project.id}',
            'project_name: ${project.name}',
            'creation_type: bootstrap',
          ],
          createdAt: DateTime.now(),
          verified: false,
        ),
      );

      await _auditService.logAction(
        actionType: 'initial_snapshot_created',
        description: 'Initial snapshot created for rollback capability',
        contextData: {
          'project_id': project.id,
        },
        userId: project.adminId,
      );
    } catch (e) {
      throw Exception('Failed to create initial snapshot: $e');
    }
  }

  /// Set up default monitoring for project
  Future<void> _setupDefaultMonitoring(Project project) async {
    try {
      // Configure system health monitoring
      await _securityMonitor.enableProjectMonitoring(project.id);

      // Set up default alert thresholds
      await _securityMonitor.configureAlertThresholds(
        project.id,
        {
          'database_access': 'medium',
          'system_anomaly': 'medium',
          'network_anomaly': 'high',
          'auth_failures': 'low',
        },
      );

      await _auditService.logAction(
        actionType: 'default_monitoring_setup',
        description: 'Default monitoring configured for project',
        contextData: {
          'project_id': project.id,
          'monitoring_enabled': true,
        },
        userId: project.adminId,
      );
    } catch (e) {
      throw Exception('Failed to set up default monitoring: $e');
    }
  }

  /// Get default .gitignore content
  String _getDefaultGitignore() {
    return '''# DevGuard AI Copilot
.devguard/
*.log
.env
.env.local

# Dependencies
node_modules/
vendor/

# Build outputs
build/
dist/
*.exe
*.dll
*.so
*.dylib

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.temp
*~
''';
  }

  /// Get all projects
  Future<List<Project>> getAllProjects() async {
    return List<Project>.from(_projects);
  }

  /// Get project by ID
  Future<Project?> getProjectById(String projectId) async {
    try {
      return _projects.firstWhere((p) => p.id == projectId);
    } catch (e) {
      return null;
    }
  }

  /// Check if any projects exist
  bool hasProjects() {
    return _projects.isNotEmpty;
  }

  /// Dispose resources
  void dispose() {
    _projectsController.close();
  }
}

/// Project creation result
class ProjectCreationResult {
  final bool success;
  final String message;
  final Project? project;
  final dynamic adminUser;

  ProjectCreationResult({
    required this.success,
    required this.message,
    this.project,
    this.adminUser,
  });
}
