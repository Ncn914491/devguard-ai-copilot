import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../database/services/user_service.dart';
import '../database/services/task_service.dart';
import '../database/services/audit_log_service.dart';
import '../gitops/github_service.dart';
import '../gitops/gitlab_service.dart';
import 'user_management_api.dart';
import 'task_management_api.dart';
import 'repository_api.dart';
import 'websocket_service.dart';

/// Comprehensive backend API service with REST endpoints, validation, and security
/// Satisfies Requirements: 3.1, 3.2, 3.3, 3.4, 3.5 (Secure API with RBAC)
class BackendAPIService {
  static final BackendAPIService _instance = BackendAPIService._internal();
  static BackendAPIService get instance => _instance;
  BackendAPIService._internal();

  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;
  final _userAPI = UserManagementAPI.instance;
  final _taskAPI = TaskManagementAPI.instance;
  final _repositoryAPI = RepositoryAPI.instance;
  final _websocketService = WebSocketService.instance;

  // Rate limiting storage
  final Map<String, List<DateTime>> _requestCounts = {};
  final Map<String, DateTime> _blockedIPs = {};

  // API configuration
  static const int maxRequestsPerMinute = 60;
  static const int maxRequestsPerHour = 1000;
  static const Duration blockDuration = Duration(minutes: 15);

  /// Initialize the backend API service
  Future<void> initialize() async {
    await _websocketService.initialize();

    await _auditService.logAction(
      actionType: 'backend_api_initialized',
      description:
          'Backend API service initialized with security and rate limiting',
      aiReasoning:
          'API service provides secure REST endpoints with comprehensive validation',
      contextData: {
        'max_requests_per_minute': maxRequestsPerMinute,
        'max_requests_per_hour': maxRequestsPerHour,
      },
    );
  }

  /// Process API request with security, validation, and rate limiting
  Future<APIResponse<T>> processRequest<T>({
    required String endpoint,
    required String method,
    required Future<APIResponse<T>> Function() handler,
    String? clientIP,
    Map<String, String>? headers,
    String? body,
  }) async {
    try {
      // Apply rate limiting
      final rateLimitResult = _checkRateLimit(clientIP ?? 'unknown');
      if (!rateLimitResult.allowed) {
        await _auditService.logAction(
          actionType: 'api_rate_limited',
          description: 'API request rate limited',
          contextData: {
            'endpoint': endpoint,
            'method': method,
            'client_ip': clientIP ?? 'unknown',
            'reason': rateLimitResult.reason,
          },
        );

        return APIResponse<T>(
          success: false,
          message: 'Rate limit exceeded. ${rateLimitResult.reason}',
          statusCode: 429,
          metadata: {
            'retry_after': rateLimitResult.retryAfter?.inSeconds,
          },
        );
      }

      // Apply security headers validation
      final securityResult = _validateSecurityHeaders(headers ?? {});
      if (!securityResult.valid) {
        await _auditService.logAction(
          actionType: 'api_security_violation',
          description: 'API request failed security validation',
          contextData: {
            'endpoint': endpoint,
            'method': method,
            'client_ip': clientIP ?? 'unknown',
            'violation': securityResult.violation,
          },
        );

        return APIResponse<T>(
          success: false,
          message: 'Security validation failed',
          statusCode: 400,
        );
      }

      // Record successful request
      _recordRequest(clientIP ?? 'unknown');

      // Execute the handler
      final result = await handler();

      // Add security headers to response
      final responseWithHeaders = _addSecurityHeaders(result);

      // Log successful API call
      await _auditService.logAction(
        actionType: 'api_request_processed',
        description: 'API request processed successfully',
        contextData: {
          'endpoint': endpoint,
          'method': method,
          'status_code': result.statusCode,
          'client_ip': clientIP ?? 'unknown',
        },
        userId: _authService.currentUser?.id,
      );

      return responseWithHeaders;
    } catch (e) {
      // Log error
      await _auditService.logAction(
        actionType: 'api_request_error',
        description: 'API request processing error: ${e.toString()}',
        contextData: {
          'endpoint': endpoint,
          'method': method,
          'error': e.toString(),
          'client_ip': clientIP ?? 'unknown',
        },
        userId: _authService.currentUser?.id,
      );

      return APIResponse<T>(
        success: false,
        message: 'Internal server error',
        statusCode: 500,
      );
    }
  }

