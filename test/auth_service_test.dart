import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/auth/auth_service.dart';
import '../lib/core/database/database_service.dart';

// Generate mocks
@GenerateMocks([DatabaseService])
import 'auth_service_test.mocks.dart';

void main() {
  group('AuthService Tests', () {
    late AuthService authService;
    late MockDatabaseService mockDatabaseService;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      authService = AuthService.instance;
      mockDatabaseService = MockDatabaseService();
    });

    test('should authenticate user with valid credentials', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'validPassword123';

      // Act
      final result = await authService.authenticate(email, password);

      // Assert
      expect(result, isNotNull);
      expect(result['success'], isTrue);
      expect(result['user'], isNotNull);
    });

    test('should reject authentication with invalid credentials', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'wrongPassword';

      // Act
      final result = await authService.authenticate(email, password);

      // Assert
      expect(result['success'], isFalse);
      expect(result['error'], isNotNull);
    });

    test('should register new user successfully', () async {
      // Arrange
      const email = 'newuser@example.com';
      const password = 'securePassword123';
      const name = 'New User';
      const role = UserRole.developer;

      // Act
      final result = await authService.register(
        email: email,
        password: password,
        name: name,
        role: role,
      );

      // Assert
      expect(result, isNotNull);
      expect(result['success'], isTrue);
      expect(result['userId'], isNotNull);
    });

    test('should validate password strength', () {
      // Arrange
      const weakPassword = '123';
      const mediumPassword = 'password123';
      const strongPassword = 'SecurePass123!';

      // Act & Assert
      expect(authService.isPasswordStrong(weakPassword), isFalse);
      expect(authService.isPasswordStrong(mediumPassword), isFalse);
      expect(authService.isPasswordStrong(strongPassword), isTrue);
    });

    test('should validate email format', () {
      // Arrange
      const validEmail = 'user@example.com';
      const invalidEmail = 'invalid-email';

      // Act & Assert
      expect(authService.isValidEmail(validEmail), isTrue);
      expect(authService.isValidEmail(invalidEmail), isFalse);
    });

    test('should check user permissions correctly', () async {
      // Arrange
      const userId = 'user123';
      const adminUserId = 'admin123';

      // Act
      final userCanDeploy =
          await authService.hasPermission(userId, Permission.deploy);
      final adminCanDeploy =
          await authService.hasPermission(adminUserId, Permission.deploy);

      // Assert
      expect(userCanDeploy, isFalse);
      expect(adminCanDeploy, isTrue);
    });

    test('should generate secure JWT token', () async {
      // Arrange
      const userId = 'user123';
      const email = 'user@example.com';
      const role = UserRole.developer;

      // Act
      final token = await authService.generateToken(userId, email, role);

      // Assert
      expect(token, isNotEmpty);
      expect(token.split('.').length, equals(3)); // JWT has 3 parts
    });

    test('should validate JWT token', () async {
      // Arrange
      const userId = 'user123';
      const email = 'user@example.com';
      const role = UserRole.developer;
      final token = await authService.generateToken(userId, email, role);

      // Act
      final isValid = await authService.validateToken(token);

      // Assert
      expect(isValid, isTrue);
    });

    test('should refresh expired token', () async {
      // Arrange
      const refreshToken = 'valid-refresh-token';

      // Act
      final result = await authService.refreshToken(refreshToken);

      // Assert
      expect(result, isNotNull);
      expect(result['accessToken'], isNotNull);
      expect(result['refreshToken'], isNotNull);
    });

    test('should logout user and invalidate token', () async {
      // Arrange
      const userId = 'user123';
      const token = 'valid-jwt-token';

      // Act
      final result = await authService.logout(userId, token);

      // Assert
      expect(result, isTrue);
    });

    test('should change user password', () async {
      // Arrange
      const userId = 'user123';
      const currentPassword = 'oldPassword123';
      const newPassword = 'newSecurePassword123!';

      // Act
      final result = await authService.changePassword(
        userId,
        currentPassword,
        newPassword,
      );

      // Assert
      expect(result, isTrue);
    });

    test('should reset password with valid token', () async {
      // Arrange
      const email = 'user@example.com';
      const resetToken = 'valid-reset-token';
      const newPassword = 'newPassword123!';

      // Act
      final result = await authService.resetPassword(
        email,
        resetToken,
        newPassword,
      );

      // Assert
      expect(result, isTrue);
    });

    test('should get user role correctly', () async {
      // Arrange
      const userId = 'user123';

      // Act
      final role = await authService.getUserRole(userId);

      // Assert
      expect(role, isA<UserRole>());
    });

    test('should check if user is admin', () async {
      // Arrange
      const adminUserId = 'admin123';
      const regularUserId = 'user123';

      // Act
      final isAdmin = await authService.isAdmin(adminUserId);
      final isNotAdmin = await authService.isAdmin(regularUserId);

      // Assert
      expect(isAdmin, isTrue);
      expect(isNotAdmin, isFalse);
    });

    test('should get current authenticated user', () async {
      // Arrange
      const token = 'valid-jwt-token';

      // Act
      final user = await authService.getCurrentUser(token);

      // Assert
      expect(user, isNotNull);
      expect(user['id'], isNotNull);
      expect(user['email'], isNotNull);
      expect(user['role'], isNotNull);
    });
  });
}

enum UserRole {
  admin,
  leadDeveloper,
  developer,
  viewer,
}

enum Permission {
  deploy,
  manageUsers,
  viewAuditLogs,
  manageSecurityAlerts,
  createTasks,
  assignTasks,
  viewReports,
}
