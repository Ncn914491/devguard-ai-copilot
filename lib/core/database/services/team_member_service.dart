import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../database_service.dart';
import '../models/team_member.dart';
import 'audit_log_service.dart';

class TeamMemberService {
  static final TeamMemberService _instance = TeamMemberService._internal();
  static TeamMemberService get instance => _instance;
  TeamMemberService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;

  Future<Database> get _db async => await DatabaseService.instance.database;

  /// Create a new team member
  /// Satisfies Requirements: 5.1, 5.2 (Team management and assignment tracking)
  Future<String> createTeamMember(TeamMember member) async {
    final db = await _db;
    final id = member.id.isEmpty ? _uuid.v4() : member.id;
    
    final memberWithId = member.copyWith(
      id: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await db.insert('team_members', memberWithId.toMap());
    
    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'team_member_created',
      description: 'Created team member: ${member.name} (${member.role})',
      contextData: {'team_member_id': id, 'role': member.role},
    );

    return id;
  }

  /// Get team member by ID
  /// Satisfies Requirements: 5.1 (Team dashboard display)
  Future<TeamMember?> getTeamMember(String id) async {
    final db = await _db;
    final maps = await db.query(
      'team_members',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return TeamMember.fromMap(maps.first);
    }
    return null;
  }

  /// Get all team members
  /// Satisfies Requirements: 5.1 (Team dashboard with all members, roles, and status)
  Future<List<TeamMember>> getAllTeamMembers() async {
    final db = await _db;
    final maps = await db.query('team_members', orderBy: 'name ASC');
    return maps.map((map) => TeamMember.fromMap(map)).toList();
  }

  /// Get team members by status
  /// Satisfies Requirements: 5.5 (Bench status indication)
  Future<List<TeamMember>> getTeamMembersByStatus(String status) async {
    final db = await _db;
    final maps = await db.query(
      'team_members',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'name ASC',
    );
    return maps.map((map) => TeamMember.fromMap(map)).toList();
  }

  /// Update team member
  /// Satisfies Requirements: 5.2, 5.3 (Assignment updates with approval tracking)
  Future<void> updateTeamMember(TeamMember member) async {
    final db = await _db;
    final updatedMember = member.copyWith(updatedAt: DateTime.now());
    
    await db.update(
      'team_members',
      updatedMember.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );

    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'team_member_updated',
      description: 'Updated team member: ${member.name}',
      contextData: {'team_member_id': member.id, 'status': member.status},
    );
  }

  /// Update team member assignments
  /// Satisfies Requirements: 5.2, 5.3 (AI-suggested assignments with human approval)
  Future<void> updateAssignments(String memberId, List<String> assignments, {String? approvedBy}) async {
    final member = await getTeamMember(memberId);
    if (member == null) return;

    final updatedMember = member.copyWith(
      assignments: assignments,
      updatedAt: DateTime.now(),
    );

    await updateTeamMember(updatedMember);

    // Log assignment change with approval tracking (Requirement 9.4)
    await _auditService.logAction(
      actionType: 'assignments_updated',
      description: 'Updated assignments for ${member.name}: ${assignments.join(", ")}',
      contextData: {'team_member_id': memberId, 'assignments': assignments},
      requiresApproval: true,
      approvedBy: approvedBy,
    );
  }

  /// Delete team member
  /// Satisfies Requirements: 9.1 (Audit logging for all actions)
  Future<void> deleteTeamMember(String id) async {
    final db = await _db;
    final member = await getTeamMember(id);
    
    await db.delete(
      'team_members',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'team_member_deleted',
      description: 'Deleted team member: ${member?.name ?? id}',
      contextData: {'team_member_id': id},
    );
  }

  /// Get available team members (not on bench)
  /// Satisfies Requirements: 5.2 (AI-suggested assignments based on workload)
  Future<List<TeamMember>> getAvailableMembers() async {
    final db = await _db;
    final maps = await db.query(
      'team_members',
      where: 'status != ?',
      whereArgs: ['bench'],
      orderBy: 'workload ASC, name ASC',
    );
    return maps.map((map) => TeamMember.fromMap(map)).toList();
  }

  /// Get team members by expertise
  /// Satisfies Requirements: 5.2 (AI-suggested assignments based on expertise)
  Future<List<TeamMember>> getTeamMembersByExpertise(String expertise) async {
    final db = await _db;
    final maps = await db.query(
      'team_members',
      where: 'expertise LIKE ?',
      whereArgs: ['%$expertise%'],
      orderBy: 'workload ASC, name ASC',
    );
    return maps.map((map) => TeamMember.fromMap(map)).toList();
  }
}