  /// User Management API endpoints
  Future<APIResponse<List<User>>> getUsers({
    String? role,
    String? status,
    String? clientIP,
  }) async {
    return await processRequest<List<User>>(
      endpoint: '/api/users',
      method: 'GET',
      clientIP: clientIP,
      handler: () => _userAPI.getUsers(role: role, status: status),
    );
  }

  Future<APIResponse<User>> getUser(String userId, {String? clientIP}) async {
    return await processRequest<User>(
      endpoint: '/api/users/$userId',
      method: 'GET',
      clientIP: clientIP,
      handler: () => _userAPI.getUser(userId),
    );
  }

  Future<APIResponse<String>> createUser({
    required String email,
    required String name,
    required String role,
    required String password,
    String? clientIP,
  }) async {
    return await processRequest<String>(
      endpoint: '/api/users',
      method: 'POST',
      clientIP: clientIP,
      handler: () => _userAPI.createUser(
        email: email,
        name: name,
        role: role,
        password: password,
      ),
    );
  }

  Future<APIResponse<void>> updateUser({
    required String userId,
    String? name,
    String? role,
    String? status,
    String? clientIP,
  }) async {
    return await processRequest<void>(
      endpoint: '/api/users/$userId',
      method: 'PUT',
      clientIP: clientIP,
      handler: () => _userAPI.updateUser(
        userId: userId,
        name: name,
        role: role,
        status: status,
      ),
    );
  }

  Future<APIResponse<void>> deleteUser(String userId,
      {String? clientIP}) async {
    return await processRequest<void>(
      endpoint: '/api/users/$userId',
      method: 'DELETE',
      clientIP: clientIP,
      handler: () => _userAPI.deleteUser(userId),
    );
  }

  /// Task Management API endpoints
  Future<APIResponse<List<Task>>> getTasks({
    String? assigneeId,
    String? status,
    String? priority,
    String? type,
    String? clientIP,
  }) async {
    return await processRequest<List<Task>>(
      endpoint: '/api/tasks',
      method: 'GET',
      clientIP: clientIP,
      handler: () => _taskAPI.getTasks(
        assigneeId: assigneeId,
        status: status,
        priority: priority,
        type: type,
      ),
    );
  }

  Future<APIResponse<Task>> getTask(String taskId, {String? clientIP}) async {
    return await processRequest<Task>(
      endpoint: '/api/tasks/$taskId',
      method: 'GET',
      clientIP: clientIP,
      handler: () => _taskAPI.getTask(taskId),
    );
  }

  Future<APIResponse<String>> createTask({
    required String title,
    required String description,
    required String type,
    required String priority,
    required String assigneeId,
    required int estimatedHours,
    required DateTime dueDate,
    List<String>? dependencies,
    String? clientIP,
  }) async {
    return await processRequest<String>(
      endpoint: '/api/tasks',
      method: 'POST',
      clientIP: clientIP,
      handler: () => _taskAPI.createTask(
        title: title,
        description: description,
        type: type,
        priority: priority,
        assigneeId: assigneeId,
        estimatedHours: estimatedHours,
        dueDate: dueDate,
        dependencies: dependencies ?? [],
      ),
    );
  }

