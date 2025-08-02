import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../database/services/services.dart';
import '../database/models/models.dart';

/// Authentication service with role-based access control (RBAC)
/// Supports Admin, Lead Developer, Developer, and Viewer roles
class AuthService {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;
  AuthService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;
  
  User? _currentUser;
  String? _currentToken;
  Timer? _tokenRefreshTimer;

  /// Current authenticated user
  User? get currentUser => _currentUser;
  
  /// Current JWT token
  String? get currentToken => _currentToken;
  
  /// Check if user is authenticated
  bool get isAuthenticated => _currentUser != null && _currentToken != null;

  /// Initialize authentication service
  Future<void> initialize() async {
    // Check for existing session
    await _loadStoredSession();
    
    await _auditService.logAction(
      actionType: 'auth_service_initialized',
      description: 'Authentication service initialized',
      aiReasoning: 'Authentication service provides secure RBAC for application access',
      contextData: {
        'has_stored_session': _currentUser != null,
      },
    );
  }

  /// Authenticate user with email and password
  Future<AuthResult> authenticate(String email, String password) async {
    try {
      // Hash password for comparison
      final passwordHash = _hashPassword(password);
      
      // Find user by email
      final user = await _findUserByEmail(email);
      if (user == null) {
        await _auditService.logAction(
          actionType: 'auth_failed',
          description: 'Authentication failed: User not found',
          contextData: {'email': email, 'reason': 'user_not_found'},
        );
        return AuthResult(success: false, message: 'Invalid credentials');
      }
      
      // Verify password
      if (user.passwordHash != passwordHash) {
        await _auditService.logAction(
          actionType: 'auth_failed',
          description: 'Authentication failed: Invalid password',
          contextData: {'email': email, 'reason': 'invalid_password'},
          userId: user.id,
        );
        return AuthResult(success: false, message: 'Invalid credentials');
      }
      
      // Check if user is active
      if (user.status != 'active') {
        await _auditService.logAction(
          actionType: 'auth_failed',
          description: 'Authentication failed: User account inactive',
          contextData: {'email': email, 'reason': 'account_inactive'},
          userId: user.id,
        );
        return AuthResult(success: false, message: 'Account is inactive');
      }
      
      // Generate JWT token
      final token = _generateJWTToken(user);
      
      // Update user session
      _currentUser = user;
      _currentToken = token;
      
      // Store session
      await _storeSession(user, token);
      
      // Start token refresh timer
      _startTokenRefreshTimer();
      
      await _auditService.logAction(
        actionType: 'auth_success',
        description: 'User authenticated successfully',
        contextData: {
          'email': email,
          'role': user.role,
          'login_time': DateTime.now().toIso8601String(),
        },
        userId: user.id,
      );
      
      return AuthResult(
        success: true,
        message: 'Authentication successful',
        user: user,
        token: token,
      );
      
    } catch (e) {
      await _auditService.logAction(
        actionType: 'auth_error',
        description: 'Authentication error: ${e.toString()}',
        contextData: {'email': email, 'error': e.toString()},
      );
      return AuthResult(success: false, message: 'Authentication failed');
    }
  }

