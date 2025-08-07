import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devguard_ai_copilot/core/supabase/services/supabase_team_member_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_service.dart';
import 'package:devguard_ai_copilot/core/supabase/supabase_error_handler.dart';
import 'package:devguard_ai_copilot/core/database/models/team_member.dart';

// Generate mocks
@GenerateMocks([
  SupabaseClient,
  PostgrestClient,
  PostgrestFilterBuilder,
  PostgrestTransformBuilder,
  RealtimeClient,
  RealtimeChannel,
])
import 'supabase_team_member_service_unit_test.mocks.dart';

void main() {
  group('SupabaseTeamMemberService Unit Tests', () {
    late SupabaseTeamMemberService service;
    late MockSupabaseClient mockClient;
    late MockPostgrestClient mockPostgrestClient;
    late MockPostgrestFilterBuilder mockFilterBuilder;
    late MockPostgrestTransformBuilder mockTransformBuilder;

    setUp(() {
      service = SupabaseTeamMemberService.instance;
      mockClient = MockSupabaseClient();
      mockPostgrestClient = MockPostgrestClient();
      mockFilterBuilder = MockPostgrestFilterBuilder();
      mockTransformBuilder = MockPostgrestTransformBuilder();

      // Mock the SupabaseService to return our mock client
      when(mockClient.from('team_members')).thenReturn(mockPostgrestClient);
    });

    group('fromMap', () {
      test('should convert map to TeamMember correctly', () {
        final map = {
          'id': 'team-123',
          'name': 'John Doe',
          'email': 'john@example.com',
          'role': 'developer',
          'status': 'active',
          'assignments': ['project-1', 'project-2'],
          'expertise': ['flutter', 'dart'],
          'workload': 75,
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-02T00:00:00Z',
        };

        final teamMember = service.fromMap(map);

        expect(teamMember.id, 'team-123');
        expect(teamMember.name, 'John Doe');
        expect(teamMember.email, 'john@example.com');
        expect(teamMember.role, 'developer');
        expect(teamMember.status, 'active');
        expect(teamMember.assignments, ['project-1', 'project-2']);
        expect(teamMember.expertise, ['flutter', 'dart']);
        expect(teamMember.workload, 75);
      });

      test('should handle null values gracefully', () {
        final map = {
          'id': 'team-123',
          'name': 'John Doe',
          'email': 'john@example.com',
          'role': 'developer',
          'status': 'active',
          'assignments': null,
          'expertise': null,
          'workload': null,
          'created_at': null,
          'updated_at': null,
        };

        final teamMember = service.fromMap(map);

        expect(teamMember.assignments, isEmpty);
        expect(teamMember.expertise, isEmpty);
        expect(teamMember.workload, 0);
      });
    });

    group('toMap', () {
      test('should convert TeamMember to map correctly', () {
        final teamMember = TeamMember(
          id: 'team-123',
          name: 'John Doe',
          email: 'john@example.com',
          role: 'developer',
          status: 'active',
          assignments: ['project-1', 'project-2'],
          expertise: ['flutter', 'dart'],
          workload: 75,
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
          updatedAt: DateTime.parse('2024-01-02T00:00:00Z'),
        );

        final map = service.toMap(teamMember);

        expect(map['id'], 'team-123');
        expect(map['name'], 'John Doe');
        expect(map['email'], 'john@example.com');
        expect(map['role'], 'developer');
        expect(map['status'], 'active');
        expect(map['assignments'], ['project-1', 'project-2']);
        expect(map['expertise'], ['flutter', 'dart']);
        expect(map['workload'], 75);
        expect(map['created_at'], '2024-01-01T00:00:00.000Z');
        expect(map['updated_at'], '2024-01-02T00:00:00.000Z');
      });
    });

    group('validateData', () {
      test('should pass validation for valid data', () {
        final data = {
          'id': 'team-123',
          'name': 'John Doe',
          'email': 'john@example.com',
          'role': 'developer',
          'status': 'active',
          'workload': 75,
        };

        expect(() => service.validateData(data), returnsNormally);
      });

      test('should throw validation error for missing name', () {
        final data = {
          'id': 'team-123',
          'name': '',
          'email': 'john@example.com',
          'role': 'developer',
          'status': 'active',
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'Team member name is required',
          )),
        );
      });

      test('should throw validation error for invalid email', () {
        final data = {
          'id': 'team-123',
          'name': 'John Doe',
          'email': 'invalid-email',
          'role': 'developer',
          'status': 'active',
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'Invalid email format',
          )),
        );
      });

      test('should throw validation error for invalid role', () {
        final data = {
          'id': 'team-123',
          'name': 'John Doe',
          'email': 'john@example.com',
          'role': 'invalid_role',
          'status': 'active',
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            contains('Invalid role'),
          )),
        );
      });

      test('should throw validation error for invalid status', () {
        final data = {
          'id': 'team-123',
          'name': 'John Doe',
          'email': 'john@example.com',
          'role': 'developer',
          'status': 'invalid_status',
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            contains('Invalid status'),
          )),
        );
      });

      test('should throw validation error for invalid workload', () {
        final data = {
          'id': 'team-123',
          'name': 'John Doe',
          'email': 'john@example.com',
          'role': 'developer',
          'status': 'active',
          'workload': 150, // Invalid: > 100
        };

        expect(
          () => service.validateData(data),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'Workload must be an integer between 0 and 100',
          )),
        );
      });
    });

    group('createTeamMember', () {
      test('should create team member successfully', () async {
        final teamMember = TeamMember(
          id: 'team-123',
          name: 'John Doe',
          email: 'john@example.com',
          role: 'developer',
          status: 'active',
          assignments: [],
          expertise: [],
          workload: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Mock successful creation
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('email', 'john@example.com'))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.limit(1)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);

        when(mockPostgrestClient.insert(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select('id')).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.single()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any))
            .thenAnswer((_) async => {'id': 'team-123'});

        final result = await service.createTeamMember(teamMember);

        expect(result, 'team-123');
        verify(mockPostgrestClient.insert(any)).called(1);
      });

      test('should throw error for duplicate email', () async {
        final teamMember = TeamMember(
          id: 'team-123',
          name: 'John Doe',
          email: 'existing@example.com',
          role: 'developer',
          status: 'active',
          assignments: [],
          expertise: [],
          workload: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Mock existing team member with same email
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('email', 'existing@example.com'))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.limit(1)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenAnswer((_) async => [
              {
                'id': 'existing-123',
                'name': 'Existing User',
                'email': 'existing@example.com',
                'role': 'developer',
                'status': 'active',
                'assignments': [],
                'expertise': [],
                'workload': 0,
                'created_at': '2024-01-01T00:00:00Z',
                'updated_at': '2024-01-01T00:00:00Z',
              }
            ]);

        expect(
          () => service.createTeamMember(teamMember),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'A team member with this email already exists',
          )),
        );
      });
    });

    group('getTeamMemberByEmail', () {
      test('should return team member when found', () async {
        const email = 'john@example.com';
        final expectedData = {
          'id': 'team-123',
          'name': 'John Doe',
          'email': email,
          'role': 'developer',
          'status': 'active',
          'assignments': [],
          'expertise': [],
          'workload': 0,
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-01T00:00:00Z',
        };

        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('email', email))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order('name', ascending: true))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.limit(1)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any))
            .thenAnswer((_) async => [expectedData]);

        final result = await service.getTeamMemberByEmail(email);

        expect(result, isNotNull);
        expect(result!.email, email);
        expect(result.name, 'John Doe');
      });

      test('should return null when not found', () async {
        const email = 'notfound@example.com';

        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('email', email))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order('name', ascending: true))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.limit(1)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);

        final result = await service.getTeamMemberByEmail(email);

        expect(result, isNull);
      });

      test('should throw error for empty email', () async {
        expect(
          () => service.getTeamMemberByEmail(''),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'Email cannot be empty',
          )),
        );
      });
    });

    group('updateWorkload', () {
      test('should update workload successfully', () async {
        const memberId = 'team-123';
        const newWorkload = 80;

        final existingMember = TeamMember(
          id: memberId,
          name: 'John Doe',
          email: 'john@example.com',
          role: 'developer',
          status: 'active',
          assignments: [],
          expertise: [],
          workload: 50,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Mock getting existing member
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', memberId))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.maybeSingle()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any))
            .thenAnswer((_) async => service.toMap(existingMember));

        // Mock update operation
        when(mockPostgrestClient.update(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', memberId))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenAnswer((_) async => {});

        await service.updateWorkload(memberId, newWorkload);

        verify(mockPostgrestClient.update(any)).called(1);
      });

      test('should throw error for invalid workload', () async {
        const memberId = 'team-123';
        const invalidWorkload = 150;

        expect(
          () => service.updateWorkload(memberId, invalidWorkload),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'Workload must be between 0 and 100',
          )),
        );
      });

      test('should throw error for non-existent member', () async {
        const memberId = 'non-existent';
        const newWorkload = 80;

        // Mock member not found
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', memberId))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.maybeSingle()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenAnswer((_) async => null);

        expect(
          () => service.updateWorkload(memberId, newWorkload),
          throwsA(isA<AppError>().having(
            (e) => e.message,
            'message',
            'Team member not found',
          )),
        );
      });
    });

    group('getTeamStatistics', () {
      test('should calculate team statistics correctly', () async {
        final mockMembers = [
          {
            'id': 'team-1',
            'name': 'John Doe',
            'email': 'john@example.com',
            'role': 'developer',
            'status': 'active',
            'assignments': [],
            'expertise': ['flutter'],
            'workload': 80,
            'created_at': '2024-01-01T00:00:00Z',
            'updated_at': '2024-01-01T00:00:00Z',
          },
          {
            'id': 'team-2',
            'name': 'Jane Smith',
            'email': 'jane@example.com',
            'role': 'lead_developer',
            'status': 'active',
            'assignments': [],
            'expertise': ['dart', 'flutter'],
            'workload': 60,
            'created_at': '2024-01-01T00:00:00Z',
            'updated_at': '2024-01-01T00:00:00Z',
          },
          {
            'id': 'team-3',
            'name': 'Bob Wilson',
            'email': 'bob@example.com',
            'role': 'developer',
            'status': 'bench',
            'assignments': [],
            'expertise': ['react'],
            'workload': 0,
            'created_at': '2024-01-01T00:00:00Z',
            'updated_at': '2024-01-01T00:00:00Z',
          },
        ];

        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order('name', ascending: true))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenAnswer((_) async => mockMembers);

        final stats = await service.getTeamStatistics();

        expect(stats['total'], 3);
        expect(stats['active'], 2);
        expect(stats['bench'], 1);
        expect(stats['inactive'], 0);
        expect(stats['averageWorkload'], closeTo(46.67, 0.1));

        final roleDistribution = stats['roleDistribution'] as Map<String, int>;
        expect(roleDistribution['developer'], 2);
        expect(roleDistribution['lead_developer'], 1);

        final expertiseDistribution =
            stats['expertiseDistribution'] as Map<String, int>;
        expect(expertiseDistribution['flutter'], 2);
        expect(expertiseDistribution['dart'], 1);
        expect(expertiseDistribution['react'], 1);
      });

      test('should handle empty team list', () async {
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order('name', ascending: true))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);

        final stats = await service.getTeamStatistics();

        expect(stats['total'], 0);
        expect(stats['active'], 0);
        expect(stats['bench'], 0);
        expect(stats['inactive'], 0);
        expect(stats['averageWorkload'], 0.0);
      });
    });

    group('Error Handling', () {
      test('should handle database errors gracefully', () async {
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order('name', ascending: true))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenThrow(
            PostgrestException(message: 'Database error', code: 'PGRST000'));

        expect(
          () => service.getAllTeamMembers(),
          throwsA(isA<AppError>().having(
            (e) => e.type,
            'type',
            AppErrorType.database,
          )),
        );
      });

      test('should handle network errors gracefully', () async {
        when(mockPostgrestClient.select()).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order('name', ascending: true))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.then(any)).thenThrow(Exception('Network error'));

        expect(
          () => service.getAllTeamMembers(),
          throwsA(isA<AppError>()),
        );
      });
    });
  });
}
