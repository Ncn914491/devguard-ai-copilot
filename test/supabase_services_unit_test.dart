import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_auth_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_error_handler.dart';

// Generate mocks
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  PostgrestClient,
  PostgrestFilterBuilder,
  PostgrestTransformBuilder,
  RealtimeClient,
  RealtimeChannel,
  User,
  Session,
])
import 'supabase_services_unit_test.mocks.dart';

void main() {
  group('SupabaseService Unit Tests', () {
    late SupabaseService supabaseService;
    late MockSupabaseClient mockClient;

    setUp(() {
      supabaseService = SupabaseService.instance;
      mockClient = MockSupabaseClient();
      supabaseService.reset(); // Reset state before each test
    });

    test('should have correct initial state', () {
      expect(supabaseService.isInitialized, false);
      expect(supabaseService.connectionState,
          SupabaseConnectionState.disconnected);
      expect(supabaseService.isConnected, false);
      expect(supabaseService.lastError, null);
    });

    test('should provide connection status', () {
      final status = supabaseService.connectionStatus;

      expect(status['isInitialized'], false);
      expect(status['connectionState'], 'SupabaseConnectionState.disconnected');
      expect(status['lastError'], null);
      expect(status['hasValidSession'], false);
    });

    test('should reset connection state', () {
      supabaseService.reset();

      expect(supabaseService.isInitialized, false);
      expect(supabaseService.connectionState,
          SupabaseConnectionState.disconnected);
      expect(supabaseService.lastError, null);
    });

    test('should throw exception when accessing client before initialization',
        () {
      expect(() => supabaseService.client, throwsException);
    });
  });

  group('SupabaseAuthService Unit Tests', () {
    late SupabaseAuthService authService;
    late MockSupabaseClient mockClient;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late MockSession mockSession;

    setUp(() {
      authService = SupabaseAuthService.instance;
      mockClient = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      mockSession = MockSession();

      when(mockClient.auth).thenReturn(mockAuth);
    });

    group('signInWithEmail', () {
      test('should return success result on successful authentication',
          () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';

        final authResponse = AuthResponse(
          user: mockUser,
          session: mockSession,
        );

        when(mockAuth.signInWithPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => authResponse);

        when(mockUser.id).thenReturn('user-123');

        // Act
        final result = await authService.signInWithEmail(email, password);

        // Assert
        expect(result.success, true);
        expect(result.message, 'Authentication successful');
        expect(result.user, mockUser);
        expect(result.session, mockSession);
      });

      test('should return failure result on authentication error', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'wrongpassword';

        when(mockAuth.signInWithPassword(
          email: email,
          password: password,
        )).thenThrow(const AuthException('Invalid login credentials'));

        // Act
        final result = await authService.signInWithEmail(email, password);

        // Assert
        expect(result.success, false);
        expect(result.message, 'Invalid email or password');
        expect(result.user, null);
        expect(result.session, null);
      });

      test('should handle network errors', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';

        when(mockAuth.signInWithPassword(
          email: email,
          password: password,
        )).thenThrow(Exception('Network error'));

        // Act
        final result = await authService.signInWithEmail(email, password);

        // Assert
        expect(result.success, false);
        expect(result.message.contains('Authentication failed'), true);
      });
    });

    group('signUp', () {
      test('should return success result on successful registration', () async {
        // Arrange
        const email = 'newuser@example.com';
        const password = 'password123';
        final metadata = {'role': 'developer'};

        final authResponse = AuthResponse(
          user: mockUser,
          session: mockSession,
        );

        when(mockAuth.signUp(
          email: email,
          password: password,
          data: metadata,
        )).thenAnswer((_) async => authResponse);

        when(mockUser.id).thenReturn('user-456');

        // Act
        final result =
            await authService.signUp(email, password, metadata: metadata);

        // Assert
        expect(result.success, true);
        expect(result.message, 'Registration successful');
        expect(result.user, mockUser);
        expect(result.session, mockSession);
      });

      test('should handle registration errors', () async {
        // Arrange
        const email = 'existing@example.com';
        const password = 'password123';

        when(mockAuth.signUp(
          email: email,
          password: password,
          data: null,
        )).thenThrow(const AuthException('email already registered'));

        // Act
        final result = await authService.signUp(email, password);

        // Assert
        expect(result.success, false);
        expect(result.message, 'An account with this email already exists');
      });
    });

    group('signOut', () {
      test('should return success result on successful sign out', () async {
        // Arrange
        when(mockAuth.signOut()).thenAnswer((_) async {});

        // Act
        final result = await authService.signOut();

        // Assert
        expect(result.success, true);
        expect(result.message, 'Signed out successfully');
      });

      test('should handle sign out errors', () async {
        // Arrange
        when(mockAuth.signOut())
            .thenThrow(const AuthException('Sign out failed'));

        // Act
        final result = await authService.signOut();

        // Assert
        expect(result.success, false);
        expect(result.message.contains('Sign out failed'), true);
      });
    });

    group('resetPasswordForEmail', () {
      test('should return success result on successful password reset request',
          () async {
        // Arrange
        const email = 'user@example.com';

        when(mockAuth.resetPasswordForEmail(email)).thenAnswer((_) async {});

        // Act
        final result = await authService.resetPasswordForEmail(email);

        // Assert
        expect(result.success, true);
        expect(result.message,
            'Password reset email sent. Please check your inbox.');
      });

      test('should handle password reset errors', () async {
        // Arrange
        const email = 'nonexistent@example.com';

        when(mockAuth.resetPasswordForEmail(email))
            .thenThrow(const AuthException('user not found'));

        // Act
        final result = await authService.resetPasswordForEmail(email);

        // Assert
        expect(result.success, false);
        expect(result.message, 'Account not found');
      });
    });

    group('hasPermission', () {
      test('should return false for unauthenticated user', () {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        // Act & Assert
        expect(authService.hasPermission('manage_users'), false);
        expect(authService.hasPermission('view_dashboards'), false);
      });

      test('should return correct permissions for admin role', () {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.userMetadata).thenReturn({'role': 'admin'});

        // Act & Assert
        expect(authService.hasPermission('manage_users'), true);
        expect(authService.hasPermission('manage_repositories'), true);
        expect(authService.hasPermission('view_dashboards'), true);
      });

      test('should return correct permissions for developer role', () {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.userMetadata).thenReturn({'role': 'developer'});

        // Act & Assert
        expect(authService.hasPermission('manage_users'), false);
        expect(authService.hasPermission('create_tasks'), true);
        expect(authService.hasPermission('view_dashboards'), true);
      });

      test('should return correct permissions for viewer role', () {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.userMetadata).thenReturn({'role': 'viewer'});

        // Act & Assert
        expect(authService.hasPermission('manage_users'), false);
        expect(authService.hasPermission('create_tasks'), false);
        expect(authService.hasPermission('view_dashboards'), true);
      });
    });
  });

  group('SupabaseErrorHandler Unit Tests', () {
    test('should handle PostgrestException correctly', () {
      const error = PostgrestException(
        message: 'Test error',
        code: '23505',
      );

      final appError = SupabaseErrorHandler.handleError(error);

      expect(appError.type, AppErrorType.validation);
      expect(appError.message, 'This record already exists');
    });

    test('should handle AuthException correctly', () {
      const error = AuthException('Invalid login credentials');

      final appError = SupabaseErrorHandler.handleError(error);

      expect(appError.type, AppErrorType.authentication);
      expect(appError.message, 'Invalid email or password');
    });

    test('should handle StorageException correctly', () {
      const error = StorageException('File not found', statusCode: '404');

      final appError = SupabaseErrorHandler.handleError(error);

      expect(appError.type, AppErrorType.notFound);
      expect(appError.message, 'File not found');
    });

    test('should handle unknown errors', () {
      final error = Exception('Unknown error');

      final appError = SupabaseErrorHandler.handleError(error);

      expect(appError.type, AppErrorType.unknown);
      expect(appError.message.contains('Unknown error'), true);
    });

    test('should provide correct auth error messages', () {
      expect(
          SupabaseErrorHandler.getAuthErrorMessage(
              const AuthException('Invalid login credentials')),
          'Invalid email or password');

      expect(
          SupabaseErrorHandler.getAuthErrorMessage(
              const AuthException('email not confirmed')),
          'Please verify your email address');

      expect(
          SupabaseErrorHandler.getAuthErrorMessage(
              const AuthException('user not found')),
          'Account not found');
    });
  });

  group('RetryPolicy Unit Tests', () {
    test('should determine retryable errors correctly', () {
      final networkError = AppError.network('Network error');
      final authError = AppError.authentication('Auth error');
      final databaseError = AppError.database('DB error', isRetryable: true);

      expect(RetryPolicy.isRetryableError(networkError), true);
      expect(RetryPolicy.isRetryableError(authError), false);
      expect(RetryPolicy.isRetryableError(databaseError), true);
    });

    test('should provide recovery messages', () {
      final networkError = AppError.network('Network error');
      final authError = AppError.authentication('Auth error');
      final validationError = AppError.validation('Validation error');

      expect(RetryPolicy.getRecoveryMessage(networkError),
          'Please check your internet connection and try again.');
      expect(RetryPolicy.getRecoveryMessage(authError),
          'Please check your credentials and try logging in again.');
      expect(RetryPolicy.getRecoveryMessage(validationError),
          'Please check your input and try again.');
    });

    test('should retry operations with exponential backoff', () async {
      int attempts = 0;

      try {
        await RetryPolicy.withRetry(
          () async {
            attempts++;
            if (attempts < 3) {
              throw AppError.network('Network error');
            }
            return 'success';
          },
          maxRetries: 3,
          delay: const Duration(milliseconds: 10),
          shouldRetry: RetryPolicy.isRetryableError,
        );
      } catch (e) {
        // Should succeed on third attempt
      }

      expect(attempts, 3);
    });

    test('should not retry non-retryable errors', () async {
      int attempts = 0;

      try {
        await RetryPolicy.withRetry(
          () async {
            attempts++;
            throw AppError.authentication('Auth error');
          },
          maxRetries: 3,
          shouldRetry: RetryPolicy.isRetryableError,
        );
      } catch (e) {
        // Should fail immediately
      }

      expect(attempts, 1);
    });
  });

  group('AppError Unit Tests', () {
    test('should create different error types correctly', () {
      final networkError = AppError.network('Network error');
      final authError = AppError.authentication('Auth error');
      final validationError = AppError.validation('Validation error');
      final databaseError = AppError.database('DB error', isRetryable: true);

      expect(networkError.type, AppErrorType.network);
      expect(networkError.isRetryable, true);

      expect(authError.type, AppErrorType.authentication);
      expect(authError.isRetryable, false);

      expect(validationError.type, AppErrorType.validation);
      expect(validationError.isRetryable, false);

      expect(databaseError.type, AppErrorType.database);
      expect(databaseError.isRetryable, true);
    });

    test('should convert to string correctly', () {
      final error = AppError.validation('Test message');
      expect(error.toString(), 'Test message');
    });

    test('should create all error types', () {
      expect(AppError.network('msg').type, AppErrorType.network);
      expect(AppError.authentication('msg').type, AppErrorType.authentication);
      expect(AppError.authorization('msg').type, AppErrorType.authorization);
      expect(AppError.validation('msg').type, AppErrorType.validation);
      expect(AppError.database('msg').type, AppErrorType.database);
      expect(AppError.storage('msg').type, AppErrorType.storage);
      expect(AppError.realtime('msg').type, AppErrorType.realtime);
      expect(AppError.notFound('msg').type, AppErrorType.notFound);
      expect(AppError.rateLimited('msg').type, AppErrorType.rateLimited);
      expect(AppError.unknown('msg').type, AppErrorType.unknown);
    });
  });
}
