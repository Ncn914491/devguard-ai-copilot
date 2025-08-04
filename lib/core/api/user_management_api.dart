import 'dart:async';
import 'dart:convert';
import '../database/services/user_service.dart';
import '../database/services/audit_log_service.dart';
import '../auth/auth_service.dart';

/// User Management API with RBAC and comprehensive validation
/// Satisfies Requirements: 3.1, 3.2, 3.3, 3.4, 3.5 (User management with secure authentication)
class UserManagementAPI {
  static final UserManagementAPI _instance = UserManagementAPI._internal();
  static UserManagementAPI get instance => _instance;
  UserManagementAPI._internal();

  final _userService = UserService.instance;
  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;

  /// Get all users with optional filtering
  /// GET /api/users
  Future<APIResponse<List<User>>> getUsers({
    String? role,
    String? status,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<List<User>>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('manage_users') &&
          !_authService.hasPermission('view_team_tasks')) {
        return APIResponse<List<User>>(
          success: false,
          message: 'Insufficient permissions to view users',
          statusCode: 403,
        );
      }

      final users = await _userService.getUsers(role: role, status: status);

      await _auditService.logAction(
        actionType: 'users_retrieved',
        description:
            'Retrieved users list with filters: role=$role, status=$status',
        contextData: {
          'filter_role': role,
          'filter_status': status,
          'result_count': users.length,
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<List<User>>(
        success: true,
        message: 'Users retrieved successfully',
        data: users,
        statusCode: 200,
        metadata: {
          'total_count': users.length,
          'filters_applied': {
            'role': role,
            'status': status,
          },
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'users_retrieval_error',
        description: 'Error retrieving users: ${e.toString()}',
        contextData: {'error': e.toString()},
        userId: _authService.currentUser?.id,
      );

      return APIResponse<List<User>>(
        success: false,
        message: 'Failed to retrieve users: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Get user by ID
  /// GET /api/users/{id}
  Future<APIResponse<User>> getUser(String userId) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<User>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions - users can view their own profile
      final currentUser = _authService.currentUser!;
      if (currentUser.id != userId &&
          !_authService.hasPermission('manage_users')) {
        return APIResponse<User>(
          success: false,
          message: 'Insufficient permissions to view this user',
          statusCode: 403,
        );
      }

      // Validate user ID
      if (userId.trim().isEmpty) {
        return APIResponse<User>(
          success: false,
          message: 'User ID is required',
          statusCode: 400,
        );
      }

      final user = await _userService.getUser(userId);
      if (user == null) {
        return APIResponse<User>(
          success: false,
          message: 'User not found',
          statusCode: 404,
        );
      }

      await _auditService.logAction(
        actionType: 'user_retrieved',
        description: 'Retrieved user profile: ${user.name}',
        contextData: {
          'target_user_id': userId,
          'target_user_email': user.email,
        },
        userId: currentUser.id,
      );

      return APIResponse<User>(
        success: true,
        message: 'User retrieved successfully',
        data: user,
        statusCode: 200,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'user_retrieval_error',
        description: 'Error retrieving user: ${e.toString()}',
        contextData: {
          'target_user_id': userId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<User>(
        success: false,
        message: 'Failed to retrieve user: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Create new user
  /// POST /api/users
  Future<APIResponse<String>> createUser({
    required String email,
    required String name,
    required String role,
    required String password,
  }) async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<String>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('manage_users')) {
        return APIResponse<String>(
          success: false,
          message: 'Insufficient permissions to create users',
          statusCode: 403,
        );
      }

      // Validate input
      final validationError = _validateUserInput(
        email: email,
        name: name,
        role: role,
        password: password,
      );
      if (validationError != null) {
        return APIResponse<String>(
          success: false,
          message: validationError,
          statusCode: 400,
        );
      }

      // Check if email already exists
      if (await _userService.emailExists(email)) {
        return APIResponse<String>(
          success: false,
          message: 'Email address already exists',
          statusCode: 409,
        );
      }

      // Create user
      final user = User(
        id: '',
        email: email.toLowerCase().trim(),
        name: name.trim(),
        role: role.toLowerCase(),
        status: 'active',
        passwordHash: _userService.hashPassword(password),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final userId = await _userService.createUser(user);

      await _auditService.logAction(
        actionType: 'user_created',
        description: 'Created new user account: $name ($email)',
        contextData: {
          'new_user_id': userId,
          'email': email,
          'name': name,
          'role': role,
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<String>(
        success: true,
        message: 'User created successfully',
        data: userId,
        statusCode: 201,
        metadata: {
          'user_id': userId,
          'email': email,
          'role': role,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'user_creation_error',
        description: 'Error creating user: ${e.toString()}',
        contextData: {
          'email': email,
          'name': name,
          'role': role,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<String>(
        success: false,
        message: 'Failed to create user: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Update user
  /// PUT /api/users/{id}
  Future<APIResponse<void>> updateUser({
    required String userId,
    String? name,
    String? role,
    String? status,
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
      final currentUser = _authService.currentUser!;
      final canManageUsers = _authService.hasPermission('manage_users');
      final isOwnProfile = currentUser.id == userId;

      if (!canManageUsers && !isOwnProfile) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions to update this user',
          statusCode: 403,
        );
      }

      // Validate user ID
      if (userId.trim().isEmpty) {
        return APIResponse<void>(
          success: false,
          message: 'User ID is required',
          statusCode: 400,
        );
      }

      // Get existing user
      final existingUser = await _userService.getUser(userId);
      if (existingUser == null) {
        return APIResponse<void>(
          success: false,
          message: 'User not found',
          statusCode: 404,
        );
      }

      // Validate role change permissions
      if (role != null && !canManageUsers) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions to change user role',
          statusCode: 403,
        );
      }

      // Validate status change permissions
      if (status != null && !canManageUsers) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions to change user status',
          statusCode: 403,
        );
      }

      // Validate input
      if (name != null && name.trim().length < 2) {
        return APIResponse<void>(
          success: false,
          message: 'Name must be at least 2 characters long',
          statusCode: 400,
        );
      }

      if (role != null) {
        const validRoles = ['admin', 'lead_developer', 'developer', 'viewer'];
        if (!validRoles.contains(role.toLowerCase())) {
          return APIResponse<void>(
            success: false,
            message: 'Invalid role specified',
            statusCode: 400,
          );
        }
      }

      if (status != null) {
        const validStatuses = ['active', 'inactive', 'suspended'];
        if (!validStatuses.contains(status.toLowerCase())) {
          return APIResponse<void>(
            success: false,
            message: 'Invalid status specified',
            statusCode: 400,
          );
        }
      }

      // Update user
      final updatedUser = existingUser.copyWith(
        name: name?.trim(),
        role: role?.toLowerCase(),
        status: status?.toLowerCase(),
        updatedAt: DateTime.now(),
      );

      await _userService.updateUser(updatedUser);

      await _auditService.logAction(
        actionType: 'user_updated',
        description: 'Updated user: ${existingUser.name}',
        contextData: {
          'target_user_id': userId,
          'changes': {
            'name': name,
            'role': role,
            'status': status,
          },
          'updated_by_self': isOwnProfile,
        },
        userId: currentUser.id,
      );

      return APIResponse<void>(
        success: true,
        message: 'User updated successfully',
        statusCode: 200,
        metadata: {
          'updated_fields': {
            'name': name != null,
            'role': role != null,
            'status': status != null,
          },
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'user_update_error',
        description: 'Error updating user: ${e.toString()}',
        contextData: {
          'target_user_id': userId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<void>(
        success: false,
        message: 'Failed to update user: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Delete user
  /// DELETE /api/users/{id}
  Future<APIResponse<void>> deleteUser(String userId) async {
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
          message: 'Insufficient permissions to delete users',
          statusCode: 403,
        );
      }

      // Validate user ID
      if (userId.trim().isEmpty) {
        return APIResponse<void>(
          success: false,
          message: 'User ID is required',
          statusCode: 400,
        );
      }

      // Prevent self-deletion
      if (_authService.currentUser?.id == userId) {
        return APIResponse<void>(
          success: false,
          message: 'Cannot delete your own account',
          statusCode: 400,
        );
      }

      // Get user to delete
      final userToDelete = await _userService.getUser(userId);
      if (userToDelete == null) {
        return APIResponse<void>(
          success: false,
          message: 'User not found',
          statusCode: 404,
        );
      }

      // Delete user
      await _userService.deleteUser(userId);

      await _auditService.logAction(
        actionType: 'user_deleted',
        description:
            'Deleted user account: ${userToDelete.name} (${userToDelete.email})',
        contextData: {
          'deleted_user_id': userId,
          'deleted_user_email': userToDelete.email,
          'deleted_user_role': userToDelete.role,
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<void>(
        success: true,
        message: 'User deleted successfully',
        statusCode: 200,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'user_deletion_error',
        description: 'Error deleting user: ${e.toString()}',
        contextData: {
          'target_user_id': userId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<void>(
        success: false,
        message: 'Failed to delete user: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Update user password
  /// PUT /api/users/{id}/password
  Future<APIResponse<void>> updateUserPassword({
    required String userId,
    required String newPassword,
    String? currentPassword,
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
      final currentUser = _authService.currentUser!;
      final canManageUsers = _authService.hasPermission('manage_users');
      final isOwnProfile = currentUser.id == userId;

      if (!canManageUsers && !isOwnProfile) {
        return APIResponse<void>(
          success: false,
          message: 'Insufficient permissions to change password',
          statusCode: 403,
        );
      }

      // Validate password
      if (newPassword.length < 8) {
        return APIResponse<void>(
          success: false,
          message: 'Password must be at least 8 characters long',
          statusCode: 400,
        );
      }

      // If changing own password, verify current password
      if (isOwnProfile && !canManageUsers) {
        if (currentPassword == null || currentPassword.isEmpty) {
          return APIResponse<void>(
            success: false,
            message: 'Current password is required',
            statusCode: 400,
          );
        }

        final user = await _userService.verifyCredentials(
          currentUser.email,
          currentPassword,
        );
        if (user == null) {
          return APIResponse<void>(
            success: false,
            message: 'Current password is incorrect',
            statusCode: 400,
          );
        }
      }

      // Update password
      await _userService.updateUserPassword(userId, newPassword);

      await _auditService.logAction(
        actionType: 'password_updated',
        description: 'Password updated for user',
        contextData: {
          'target_user_id': userId,
          'updated_by_self': isOwnProfile,
          'updated_by_admin': canManageUsers && !isOwnProfile,
        },
        userId: currentUser.id,
      );

      return APIResponse<void>(
        success: true,
        message: 'Password updated successfully',
        statusCode: 200,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'password_update_error',
        description: 'Error updating password: ${e.toString()}',
        contextData: {
          'target_user_id': userId,
          'error': e.toString(),
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<void>(
        success: false,
        message: 'Failed to update password: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Get user statistics
  /// GET /api/users/stats
  Future<APIResponse<Map<String, int>>> getUserStats() async {
    try {
      // Check authentication
      if (!_authService.isAuthenticated) {
        return APIResponse<Map<String, int>>(
          success: false,
          message: 'Authentication required',
          statusCode: 401,
        );
      }

      // Check permissions
      if (!_authService.hasPermission('manage_users')) {
        return APIResponse<Map<String, int>>(
          success: false,
          message: 'Insufficient permissions to view user statistics',
          statusCode: 403,
        );
      }

      final stats = await _userService.getUserStats();

      await _auditService.logAction(
        actionType: 'user_stats_retrieved',
        description: 'Retrieved user statistics',
        contextData: stats,
        userId: _authService.currentUser?.id,
      );

      return APIResponse<Map<String, int>>(
        success: true,
        message: 'User statistics retrieved successfully',
        data: stats,
        statusCode: 200,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'user_stats_error',
        description: 'Error retrieving user statistics: ${e.toString()}',
        contextData: {'error': e.toString()},
        userId: _authService.currentUser?.id,
      );

      return APIResponse<Map<String, int>>(
        success: false,
        message: 'Failed to retrieve user statistics: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Validate user input
  String? _validateUserInput({
    required String email,
    required String name,
    required String role,
    required String password,
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
    if (!validRoles.contains(role.toLowerCase())) {
      return 'Invalid role specified';
    }

    // Password validation
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter, one uppercase letter, and one number';
    }

    return null;
  }
}

/// Generic API response wrapper (if not already defined elsewhere)
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
}

// User model is imported from auth_service.dart
