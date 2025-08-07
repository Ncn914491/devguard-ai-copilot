import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'supabase_error_handler.dart';
import '../database/services/services.dart';

/// Authentication service using Supabase Auth
/// Replaces the legacy JWT-based authentication with Supabase Auth
/// Supports email/password authentication, GitHub OAuth, and session management
class SupabaseAuthService {
  static final SupabaseAuthService _instance = SupabaseAuthService._internal();
  static SupabaseAuthService get instance => _instance;
  SupabaseAuthService._internal();

  final _supabaseService = SupabaseService.instance;
  final _auditService = AuditLogService.instance;

  StreamSubscription<AuthState>? _authStateSubscription;
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  Timer? _refreshTimer;

  /// Current authenticated user from Supabase
  User? get currentUser => _supabaseService.currentUser;

  /// Current session from Supabase
  Session? get currentSession => _supabaseService.currentSession;

  /// Current JWT token
  String? get currentToken => currentSession?.accessToken;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null && currentSession != null;

  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  /// Initialize authentication service
  Future<void> initialize() async {
    try {
      // Ensure Supabase is initialized
      if (!_supabaseService.isInitialized) {
        await _supabaseService.initialize();
      }

      // Set up auth state listener
      _setupAuthStateListener();

      // Set up auto-refresh if there's already a session
      if (hasValidSession) {
        _setupAutoRefresh();
      }

      await _auditService.logAction(
        actionType: 'supabase_auth_service_initialized',
        description: 'Supabase authentication service initialized',
        aiReasoning:
            'Authentication service provides secure Supabase Auth integration',
        contextData: {
          'has_active_session': currentSession != null,
          'user_id': currentUser?.id,
        },
      );

      debugPrint('✅ SupabaseAuthService initialized successfully');
    } catch (e) {
      debugPrint('❌ SupabaseAuthService initialization failed: $e');
      rethrow;
    }
  }

  /// Set up authentication state listener
  void _setupAuthStateListener() {
    _authStateSubscription?.cancel();
    _authStateSubscription =
        _supabaseService.client.auth.onAuthStateChange.listen(
      (AuthState authState) {
        debugPrint('🔄 Auth state changed: ${authState.event}');

        // Handle the auth state change
        _handleAuthStateChange(authState);

        // Broadcast to listeners
        _authStateController.add(authState);

        // Log auth state changes
        _auditService.logAction(
          actionType: 'auth_state_changed',
          description: 'Authentication state changed: ${authState.event}',
          contextData: {
            'event': authState.event.toString(),
            'user_id': authState.session?.user.id,
            'timestamp': DateTime.now().toIso8601String(),
          },
          userId: authState.session?.user.id,
        );
      },
      onError: (error) {
        debugPrint('❌ Auth state listener error: $error');
        _auditService.logAction(
          actionType: 'auth_state_error',
          description:
              'Authentication state listener error: ${error.toString()}',
          contextData: {'error': error.toString()},
        );
      },
    );
  }

  /// Handle auth state changes and set up auto-refresh
  void _handleAuthStateChange(AuthState authState) {
    switch (authState.event) {
      case AuthChangeEvent.signedIn:
        debugPrint('🔐 User signed in: ${authState.session?.user.id}');
        _setupAutoRefresh();
        break;
      case AuthChangeEvent.signedOut:
        debugPrint('🔓 User signed out');
        _refreshTimer?.cancel();
        break;
      case AuthChangeEvent.tokenRefreshed:
        debugPrint('🔄 Token refreshed');
        _setupAutoRefresh();
        break;
      case AuthChangeEvent.userUpdated:
        debugPrint('👤 User updated');
        break;
      case AuthChangeEvent.passwordRecovery:
        debugPrint('🔑 Password recovery initiated');
        break;
      default:
        debugPrint('🔄 Auth state changed: ${authState.event}');
    }
  }

