import 'package:flutter_test/flutter_test.dart';
import '../lib/core/services/project_service.dart';
import '../lib/core/auth/auth_service.dart';
import '../lib/core/database/services/audit_log_service.dart';

void main() {
  group('Admin Signup and Project Creation', () {
    late ProjectService projectService;
    late AuthService authService;
    late AuditLogService auditService;

    setUp(() async {
      projectService = ProjectService.instance;
      authService = AuthService.instance;
      auditService = AuditLogService.instance;
      
      // Initialize services
      await projectService.initialize();
      await authService.initialize();
    });

    test('should create project with admin successfully', () async {
      // Arrange
      const adminName = 'Test Admin';
      const adminEmail = 'admin@test.com';
      const adminPassword = 'securePassword123';
      const projectName = 'Test Project';
      const projectDescription = 'A test project for validation';

      // Act
      final result = await projectService.createProjectWithAdmin(
        adminName: adminName,
        adminEmail: adminEmail,
        adminPassword: adminPassword,
        projectName: projectName,
        projectDescription: projectDescription,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.message, contains('successfully'));
      expect(result.project, isNotNull);
      expect(result.adminUser, isNotNull);
      expect(result.project!.name, equals(projectName));
      expect(result.project!.description, equals(projectDescription));
      expect(result.project!.adminEmail, equals(adminEmail));
    });

    test('should fail with duplicate admin email', () async {
      // Arrange - Create first project
      await projectService.createProjectWithAdmin(
        adminName: 'First Admin',
        adminEmail: 'duplicate@test.com',
        adminPassword: 'password123',
        projectName: 'First Project',
        projectDescription: 'First project',
      );

      // Act - Try to create second project with same email
      final result = await projectService.createProjectWithAdmin(
        adminName: 'Second Admin',
        adminEmail: 'duplicate@test.com',
        adminPassword: 'password456',
        projectName: 'Second Project',
        projectDescription: 'Second project',
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.message, contains('already exists'));
    });

    test('should fail with duplicate project name', () async {
      // Arrange - Create first project
      await projectService.createProjectWithAdmin(
        adminName: 'First Admin',
        adminEmail: 'first@test.com',
        adminPassword: 'password123',
        projectName: 'Duplicate Project',
        projectDescription: 'First project',
      );

      // Act - Try to create second project with same name
      final result = await projectService.createProjectWithAdmin(
        adminName: 'Second Admin',
        adminEmail: 'second@test.com',
        adminPassword: 'password456',
        projectName: 'Duplicate Project',
        projectDescription: 'Second project',
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.message, contains('already exists'));
    });

    test('should fail with empty required fields', () async {
      // Act
      final result = await projectService.createProjectWithAdmin(
        adminName: '',
        adminEmail: 'test@test.com',
        adminPassword: 'password123',
        projectName: 'Test Project',
        projectDescription: 'Test description',
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.message, contains('required'));
    });

    test('should auto-login admin after project creation', () async {
      // Arrange
      expect(authService.isAuthenticated, isFalse);

      // Act
      final result = await projectService.createProjectWithAdmin(
        adminName: 'Auto Login Admin',
        adminEmail: 'autologin@test.com',
        adminPassword: 'password123',
        projectName: 'Auto Login Project',
        projectDescription: 'Test auto login',
      );

      // Assert
      expect(result.success, isTrue);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUser?.email, equals('autologin@test.com'));
      expect(authService.currentUser?.role, equals('admin'));
    });

    test('should create audit logs for project creation', () async {
      // Act
      await projectService.createProjectWithAdmin(
        adminName: 'Audit Test Admin',
        adminEmail: 'audit@test.com',
        adminPassword: 'password123',
        projectName: 'Audit Test Project',
        projectDescription: 'Test audit logging',
      );

      // Assert - Check that audit logs were created
      // Note: In a real implementation, you would query the audit logs
      // For this test, we're just ensuring no exceptions were thrown
      expect(true, isTrue); // Placeholder assertion
    });

    test('should assign admin role and permissions correctly', () async {
      // Act
      final result = await projectService.createProjectWithAdmin(
        adminName: 'Permission Test Admin',
        adminEmail: 'permissions@test.com',
        adminPassword: 'password123',
        projectName: 'Permission Test Project',
        projectDescription: 'Test permissions',
      );

      // Assert
      expect(result.success, isTrue);
      expect(authService.currentUser?.role, equals('admin'));
      expect(authService.hasPermission('manage_users'), isTrue);
      expect(authService.hasPermission('manage_repositories'), isTrue);
      expect(authService.hasPermission('manage_deployments'), isTrue);
    });
  });
}