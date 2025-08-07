import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_error_handler.dart';

void main() {
  group('SupabaseService', () {
    test('should have correct initial state', () {
      final service = SupabaseService.instance;
      
      expect(service.isInitialized, false);
      expect(service.connectionState, SupabaseConnectionState.disconnected);
      expect(service.isConnected, false);
      expect(service.lastError, null);
    });

    test('should provide connection status', () {
      final service = SupabaseService.instance;
      final status = service.connectionStatus;
      
      expect(status['isInitialized'], false);
      expect(status['connectionState'], 'SupabaseConnectionState.disconnected');
      expect(status['lastError'], null);
      expect(status['hasValidSession'], false);
    });

    test('should reset connection state', () {
      final service = SupabaseService.instance;
      service.reset();
      
      expect(service.isInitialized, false);
      expect(service.connectionState, SupabaseConnectionState.disconnected);
      expect(service.lastError, null);
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
      final error = AuthException('Invalid login credentials');
      
      final appError = SupabaseErrorHandler.handleError(error);
      
      expect(appError.type, AppErrorType.authentication);
      expect(appError.message, 'Invalid email or password');
    });

    test('should handle unknown errors', () {
      final error = Exception('Unknown error');
      
      final appError = SupabaseErrorHandler.handleError(error);
      
      expect(appError.type, AppErrorType.unknown);
      expect(appError.message.contains('Unknown error'), true);
    });
  });

  group('RetryPolicy', () {
    test('should determine retryable errors correctly', () {
      final networkError = AppError.network('Network error');
      final authError = AppError.authentication('Auth error');
      
      expect(RetryPolicy.isRetryableError(networkError), true);
      expect(RetryPolicy.isRetryableError(authError), false);
    });

    test('should provide recovery messages', () {
      final networkError = AppError.network('Network error');
      final message = RetryPolicy.getRecoveryMessage(networkError);
      
      expect(message, 'Please check your internet connection and try again.');
    });
  });

  group('AppError', () {
    test('should create different error types', () {
      final networkError = AppError.network('Network error');
      final authError = AppError.authentication('Auth error');
      final validationError = AppError.validation('Validation error');
      
      expect(networkError.type, AppErrorType.network);
      expect(networkError.isRetryable, true);
      
      expect(authError.type, AppErrorType.authentication);
      expect(authError.isRetryable, false);
      
      expect(validationError.type, AppErrorType.validation);
      expect(validationError.isRetryable, false);
    });

    test('should convert to string correctly', () {
      final error = AppError.validation('Test message');
      expect(error.toString(), 'Test message');
    });
  });
}