  /// Authenticate with GitHub OAuth
  Future<AuthResult> authenticateWithGitHub(String githubToken) async {
    try {
      // Verify GitHub token and get user info
      final githubUser = await _verifyGitHubToken(githubToken);
      if (githubUser == null) {
        return AuthResult(success: false, message: 'Invalid GitHub token');
      }
      
      // Find or create user
      User? user = await _findUserByEmail(githubUser['email']);
      if (user == null) {
        // Create new user from GitHub profile
        user = User(
          id: _uuid.v4(),
          email: githubUser['email'],
          name: githubUser['name'] ?? githubUser['login'],
          role: 'developer', // Default role for OAuth users
          status: 'active',
          githubUsername: githubUser['login'],
          avatarUrl: githubUser['avatar_url'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          passwordHash: '', // OAuth users don't have passwords
        );
        
        await _createUser(user);
      }
      
      // Generate JWT token
      final token = _generateJWTToken(user);
      
      // Update session
      _currentUser = user;
      _currentToken = token;
      
      await _storeSession(user, token);
      _startTokenRefreshTimer();
      
      await _auditService.logAction(
        actionType: 'oauth_auth_success',
        description: 'GitHub OAuth authentication successful',
        contextData: {
          'email': user.email,
          'github_username': user.githubUsername,
          'role': user.role,
        },
        userId: user.id,
      );
      
      return AuthResult(
        success: true,
        message: 'GitHub authentication successful',
        user: user,
        token: token,
      );
      
    } catch (e) {
      await _auditService.logAction(
        actionType: 'oauth_auth_error',
        description: 'GitHub OAuth authentication error: ${e.toString()}',
        contextData: {'error': e.toString()},
      );
      return AuthResult(success: false, message: 'GitHub authentication failed');
    }
  }

  /// Logout current user
  Future<void> logout() async {
    if (_currentUser != null) {
      await _auditService.logAction(
        actionType: 'user_logout',
        description: 'User logged out',
        contextData: {
          'email': _currentUser!.email,
          'logout_time': DateTime.now().toIso8601String(),
        },
        userId: _currentUser!.id,
      );
    }
    
    // Clear session
    _currentUser = null;
    _currentToken = null;
    
    // Stop token refresh timer
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    
    // Clear stored session
    await _clearStoredSession();
  }

  /// Check if user has permission for specific action
  bool hasPermission(String action) {
    if (_currentUser == null) return false;
    
    final role = _currentUser!.role;
    
    switch (action) {
      // Admin permissions
      case 'manage_users':
      case 'manage_repositories':
      case 'manage_deployments':
      case 'view_all_tasks':
      case 'assign_tasks':
      case 'manage_system_settings':
        return role == 'admin';
      
      // Lead Developer permissions
      case 'review_code':
      case 'assign_developer_tasks':
      case 'view_team_tasks':
      case 'create_deployments':
      case 'approve_pull_requests':
        return role == 'admin' || role == 'lead_developer';
      
      // Developer permissions
      case 'create_tasks':
      case 'edit_assigned_tasks':
      case 'commit_code':
      case 'create_pull_requests':
      case 'view_assigned_repositories':
        return role == 'admin' || role == 'lead_developer' || role == 'developer';
      
      // Viewer permissions
      case 'view_dashboards':
      case 'view_public_repositories':
      case 'view_project_overview':
        return true; // All authenticated users can view
      
      default:
        return false;
    }
  }

  /// Get user role-specific dashboard configuration
  DashboardConfig getDashboardConfig() {
    if (_currentUser == null) {
      return DashboardConfig(
        role: 'guest',
        availableScreens: ['login'],
        permissions: [],
      );
    }
    
    final role = _currentUser!.role;
    
    switch (role) {
      case 'admin':
        return DashboardConfig(
          role: role,
          availableScreens: [
            'home',
            'repositories',
            'team_management',
            'user_management',
            'deployments',
            'security',
            'audit',
            'system_settings',
            'code_editor',
            'terminal',
          ],
          permissions: [
            'manage_users',
            'manage_repositories',
            'manage_deployments',
            'view_all_tasks',
            'assign_tasks',
            'manage_system_settings',
            'review_code',
            'create_tasks',
            'commit_code',
            'view_dashboards',
          ],
        );
      
      case 'lead_developer':
        return DashboardConfig(
          role: role,
          availableScreens: [
            'home',
            'repositories',
            'team_tasks',
            'code_review',
            'deployments',
            'code_editor',
            'terminal',
          ],
          permissions: [
            'review_code',
            'assign_developer_tasks',
            'view_team_tasks',
            'create_deployments',
            'approve_pull_requests',
            'create_tasks',
            'commit_code',
            'view_dashboards',
          ],
        );
      
      case 'developer':
        return DashboardConfig(
          role: role,
          availableScreens: [
            'home',
            'my_tasks',
            'assigned_repositories',
            'code_editor',
            'terminal',
          ],
          permissions: [
            'create_tasks',
            'edit_assigned_tasks',
            'commit_code',
            'create_pull_requests',
            'view_assigned_repositories',
            'view_dashboards',
          ],
        );
      
      case 'viewer':
        return DashboardConfig(
          role: role,
          availableScreens: [
            'home',
            'project_overview',
            'public_repositories',
          ],
          permissions: [
            'view_dashboards',
            'view_public_repositories',
            'view_project_overview',
          ],
        );
      
      default:
        return DashboardConfig(
          role: 'unknown',
          availableScreens: ['home'],
          permissions: ['view_dashboards'],
        );
    }
  }

  /// Refresh JWT token
  Future<String?> refreshToken() async {
    if (_currentUser == null) return null;
    
    try {
      final newToken = _generateJWTToken(_currentUser!);
      _currentToken = newToken;
      
      await _storeSession(_currentUser!, newToken);
      
      await _auditService.logAction(
        actionType: 'token_refreshed',
        description: 'JWT token refreshed',
        contextData: {
          'user_id': _currentUser!.id,
          'refresh_time': DateTime.now().toIso8601String(),
        },
        userId: _currentUser!.id,
      );
      
      return newToken;
      
    } catch (e) {
      await _auditService.logAction(
        actionType: 'token_refresh_failed',
        description: 'JWT token refresh failed: ${e.toString()}',
        contextData: {'error': e.toString()},
        userId: _currentUser?.id,
      );
      return null;
    }
  }

  /// Create new user account
  Future<User> createUser({
    required String email,
    required String name,
    required String password,
    required String role,
  }) async {
    final user = User(
      id: _uuid.v4(),
      email: email,
      name: name,
      role: role,
      status: 'active',
      passwordHash: _hashPassword(password),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await _createUser(user);
    
    await _auditService.logAction(
      actionType: 'user_created',
      description: 'New user account created',
      contextData: {
        'email': email,
        'name': name,
        'role': role,
      },
      userId: _currentUser?.id,
    );
    
    return user;
  }

  /// Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password + 'devguard_salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate JWT token (simplified implementation)
  String _generateJWTToken(User user) {
    final header = base64Url.encode(utf8.encode(jsonEncode({
      'alg': 'HS256',
      'typ': 'JWT',
    })));
    
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': user.id,
      'email': user.email,
      'role': user.role,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
    })));
    
    final signature = base64Url.encode(
      Hmac(sha256, utf8.encode('devguard_jwt_secret')).convert(
        utf8.encode('$header.$payload')
      ).bytes
    );
    
    return '$header.$payload.$signature';
  }

  /// Verify GitHub token (mock implementation)
  Future<Map<String, dynamic>?> _verifyGitHubToken(String token) async {
    // In a real implementation, this would call GitHub API
    // For demo purposes, return mock data
    return {
      'login': 'demo_user',
      'email': 'demo@github.com',
      'name': 'Demo User',
      'avatar_url': 'https://github.com/images/error/octocat_happy.gif',
    };
  }

  /// Find user by email (public method for onboarding service)
  Future<User?> findUserByEmail(String email) async {
    return await _findUserByEmail(email);
  }

  /// Authenticate user directly (for project creation)
  Future<void> authenticateUser(User user) async {
    // Generate JWT token
    final token = _generateJWTToken(user);
    
    // Update user session
    _currentUser = user;
    _currentToken = token;
    
    // Store session
    await _storeSession(user, token);
    
    // Start token refresh timer
    _startTokenRefreshTimer();
    
    await _auditService.logAction(
      actionType: 'direct_auth_success',
      description: 'User authenticated directly after account creation',
      contextData: {
        'email': user.email,
        'role': user.role,
        'auth_type': 'direct',
      },
      userId: user.id,
    );
  }

  /// Find user by email (private implementation)
  Future<User?> _findUserByEmail(String email) async {
    // This would query the database for user
    // For demo purposes, return mock users
    final mockUsers = {
      'admin@devguard.ai': User(
        id: 'admin-id',
        email: 'admin@devguard.ai',
        name: 'Admin User',
        role: 'admin',
        status: 'active',
        passwordHash: _hashPassword('admin123'),
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      ),
      'lead@devguard.ai': User(
        id: 'lead-id',
        email: 'lead@devguard.ai',
        name: 'Lead Developer',
        role: 'lead_developer',
        status: 'active',
        passwordHash: _hashPassword('lead123'),
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        updatedAt: DateTime.now(),
      ),
      'dev@devguard.ai': User(
        id: 'dev-id',
        email: 'dev@devguard.ai',
        name: 'Developer',
        role: 'developer',
        status: 'active',
        passwordHash: _hashPassword('dev123'),
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now(),
      ),
      'viewer@devguard.ai': User(
        id: 'viewer-id',
        email: 'viewer@devguard.ai',
        name: 'Viewer',
        role: 'viewer',
        status: 'active',
        passwordHash: _hashPassword('viewer123'),
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now(),
      ),
    };
    
    return mockUsers[email];
  }

  /// Create user in database
  Future<void> _createUser(User user) async {
    // This would save user to database
    // For demo purposes, just log the action
    print('User created: ${user.email} (${user.role})');
  }

  /// Load stored session
  Future<void> _loadStoredSession() async {
    // This would load session from secure storage
    // For demo purposes, skip implementation
  }

  /// Store session
  Future<void> _storeSession(User user, String token) async {
    // This would store session in secure storage
    // For demo purposes, skip implementation
  }

  /// Clear stored session
  Future<void> _clearStoredSession() async {
    // This would clear session from secure storage
    // For demo purposes, skip implementation
  }

  /// Start token refresh timer
  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(const Duration(hours: 1), (_) {
      refreshToken();
    });
  }

  /// Dispose resources
  void dispose() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    _currentUser = null;
    _currentToken = null;
  }
}

/// User model
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
  });
}

/// Authentication result
class AuthResult {
  final bool success;
  final String message;
  final User? user;
  final String? token;

  AuthResult({
    required this.success,
    required this.message,
    this.user,
    this.token,
  });
}

/// Dashboard configuration based on user role
class DashboardConfig {
  final String role;
  final List<String> availableScreens;
  final List<String> permissions;

  DashboardConfig({
    required this.role,
    required this.availableScreens,
    required this.permissions,
  });
}