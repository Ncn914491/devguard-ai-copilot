import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/services/project_service.dart';
import '../lib/core/models/project.dart';
import '../lib/core/database/database_service.dart';

// Generate mocks
@GenerateMocks([DatabaseService])
import 'project_service_test.mocks.dart';

void main() {
  group('ProjectService Tests', () {
    late ProjectService projectService;
    late MockDatabaseService mockDatabaseService;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      projectService = ProjectService.instance;
      mockDatabaseService = MockDatabaseService();
    });

    test('should create project successfully', () async {
      // Arrange
      const projectName = 'Test Project';
      const description = 'Test Description';
      const adminEmail = 'admin@example.com';

      // Act
      final result = await projectService.createProject(
        projectName,
        description,
        adminEmail,
      );

      // Assert
      expect(result, isNotNull);
      expect(result.name, equals(projectName));
      expect(result.description, equals(description));
      expect(result.adminEmail, equals(adminEmail));
    });

    test('should validate project name requirements', () {
      // Arrange
      const validName = 'Valid Project Name';
      const invalidShortName = 'ab';
      const invalidLongName = 'a' * 101;
      const invalidSpecialChars = 'Project@#$';

      // Act & Assert
      expect(projectService.isValidProjectName(validName), isTrue);
      expect(projectService.isValidProjectName(invalidShortName), isFalse);
      expect(projectService.isValidProjectName(invalidLongName), isFalse);
      expect(projectService.isValidProjectName(invalidSpecialChars), isFalse);
    });

    test('should get project by id', () async {
      // Arrange
      const projectId = 'test-project-id';
      final expectedProject = Project(
        id: projectId,
        name: 'Test Project',
        description: 'Test Description',
        adminEmail: 'admin@example.com',
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Act
      final result = await projectService.getProjectById(projectId);

      // Assert
      expect(result, isNotNull);
      expect(result?.id, equals(projectId));
    });

    test('should update project successfully', () async {
      // Arrange
      final project = Project(
        id: 'test-id',
        name: 'Original Name',
        description: 'Original Description',
        adminEmail: 'admin@example.com',
        createdAt: DateTime.now(),
        isActive: true,
      );

      const newName = 'Updated Name';
      const newDescription = 'Updated Description';

      // Act
      final result = await projectService.updateProject(
        project.id,
        name: newName,
        description: newDescription,
      );

      // Assert
      expect(result, isTrue);
    });

    test('should deactivate project', () async {
      // Arrange
      const projectId = 'test-project-id';

      // Act
      final result = await projectService.deactivateProject(projectId);

      // Assert
      expect(result, isTrue);
    });

    test('should get all active projects', () async {
      // Act
      final projects = await projectService.getAllActiveProjects();

      // Assert
      expect(projects, isA<List<Project>>());
    });

    test('should validate admin email format', () {
      // Arrange
      const validEmail = 'admin@example.com';
      const invalidEmail = 'invalid-email';

      // Act & Assert
      expect(projectService.isValidAdminEmail(validEmail), isTrue);
      expect(projectService.isValidAdminEmail(invalidEmail), isFalse);
    });

    test('should generate unique project id', () {
      // Act
      final id1 = projectService.generateProjectId();
      final id2 = projectService.generateProjectId();

      // Assert
      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);
      expect(id1, isNot(equals(id2)));
    });

    test('should handle project creation with duplicate name', () async {
      // Arrange
      const projectName = 'Duplicate Project';
      const description = 'Test Description';
      const adminEmail = 'admin@example.com';

      // Create first project
      await projectService.createProject(projectName, description, adminEmail);

      // Act & Assert - Try to create duplicate
      expect(
        () => projectService.createProject(projectName, description, adminEmail),
        throwsA(isA<Exception>()),
      );
    });

    test('should get project statistics', () async {
      // Act
      final stats = await projectService.getProjectStatistics();

      // Assert
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('totalProjects'), isTrue);
      expect(stats.containsKey('activeProjects'), isTrue);
      expect(stats.containsKey('inactiveProjects'), isTrue);
    });
  });
}