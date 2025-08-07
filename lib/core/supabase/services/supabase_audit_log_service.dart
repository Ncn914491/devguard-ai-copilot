import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../database/models/audit_log.dart';
import '../supabase_error_handler.dart';
import 'supabase_base_service.dart';

/// Supabase implementation of audit log service
/// Replaces SQLite queries with supabase.from('audit_logs') operations
/// Requirements: 1.2, 1.4, 3.5 - Comprehensive audit logging with JSONB context data
class SupabaseAuditLogService extends SupabaseBaseService<AuditLog> {
  static final SupabaseAuditLogService _instance =
      SupabaseAuditLogService._internal();
  static SupabaseAuditLogService get instance => _instance;
  SupabaseAuditLogService._internal();

  @override
  String get tableName => 'audit_logs';

  @override
  AuditLog fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] ?? '',
      actionType: map['action_type'] ?? '',
      description: map['description'] ?? '',
      aiReasoning: map['ai_reasoning'],
      contextData: _parseJsonData(map['context_data']),
      userId: map['user_id'],
      timestamp: _parseDateTime(map['timestamp']),
      requiresApproval: map['requires_approval'] == true,
      approved: map['approved'] == true,
      approvedBy: map['approved_by'],
      approvedAt: map['approved_at'] != null
          ? _parseDateTime(map['approved_at'])
          : null,
    );
  }

  @override
  Map<String, dynamic> toMap(AuditLog item) {
    return {
      'id': item.id,
      'action_type': item.actionType,
      'description': item.description,
      'ai_reasoning': item.aiReasoning,
      'context_data': _encodeJsonData(item.contextData),
      'user_id': item.userId,
      'timestamp': item.timestamp.toIso8601String(),
      'requires_approval': item.requiresApproval,
      'approved': item.approved,
      'approved_by': item.approvedBy,
      'approved_at': item.approvedAt?.toIso8601String(),
    };
  }

  @override
  void validateData(Map<String, dynamic> data) {
    // Validate required fields
    if (data['action_type'] == null ||
        data['action_type'].toString().trim().isEmpty) {
      throw AppError.validation('Action type is required');
    }

    if (data['description'] == null ||
        data['description'].toString().trim().isEmpty) {
      throw AppError.validation('Description is required');
    }

    if (data['timestamp'] == null) {
      throw AppError.validation('Timestamp is required');
    }

    // Validate action type format
    final actionType = data['action_type'].toString();
    if (!RegExp(r'^[a-z_]+$').hasMatch(actionType)) {
      throw AppError.validation(
          'Action type must contain only lowercase letters and underscores');
    }

    // Validate boolean fields
    if (data['requires_approval'] != null &&
        data['requires_approval'] is! bool) {
      throw AppError.validation('Requires approval must be a boolean value');
    }

    if (data['approved'] != null && data['approved'] is! bool) {
      throw AppError.validation('Approved must be a boolean value');
    }

    // Validate approval logic
    if (data['approved'] == true && data['approved_by'] == null) {
      throw AppError.validation(
          'Approved by is required when approved is true');
    }

    if (data['approved'] == true && data['approved_at'] == null) {
      data['approved_at'] = DateTime.now().toIso8601String();
    }
  }

  /// Log an action with optional context data
  /// Satisfies Requirements: 3.5 (Comprehensive audit logging)
  Future<String> logAction({
    required String actionType,
    required String description,
    String? aiReasoning,
    Map<String, dynamic>? contextData,
    String? userId,
    bool requiresApproval = false,
    String? approvedBy,
  }) async {
    try {
      final auditLog = AuditLog(
        id: generateId(),
        actionType: actionType,
        description: description,
        aiReasoning: aiReasoning,
        contextData: contextData != null ? jsonEncode(contextData) : null,
        userId: userId,
        timestamp: DateTime.now(),
        requiresApproval: requiresApproval,
        approved: !requiresApproval || approvedBy != null,
        approvedBy: approvedBy,
        approvedAt:
            (!requiresApproval || approvedBy != null) ? DateTime.now() : null,
      );

      return await create(auditLog);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get audit log by ID
  /// Satisfies Requirements: 3.5 (Audit log retrieval)
  Future<AuditLog?> getAuditLog(String id) async {
    return await getById(id);
  }

  /// Get all audit logs
  /// Satisfies Requirements: 3.5 (Audit trail querying)
  Future<List<AuditLog>> getAllAuditLogs() async {
    return await getAll(orderBy: 'timestamp', ascending: false);
  }

  /// Get audit logs by action type
  /// Satisfies Requirements: 3.5 (Filtering capabilities)
  Future<List<AuditLog>> getAuditLogsByActionType(String actionType) async {
    try {
      return await getWhere(
        column: 'action_type',
        value: actionType,
        orderBy: 'timestamp',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get audit logs by user
  Future<List<AuditLog>> getAuditLogsByUser(String userId) async {
    try {
      return await getWhere(
        column: 'user_id',
        value: userId,
        orderBy: 'timestamp',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get audit logs requiring approval
  Future<List<AuditLog>> getAuditLogsRequiringApproval() async {
    try {
      return await getWhere(
        column: 'requires_approval',
        value: true,
        orderBy: 'timestamp',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get pending approval audit logs
  Future<List<AuditLog>> getPendingApprovalAuditLogs() async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .eq('requires_approval', true)
            .eq('approved', false)
            .order('timestamp', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get approved audit logs
  Future<List<AuditLog>> getApprovedAuditLogs() async {
    try {
      return await getWhere(
        column: 'approved',
        value: true,
        orderBy: 'timestamp',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get audit logs in date range
  /// Satisfies Requirements: 3.5 (Date-based filtering)
  Future<List<AuditLog>> getAuditLogsInDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .gte('timestamp', startDate.toIso8601String())
            .lte('timestamp', endDate.toIso8601String())
            .order('timestamp', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get recent audit logs (last N days)
  Future<List<AuditLog>> getRecentAuditLogs({int days = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      return await getAuditLogsInDateRange(cutoffDate, DateTime.now());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update audit log
  /// Satisfies Requirements: 3.5 (Audit log management)
  Future<void> updateAuditLog(AuditLog auditLog) async {
    try {
      // Check if audit log exists
      final existing = await getById(auditLog.id);
      if (existing == null) {
        throw AppError.notFound('Audit log not found');
      }

      await update(auditLog.id, auditLog);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Approve an audit log entry
  /// Satisfies Requirements: 3.5 (Approval workflow)
  Future<void> approveAuditLog(String auditLogId, String approvedBy) async {
    try {
      final auditLog = await getAuditLog(auditLogId);
      if (auditLog == null) {
        throw AppError.notFound('Audit log not found');
      }

      if (!auditLog.requiresApproval) {
        throw AppError.validation('This audit log does not require approval');
      }

      if (auditLog.approved) {
        throw AppError.validation('This audit log is already approved');
      }

      final updatedAuditLog = auditLog.copyWith(
        approved: true,
        approvedBy: approvedBy,
        approvedAt: DateTime.now(),
      );

      await updateAuditLog(updatedAuditLog);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Reject an audit log entry (for approval workflow)
  Future<void> rejectAuditLog(
      String auditLogId, String rejectedBy, String reason) async {
    try {
      final auditLog = await getAuditLog(auditLogId);
      if (auditLog == null) {
        throw AppError.notFound('Audit log not found');
      }

      if (!auditLog.requiresApproval) {
        throw AppError.validation('This audit log does not require approval');
      }

      if (auditLog.approved) {
        throw AppError.validation('This audit log is already approved');
      }

      // Add rejection information to context data
      Map<String, dynamic> contextData = {};
      if (auditLog.contextData != null && auditLog.contextData!.isNotEmpty) {
        try {
          contextData =
              jsonDecode(auditLog.contextData!) as Map<String, dynamic>;
        } catch (e) {
          contextData = {};
        }
      }

      contextData['rejection'] = {
        'rejected_by': rejectedBy,
        'rejected_at': DateTime.now().toIso8601String(),
        'reason': reason,
      };

      final updatedAuditLog = auditLog.copyWith(
        contextData: jsonEncode(contextData),
        // Keep approved as false to indicate rejection
      );

      await updateAuditLog(updatedAuditLog);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Delete audit log (admin only)
  /// Satisfies Requirements: 3.5 (Audit log management)
  Future<void> deleteAuditLog(String id) async {
    try {
      // Check if audit log exists
      final existing = await getById(id);
      if (existing == null) {
        throw AppError.notFound('Audit log not found');
      }

      await delete(id);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Search audit logs by description or action type
  /// Satisfies Requirements: 3.5 (Search capabilities)
  Future<List<AuditLog>> searchAuditLogs(String searchTerm) async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .or('description.ilike.%$searchTerm%,action_type.ilike.%$searchTerm%,ai_reasoning.ilike.%$searchTerm%')
            .order('timestamp', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get audit logs with AI reasoning
  Future<List<AuditLog>> getAuditLogsWithAIReasoning() async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .not('ai_reasoning', 'is', null)
            .order('timestamp', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get audit log statistics
  /// Satisfies Requirements: 3.5 (Analytics and reporting)
  Future<Map<String, dynamic>> getAuditLogStatistics() async {
    try {
      final allLogs = await getAllAuditLogs();

      final stats = <String, dynamic>{
        'total': allLogs.length,
        'requiring_approval': allLogs.where((l) => l.requiresApproval).length,
        'approved': allLogs.where((l) => l.approved).length,
        'pending_approval':
            allLogs.where((l) => l.requiresApproval && !l.approved).length,
        'with_ai_reasoning': allLogs
            .where((l) => l.aiReasoning != null && l.aiReasoning!.isNotEmpty)
            .length,
        'actionTypeDistribution': <String, int>{},
        'userActivityDistribution': <String, int>{},
        'dailyActivity': <String, int>{},
      };

      // Calculate action type distribution
      for (final log in allLogs) {
        final actionStats = stats['actionTypeDistribution'] as Map<String, int>;
        actionStats[log.actionType] = (actionStats[log.actionType] ?? 0) + 1;
      }

      // Calculate user activity distribution
      for (final log in allLogs) {
        if (log.userId != null) {
          final userStats =
              stats['userActivityDistribution'] as Map<String, int>;
          userStats[log.userId!] = (userStats[log.userId!] ?? 0) + 1;
        }
      }

      // Calculate daily activity for last 30 days
      final now = DateTime.now();
      for (int i = 0; i < 30; i++) {
        final date = now.subtract(Duration(days: i));
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final dayLogs = allLogs
            .where((l) =>
                l.timestamp.year == date.year &&
                l.timestamp.month == date.month &&
                l.timestamp.day == date.day)
            .length;

        final dailyStats = stats['dailyActivity'] as Map<String, int>;
        dailyStats[dateKey] = dayLogs;
      }

      return stats;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch all audit logs for real-time updates
  /// Satisfies Requirements: 3.5 (Real-time audit monitoring)
  Stream<List<AuditLog>> watchAllAuditLogs() {
    return watchAll(orderBy: 'timestamp', ascending: false);
  }

  /// Watch pending approval audit logs for real-time updates
  Stream<List<AuditLog>> watchPendingApprovalAuditLogs() {
    try {
      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('requires_approval', true)
          .eq('approved', false)
          .order('timestamp', ascending: false)
          .map((data) => data
              .map((item) => fromMap(item as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch audit logs by user for real-time updates
  Stream<List<AuditLog>> watchAuditLogsByUser(String userId) {
    try {
      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('timestamp', ascending: false)
          .map((data) => data
              .map((item) => fromMap(item as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch a specific audit log for real-time updates
  Stream<AuditLog?> watchAuditLog(String id) {
    return watchById(id);
  }

  /// Export audit logs to JSON format
  Future<String> exportAuditLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? actionType,
    String? userId,
  }) async {
    try {
      List<AuditLog> logs;

      if (startDate != null && endDate != null) {
        logs = await getAuditLogsInDateRange(startDate, endDate);
      } else {
        logs = await getAllAuditLogs();
      }

      // Apply additional filters
      if (actionType != null) {
        logs = logs.where((l) => l.actionType == actionType).toList();
      }

      if (userId != null) {
        logs = logs.where((l) => l.userId == userId).toList();
      }

      // Convert to exportable format
      final exportData = {
        'export_timestamp': DateTime.now().toIso8601String(),
        'total_records': logs.length,
        'filters': {
          'start_date': startDate?.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
          'action_type': actionType,
          'user_id': userId,
        },
        'audit_logs': logs
            .map((log) => {
                  'id': log.id,
                  'action_type': log.actionType,
                  'description': log.description,
                  'ai_reasoning': log.aiReasoning,
                  'context_data': log.contextData,
                  'user_id': log.userId,
                  'timestamp': log.timestamp.toIso8601String(),
                  'requires_approval': log.requiresApproval,
                  'approved': log.approved,
                  'approved_by': log.approvedBy,
                  'approved_at': log.approvedAt?.toIso8601String(),
                })
            .toList(),
      };

      return jsonEncode(exportData);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Helper method to parse JSONB data from database
  String? _parseJsonData(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  /// Helper method to encode JSONB data for database
  dynamic _encodeJsonData(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return jsonDecode(value);
    } catch (e) {
      return value; // Return as string if not valid JSON
    }
  }

  /// Helper method to parse DateTime from database
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