  Future<APIResponse<void>> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? assigneeId,
    int? actualHours,
    String? clientIP,
  }) async {
    return await processRequest<void>(
      endpoint: '/api/tasks/$taskId',
      method: 'PUT',
      clientIP: clientIP,
      handler: () => _taskAPI.updateTask(
        taskId: taskId,
        title: title,
        description: description,
        status: status,
        priority: priority,
        assigneeId: assigneeId,
        actualHours: actualHours,
      ),
    );
  }

  Future<APIResponse<void>> deleteTask(String taskId,
      {String? clientIP}) async {
    return await processRequest<void>(
      endpoint: '/api/tasks/$taskId',
      method: 'DELETE',
      clientIP: clientIP,
      handler: () => _taskAPI.deleteTask(taskId),
    );
  }

  /// Repository Management API endpoints
  Future<APIResponse<List<Repository>>> getRepositories(
      {String? clientIP}) async {
    return await processRequest<List<Repository>>(
      endpoint: '/api/repositories',
      method: 'GET',
      clientIP: clientIP,
      handler: () => _repositoryAPI.getRepositories(),
    );
  }

  Future<APIResponse<Repository>> getRepository(String repoId,
      {String? clientIP}) async {
    return await processRequest<Repository>(
      endpoint: '/api/repositories/$repoId',
      method: 'GET',
      clientIP: clientIP,
      handler: () => _repositoryAPI.getRepository(repoId),
    );
  }

  Future<APIResponse<String>> cloneRepository({
    required String repoUrl,
    required String localPath,
    String? clientIP,
  }) async {
    return await processRequest<String>(
      endpoint: '/api/repositories/clone',
      method: 'POST',
      clientIP: clientIP,
      handler: () => _repositoryAPI.cloneRepository(
        repoUrl: repoUrl,
        localPath: localPath,
      ),
    );
  }

  /// GitHub/GitLab Integration API endpoints
  Future<APIResponse<List<GitHubRepository>>> getGitHubRepositories({
    required String accessToken,
    String? clientIP,
  }) async {
    return await processRequest<List<GitHubRepository>>(
      endpoint: '/api/github/repositories',
      method: 'GET',
      clientIP: clientIP,
      handler: () async {
        final githubService = GitHubService();
        final repos = await githubService.getRepositories(accessToken);
        return APIResponse<List<GitHubRepository>>(
          success: true,
          message: 'GitHub repositories retrieved successfully',
          data: repos,
          statusCode: 200,
        );
      },
    );
  }

  Future<APIResponse<GitHubPullRequest>> createGitHubPullRequest({
    required String accessToken,
    required String repoOwner,
    required String repoName,
    required String title,
    required String body,
    required String head,
    required String base,
    String? clientIP,
  }) async {
    return await processRequest<GitHubPullRequest>(
      endpoint: '/api/github/pull-requests',
      method: 'POST',
      clientIP: clientIP,
      handler: () async {
        final githubService = GitHubService();
        final pr = await githubService.createPullRequest(
          accessToken: accessToken,
          repoOwner: repoOwner,
          repoName: repoName,
          title: title,
          body: body,
          head: head,
          base: base,
        );
        return APIResponse<GitHubPullRequest>(
          success: true,
          message: 'Pull request created successfully',
          data: pr,
          statusCode: 201,
        );
      },
    );
  }

  /// WebSocket connection management
  Future<APIResponse<String>> initializeWebSocket({
    required String userId,
    String? clientIP,
  }) async {
    return await processRequest<String>(
      endpoint: '/api/websocket/connect',
      method: 'POST',
      clientIP: clientIP,
      handler: () async {
        final connectionId = await _websocketService.createConnection(userId);
        return APIResponse<String>(
          success: true,
          message: 'WebSocket connection initialized',
          data: connectionId,
          statusCode: 200,
        );
      },
    );
  }

  /// Health check endpoint
  Future<APIResponse<Map<String, dynamic>>> healthCheck(
      {String? clientIP}) async {
    return await processRequest<Map<String, dynamic>>(
      endpoint: '/api/health',
      method: 'GET',
      clientIP: clientIP,
      handler: () async {
        final healthData = {
          'status': 'healthy',
          'timestamp': DateTime.now().toIso8601String(),
          'version': '1.0.0',
          'services': {
            'auth': _authService.isAuthenticated,
            'websocket': _websocketService.isInitialized,
            'database': true, // Would check database connection
          },
        };

        return APIResponse<Map<String, dynamic>>(
          success: true,
          message: 'Service is healthy',
          data: healthData,
          statusCode: 200,
        );
      },
    );
  }

  /// Rate limiting check
  RateLimitResult _checkRateLimit(String clientIP) {
    final now = DateTime.now();

    // Check if IP is blocked
    final blockedUntil = _blockedIPs[clientIP];
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      return RateLimitResult(
        allowed: false,
        reason: 'IP temporarily blocked',
        retryAfter: blockedUntil.difference(now),
      );
    }

    // Get request history for this IP
    final requests = _requestCounts[clientIP] ?? [];

    // Remove old requests (older than 1 hour)
    requests.removeWhere((request) => now.difference(request).inHours >= 1);

    // Check hourly limit
    if (requests.length >= maxRequestsPerHour) {
      _blockedIPs[clientIP] = now.add(blockDuration);
      return RateLimitResult(
        allowed: false,
        reason: 'Hourly rate limit exceeded',
        retryAfter: blockDuration,
      );
    }

    // Check per-minute limit
    final recentRequests = requests
        .where((request) => now.difference(request).inMinutes < 1)
        .length;

    if (recentRequests >= maxRequestsPerMinute) {
      return RateLimitResult(
        allowed: false,
        reason: 'Per-minute rate limit exceeded',
        retryAfter: const Duration(minutes: 1),
      );
    }

    return RateLimitResult(allowed: true);
  }

  /// Record request for rate limiting
  void _recordRequest(String clientIP) {
    _requestCounts.putIfAbsent(clientIP, () => []).add(DateTime.now());
  }

  /// Validate security headers
  SecurityValidationResult _validateSecurityHeaders(
      Map<String, String> headers) {
    // Check for required security headers in requests
    final userAgent = headers['user-agent'] ?? '';
    if (userAgent.isEmpty) {
      return SecurityValidationResult(
        valid: false,
        violation: 'Missing User-Agent header',
      );
    }

    // Check for suspicious patterns
    final suspiciousPatterns = ['<script', 'javascript:', 'data:', 'vbscript:'];
    for (final header in headers.values) {
      for (final pattern in suspiciousPatterns) {
        if (header.toLowerCase().contains(pattern)) {
          return SecurityValidationResult(
            valid: false,
            violation: 'Suspicious content in headers',
          );
        }
      }
    }

    return SecurityValidationResult(valid: true);
  }

  /// Add security headers to response
  APIResponse<T> _addSecurityHeaders<T>(APIResponse<T> response) {
    final securityHeaders = {
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'X-XSS-Protection': '1; mode=block',
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
      'Content-Security-Policy': "default-src 'self'",
      'Referrer-Policy': 'strict-origin-when-cross-origin',
    };

    return APIResponse<T>(
      success: response.success,
      message: response.message,
      data: response.data,
      statusCode: response.statusCode,
      metadata: {
        ...?response.metadata,
        'security_headers': securityHeaders,
      },
    );
  }

  /// Dispose resources
  void dispose() {
    _requestCounts.clear();
    _blockedIPs.clear();
    _websocketService.dispose();
  }
}