  /// Authenticate user with email and password
  Future<SupabaseAuthResult> signInWithEmail(
      String email, String password) async {
    try {
      debugPrint('🔄 Attempting email/password authentication for: $email');

      final response = await _supabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && response.session != null) {
        await _auditService.logAction(
          actionType: 'supabase_auth_success',
          description: 'User authenticated successfully with email/password',
          contextData: {
            'email': email,
            'user_id': response.user!.id,
            'login_time': DateTime.now().toIso8601String(),
            'auth_method': 'email_password',
          },
          userId: response.user!.id,
        );

        debugPrint('✅ Email authentication successful for: $email');
        return SupabaseAuthResult(
          success: true,
          message: 'Authentication successful',
          user: response.user,
          session: response.session,
        );
      } else {
        return SupabaseAuthResult(
          success: false,
          message: 'Authentication failed: Invalid response',
        );
      }
    } on AuthException catch (e) {
      final errorMessage = SupabaseErrorHandler.getAuthErrorMessage(e);

      await _auditService.logAction(
        actionType: 'supabase_auth_failed',
        description: 'Email/password authentication failed',
        contextData: {
          'email': email,
          'error_code': e.statusCode,
          'error_message': e.message,
          'auth_method': 'email_password',
        },
      );

      debugPrint('❌ Email authentication failed for $email: $errorMessage');
      return SupabaseAuthResult(
        success: false,
        message: errorMessage,
        error: e,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_auth_error',
        description: 'Authentication error: ${e.toString()}',
        contextData: {
          'email': email,
          'error': e.toString(),
          'auth_method': 'email_password',
        },
      );

      debugPrint('❌ Authentication error for $email: $e');
      return SupabaseAuthResult(
        success: false,
        message: 'Authentication failed: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Register new user with email and password
  Future<SupabaseAuthResult> signUp(
    String email,
    String password, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('🔄 Attempting user registration for: $email');

      final response = await _supabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );

      if (response.user != null) {
        await _auditService.logAction(
          actionType: 'supabase_user_registered',
          description: 'New user registered successfully',
          contextData: {
            'email': email,
            'user_id': response.user!.id,
            'registration_time': DateTime.now().toIso8601String(),
            'metadata': metadata,
          },
          userId: response.user!.id,
        );

        debugPrint('✅ User registration successful for: $email');
        return SupabaseAuthResult(
          success: true,
          message: response.session != null
              ? 'Registration successful'
              : 'Registration successful. Please check your email for verification.',
          user: response.user,
          session: response.session,
        );
      } else {
        return SupabaseAuthResult(
          success: false,
          message: 'Registration failed: Invalid response',
        );
      }
    } on AuthException catch (e) {
      final errorMessage = SupabaseErrorHandler.getAuthErrorMessage(e);

      await _auditService.logAction(
        actionType: 'supabase_registration_failed',
        description: 'User registration failed',
        contextData: {
          'email': email,
          'error_code': e.statusCode,
          'error_message': e.message,
        },
      );

      debugPrint('❌ User registration failed for $email: $errorMessage');
      return SupabaseAuthResult(
        success: false,
        message: errorMessage,
        error: e,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_registration_error',
        description: 'Registration error: ${e.toString()}',
        contextData: {
          'email': email,
          'error': e.toString(),
        },
      );

      debugPrint('❌ Registration error for $email: $e');
      return SupabaseAuthResult(
        success: false,
        message: 'Registration failed: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Authenticate with GitHub OAuth
  Future<SupabaseAuthResult> signInWithGitHub() async {
    try {
      debugPrint('🔄 Attempting GitHub OAuth authentication');

      final response = await _supabaseService.client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: _getRedirectUrl(),
      );

      // OAuth flow is handled by browser/webview, success will be detected via auth state changes
      debugPrint('✅ GitHub OAuth flow initiated');
      return SupabaseAuthResult(
        success: true,
        message:
            'GitHub OAuth flow initiated. Please complete authentication in browser.',
      );
    } on AuthException catch (e) {
      final errorMessage = SupabaseErrorHandler.getAuthErrorMessage(e);

      await _auditService.logAction(
        actionType: 'supabase_github_oauth_failed',
        description: 'GitHub OAuth authentication failed',
        contextData: {
          'error_code': e.statusCode,
          'error_message': e.message,
          'auth_method': 'github_oauth',
        },
      );

      debugPrint('❌ GitHub OAuth failed: $errorMessage');
      return SupabaseAuthResult(
        success: false,
        message: errorMessage,
        error: e,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_github_oauth_error',
        description: 'GitHub OAuth error: ${e.toString()}',
        contextData: {
          'error': e.toString(),
          'auth_method': 'github_oauth',
        },
      );

      debugPrint('❌ GitHub OAuth error: $e');
      return SupabaseAuthResult(
        success: false,
        message: 'GitHub authentication failed: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Get redirect URL for OAuth flows
  String _getRedirectUrl() {
    // In production, this should be configured based on environment
    // For development, use localhost
    if (kDebugMode) {
      return 'http://localhost:3000/auth/callback';
    }

    // For production, use your actual domain
    return 'https://your-app-domain.com/auth/callback';
  }

  /// Request password reset
  Future<SupabaseAuthResult> resetPasswordForEmail(String email) async {
    try {
      debugPrint('🔄 Requesting password reset for: $email');

      await _supabaseService.client.auth.resetPasswordForEmail(email);

      await _auditService.logAction(
        actionType: 'supabase_password_reset_requested',
        description: 'Password reset email sent',
        contextData: {
          'email': email,
          'request_time': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('✅ Password reset email sent to: $email');
      return SupabaseAuthResult(
        success: true,
        message: 'Password reset email sent. Please check your inbox.',
      );
    } on AuthException catch (e) {
      final errorMessage = SupabaseErrorHandler.getAuthErrorMessage(e);

      await _auditService.logAction(
        actionType: 'supabase_password_reset_failed',
        description: 'Password reset request failed',
        contextData: {
          'email': email,
          'error_code': e.statusCode,
          'error_message': e.message,
        },
      );

      debugPrint('❌ Password reset failed for $email: $errorMessage');
      return SupabaseAuthResult(
        success: false,
        message: errorMessage,
        error: e,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_password_reset_error',
        description: 'Password reset error: ${e.toString()}',
        contextData: {
          'email': email,
          'error': e.toString(),
        },
      );

      debugPrint('❌ Password reset error for $email: $e');
      return SupabaseAuthResult(
        success: false,
        message: 'Password reset failed: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Sign out current user
  Future<SupabaseAuthResult> signOut() async {
    try {
      final userId = currentUser?.id;
      debugPrint('🔄 Signing out user: $userId');

      await _supabaseService.client.auth.signOut();

      await _auditService.logAction(
        actionType: 'supabase_user_logout',
        description: 'User signed out successfully',
        contextData: {
          'user_id': userId,
          'logout_time': DateTime.now().toIso8601String(),
        },
        userId: userId,
      );

      debugPrint('✅ User signed out successfully');
      return SupabaseAuthResult(
        success: true,
        message: 'Signed out successfully',
      );
    } on AuthException catch (e) {
      final errorMessage = SupabaseErrorHandler.getAuthErrorMessage(e);

      await _auditService.logAction(
        actionType: 'supabase_logout_failed',
        description: 'Sign out failed',
        contextData: {
          'error_code': e.statusCode,
          'error_message': e.message,
        },
      );

      debugPrint('❌ Sign out failed: $errorMessage');
      return SupabaseAuthResult(
        success: false,
        message: errorMessage,
        error: e,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_logout_error',
        description: 'Sign out error: ${e.toString()}',
        contextData: {
          'error': e.toString(),
        },
      );

      debugPrint('❌ Sign out error: $e');
      return SupabaseAuthResult(
        success: false,
        message: 'Sign out failed: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Refresh current session
  Future<SupabaseAuthResult> refreshSession() async {
    try {
      debugPrint('🔄 Refreshing session');

      final response = await _supabaseService.client.auth.refreshSession();

      if (response.session != null) {
        await _auditService.logAction(
          actionType: 'supabase_session_refreshed',
          description: 'Session refreshed successfully',
          contextData: {
            'user_id': response.session!.user.id,
            'refresh_time': DateTime.now().toIso8601String(),
          },
          userId: response.session!.user.id,
        );

        debugPrint('✅ Session refreshed successfully');
        return SupabaseAuthResult(
          success: true,
          message: 'Session refreshed',
          user: response.session!.user,
          session: response.session,
        );
      } else {
        return SupabaseAuthResult(
          success: false,
          message: 'Failed to refresh session',
        );
      }
    } on AuthException catch (e) {
      final errorMessage = SupabaseErrorHandler.getAuthErrorMessage(e);

      await _auditService.logAction(
        actionType: 'supabase_session_refresh_failed',
        description: 'Session refresh failed',
        contextData: {
          'error_code': e.statusCode,
          'error_message': e.message,
        },
      );

      debugPrint('❌ Session refresh failed: $errorMessage');
      return SupabaseAuthResult(
        success: false,
        message: errorMessage,
        error: e,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'supabase_session_refresh_error',
        description: 'Session refresh error: ${e.toString()}',
        contextData: {
          'error': e.toString(),
        },
      );

      debugPrint('❌ Session refresh error: $e');
      return SupabaseAuthResult(
        success: false,
        message: 'Session refresh failed: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Check if current session is valid
  bool get hasValidSession {
    final session = currentSession;
    if (session == null) return false;

    // Check if session is expired
    final expiresAt =
        DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    return DateTime.now().isBefore(expiresAt);
  }

  /// Get session expiry time
  DateTime? get sessionExpiresAt {
    final session = currentSession;
    if (session?.expiresAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(session!.expiresAt! * 1000);
  }

  /// Get time until session expires
  Duration? get timeUntilExpiry {
    final expiresAt = sessionExpiresAt;
    if (expiresAt == null) return null;
    return expiresAt.difference(DateTime.now());
  }

  /// Set up automatic token refresh
  void _setupAutoRefresh() {
    _refreshTimer?.cancel();

    final timeUntilExpiry = this.timeUntilExpiry;
    if (timeUntilExpiry == null || timeUntilExpiry.isNegative) return;

    // Refresh 5 minutes before expiry
    final refreshTime = timeUntilExpiry - const Duration(minutes: 5);
    if (refreshTime.isNegative) {
      // If less than 5 minutes left, refresh immediately
      refreshSession();
      return;
    }

    _refreshTimer = Timer(refreshTime, () {
      refreshSession().then((result) {
        if (result.success) {
          _setupAutoRefresh(); // Set up next refresh
        }
      });
    });
  }

  /// Check if user has permission for specific action
  bool hasPermission(String action) {
    if (!isAuthenticated) return false;

    // Get user role from metadata or default to 'viewer'
    final userMetadata = currentUser?.userMetadata ?? {};
    final role = userMetadata['role'] as String? ?? 'viewer';

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
        return role == 'admin' ||
            role == 'lead_developer' ||
            role == 'developer';

      // Viewer permissions
      case 'view_dashboards':
      case 'view_public_repositories':
      case 'view_project_overview':
        return true; // All authenticated users can view

      default:
        return false;
    }
  }

  /// Get user role from current user metadata
  String get userRole {
    if (!isAuthenticated) return 'guest';
    final userMetadata = currentUser?.userMetadata ?? {};
    return userMetadata['role'] as String? ?? 'viewer';
  }

  /// Get user role-specific dashboard configuration
  DashboardConfig getDashboardConfig() {
    if (!isAuthenticated) {
      return DashboardConfig(
        role: 'guest',
        availableScreens: ['login'],
        permissions: [],
      );
    }

    final role = userRole;

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

  /// Dispose resources
  void dispose() {
    _authStateSubscription?.cancel();
    _refreshTimer?.cancel();
    _authStateController.close();
  }
}

/// Supabase authentication result
class SupabaseAuthResult {
  final bool success;
  final String message;
  final User? user;
  final Session? session;
  final dynamic error;

  SupabaseAuthResult({
    required this.success,
    required this.message,
    this.user,
    this.session,
    this.error,
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
