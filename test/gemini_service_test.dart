import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import '../lib/core/ai/gemini_service.dart';
import '../lib/core/database/services/audit_log_service.dart';

// Generate mocks
@GenerateMocks([http.Client, AuditLogService])
import 'gemini_service_test.mocks.dart';

void main() {
  group('GeminiService Tests', () {
    late GeminiService geminiService;
    late MockClient mockHttpClient;
    late MockAuditLogService mockAuditLogService;

    setUp(() {
      geminiService = GeminiService.instance;
      mockHttpClient = MockClient();
      mockAuditLogService = MockAuditLogService();
    });

    test('should generate code suggestions successfully', () async {
      // Arrange
      const prompt = 'Create a Flutter widget for user login';
      const mockResponse = '''
        ```dart
        class LoginWidget extends StatefulWidget {
          @override
          _LoginWidgetState createState() => _LoginWidgetState();
        }
        ```
      ''';

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
            '{"candidates": [{"content": {"parts": [{"text": "$mockResponse"}]}}]}',
            200,
          ));

      // Act
      final result = await geminiService.generateCodeSuggestion(prompt);

      // Assert
      expect(result, isNotNull);
      expect(result, contains('LoginWidget'));
      expect(result, contains('StatefulWidget'));
    });

    test('should analyze code for security vulnerabilities', () async {
      // Arrange
      const codeSnippet = '''
        String password = "hardcoded_password";
        var sql = "SELECT * FROM users WHERE id = " + userId;
      ''';

      const mockResponse = '''
        Security Issues Found:
        1. Hardcoded password - Line 1
        2. SQL Injection vulnerability - Line 2
      ''';

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
            '{"candidates": [{"content": {"parts": [{"text": "$mockResponse"}]}}]}',
            200,
          ));

      // Act
      final result = await geminiService.analyzeCodeSecurity(codeSnippet);

      // Assert
      expect(result, isNotNull);
      expect(result, contains('Security Issues Found'));
      expect(result, contains('Hardcoded password'));
      expect(result, contains('SQL Injection'));
    });

    test('should generate documentation for code', () async {
      // Arrange
      const codeSnippet = '''
        class UserService {
          Future<User> getUserById(String id) async {
            return await database.query('users', where: 'id = ?', whereArgs: [id]);
          }
        }
      ''';

      const mockResponse = '''
        /// UserService class for managing user data operations
        /// 
        /// This service provides methods to interact with user data in the database.
        /// 
        /// Methods:
        /// - getUserById(String id): Retrieves a user by their unique identifier
      ''';

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
            '{"candidates": [{"content": {"parts": [{"text": "$mockResponse"}]}}]}',
            200,
          ));

      // Act
      final result = await geminiService.generateDocumentation(codeSnippet);

      // Assert
      expect(result, isNotNull);
      expect(result, contains('UserService class'));
      expect(result, contains('getUserById'));
    });

    test('should optimize code performance', () async {
      // Arrange
      const codeSnippet = '''
        List<User> users = [];
        for (int i = 0; i < userIds.length; i++) {
          users.add(await getUserById(userIds[i]));
        }
      ''';

      const mockResponse = '''
        Optimized code:
        ```dart
        List<User> users = await Future.wait(
          userIds.map((id) => getUserById(id))
        );
        ```
        
        Performance improvements:
        - Parallel execution instead of sequential
        - Reduced total execution time
      ''';

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
            '{"candidates": [{"content": {"parts": [{"text": "$mockResponse"}]}}]}',
            200,
          ));

      // Act
      final result = await geminiService.optimizeCode(codeSnippet);

      // Assert
      expect(result, isNotNull);
      expect(result, contains('Future.wait'));
      expect(result, contains('Performance improvements'));
    });

    test('should generate test cases for code', () async {
      // Arrange
      const codeSnippet = '''
        class Calculator {
          int add(int a, int b) => a + b;
          int subtract(int a, int b) => a - b;
        }
      ''';

      const mockResponse = '''
        ```dart
        test('should add two numbers correctly', () {
          final calculator = Calculator();
          expect(calculator.add(2, 3), equals(5));
        });
        
        test('should subtract two numbers correctly', () {
          final calculator = Calculator();
          expect(calculator.subtract(5, 3), equals(2));
        });
        ```
      ''';

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
            '{"candidates": [{"content": {"parts": [{"text": "$mockResponse"}]}}]}',
            200,
          ));

      // Act
      final result = await geminiService.generateTestCases(codeSnippet);

      // Assert
      expect(result, isNotNull);
      expect(result, contains('test('));
      expect(result, contains('expect('));
      expect(result, contains('Calculator'));
    });

    test('should handle API errors gracefully', () async {
      // Arrange
      const prompt = 'Generate code';

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('{"error": "API Error"}', 400));

      // Act & Assert
      expect(
        () => geminiService.generateCodeSuggestion(prompt),
        throwsA(isA<Exception>()),
      );
    });

    test('should validate API key configuration', () {
      // Act
      final isConfigured = geminiService.isApiKeyConfigured();

      // Assert
      expect(isConfigured, isA<bool>());
    });

    test('should format prompt correctly', () {
      // Arrange
      const userPrompt = 'Create a login form';
      const context = 'Flutter application';

      // Act
      final formattedPrompt = geminiService.formatPrompt(userPrompt, context);

      // Assert
      expect(formattedPrompt, contains(userPrompt));
      expect(formattedPrompt, contains(context));
      expect(formattedPrompt, contains('Flutter'));
    });

    test('should extract code from response', () {
      // Arrange
      const response = '''
        Here's the code:
        ```dart
        class TestClass {
          void testMethod() {}
        }
        ```
        This is the implementation.
      ''';

      // Act
      final extractedCode = geminiService.extractCodeFromResponse(response);

      // Assert
      expect(extractedCode, contains('class TestClass'));
      expect(extractedCode, contains('void testMethod()'));
      expect(extractedCode, isNot(contains('Here\'s the code:')));
    });

    test('should log AI interactions for audit', () async {
      // Arrange
      const prompt = 'Test prompt';
      const response = 'Test response';
      const userId = 'user123';

      when(mockAuditLogService.logAIInteraction(
        userId: anyNamed('userId'),
        prompt: anyNamed('prompt'),
        response: anyNamed('response'),
        model: anyNamed('model'),
      )).thenAnswer((_) async => true);

      // Act
      await geminiService.logInteraction(userId, prompt, response);

      // Assert
      verify(mockAuditLogService.logAIInteraction(
        userId: userId,
        prompt: prompt,
        response: response,
        model: 'gemini-pro',
      )).called(1);
    });
  });
}
