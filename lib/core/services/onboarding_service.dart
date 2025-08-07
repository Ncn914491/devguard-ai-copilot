import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/join_request.dart';
import '../database/services/audit_log_service.dart';
import '../database/services/join_request_service.dart';
import '../database/services/user_service.dart' as user_service;
import '../auth/auth_service.dart';
import 'email_service.dart';

/// Onboarding service for managing join requests and member approval workflow
class OnboardingService {
  static final OnboardingService _instance = OnboardingService._internal();
  static OnboardingService get instance => _instance;
  OnboardingService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;
  final _joinRequestService = JoinRequestService.instance;
  final _userService = user_service.UserService.instance;
  final _authService = AuthService.instance;
  final _emailService = EmailService.instance;

  final StreamController<List<JoinRequest>> _requestsController =
      StreamController<List<JoinRequest>>.broadcast();

  /// Stream of join requests for real-time updates
  Stream<List<JoinRequest>> get requestsStream => _requestsController.stream;

  /// Initialize onboarding service
  Future<void> initialize() async {
    await _auditService.logAction(
      actionType: 'onboarding_service_initialized',
      description: 'Onboarding service initialized',
      aiReasoning:
          'Onboarding service manages member join requests and approval workflows',
      contextData: {
        'service_type': 'database_backed',
      },
    );
  }

  /// Submit a new join request
  Future<RequestResult> submitJoinRequest({
    required String name,
    required String email,
    required String requestedRole,
    String? message,
  }) async {
    try {
      // Validate input
      if (name.trim().isEmpty ||
          email.trim().isEmpty ||
          requestedRole.trim().isEmpty) {
        return RequestResult(
          success: false,
          message: 'All required fields must be filled',
        );
      }

      // Check if email already has a pending request
      final existingRequest =
          await _joinRequestService.getJoinRequestByEmail(email);
      if (existingRequest != null &&
          existingRequest.status == JoinRequestStatus.pending) {
        return RequestResult(
          success: false,
          message: 'A pending request with this email already exists',
        );
      }

      // Check if user already exists
      final existingUser = await _userService.getUserByEmail(email);
      if (existingUser != null) {
        return RequestResult(
          success: false,
          message: 'A user with this email already exists',
        );
      }

      // Create join request
      final request = JoinRequest(
        id: _uuid.v4(),
        name: name.trim(),
        email: email.trim().toLowerCase(),
        requestedRole: requestedRole,
        message: message?.trim(),
        status: JoinRequestStatus.pending,
        createdAt: DateTime.now(),
      );

      // Store request in database
      await _joinRequestService.createJoinRequest(request);

      // Notify listeners
      final allRequests = await _joinRequestService.getJoinRequests();
      _requestsController.add(allRequests);

      return RequestResult(
        success: true,
        message:
            'Join request submitted successfully. An admin will review your request.',
        requestId: request.id,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'join_request_error',
        description: 'Error submitting join request: ${e.toString()}',
        contextData: {
          'email': email,
          'error': e.toString(),
        },
      );

      return RequestResult(
        success: false,
        message: 'Failed to submit join request. Please try again.',
      );
    }
  }

  /// Get all pending join requests (admin only)
  Future<List<JoinRequest>> getPendingRequests() async {
    // Check admin permission
    if (!_authService.hasPermission('manage_users')) {
      throw Exception('Insufficient permissions to view join requests');
    }

    final pendingRequests = await _joinRequestService.getPendingRequests();

    await _auditService.logAction(
      actionType: 'join_requests_viewed',
      description: 'Admin viewed pending join requests',
      contextData: {
        'pending_count': pendingRequests.length,
      },
      userId: _authService.currentUser?.id,
    );

    return pendingRequests;
  }

  /// Get all join requests (admin only)
  Future<List<JoinRequest>> getAllRequests() async {
    // Check admin permission
    if (!_authService.hasPermission('manage_users')) {
      throw Exception('Insufficient permissions to view join requests');
    }

    final allRequests = await _joinRequestService.getJoinRequests();
    return allRequests;
  }

