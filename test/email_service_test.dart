import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/core/services/email_service.dart';

// Generate mocks
@GenerateMocks([])
import 'email_service_test.mocks.dart';

void main() {
  group('EmailService Tests', () {
    late EmailService emailService;

    setUp(() {
      emailService = EmailService.instance;
    });

    test('should send welcome email successfully', () async {
      // Arrange
      const email = 'test@example.com';
      const name = 'Test User';

      // Act
      final result = await emailService.sendWelcomeEmail(email, name);

      // Assert
      expect(result, isTrue);
    });

    test('should send join request notification email', () async {
      // Arrange
      const adminEmail = 'admin@example.com';
      const requesterName = 'John Doe';
      const requesterEmail = 'john@example.com';

      // Act
      final result = await emailService.sendJoinRequestNotification(
        adminEmail,
        requesterName,
        requesterEmail,
      );

      // Assert
      expect(result, isTrue);
    });

    test('should send approval notification email', () async {
      // Arrange
      const email = 'user@example.com';
      const name = 'User Name';

      // Act
      final result = await emailService.sendApprovalNotification(email, name);

      // Assert
      expect(result, isTrue);
    });

    test('should send rejection notification email', () async {
      // Arrange
      const email = 'user@example.com';
      const name = 'User Name';
      const reason = 'Application incomplete';

      // Act
      final result = await emailService.sendRejectionNotification(
        email,
        name,
        reason,
      );

      // Assert
      expect(result, isTrue);
    });

    test('should handle email sending failures gracefully', () async {
      // Arrange
      const invalidEmail = '';

      // Act & Assert
      expect(
        () => emailService.sendWelcomeEmail(invalidEmail, 'Test'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should validate email format', () {
      // Arrange
      const validEmail = 'test@example.com';
      const invalidEmail = 'invalid-email';

      // Act & Assert
      expect(emailService.isValidEmail(validEmail), isTrue);
      expect(emailService.isValidEmail(invalidEmail), isFalse);
    });

    test('should format email templates correctly', () {
      // Arrange
      const name = 'John Doe';
      const projectName = 'Test Project';

      // Act
      final welcomeTemplate =
          emailService.getWelcomeEmailTemplate(name, projectName);
      final approvalTemplate =
          emailService.getApprovalEmailTemplate(name, projectName);

      // Assert
      expect(welcomeTemplate, contains(name));
      expect(welcomeTemplate, contains(projectName));
      expect(approvalTemplate, contains(name));
      expect(approvalTemplate, contains(projectName));
    });
  });
}
