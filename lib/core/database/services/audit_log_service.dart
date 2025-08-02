import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../database_service.dart';
import '../models/audit_log.dart';

class AuditLogService {
  static final AuditLogService _instance = AuditLogService._internal();
  static AuditLogService get instance => _instance;
  AuditLogService._internal();

  final _uuid = const Uuid();

  Future<Database> get _db async => await DatabaseService.instance.database;

  /// Log an action for audit trail
  /// Satisfies Requirements: 9.1, 9.2 (Complete audit logging with context and reasoning)
  Future<String> logAction({
    required String actionType,
    required String description,
    String? aiReasoning,
    Map<String, dynamic>? contextData,
    String? userId,
    bool requiresApproval = false,
    String? approvedBy,
  }) async {
    final db = await _db;
    final id = _uuid.v4();
    
    final auditLog = AuditLog(
      id: id,
      actionType: actionType,
      description: description,
      aiReasoning: aiReasoning,
      contextData: contextData != null ? _encodeContextData(contextData) : null,
      userId: userId,
      timestamp: DateTime.now(),
      requiresApproval: requiresApproval,
      approved: approvedBy != null,
      approvedBy: approvedBy,
      approvedAt: approvedBy != null ? DateTime.now() : null,
    );

    await db.insert('audit_logs', auditLog.toMap());
    return id;
  }

  /// Get audit log by ID
  /// Satisfies Requirements: 9.5 (Comprehensive audit trail access)
  Future<AuditLog?> getAuditLog(String id) async {
    final db = await _db;
    final maps = await db.query(
      'audit_logs',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return AuditLog.fromMap(maps.first);
    }
    return null;
  }

  /// Get all audit logs
  /// Satisfies Requirements: 9.5 (Complete audit trail visibility)
  Future<List<AuditLog>> getAllAuditLogs() async {
    final db = await _db;
    final maps = await db.query('audit_logs', orderBy: 'timestamp DESC');
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }

  /// Get audit logs by action type
  /// Satisfies Requirements: 9.1 (AI action tracking by category)
  Future<List<AuditLog>> getAuditLogsByActionType(String actionType) async {
    final db = await _db;
    final maps = await db.query(
      'audit_logs',
      where: 'action_type = ?',
      whereArgs: [actionType],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }

  /// Get audit logs by user
  /// Satisfies Requirements: 9.4 (Human approval tracking)
  Future<List<AuditLog>> getAuditLogsByUser(String userId) async {
    final db = await _db;
    final maps = await db.query(
      'audit_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }

  /// Get audit logs within date range
  /// Satisfies Requirements: 9.5 (Audit trail filtering and search)
  Future<List<AuditLog>> getAuditLogsByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await _db;
    final maps = await db.query(
      'audit_logs',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startDate.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }

  /// Get logs requiring approval
  /// Satisfies Requirements: 9.4 (Human approval requirement tracking)
  Future<List<AuditLog>> getLogsRequiringApproval() async {
    final db = await _db;
    final maps = await db.query(
      'audit_logs',
      where: 'requires_approval = ? AND approved = ?',
      whereArgs: [1, 0],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }

  /// Get approved logs
  /// Satisfies Requirements: 9.4 (Human approval tracking and recording)
  Future<List<AuditLog>> getApprovedLogs() async {
    final db = await _db;
    final maps = await db.query(
      'audit_logs',
      where: 'approved = ?',
      whereArgs: [1],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }

  /// Approve a pending action
  /// Satisfies Requirements: 9.4 (Human approval recording)
  Future<void> approveAction(String auditLogId, String approvedBy) async {
    final db = await _db;
    final auditLog = await getAuditLog(auditLogId);
    if (auditLog == null) return;

    final approvedLog = auditLog.copyWith(
      approved: true,
      approvedBy: approvedBy,
      approvedAt: DateTime.now(),
    );

    await db.update(
      'audit_logs',
      approvedLog.toMap(),
      where: 'id = ?',
      whereArgs: [auditLogId],
    );

    // Log the approval action itself
    await logAction(
      actionType: 'action_approved',
      description: 'Approved action: ${auditLog.description}',
      contextData: {'original_audit_log_id': auditLogId},
      userId: approvedBy,
    );
  }

  /// Get AI-driven actions
  /// Satisfies Requirements: 9.1 (AI action tracking with reasoning)
  Future<List<AuditLog>> getAIActions() async {
    final db = await _db;
    final maps = await db.query(
      'audit_logs',
      where: 'ai_reasoning IS NOT NULL',
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }

  /// Get critical actions
  /// Satisfies Requirements: 9.4 (Critical action tracking)
  Future<List<AuditLog>> getCriticalActions() async {
    final db = await _db;
    final criticalActionTypes = [
      'security_alert_created',
      'deployment_failed',
      'rollback_initiated',
      'honeytoken_accessed',
      'system_anomaly_detected',
    ];
    
    final whereClause = criticalActionTypes.map((_) => 'action_type = ?').join(' OR ');
    final maps = await db.query(
      'audit_logs',
      where: whereClause,
      whereArgs: criticalActionTypes,
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }

  /// Search audit logs
  /// Satisfies Requirements: 9.5 (Comprehensive audit trail search)
  Future<List<AuditLog>> searchAuditLogs(String searchTerm) async {
    final db = await _db;
    final maps = await db.query(
      'audit_logs',
      where: 'description LIKE ? OR action_type LIKE ? OR ai_reasoning LIKE ?',
      whereArgs: ['%$searchTerm%', '%$searchTerm%', '%$searchTerm%'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }

  /// Delete old audit logs (for maintenance)
  /// Satisfies Requirements: 9.1 (Audit log management)
  Future<int> deleteOldAuditLogs(DateTime cutoffDate) async {
    final db = await _db;
    return await db.delete(
      'audit_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );
  }

  /// Get audit statistics
  /// Satisfies Requirements: 9.5 (Audit trail analysis)
  Future<Map<String, int>> getAuditStatistics() async {
    final db = await _db;
    
    final totalLogs = await db.rawQuery('SELECT COUNT(*) as count FROM audit_logs');
    final aiActions = await db.rawQuery('SELECT COUNT(*) as count FROM audit_logs WHERE ai_reasoning IS NOT NULL');
    final pendingApprovals = await db.rawQuery('SELECT COUNT(*) as count FROM audit_logs WHERE requires_approval = 1 AND approved = 0');
    final approvedActions = await db.rawQuery('SELECT COUNT(*) as count FROM audit_logs WHERE approved = 1');
    
    return {
      'total_logs': totalLogs.first['count'] as int,
      'ai_actions': aiActions.first['count'] as int,
      'pending_approvals': pendingApprovals.first['count'] as int,
      'approved_actions': approvedActions.first['count'] as int,
    };
  }

  /// Initialize project-specific auditing
  Future<void> initializeProjectAuditing(String projectId) async {
    await logAction(
      actionType: 'project_auditing_initialized',
      description: 'Project-specific auditing initialized',
      contextData: {'project_id': projectId},
    );
  }

  /// Helper method to encode context data as JSON string
  String _encodeContextData(Map<String, dynamic> contextData) {
    try {
      // Simple JSON-like encoding for SQLite storage
      final entries = contextData.entries.map((e) => '"${e.key}":"${e.value}"').join(',');
      return '{$entries}';
    } catch (e) {
      return contextData.toString();
    }
  }
}