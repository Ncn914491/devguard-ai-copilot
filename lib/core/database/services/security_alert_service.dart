import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../database_service.dart';
import '../models/security_alert.dart';
import 'audit_log_service.dart';

class SecurityAlertService {
  static final SecurityAlertService _instance = SecurityAlertService._internal();
  static SecurityAlertService get instance => _instance;
  SecurityAlertService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;

  Future<Database> get _db async => await DatabaseService.instance.database;

  /// Create a new security alert
  /// Satisfies Requirements: 3.2, 3.5, 4.5 (Database breach detection, anomaly alerts)
  Future<String> createSecurityAlert(SecurityAlert alert) async {
    final db = await _db;
    final id = alert.id.isEmpty ? _uuid.v4() : alert.id;
    
    final alertWithId = alert.copyWith(
      id: id,
      detectedAt: DateTime.now(),
    );

    await db.insert('security_alerts', alertWithId.toMap());
    
    // Log the action for transparency (Requirement 9.1, 9.3)
    await _auditService.logAction(
      actionType: 'security_alert_created',
      description: 'Security alert created: ${alert.title} (${alert.severity})',
      aiReasoning: alert.aiExplanation,
      contextData: {
        'alert_id': id, 
        'type': alert.type, 
        'severity': alert.severity,
        'rollback_suggested': alert.rollbackSuggested,
      },
    );

    return id;
  }

  /// Get security alert by ID
  /// Satisfies Requirements: 3.5, 9.3 (Alert details with explanations)
  Future<SecurityAlert?> getSecurityAlert(String id) async {
    final db = await _db;
    final maps = await db.query(
      'security_alerts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return SecurityAlert.fromMap(maps.first);
    }
    return null;
  }

  /// Get all security alerts
  /// Satisfies Requirements: 3.5, 4.5 (Security dashboard with all alerts)
  Future<List<SecurityAlert>> getAllSecurityAlerts() async {
    final db = await _db;
    final maps = await db.query('security_alerts', orderBy: 'detected_at DESC');
    return maps.map((map) => SecurityAlert.fromMap(map)).toList();
  }

  /// Get alerts by severity
  /// Satisfies Requirements: 3.5 (AI-generated explanations with severity ratings)
  Future<List<SecurityAlert>> getAlertsBySeverity(String severity) async {
    final db = await _db;
    final maps = await db.query(
      'security_alerts',
      where: 'severity = ?',
      whereArgs: [severity],
      orderBy: 'detected_at DESC',
    );
    return maps.map((map) => SecurityAlert.fromMap(map)).toList();
  }

  /// Get alerts by type
  /// Satisfies Requirements: 3.1, 3.2, 3.3, 3.4 (Different alert types)
  Future<List<SecurityAlert>> getAlertsByType(String type) async {
    final db = await _db;
    final maps = await db.query(
      'security_alerts',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'detected_at DESC',
    );
    return maps.map((map) => SecurityAlert.fromMap(map)).toList();
  }

  /// Get alerts by status
  /// Satisfies Requirements: 3.5, 4.5 (Alert resolution tracking)
  Future<List<SecurityAlert>> getAlertsByStatus(String status) async {
    final db = await _db;
    final maps = await db.query(
      'security_alerts',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'detected_at DESC',
    );
    return maps.map((map) => SecurityAlert.fromMap(map)).toList();
  }

