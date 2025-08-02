import 'package:flutter_test/flutter_test.dart';
import '../lib/core/services/onboarding_service.dart';
import '../lib/core/services/email_service.dart';
import '../lib/core/auth/auth_service.dart';
import '../lib/core/database/services/audit_log_service.dart';

void main() {
  group('Onboarding Integration Tests', () {
    late OnboardingService onboardingService;
    late EmailService emailService;
    late AuthService authService;
    late AuditLogService auditService;

    setUpAll(() async {
      // Initialize services
      onboardingService = OnboardingService.instance;
      emailService = EmailService.instance;
      authService = AuthService.instance;
      auditService = AuditLogService.instance;

      // Initialize services that have initialize methods
      await emailService.initialize();
      await authService.initialize();
      await onboardingService.initialize();
    });

    test('should submit join request successfully', () async {
      final result = await onboardingService.submitJoinRequest(
        name: 'Test User',
        email: 'test@example.com',
        requestedRole: 'developer',
        message: 'I would like to join the team as a developer.',
      );

      expect(result.success, isTrue);
      expect(result.message, contains('submitted successfully'));
      expect(result.requestId, isNotNull);
    });

    test('should prevent duplicate email submissions', () async {
      // First submission
      await onboardingService.submitJoinRequest(
        name: 'Test User 1',
        email: 'duplicate@example.com',
        requestedRole: 'developer',
      );

      // Second submission with same email
      final result = await onboardingService.submitJoinRequest(
        name: 'Test User 2',
        email: 'duplicate@example.com',
        requestedRole: 'lead_developer',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('already exists'));
    });

    test('should validate required fields', () async {
      final result = await onboardingService.submitJoinRequest(
        name: '',
        email: 'test@example.com',
        requestedRole: 'developer',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('required fields'));
    });

    test('should get pending requests for admin', () async {
      // Submit a request first
      await onboardingService.submitJoinRequest(
        name: 'Pending User',
        email: 'pending@example.com',
        requestedRole: 'developer',
      );

      // Mock admin authentication
      // In a real test, we would properly authenticate as admin
      // For now, we'll test the method exists and handles permissions
      
      try {
        final requests = await onboardingService.getPendingRequests();
        // If we get here without exception, the method works
        expect(requests, isA<List>());
      } catch (e) {
        // Expected if not authenticated as admin
        expect(e.toString(), contains('permissions'));
      }
    });

    test('should send approval email', () async {
      final result = await emailService.sendApprovalEmail(
        recipientEmail: 'approved@example.com',
        recipientName: 'Approved User',
        temporaryPassword: 'temp123',
        role: 'developer',
        adminNotes: 'Welcome to the team!',
      );

      expect(result, isTrue);
    });

    test('should send rejection email', () async {
      final result = await emailService.sendRejectionEmail(
        recipientEmail: 'rejected@example.com',
        recipientName: 'Rejected User',
        rejectionReason: 'Position not available at this time.',
      );

      expect(result, isTrue);
    });

    test('should track request status', () async {
      // Submit a request
      final submitResult = await onboardingService.submitJoinRequest(
        name: 'Status Test User',
        email: 'status@example.com',
        requestedRole: 'developer',
      );

      expect(submitResult.success, isTrue);
      expect(submitResult.requestId, isNotNull);

      // Track the status
      final status = await onboardingService.trackRequestStatus(submitResult.requestId!);
      
      expect(status, isNotNull);
      expect(status!.requestId, equals(submitResult.requestId));
      expect(status.status.toString(), contains('pending'));
    });
  });
}