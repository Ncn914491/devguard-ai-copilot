import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:devguard_ai_copilot/core/gitops/github_service.dart';
import 'package:devguard_ai_copilot/core/database/services/audit_log_service.dart';

// Generate mocks
@GenerateMocks([http.Client, AuditLogService])
import 'github_integration_test.mocks.dart';

void main() {
  group('GitHub Integration Tests', () {
    late GitHubService githubService;
    late MockClient mockClient;
    late MockAuditLogService mockAuditService;

    setUp(() {
      githubService = GitHubService.instance;
      mockClient = MockClient();
      mockAuditService = MockAuditLogService();
    });

    tearDown(() {
      githubService.dispose();
    });

    group('Repository Operations', () {
      test('should clone repository successfully', () async {
        // Mock successful repository response
        when(mockClient.get(
          Uri.parse('https://api.github.com/repos/test/repo'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response('''
          {
            "id": 123,
            "name": "repo",
            "full_name": "test/repo",
            "clone_url": "https://github.com/test/repo.git",
            "default_branch": "main",
            "private": false,
            "description": "Test repository"
          }
        ''', 200));

        // Initialize service
        await githubService.initialize('fake-token', 'test', 'repo');

        // Test repository cloning
        final repository = await githubService.cloneRepository();

        expect(repository.name, equals('repo'));
        expect(repository.fullName, equals('test/repo'));
        expect(repository.defaultBranch, equals('main'));
        expect(repository.private, equals(false));
      });

      test('should handle repository access failure', () async {
        // Mock failed repository response
        when(mockClient.get(
          Uri.parse('https://api.github.com/repos/test/repo'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response('Not Found', 404));

        // Test initialization failure
        expect(
          () => githubService.initialize('fake-token', 'test', 'repo'),
          throwsException,
        );
      });
    });

    group('Branch Operations', () {
      test('should create branch successfully', () async {
        // Mock successful branch creation
        when(mockClient.get(
          Uri.parse(
              'https://api.github.com/repos/test/repo/git/refs/heads/main'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response('''
          {
            "object": {
              "sha": "abc123"
            }
          }
        ''', 200));

        when(mockClient.post(
          Uri.parse('https://api.github.com/repos/test/repo/git/refs'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('''
          {
            "ref": "refs/heads/feature-branch",
            "url": "https://api.github.com/repos/test/repo/git/refs/heads/feature-branch",
            "object": {
              "sha": "def456"
            }
          }
        ''', 201));

        // Initialize service
        await githubService.initialize('fake-token', 'test', 'repo');

        // Test branch creation
        final branch =
            await githubService.createBranch('feature-branch', 'main');

        expect(branch.name, equals('feature-branch'));
        expect(branch.sha, equals('def456'));
      });

      test('should handle branch creation failure', () async {
        // Mock failed branch creation
        when(mockClient.get(
          Uri.parse(
              'https://api.github.com/repos/test/repo/git/refs/heads/main'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response('Not Found', 404));

        // Initialize service
        await githubService.initialize('fake-token', 'test', 'repo');

        // Test branch creation failure
        expect(
          () => githubService.createBranch('feature-branch', 'main'),
          throwsException,
        );
      });
    });

    group('Pull Request Operations', () {
      test('should create pull request successfully', () async {
        // Mock successful PR creation
        when(mockClient.post(
          Uri.parse('https://api.github.com/repos/test/repo/pulls'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('''
          {
            "number": 1,
            "title": "Test PR",
            "body": "Test description",
            "state": "open",
            "html_url": "https://github.com/test/repo/pull/1",
            "created_at": "2023-01-01T00:00:00Z"
          }
        ''', 201));

        // Initialize service
        await githubService.initialize('fake-token', 'test', 'repo');

        // Test PR creation
        final pr = await githubService.createPullRequest(
          'Test PR',
          'Test description',
          'feature-branch',
          'main',
        );

        expect(pr.number, equals(1));
        expect(pr.title, equals('Test PR'));
        expect(pr.state, equals('open'));
      });
    });

    group('Issue Operations', () {
      test('should fetch repository issues successfully', () async {
        // Mock successful issues response
        when(mockClient.get(
          Uri.parse('https://api.github.com/repos/test/repo/issues?state=open'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response('''
          [
            {
              "number": 1,
              "title": "Test Issue",
              "body": "Test description",
              "state": "open",
              "html_url": "https://github.com/test/repo/issues/1",
              "labels": [{"name": "bug"}],
              "created_at": "2023-01-01T00:00:00Z"
            }
          ]
        ''', 200));

        // Initialize service
        await githubService.initialize('fake-token', 'test', 'repo');

        // Test issues fetching
        final issues = await githubService.getRepositoryIssues();

        expect(issues.length, equals(1));
        expect(issues.first.number, equals(1));
        expect(issues.first.title, equals('Test Issue'));
        expect(issues.first.labels, contains('bug'));
      });

      test('should create issue successfully', () async {
        // Mock successful issue creation
        when(mockClient.post(
          Uri.parse('https://api.github.com/repos/test/repo/issues'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('''
          {
            "number": 2,
            "title": "New Issue",
            "body": "New description",
            "state": "open",
            "html_url": "https://github.com/test/repo/issues/2",
            "labels": [{"name": "feature"}],
            "created_at": "2023-01-01T00:00:00Z"
          }
        ''', 201));

        // Initialize service
        await githubService.initialize('fake-token', 'test', 'repo');

        // Test issue creation
        final issue = await githubService.createIssue(
          'New Issue',
          'New description',
          labels: ['feature'],
        );

        expect(issue.number, equals(2));
        expect(issue.title, equals('New Issue'));
        expect(issue.labels, contains('feature'));
      });
    });

    group('Integration Status', () {
      test('should return connected status when initialized', () async {
        // Mock rate limit response
        when(mockClient.get(
          Uri.parse('https://api.github.com/rate_limit'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response('''
          {
            "rate": {
              "remaining": 4999,
              "reset": 1672531200
            }
          }
        ''', 200));

        // Initialize service
        await githubService.initialize('fake-token', 'test', 'repo');

        // Test integration status
        final status = await githubService.getIntegrationStatus();

        expect(status.connected, equals(true));
        expect(status.repository, equals('test/repo'));
        expect(status.rateLimitRemaining, equals(4999));
      });

      test('should return disconnected status when not initialized', () async {
        // Test integration status without initialization
        final status = await githubService.getIntegrationStatus();

        expect(status.connected, equals(false));
        expect(status.repository, isNull);
        expect(status.rateLimitRemaining, equals(0));
      });
    });

    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        // Mock network error
        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenThrow(Exception('Network error'));

        // Test error handling
        expect(
          () => githubService.initialize('fake-token', 'test', 'repo'),
          throwsException,
        );
      });

      test('should handle API rate limiting', () async {
        // Mock rate limit exceeded response
        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response('''
          {
            "message": "API rate limit exceeded"
          }
        ''', 403));

        // Test rate limit handling
        expect(
          () => githubService.initialize('fake-token', 'test', 'repo'),
          throwsException,
        );
      });
    });
  });
}
