import 'dart:async';

import '../models/join_request.dart';
import '../services/onboarding_service.dart';
import '../auth/auth_service.dart';

/// API layer for onboarding operations
/// Provides REST-like interface for join request management
class OnboardingAPI {
  static final OnboardingAPI _instance = OnboardingAPI._internal();
  static OnboardingAPI get instance => _instance;
  OnboardingAPI._internal();

  final _onboardingService = OnboardingService.instance;
  final _authService = AuthService.instance;

  /// Submit join request API endpoint
  /// POST /api/join-requests
  Future<APIResponse<String>> submitJoinRequest({
    required String name,
    required String email,
    required String requestedRole,
    String? message,
  }) async {
    try {
      // Validate input
      final validationError = _validateJoinRequestInput(
        name: name,
        email: email,
        requestedRole: requestedRole,
      );

      if (validationError != null) {
        return APIResponse<String>(
          success: false,
          message: validationError,
          statusCode: 400,
        );
      }

      // Submit request through service
      final result = await _onboardingService.submitJoinRequest(
        name: name,
        email: email,
        requestedRole: requestedRole,
        message: message,
      );

      return APIResponse<String>(
        success: result.success,
        message: result.message,
        data: result.requestId,
        statusCode: result.success ? 201 : 400,
      );
    } catch (e) {
      return APIResponse<String>(
        success: false,
        message: 'Internal server error: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Get pending join requests API endpoint
  /// GET /api/join-requests/pending
  Future<APIResponse<List<JoinRequest>>> getPendingRequests() async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<List<JoinRequest>>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('manage_users')) {
        return APIResponse<List<JoinRequest>>(
          success: false,
          message: 'Insufficient permissions',
          statusCode: 403,
        );
      }

      final requests = await _onboardingService.getPendingRequests();

      return APIResponse<List<JoinRequest>>(
        success: true,
        message: 'Pending requests retrieved successfully',
        data: requests,
        statusCode: 200,
      );
    } catch (e) {
      return APIResponse<List<JoinRequest>>(
        success: false,
        message: 'Internal server error: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Get all join requests API endpoint
  /// GET /api/join-requests
  Future<APIResponse<List<JoinRequest>>> getAllRequests() async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<List<JoinRequest>>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('manage_users')) {
        return APIResponse<List<JoinRequest>>(
          success: false,
          message: 'Insufficient permissions',
          statusCode: 403,
        );
      }

      final requests = await _onboardingService.getAllRequests();

      return APIResponse<List<JoinRequest>>(
        success: true,
        message: 'All requests retrieved successfully',
        data: requests,
        statusCode: 200,
      );
    } catch (e) {
      return APIResponse<List<JoinRequest>>(
        success: false,
        message: 'Internal server error: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Approve join request API endpoint
  /// POST /api/join-requests/{id}/approve
  Future<APIResponse<void>> approveRequest(
    String requestId, {
    String? adminNotes,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<void>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('manage_users')) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions',
          statusCode: 403,
        );
      }

      // Validate request ID
      if (requestId.trim().isEmpty) {
        return APIResponse<void>(
          success: false,
          message: 'Request ID is required',
          statusCode: 400,
        );
      }

      final success = await _onboardingService.approveRequest(
        requestId,
        adminNotes: adminNotes,
      );

      return APIResponse<void>(
        success: success,
        message: success
            ? 'Request approved successfully'
            : 'Failed to approve request',
        statusCode: success ? 200 : 400,
      );
    } catch (e) {
      return APIResponse<void>(
        success: false,
        message: 'Internal server error: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Reject join request API endpoint
  /// POST /api/join-requests/{id}/reject
  Future<APIResponse<void>> rejectRequest(
    String requestId,
    String reason,
  ) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<void>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('manage_users')) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions',
          statusCode: 403,
        );
      }

      // Validate input
      if (requestId.trim().isEmpty) {
        return APIResponse<void>(
          success: false,
          message: 'Request ID is required',
          statusCode: 400,
        );
      }

      if (reason.trim().isEmpty) {
        return APIResponse<void>(
          success: false,
          message: 'Rejection reason is required',
          statusCode: 400,
        );
      }

      final success = await _onboardingService.rejectRequest(requestId, reason);

      return APIResponse<void>(
        success: success,
        message: success
            ? 'Request rejected successfully'
            : 'Failed to reject request',
        statusCode: success ? 200 : 400,
      );
    } catch (e) {
      return APIResponse<void>(
        success: false,
        message: 'Internal server error: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Track request status API endpoint
  /// GET /api/join-requests/{id}/status
  Future<APIResponse<RequestStatus>> trackRequestStatus(
      String requestId) async {
    try {
      // Validate request ID
      if (requestId.trim().isEmpty) {
        return APIResponse<RequestStatus>(
          success: false,
          message: 'Request ID is required',
          statusCode: 400,
        );
      }

      final status = await _onboardingService.trackRequestStatus(requestId);

      return APIResponse<RequestStatus>(
        success: true,
        message: 'Request status retrieved successfully',
        data: status,
        statusCode: 200,
      );
    } catch (e) {
      return APIResponse<RequestStatus>(
        success: false,
        message: e.toString().contains('Request not found')
            ? 'Request not found'
            : 'Internal server error: ${e.toString()}',
        statusCode: e.toString().contains('Request not found') ? 404 : 500,
      );
    }
  }

  /// Validate join request input
  String? _validateJoinRequestInput({
    required String name,
    required String email,
    required String requestedRole,
  }) {
    // Name validation
    if (name.trim().isEmpty) {
      return 'Name is required';
    }
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }

    // Email validation
    if (email.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    // Role validation
    const validRoles = ['admin', 'lead_developer', 'developer', 'viewer'];
    if (!validRoles.contains(requestedRole.toLowerCase())) {
      return 'Invalid role specified';
    }

    return null;
  }
}

/// Generic API response wrapper
class APIResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int statusCode;
  final Map<String, dynamic>? metadata;

  APIResponse({
    required this.success,
    required this.message,
    this.data,
    required this.statusCode,
    this.metadata,
  });

  factory APIResponse.fromJson(Map<String, dynamic> json) {
    return APIResponse<T>(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'],
      statusCode: json['status_code'] ?? 500,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data,
      'status_code': statusCode,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'APIResponse(success: $success, message: $message, statusCode: $statusCode)';
  }
}
