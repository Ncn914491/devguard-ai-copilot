import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/models/team_member.dart';
import '../supabase_error_handler.dart';
import 'supabase_base_service.dart';

// Import error handling classes directly
import '../supabase_service.dart';

/// Supabase implementation of team member service
/// Replaces SQLite queries with supabase.from('team_members') operations
/// Requirements: 1.2, 1.4, 3.2 - Team member management with real-time capabilities
class SupabaseTeamMemberService extends SupabaseBaseService<TeamMember> {
  static final SupabaseTeamMemberService _instance =
      SupabaseTeamMemberService._internal();
  static SupabaseTeamMemberService get instance => _instance;
  SupabaseTeamMemberService._internal();

  @override
  String get tableName => 'team_members';

  @override
  TeamMember fromMap(Map<String, dynamic> map) {
    return TeamMember(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      status: map['status'] ?? '',
      assignments: _parseStringList(map['assignments']),
      expertise: _parseStringList(map['expertise']),
      workload: map['workload']?.toInt() ?? 0,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  @override
  Map<String, dynamic> toMap(TeamMember item) {
    return {
      'id': item.id,
      'name': item.name,
      'email': item.email,
      'role': item.role,
      'status': item.status,
      'assignments': item.assignments,
      'expertise': item.expertise,
      'workload': item.workload,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
    };
  }

  @override
  void validateData(Map<String, dynamic> data) {
    // Validate required fields
    if (data['name'] == null || data['name'].toString().trim().isEmpty) {
      throw AppError.validation('Team member name is required');
    }

    if (data['email'] == null || data['email'].toString().trim().isEmpty) {
      throw AppError.validation('Team member email is required');
    }

    if (data['role'] == null || data['role'].toString().trim().isEmpty) {
      throw AppError.validation('Team member role is required');
    }

    if (data['status'] == null || data['status'].toString().trim().isEmpty) {
      throw AppError.validation('Team member status is required');
    }

    // Validate email format
    final email = data['email'].toString();
    if (!_isValidEmail(email)) {
      throw AppError.validation('Invalid email format');
    }

    // Validate role
    const validRoles = ['admin', 'lead_developer', 'developer', 'viewer'];
    if (!validRoles.contains(data['role'])) {
      throw AppError.validation(
          'Invalid role. Must be one of: ${validRoles.join(', ')}');
    }

    // Validate status
    const validStatuses = ['active', 'inactive', 'bench'];
    if (!validStatuses.contains(data['status'])) {
      throw AppError.validation(
          'Invalid status. Must be one of: ${validStatuses.join(', ')}');
    }

    // Validate workload
    if (data['workload'] != null) {
      final workload = data['workload'];
      if (workload is! int || workload < 0 || workload > 100) {
        throw AppError.validation(
            'Workload must be an integer between 0 and 100');
      }
    }
  }

  /// Create a new team member
  /// Satisfies Requirements: 3.2 (Team member data model)
  Future<String> createTeamMember(TeamMember member) async {
    try {
      // Check for duplicate email
      final existing = await getTeamMemberByEmail(member.email);
      if (existing != null) {
        throw AppError.validation(
            'A team member with this email already exists');
      }

      return await create(member);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get team member by ID
  /// Satisfies Requirements: 3.2 (Team member retrieval)
  Future<TeamMember?> getTeamMember(String id) async {
    return await getById(id);
  }

  /// Get all team members
  /// Satisfies Requirements: 3.2 (Team dashboard with all members)
  Future<List<TeamMember>> getAllTeamMembers() async {
    return await getAll(orderBy: 'name', ascending: true);
  }

  /// Get team member by email
  Future<TeamMember?> getTeamMemberByEmail(String email) async {
    try {
      if (email.isEmpty) {
        throw AppError.validation('Email cannot be empty');
      }

      final results = await getWhere(column: 'email', value: email, limit: 1);
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get team members by status
  /// Satisfies Requirements: 3.2 (Status-based filtering)
  Future<List<TeamMember>> getTeamMembersByStatus(String status) async {
    try {
      return await getWhere(
        column: 'status',
        value: status,
        orderBy: 'name',
        ascending: true,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get team members by role
  Future<List<TeamMember>> getTeamMembersByRole(String role) async {
    try {
      return await getWhere(
        column: 'role',
        value: role,
        orderBy: 'name',
        ascending: true,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update team member
  /// Satisfies Requirements: 3.2 (Team member updates)
  Future<void> updateTeamMember(TeamMember member) async {
    try {
      // Check if member exists
      final existing = await getById(member.id);
      if (existing == null) {
        throw AppError.notFound('Team member not found');
      }

      // Check for duplicate email if email is being changed
      if (existing.email != member.email) {
        final emailExists = await getTeamMemberByEmail(member.email);
        if (emailExists != null && emailExists.id != member.id) {
          throw AppError.validation(
              'A team member with this email already exists');
        }
      }

      await update(member.id, member);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update team member assignments
  /// Satisfies Requirements: 3.2 (Assignment tracking)
  Future<void> updateAssignments(
      String memberId, List<String> assignments) async {
    try {
      final member = await getTeamMember(memberId);
      if (member == null) {
        throw AppError.notFound('Team member not found');
      }

      final updatedMember = member.copyWith(
        assignments: assignments,
        updatedAt: DateTime.now(),
      );

      await updateTeamMember(updatedMember);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update team member workload
  Future<void> updateWorkload(String memberId, int workload) async {
    try {
      if (workload < 0 || workload > 100) {
        throw AppError.validation('Workload must be between 0 and 100');
      }

      final member = await getTeamMember(memberId);
      if (member == null) {
        throw AppError.notFound('Team member not found');
      }

      final updatedMember = member.copyWith(
        workload: workload,
        updatedAt: DateTime.now(),
      );

      await updateTeamMember(updatedMember);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Delete team member
  /// Satisfies Requirements: 3.2 (Team member management)
  Future<void> deleteTeamMember(String id) async {
    try {
      // Check if member exists
      final existing = await getById(id);
      if (existing == null) {
        throw AppError.notFound('Team member not found');
      }

      await delete(id);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get available team members (not on bench)
  /// Satisfies Requirements: 3.2 (Workload-based filtering)
  Future<List<TeamMember>> getAvailableMembers() async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .neq('status', 'bench')
            .order('workload', ascending: true)
            .order('name', ascending: true),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get team members by expertise
  /// Satisfies Requirements: 3.2 (Expertise-based filtering)
  Future<List<TeamMember>> getTeamMembersByExpertise(String expertise) async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .contains('expertise', [expertise])
            .order('workload', ascending: true)
            .order('name', ascending: true),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get team members with low workload (for assignment suggestions)
  Future<List<TeamMember>> getLowWorkloadMembers({int maxWorkload = 70}) async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .eq('status', 'active')
            .lte('workload', maxWorkload)
            .order('workload', ascending: true)
            .order('name', ascending: true),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch all team members for real-time updates
  /// Satisfies Requirements: 3.2 (Real-time team member changes)
  Stream<List<TeamMember>> watchAllTeamMembers() {
    return watchAll(orderBy: 'name', ascending: true);
  }

  /// Watch team members by status for real-time updates
  Stream<List<TeamMember>> watchTeamMembersByStatus(String status) {
    try {
      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('status', status)
          .order('name', ascending: true)
          .map((data) => data
              .map((item) => fromMap(item as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch a specific team member for real-time updates
  Stream<TeamMember?> watchTeamMember(String id) {
    return watchById(id);
  }

  /// Get team member statistics
  Future<Map<String, dynamic>> getTeamStatistics() async {
    try {
      final allMembers = await getAllTeamMembers();

      final stats = <String, dynamic>{
        'total': allMembers.length,
        'active': allMembers.where((m) => m.status == 'active').length,
        'bench': allMembers.where((m) => m.status == 'bench').length,
        'inactive': allMembers.where((m) => m.status == 'inactive').length,
        'averageWorkload': allMembers.isNotEmpty
            ? allMembers.map((m) => m.workload).reduce((a, b) => a + b) /
                allMembers.length
            : 0.0,
        'roleDistribution': <String, int>{},
        'expertiseDistribution': <String, int>{},
      };

      // Calculate role distribution
      for (final member in allMembers) {
        final roleStats = stats['roleDistribution'] as Map<String, int>;
        roleStats[member.role] = (roleStats[member.role] ?? 0) + 1;
      }

      // Calculate expertise distribution
      for (final member in allMembers) {
        for (final expertise in member.expertise) {
          final expertiseStats =
              stats['expertiseDistribution'] as Map<String, int>;
          expertiseStats[expertise] = (expertiseStats[expertise] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Helper method to parse string lists from database
  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    if (value is String && value.isNotEmpty) {
      return value.split(',').where((s) => s.trim().isNotEmpty).toList();
    }
    return [];
  }

  /// Helper method to parse DateTime from database
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  /// Helper method to validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }
}
