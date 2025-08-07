import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../models/project.dart';
import '../auth/auth_service.dart';

/// Fast project service for demo purposes - skips heavy infrastructure setup
class FastProjectService {
  static final FastProjectService _instance = FastProjectService._internal();
  static FastProjectService get instance => _instance;
  FastProjectService._internal();

  final _uuid = const Uuid();
  final _authService = AuthService.instance;

  // In-memory storage for demo purposes
  final List<Project> _projects = [];

  final StreamController<List<Project>> _projectsController =
      StreamController<List<Project>>.broadcast();

  /// Stream of projects for real-time updates
  Stream<List<Project>> get projectsStream => _projectsController.stream;

  /// Initialize project service
  Future<void> initialize() async {
    debugPrint('✅ Fast Project service initialized');
  }

  /// Create a new project with initial admin - fast version
  Future<ProjectCreationResult> createProjectWithAdmin({
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    required String projectName,
    required String projectDescription,
  }) async {
    try {
      debugPrint('🚀 Starting fast project creation...');

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

      debugPrint('✅ Validation passed, creating admin user...');

      // Create admin user first
      final adminUser = await _authService.createUser(
        email: adminEmail.trim().toLowerCase(),
        name: adminName.trim(),
        password: adminPassword,
        role: 'admin',
      );

      debugPrint('✅ Admin user created, creating project...');

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

      debugPrint('✅ Project stored, authenticating user...');

      // Auto-login the new admin
      await _authService.authenticateUser(adminUser);

      debugPrint('✅ Project creation completed successfully!');

      return ProjectCreationResult(
        success: true,
        message:
            'Project created successfully! You are now logged in as the administrator.',
        project: project,
        adminUser: adminUser,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Project creation failed: $e');
      debugPrint('Stack trace: $stackTrace');

      return ProjectCreationResult(
        success: false,
        message: 'Failed to create project: ${e.toString()}',
      );
    }
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