  /// Update security alert
  /// Satisfies Requirements: 9.1 (Audit logging for all changes)
  Future<void> updateSecurityAlert(SecurityAlert alert) async {
    final db = await _db;
    
    await db.update(
      'security_alerts',
      alert.toMap(),
      where: 'id = ?',
      whereArgs: [alert.id],
    );

    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'security_alert_updated',
      description: 'Updated security alert: ${alert.title} - Status: ${alert.status}',
      contextData: {
        'alert_id': alert.id, 
        'status': alert.status,
        'assigned_to': alert.assignedTo,
      },
    );
  }

  /// Resolve security alert
  /// Satisfies Requirements: 3.5, 4.5 (Alert resolution with human oversight)
  Future<void> resolveAlert(String alertId, String resolution, {String? resolvedBy}) async {
    final alert = await getSecurityAlert(alertId);
    if (alert == null) return;

    final resolvedAlert = alert.copyWith(
      status: resolution, // 'resolved' or 'false_positive'
      resolvedAt: DateTime.now(),
    );

    await updateSecurityAlert(resolvedAlert);

    // Log resolution with human approval tracking (Requirement 9.4)
    await _auditService.logAction(
      actionType: 'security_alert_resolved',
      description: 'Resolved security alert: ${alert.title} as $resolution',
      contextData: {
        'alert_id': alertId, 
        'resolution': resolution,
        'resolved_by': resolvedBy,
      },
      requiresApproval: true,
      approvedBy: resolvedBy,
    );
  }

  /// Assign alert to team member
  /// Satisfies Requirements: 3.5, 4.5 (Alert assignment for investigation)
  Future<void> assignAlert(String alertId, String assigneeId, {String? assignedBy}) async {
    final alert = await getSecurityAlert(alertId);
    if (alert == null) return;

    final assignedAlert = alert.copyWith(
      assignedTo: assigneeId,
      status: 'investigating',
    );

    await updateSecurityAlert(assignedAlert);

    // Log assignment (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'security_alert_assigned',
      description: 'Assigned security alert: ${alert.title} to $assigneeId',
      contextData: {
        'alert_id': alertId, 
        'assigned_to': assigneeId,
        'assigned_by': assignedBy,
      },
      userId: assignedBy,
    );
  }

  /// Get critical unresolved alerts
  /// Satisfies Requirements: 3.5, 4.5 (Critical alert prioritization)
  Future<List<SecurityAlert>> getCriticalUnresolvedAlerts() async {
    final db = await _db;
    final maps = await db.query(
      'security_alerts',
      where: 'severity = ? AND status NOT IN (?, ?)',
      whereArgs: ['critical', 'resolved', 'false_positive'],
      orderBy: 'detected_at DESC',
    );
    return maps.map((map) => SecurityAlert.fromMap(map)).toList();
  }

  /// Get alerts suggesting rollback
  /// Satisfies Requirements: 7.2 (Security anomaly rollback suggestions)
  Future<List<SecurityAlert>> getAlertsWithRollbackSuggestion() async {
    final db = await _db;
    final maps = await db.query(
      'security_alerts',
      where: 'rollback_suggested = ? AND status NOT IN (?, ?)',
      whereArgs: [1, 'resolved', 'false_positive'],
      orderBy: 'detected_at DESC',
    );
    return maps.map((map) => SecurityAlert.fromMap(map)).toList();
  }

  /// Delete security alert
  /// Satisfies Requirements: 9.1 (Audit logging for all actions)
  Future<void> deleteSecurityAlert(String id) async {
    final db = await _db;
    final alert = await getSecurityAlert(id);
    
    await db.delete(
      'security_alerts',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Log the action for transparency (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'security_alert_deleted',
      description: 'Deleted security alert: ${alert?.title ?? id}',
      contextData: {'alert_id': id},
    );
  }

  /// Create honeytoken access alert
  /// Satisfies Requirements: 3.1, 3.2 (Honeytoken breach detection)
  Future<String> createHoneytokenAlert(String tokenType, String tokenValue, String accessDetails) async {
    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'database_breach',
      severity: 'critical',
      title: 'Honeytoken Access Detected',
      description: 'Unauthorized access to honeytoken detected: $tokenType',
      aiExplanation: 'A honeytoken ($tokenType) has been accessed, indicating potential database breach. '
          'Honeytokens are fake sensitive data records designed to detect unauthorized access. '
          'This access suggests that an attacker may have gained access to the database and is attempting to extract sensitive information.',
      triggerData: accessDetails,
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: true,
    );

    return await createSecurityAlert(alert);
  }

  /// Get recent security alerts
  /// Satisfies Requirements: 3.1 (Security alert retrieval)
  Future<List<SecurityAlert>> getRecentAlerts({int limit = 10}) async {
    final db = await _db;
    final maps = await db.query(
      'security_alerts',
      orderBy: 'detected_at DESC',
      limit: limit,
    );
    return maps.map((map) => SecurityAlert.fromMap(map)).toList();
  }
}