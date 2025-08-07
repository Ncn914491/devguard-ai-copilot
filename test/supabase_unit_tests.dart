import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_auth_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_error_handler.dart';

// Generate mocks for testing
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  User,
  Session,
])
import 'supabase_unit_tests.mocks.dart';

void main() {
  group('Supabase Unit Tests', () {
    group('SupabaseService', () {
      late SupabaseService service;

      setUp(() {
        service = SupabaseService.instance;
        service.reset();
      });

      test('should have correct initial state', () {
        expect(service.isInitialized, false);
        expect(service.connectionState, SupabaseConnectionState.disconnected);
        expect(service.isConnected, false);
        expect(service.lastError, null);
      });

      test('should provide connection status', () {
        final status = service.connectionStatus;
        expect(status['isInitialized'], false);
        expect(
            status['connectionState'], 'SupabaseConnectionState.disconnected');
        expect(status['lastError'], null);
        expect(status['hasValidSession'], false);
      });

      test('should reset connection state', () {
        service.reset();
        expect(service.isInitialized, false);
        expect(service.connectionState, SupabaseConnectionState.disconnected);
        expect(service.lastError, null);
      });

      test('should throw exception when accessing client before initialization',
          () {
        expect(() => service.client, throwsException);
      });
    });

    group('SupabaseAuthService', () {
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

      test('should return success on valid email authentication', () async {
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

        final result = await authService.signInWithEmail(email, password);

        expect(result.success, true);
        expect(result.message, 'Authentication successful');
        expect(result.user, mockUser);
        expect(result.session, mockSession);
      });

      test('should handle authentication errors', () async {
        const email = 'test@example.com';
        const password = 'wrongpassword';

        when(mockAuth.signInWithPassword(
          email: email,
          password: password,
        )).thenThrow(const AuthException('Invalid login credentials'));

        final result = await authService.signInWithEmail(email, password);

        expect(result.success, false);
        expect(result.message, 'Invalid email or password');
        expect(result.user, null);
        expect(result.session, null);
      });

      test('should handle user registration', () async {
        const email = 'newuser@example.com';
        const password = 'password123';

        final authResponse = AuthResponse(
          user: mockUser,
          session: mockSession,
        );

        when(mockAuth.signUp(
          email: email,
          password: password,
          data: null,
        )).thenAnswer((_) async => authResponse);

        when(mockUser.id).thenReturn('user-456');

        final result = await authService.signUp(email, password);

        expect(result.success, true);
        expect(result.message, 'Registration successful');
        expect(result.user, mockUser);
        expect(result.session, mockSession);
      });

      test('should handle sign out', () async {
        when(mockAuth.signOut()).thenAnswer((_) async {});

        final result = await authService.signOut();

        expect(result.success, true);
        expect(result.message, 'Signed out successfully');
      });

      test('should handle password reset', () async {
        const email = 'user@example.com';

        when(mockAuth.resetPasswordForEmail(email)).thenAnswer((_) async {});

        final result = await authService.resetPasswordForEmail(email);

        expect(result.success, true);
        expect(result.message,
            'Password reset email sent. Please check your inbox.');
      });

      test('should check permissions correctly', () {
        when(mockAuth.currentUser).thenReturn(null);
        expect(authService.hasPermission('manage_users'), false);

        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.userMetadata).thenReturn({'role': 'admin'});
        expect(authService.hasPermission('manage_users'), true);

        when(mockUser.userMetadata).thenReturn({'role': 'developer'});
        expect(authService.hasPermission('manage_users'), false);
        expect(authService.hasPermission('create_tasks'), true);

        when(mockUser.userMetadata).thenReturn({'role': 'viewer'});
        expect(authService.hasPermission('create_tasks'), false);
        expect(authService.hasPermission('view_dashboards'), true);
      });
    });

    group('SupabaseErrorHandler', () {
      test('should handle PostgrestException correctly', () {
        final error = PostgrestException(
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
      });
    });

    group('RetryPolicy', () {
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

        expect(RetryPolicy.getRecoveryMessage(networkError),
            'Please check your internet connection and try again.');
        expect(RetryPolicy.getRecoveryMessage(authError),
            'Please check your credentials and try logging in again.');
      });

      test('should retry operations with exponential backoff', () async {
        int attempts = 0;

        final result = await RetryPolicy.withRetry(
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

        expect(result, 'success');
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
          // Expected to fail
        }

        expect(attempts, 1);
      });
    });

    group('AppError', () {
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
        expect(
            AppError.authentication('msg').type, AppErrorType.authentication);
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
  });
}