/// Rate limiting result
class RateLimitResult {
  final bool allowed;
  final String? reason;
  final Duration? retryAfter;

  RateLimitResult({
    required this.allowed,
    this.reason,
    this.retryAfter,
  });
}

/// Security validation result
class SecurityValidationResult {
  final bool valid;
  final String? violation;

  SecurityValidationResult({
    required this.valid,
    this.violation,
  });
}

/// Generic API response wrapper (if not already defined)
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

/// Placeholder classes for GitHub integration (to be implemented)
class GitHubRepository {
  final String id;
  final String name;
  final String fullName;
  final String? description;
  final bool private;
  final String htmlUrl;
  final String cloneUrl;

  GitHubRepository({
    required this.id,
    required this.name,
    required this.fullName,
    this.description,
    required this.private,
    required this.htmlUrl,
    required this.cloneUrl,
  });
}

class GitHubPullRequest {
  final String id;
  final int number;
  final String title;
  final String body;
  final String state;
  final String htmlUrl;

  GitHubPullRequest({
    required this.id,
    required this.number,
    required this.title,
    required this.body,
    required this.state,
    required this.htmlUrl,
  });
}

/// Placeholder classes for repository management
class Repository {
  final String id;
  final String name;
  final String path;
  final String? remoteUrl;
  final DateTime createdAt;

  Repository({
    required this.id,
    required this.name,
    required this.path,
    this.remoteUrl,
    required this.createdAt,
  });
}

// User and Task models are imported from their respective services
