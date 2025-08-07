import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_auth_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_error_handler.dart';
import 'package:devguard_ai_copilot/core/supabase/services/supabase_base_service.dart';

// Generate mocks for comprehensive testing
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
  AuthResponse,
])
import 'supabase_comprehensive_unit_test.mocks.dart';

void main() {
  group('Comprehensive Supabase Unit Tests', () {
    late MockSupabaseClient mockClient;
    late MockGoTrueClient mockAuth;
    late MockPostgrestClient mockPostgrest;
    late MockUser mockUser;
    late MockSession mockSession;

    setUp(() {
      mockClient = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockPostgrest = MockPostgrestClient();
      mockUser = MockUser();
      mockSession = MockSession();

      when(mockClient.auth).thenReturn(mockAuth);
      when(mockClient.from(any)).thenReturn(mockPostgrest);
    });

    group('SupabaseService Tests', () {
      test('should initialize correctly', () {
        final service = SupabaseService.instance;
        expect(service.isInitialized, false);
        expect(service.connectionState, SupabaseConnectionState.disconnected);
      });

      test('should handle connection state changes', () {
        final service = SupabaseService.instance;
        service.reset();

        expect(service.connectionState, SupabaseConnectionState.disconnected);
        expect(service.isConnected, false);
      });

      test('should provide connection status', () {
        final service = SupabaseService.instance;
        final status = service.connectionStatus;

        expect(status, isA<Map<String, dynamic>>());
        expect(status.containsKey('isInitialized'), true);
        expect(status.containsKey('connectionState'), true);
      });
    });

    group('SupabaseAuthService Tests', () {
      late SupabaseAuthService authService;

      setUp(() {
        authService = SupabaseAuthService.instance;
      });

      test('should handle successful email authentication', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';

        when(mockUser.id).thenReturn('user-123');
        when(mockUser.email).thenReturn(email);
        when(mockUser.userMetadata).thenReturn({'role': 'developer'});

        final authResponse = MockAuthResponse();
        when(authResponse.user).thenReturn(mockUser);
        when(authResponse.session).thenReturn(mockSession);

        when(mockAuth.signInWithPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => authResponse);

        // Act
        final result = await authService.signInWithEmail(email, password);

        // Assert
        expect(result.success, true);
        expect(result.user, mockUser);
        expect(result.session, mockSession);
      });

      test('should handle authentication errors', () async {
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
        expect(result.message, contains('Invalid'));
      });

      test('should handle user registration', () async {
        // Arrange
        const email = 'newuser@example.com';
        const password = 'password123';
        final metadata = {'role': 'developer'};

        when(mockUser.id).thenReturn('user-456');
        when(mockUser.email).thenReturn(email);

        final authResponse = MockAuthResponse();
        when(authResponse.user).thenReturn(mockUser);
        when(authResponse.session).thenReturn(mockSession);

        when(mockAuth.signUp(
          email: email,
          password: password,
          data: metadata,
        )).thenAnswer((_) async => authResponse);

        // Act
        final result =
            await authService.signUp(email, password, metadata: metadata);

        // Assert
        expect(result.success, true);
        expect(result.user, mockUser);
      });

      test('should handle sign out', () async {
        // Arrange
        when(mockAuth.signOut()).thenAnswer((_) async {});

        // Act
        final result = await authService.signOut();

        // Assert
        expect(result.success, true);
        expect(result.message, 'Signed out successfully');
      });

      test('should handle password reset', () async {
        // Arrange
        const email = 'user@example.com';
        when(mockAuth.resetPasswordForEmail(email)).thenAnswer((_) async {});

        // Act
        final result = await authService.resetPasswordForEmail(email);

        // Assert
        expect(result.success, true);
        expect(result.message, contains('Password reset email sent'));
      });

      test('should check permissions correctly', () {
        // Arrange
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.userMetadata).thenReturn({'role': 'admin'});

        // Act & Assert
        expect(authService.hasPermission('manage_users'), true);
        expect(authService.hasPermission('view_dashboards'), true);

        // Test developer role
        when(mockUser.userMetadata).thenReturn({'role': 'developer'});
        expect(authService.hasPermission('manage_users'), false);
        expect(authService.hasPermission('create_tasks'), true);

        // Test viewer role
        when(mockUser.userMetadata).thenReturn({'role': 'viewer'});
        expect(authService.hasPermission('create_tasks'), false);
        expect(authService.hasPermission('view_dashboards'), true);
      });
    });

    group('SupabaseErrorHandler Tests', () {
      test('should handle PostgrestException', () {
        const error = PostgrestException(message: 'Test error', code: '23505');
        final appError = SupabaseErrorHandler.handleError(error);

        expect(appError.type, AppErrorType.validation);
        expect(appError.message, 'This record already exists');
      });

      test('should handle AuthException', () {
        const error = AuthException('Invalid login credentials');
        final appError = SupabaseErrorHandler.handleError(error);

        expect(appError.type, AppErrorType.authentication);
        expect(appError.message, 'Invalid email or password');
      });

      test('should handle StorageException', () {
        const error = StorageException('File not found', statusCode: '404');
        final appError = SupabaseErrorHandler.handleError(error);

        expect(appError.type, AppErrorType.notFound);
        expect(appError.message, 'File not found');
      });

      test('should handle unknown errors', () {
        final error = Exception('Unknown error');
        final appError = SupabaseErrorHandler.handleError(error);

        expect(appError.type, AppErrorType.unknown);
        expect(appError.message, contains('Unknown error'));
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

    group('RetryPolicy Tests', () {
      test('should identify retryable errors', () {
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
          // Expected to fail immediately
        }

        expect(attempts, 1);
      });
    });

    group('AppError Tests', () {
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

    group('Edge Cases and Error Scenarios', () {
      test('should handle null responses gracefully', () async {
        // Test auth service with null responses
        when(mockAuth.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => MockAuthResponse());

        final result =
            await authService.signInWithEmail('test@example.com', 'password');
        expect(result.success, false);
      });

      test('should handle network timeouts', () async {
        when(mockAuth.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(Exception('Network timeout'));

        final result =
            await authService.signInWithEmail('test@example.com', 'password');
        expect(result.success, false);
        expect(result.message, contains('Authentication failed'));
      });

      test('should handle malformed data', () {
        final malformedError =
            SupabaseErrorHandler.handleError('not an exception');
        expect(malformedError.type, AppErrorType.unknown);
      });

      test('should handle concurrent operations', () async {
        // Test multiple simultaneous auth attempts
        final futures = List.generate(
            5,
            (index) => authService.signInWithEmail(
                'user$index@example.com', 'password'));

        when(mockAuth.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 10));
          throw const AuthException('Invalid credentials');
        });

        final results = await Future.wait(futures);
        expect(results.every((result) => !result.success), true);
      });
    });

    group('Performance Tests', () {
      test('should handle rapid successive calls', () async {
        const iterations = 100;
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < iterations; i++) {
          SupabaseErrorHandler.handleError(const AuthException('test'));
        }

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds,
            lessThan(1000)); // Should complete within 1 second
      });

      test('should handle large error messages', () {
        final largeMessage = 'Error: ' + 'x' * 10000; // 10KB error message
        final error = AppError.unknown(largeMessage);

        expect(error.message.length, greaterThan(10000));
        expect(error.toString().length, greaterThan(10000));
      });
    });
  });
}
