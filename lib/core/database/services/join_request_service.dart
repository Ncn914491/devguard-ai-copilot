import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../database_service.dart';
import '../../models/join_request.dart';
import 'audit_log_service.dart';

/// Database service for managing join requests
class JoinRequestService {
  static final JoinRequestService _instance = JoinRequestService._internal();
  static JoinRequestService get instance => _instance;
  JoinRequestService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;

  Future<Database> get _db async => await DatabaseService.instance.database;

  /// Create a new join request
  /// Satisfies Requirements: 2.1 (Join request submission with validation and storage)
  Future<String> createJoinRequest(JoinRequest request) async {
    final db = await _db;
    final id = request.id.isEmpty ? _uuid.v4() : request.id;

    final requestWithId = request.copyWith(
      id: id,
      createdAt: DateTime.now(),
    );

    await db.insert('join_requests', _joinRequestToMap(requestWithId));

    // Log the action for transparency
    await _auditService.logAction(
      actionType: 'join_request_created',
      description:
          'New join request submitted: ${request.name} (${request.email})',
      aiReasoning: 'User submitted request to join project with specified role',
      contextData: {
        'request_id': id,
        'name': request.name,
        'email': request.email,
        'requested_role': request.requestedRole,
        'has_message': request.message != null,
      },
    );

    return id;
  }

  /// Get join request by ID
  /// Satisfies Requirements: 2.2 (Admin dashboard section for reviewing pending join requests)
  Future<JoinRequest?> getJoinRequest(String id) async {
    final db = await _db;
    final maps = await db.query(
      'join_requests',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _joinRequestFromMap(maps.first);
    }
    return null;
  }

  /// Get join request by email
  /// Satisfies Requirements: 2.1 (Validation to prevent duplicate requests)
  Future<JoinRequest?> getJoinRequestByEmail(String email) async {
    final db = await _db;
    final maps = await db.query(
      'join_requests',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return _joinRequestFromMap(maps.first);
    }
    return null;
  }

  /// Get all join requests with optional status filter
  /// Satisfies Requirements: 2.2 (Admin dashboard section for reviewing requests)
  Future<List<JoinRequest>> getJoinRequests({JoinRequestStatus? status}) async {
    final db = await _db;

    String? whereClause;
    List<dynamic>? whereArgs;

    if (status != null) {
      whereClause = 'status = ?';
      whereArgs = [status.toString().split('.').last];
    }

    final maps = await db.query(
      'join_requests',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => _joinRequestFromMap(map)).toList();
  }

  /// Get pending join requests
  /// Satisfies Requirements: 2.2 (Admin dashboard for reviewing pending requests)
  Future<List<JoinRequest>> getPendingRequests() async {
    return await getJoinRequests(status: JoinRequestStatus.pending);
  }

  /// Update join request
  /// Satisfies Requirements: 2.3 (Approval/rejection workflow)
  Future<void> updateJoinRequest(JoinRequest request) async {
    final db = await _db;

    await db.update(
      'join_requests',
      _joinRequestToMap(request),
      where: 'id = ?',
      whereArgs: [request.id],
    );

    // Log the action for transparency
    await _auditService.logAction(
      actionType: 'join_request_updated',
      description: 'Join request updated: ${request.name} - ${request.status}',
      aiReasoning:
          'Admin processed join request with approval/rejection decision',
      contextData: {
        'request_id': request.id,
        'status': request.status.toString().split('.').last,
        'reviewed_by': request.reviewedBy,
        'has_admin_notes': request.adminNotes != null,
        'has_rejection_reason': request.rejectionReason != null,
      },
    );
  }

  /// Approve join request
  /// Satisfies Requirements: 2.3 (Approval workflow with admin notes)
  Future<void> approveJoinRequest(
    String requestId,
    String reviewedBy, {
    String? adminNotes,
  }) async {
    final request = await getJoinRequest(requestId);
    if (request == null) {
      throw Exception('Join request not found');
    }

    if (request.status != JoinRequestStatus.pending) {
      throw Exception('Request has already been processed');
    }

    final updatedRequest = request.copyWith(
      status: JoinRequestStatus.approved,
      reviewedAt: DateTime.now(),
      reviewedBy: reviewedBy,
      adminNotes: adminNotes,
    );

    await updateJoinRequest(updatedRequest);
  }

  /// Reject join request
  /// Satisfies Requirements: 2.3 (Rejection workflow with reason)
  Future<void> rejectJoinRequest(
    String requestId,
    String reviewedBy,
    String rejectionReason,
  ) async {
    final request = await getJoinRequest(requestId);
    if (request == null) {
      throw Exception('Join request not found');
    }

    if (request.status != JoinRequestStatus.pending) {
      throw Exception('Request has already been processed');
    }

    final updatedRequest = request.copyWith(
      status: JoinRequestStatus.rejected,
      reviewedAt: DateTime.now(),
      reviewedBy: reviewedBy,
      rejectionReason: rejectionReason,
    );

    await updateJoinRequest(updatedRequest);
  }

  /// Delete join request
  /// Satisfies Requirements: Data cleanup and audit logging
  Future<void> deleteJoinRequest(String id) async {
    final db = await _db;
    final request = await getJoinRequest(id);

    await db.delete(
      'join_requests',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Log the action for transparency
    await _auditService.logAction(
      actionType: 'join_request_deleted',
      description: 'Join request deleted: ${request?.name ?? id}',
      contextData: {'request_id': id},
    );
  }

  /// Get join request statistics
  /// Satisfies Requirements: Admin dashboard analytics
  Future<Map<String, int>> getJoinRequestStats() async {
    final db = await _db;

    final totalResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM join_requests');
    final pendingResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM join_requests WHERE status = ?',
        ['pending']);
    final approvedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM join_requests WHERE status = ?',
        ['approved']);
    final rejectedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM join_requests WHERE status = ?',
        ['rejected']);

    return {
      'total': totalResult.first['count'] as int,
      'pending': pendingResult.first['count'] as int,
      'approved': approvedResult.first['count'] as int,
      'rejected': rejectedResult.first['count'] as int,
    };
  }

  /// Convert JoinRequest to database map
  Map<String, dynamic> _joinRequestToMap(JoinRequest request) {
    return {
      'id': request.id,
      'name': request.name,
      'email': request.email,
      'requested_role': request.requestedRole,
      'message': request.message,
      'status': request.status.toString().split('.').last,
      'created_at': request.createdAt.millisecondsSinceEpoch,
      'reviewed_at': request.reviewedAt?.millisecondsSinceEpoch,
      'reviewed_by': request.reviewedBy,
      'admin_notes': request.adminNotes,
      'rejection_reason': request.rejectionReason,
    };
  }

  /// Convert database map to JoinRequest
  JoinRequest _joinRequestFromMap(Map<String, dynamic> map) {
    return JoinRequest(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      requestedRole: map['requested_role'],
      message: map['message'],
      status: JoinRequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['reviewed_at'])
          : null,
      reviewedBy: map['reviewed_by'],
      adminNotes: map['admin_notes'],
      rejectionReason: map['rejection_reason'],
    );
  }
}