  /// Approve a join request (admin only)
  Future<bool> approveRequest(String requestId, {String? adminNotes}) async {
    try {
      // Check admin permission
      if (!_authService.hasPermission('manage_users')) {
        throw Exception('Insufficient permissions to approve join requests');
      }

      // Get request from database
      final request = await _joinRequestService.getJoinRequest(requestId);
      if (request == null) {
        throw Exception('Join request not found');
      }

      if (request.status != JoinRequestStatus.pending) {
        throw Exception('Request has already been processed');
      }

      // Approve request in database
      await _joinRequestService.approveJoinRequest(
        requestId,
        _authService.currentUser!.id,
        adminNotes: adminNotes,
      );

      // Create user account
      final temporaryPassword = _generateTemporaryPassword();
      final newUser = user_service.User(
        id: _uuid.v4(),
        email: request.email,
        name: request.name,
        role: request.requestedRole,
        status: 'active',
        passwordHash: _hashPassword(temporaryPassword),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastLogin: null,
      );

      await _userService.createUser(newUser);

      // Send approval email with credentials
      final emailSent = await _emailService.sendApprovalEmail(
        recipientEmail: request.email,
        recipientName: request.name,
        temporaryPassword: temporaryPassword,
        role: request.requestedRole,
        adminNotes: adminNotes,
      );

      // Log approval
      await _auditService.logAction(
        actionType: 'join_request_approved',
        description: 'Join request approved and user account created',
        aiReasoning:
            'Admin approved join request and system created user account',
        contextData: {
          'request_id': requestId,
          'approved_user_id': newUser.id,
          'approved_role': request.requestedRole,
          'admin_notes': adminNotes,
          'email_sent': emailSent,
        },
        userId: _authService.currentUser?.id,
      );

      // Notify listeners
      final allRequests = await _joinRequestService.getJoinRequests();
      _requestsController.add(allRequests);

      if (!emailSent) {
        // If email failed, still show credentials in console for demo
        print('⚠️  Email delivery failed, showing credentials in console:');
        print('✓ User account created for ${request.email}');
        print('  Temporary password: $temporaryPassword');
      }

      return true;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'join_request_approval_error',
        description: 'Error approving join request: ${e.toString()}',
        contextData: {
          'request_id': requestId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return false;
    }
  }

  /// Reject a join request (admin only)
  Future<bool> rejectRequest(String requestId, String reason) async {
    try {
      // Check admin permission
      if (!_authService.hasPermission('manage_users')) {
        throw Exception('Insufficient permissions to reject join requests');
      }

      // Get request from database
      final request = await _joinRequestService.getJoinRequest(requestId);
      if (request == null) {
        throw Exception('Join request not found');
      }

      if (request.status != JoinRequestStatus.pending) {
        throw Exception('Request has already been processed');
      }

      // Reject request in database
      await _joinRequestService.rejectJoinRequest(
        requestId,
        _authService.currentUser!.id,
        reason,
      );

      // Send rejection email
      final emailSent = await _emailService.sendRejectionEmail(
        recipientEmail: request.email,
        recipientName: request.name,
        rejectionReason: reason,
      );

      // Log rejection
      await _auditService.logAction(
        actionType: 'join_request_rejected',
        description: 'Join request rejected',
        aiReasoning: 'Admin rejected join request with provided reason',
        contextData: {
          'request_id': requestId,
          'rejection_reason': reason,
          'email_sent': emailSent,
        },
        userId: _authService.currentUser?.id,
      );

      // Notify listeners
      final allRequests = await _joinRequestService.getJoinRequests();
      _requestsController.add(allRequests);

      if (!emailSent) {
        print('⚠️  Email delivery failed for rejection notification');
      }
      print('✓ Join request rejected for ${request.email}');

      return true;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'join_request_rejection_error',
        description: 'Error rejecting join request: ${e.toString()}',
        contextData: {
          'request_id': requestId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return false;
    }
  }

  /// Track request status
  Future<RequestStatus?> trackRequestStatus(String requestId) async {
    final request = await _joinRequestService.getJoinRequest(requestId);
    if (request == null) {
      throw Exception('Request not found');
    }

    return RequestStatus(
      requestId: requestId,
      status: request.status,
      message: _getStatusMessage(request),
      lastUpdated: request.reviewedAt ?? request.createdAt,
    );
  }

  String _getStatusMessage(JoinRequest request) {
    switch (request.status) {
      case JoinRequestStatus.pending:
        return 'Your request is pending admin review';
      case JoinRequestStatus.approved:
        return 'Your request has been approved. Check your email for login credentials.';
      case JoinRequestStatus.rejected:
        return 'Your request was rejected: ${request.rejectionReason ?? 'No reason provided'}';
    }
  }

  String _generateTemporaryPassword() {
    // Generate a secure temporary password
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    var password = '';

    for (int i = 0; i < 12; i++) {
      password += chars[(random + i) % chars.length];
    }

    return password;
  }

  String _hashPassword(String password) {
    // Use the same hashing method as UserService
    return _userService.hashPassword(password);
  }

  /// Dispose resources
  void dispose() {
    _requestsController.close();
  }
}

/// User model for database operations
class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final String status;
  final String passwordHash;
  final String? githubUsername;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.passwordHash,
    this.githubUsername,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
  });

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? status,
    String? passwordHash,
    String? githubUsername,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
      passwordHash: passwordHash ?? this.passwordHash,
      githubUsername: githubUsername ?? this.githubUsername,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
