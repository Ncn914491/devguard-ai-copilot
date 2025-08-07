import 'dart:async';
import '../database/services/services.dart';

/// Email service for sending notifications
/// In production, this would integrate with a real email service like SendGrid, AWS SES, etc.
class EmailService {
  static final EmailService _instance = EmailService._internal();
  static EmailService get instance => _instance;
  EmailService._internal();

  final _auditService = AuditLogService.instance;

  /// Initialize email service
  Future<void> initialize() async {
    await _auditService.logAction(
      actionType: 'email_service_initialized',
      description: 'Email service initialized',
      aiReasoning:
          'Email service provides notification capabilities for user onboarding',
      contextData: {
        'service_type': 'mock_email_service',
      },
    );
  }

  /// Send join request approval email with credentials
  Future<bool> sendApprovalEmail({
    required String recipientEmail,
    required String recipientName,
    required String temporaryPassword,
    required String role,
    String? adminNotes,
  }) async {
    try {
      // In production, this would send a real email
      // For demo purposes, we'll just log the email content

      final emailContent = _buildApprovalEmailContent(
        recipientName: recipientName,
        temporaryPassword: temporaryPassword,
        role: role,
        adminNotes: adminNotes,
      );

      await _auditService.logAction(
        actionType: 'approval_email_sent',
        description: 'Join request approval email sent',
        aiReasoning:
            'User approved for project access, credentials delivered via email',
        contextData: {
          'recipient_email': recipientEmail,
          'recipient_name': recipientName,
          'role': role,
          'has_admin_notes': adminNotes != null,
          'email_content_preview': emailContent.substring(0, 100),
        },
      );

      // Simulate email sending delay
      await Future.delayed(const Duration(milliseconds: 500));

      // For demo purposes, print the email content
      print('📧 EMAIL SENT TO: $recipientEmail');
      print('📧 SUBJECT: Welcome to DevGuard AI Copilot - Account Approved');
      print('📧 CONTENT:\n$emailContent');
      print('📧 END OF EMAIL\n');

      return true;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'approval_email_failed',
        description: 'Failed to send approval email: ${e.toString()}',
        contextData: {
          'recipient_email': recipientEmail,
          'error': e.toString(),
        },
      );

      return false;
    }
  }

  /// Send join request rejection email
  Future<bool> sendRejectionEmail({
    required String recipientEmail,
    required String recipientName,
    required String rejectionReason,
  }) async {
    try {
      final emailContent = _buildRejectionEmailContent(
        recipientName: recipientName,
        rejectionReason: rejectionReason,
      );

      await _auditService.logAction(
        actionType: 'rejection_email_sent',
        description: 'Join request rejection email sent',
        aiReasoning: 'User notified of join request rejection with reason',
        contextData: {
          'recipient_email': recipientEmail,
          'recipient_name': recipientName,
          'rejection_reason': rejectionReason,
        },
      );

      // Simulate email sending delay
      await Future.delayed(const Duration(milliseconds: 500));

      // For demo purposes, print the email content
      print('📧 EMAIL SENT TO: $recipientEmail');
      print('📧 SUBJECT: DevGuard AI Copilot - Join Request Update');
      print('📧 CONTENT:\n$emailContent');
      print('📧 END OF EMAIL\n');

      return true;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'rejection_email_failed',
        description: 'Failed to send rejection email: ${e.toString()}',
        contextData: {
          'recipient_email': recipientEmail,
          'error': e.toString(),
        },
      );

      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail({
    required String recipientEmail,
    required String recipientName,
    required String newPassword,
  }) async {
    try {
      final emailContent = _buildPasswordResetEmailContent(
        recipientName: recipientName,
        newPassword: newPassword,
      );

      await _auditService.logAction(
        actionType: 'password_reset_email_sent',
        description: 'Password reset email sent',
        aiReasoning:
            'Admin reset user password, new credentials delivered via email',
        contextData: {
          'recipient_email': recipientEmail,
          'recipient_name': recipientName,
        },
      );

      // Simulate email sending delay
      await Future.delayed(const Duration(milliseconds: 500));

      // For demo purposes, print the email content
      print('📧 EMAIL SENT TO: $recipientEmail');
      print('📧 SUBJECT: DevGuard AI Copilot - Password Reset');
      print('📧 CONTENT:\n$emailContent');
      print('📧 END OF EMAIL\n');

      return true;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'password_reset_email_failed',
        description: 'Failed to send password reset email: ${e.toString()}',
        contextData: {
          'recipient_email': recipientEmail,
          'error': e.toString(),
        },
      );

      return false;
    }
  }

  String _buildApprovalEmailContent({
    required String recipientName,
    required String temporaryPassword,
    required String role,
    String? adminNotes,
  }) {
    return '''
Dear $recipientName,

Congratulations! Your request to join the DevGuard AI Copilot project has been approved.

Your account details:
• Email: (your email address)
• Role: ${role.replaceAll('_', ' ').toUpperCase()}
• Temporary Password: $temporaryPassword

${adminNotes != null ? '\nAdmin Notes:\n$adminNotes\n' : ''}

Getting Started:
1. Log in to the application using your email and temporary password
2. Change your password after first login for security
3. Explore your role-specific dashboard and available features
4. Contact your team lead if you have any questions

Security Reminders:
• Keep your credentials secure and don't share them
• Change your temporary password immediately after login
• Report any suspicious activity to the admin team

Welcome to the team!

Best regards,
DevGuard AI Copilot Team

---
This is an automated message. Please do not reply to this email.
''';
  }

  String _buildRejectionEmailContent({
    required String recipientName,
    required String rejectionReason,
  }) {
    return '''
Dear $recipientName,

Thank you for your interest in joining the DevGuard AI Copilot project.

Unfortunately, we are unable to approve your join request at this time.

Reason: $rejectionReason

We appreciate your interest and encourage you to apply again in the future if circumstances change.

If you have any questions about this decision, please contact the project administrator.

Best regards,
DevGuard AI Copilot Team

---
This is an automated message. Please do not reply to this email.
''';
  }

  String _buildPasswordResetEmailContent({
    required String recipientName,
    required String newPassword,
  }) {
    return '''
Dear $recipientName,

Your password has been reset by an administrator.

Your new login credentials:
• Email: (your email address)
• New Password: $newPassword

Security Instructions:
1. Log in using your new password
2. Change your password immediately after login
3. Choose a strong, unique password
4. Do not share your credentials with anyone

If you did not request this password reset, please contact the administrator immediately.

Best regards,
DevGuard AI Copilot Team

---
This is an automated message. Please do not reply to this email.
''';
  }
}
