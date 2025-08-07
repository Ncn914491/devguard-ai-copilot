import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../database/models/security_alert.dart';
import '../supabase_error_handler.dart';
import 'supabase_base_service.dart';

/// Supabase implementation of security alert service
/// Replaces SQLite queries with supabase.from('security_alerts') operations
/// Requirements: 1.2, 1.4, 3.4 - Security alert management with JSONB data handling
class SupabaseSecurityAlertService extends SupabaseBaseService<SecurityAlert> {
  static final SupabaseSecurityAlertService _instance =
      SupabaseSecurityAlertService._internal();
  static SupabaseSecurityAlertService get instance => _instance;
  SupabaseSecurityAlertService._internal();

  @override
  String get tableName => 'security_alerts';

  @override
  SecurityAlert fromMap(Map<String, dynamic> map) {
    return SecurityAlert(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      severity: map['severity'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      aiExplanation: map['ai_explanation'] ?? '',
      triggerData: _parseJsonData(map['trigger_data']),
      status: map['status'] ?? 'new',
      assignedTo: map['assigned_to'],
      detectedAt: _parseDateTime(map['detected_at']),
      resolvedAt: map['resolved_at'] != null
          ? _parseDateTime(map['resolved_at'])
          : null,
      rollbackSuggested: map['rollback_suggested'] == true,
      evidence: _parseJsonData(map['evidence']),
    );
  }

  @override
  Map<String, dynamic> toMap(SecurityAlert item) {
    return {
      'id': item.id,
      'type': item.type,
      'severity': item.severity,
      'title': item.title,
      'description': item.description,
      'ai_explanation': item.aiExplanation,
      'trigger_data': _encodeJsonData(item.triggerData),
      'status': item.status,
      'assigned_to': item.assignedTo,
      'detected_at': item.detectedAt.toIso8601String(),
      'resolved_at': item.resolvedAt?.toIso8601String(),
      'rollback_suggested': item.rollbackSuggested,
      'evidence': _encodeJsonData(item.evidence),
    };
  }

  @override
  void validateData(Map<String, dynamic> data) {
    // Validate required fields
    if (data['type'] == null || data['type'].toString().trim().isEmpty) {
      throw AppError.validation('Security alert type is required');
    }

    if (data['severity'] == null ||
        data['severity'].toString().trim().isEmpty) {
      throw AppError.validation('Security alert severity is required');
    }

    if (data['title'] == null || data['title'].toString().trim().isEmpty) {
      throw AppError.validation('Security alert title is required');
    }

    if (data['description'] == null ||
        data['description'].toString().trim().isEmpty) {
      throw AppError.validation('Security alert description is required');
    }

    if (data['ai_explanation'] == null ||
        data['ai_explanation'].toString().trim().isEmpty) {
      throw AppError.validation('AI explanation is required');
    }

    if (data['detected_at'] == null) {
      throw AppError.validation('Detection timestamp is required');
    }

    // Validate type
    const validTypes = [
      'database_breach',
      'system_anomaly',
      'network_anomaly',
      'auth_flood',
      'code_vulnerability',
      'deployment_issue'
    ];
    if (!validTypes.contains(data['type'])) {
      throw AppError.validation(
          'Invalid type. Must be one of: ${validTypes.join(', ')}');
    }

    // Validate severity
    const validSeverities = ['low', 'medium', 'high', 'critical'];
    if (!validSeverities.contains(data['severity'])) {
      throw AppError.validation(
          'Invalid severity. Must be one of: ${validSeverities.join(', ')}');
    }

    // Validate status
    const validStatuses = [
      'new',
      'investigating',
      'resolved',
      'false_positive'
    ];
    if (!validStatuses.contains(data['status'])) {
      throw AppError.validation(
          'Invalid status. Must be one of: ${validStatuses.join(', ')}');
    }
  }

  /// Create a new security alert
  /// Satisfies Requirements: 3.4 (Security alert data model)
  Future<String> createSecurityAlert(SecurityAlert alert) async {
    try {
      return await create(alert);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get security alert by ID
  /// Satisfies Requirements: 3.4 (Security alert retrieval)
  Future<SecurityAlert?> getSecurityAlert(String id) async {
    return await getById(id);
  }

  /// Get all security alerts
  /// Satisfies Requirements: 3.4 (Security alert listing)
  Future<List<SecurityAlert>> getAllSecurityAlerts() async {
    return await getAll(orderBy: 'detected_at', ascending: false);
  }

  /// Get security alerts by severity
  /// Satisfies Requirements: 3.4 (Severity-based filtering)
  Future<List<SecurityAlert>> getSecurityAlertsBySeverity(
      String severity) async {
    try {
      return await getWhere(
        column: 'severity',
        value: severity,
        orderBy: 'detected_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get security alerts by type
  Future<List<SecurityAlert>> getSecurityAlertsByType(String type) async {
    try {
      return await getWhere(
        column: 'type',
        value: type,
        orderBy: 'detected_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get security alerts by status
  /// Satisfies Requirements: 3.4 (Status-based filtering)
  Future<List<SecurityAlert>> getSecurityAlertsByStatus(String status) async {
    try {
      return await getWhere(
        column: 'status',
        value: status,
        orderBy: 'detected_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get security alerts assigned to a user
  Future<List<SecurityAlert>> getSecurityAlertsByAssignee(
      String assigneeId) async {
    try {
      return await getWhere(
        column: 'assigned_to',
        value: assigneeId,
        orderBy: 'detected_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get unresolved security alerts
  Future<List<SecurityAlert>> getUnresolvedSecurityAlerts() async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .in_('status', ['new', 'investigating'])
            .order('severity', ascending: false)
            .order('detected_at', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get critical security alerts
  Future<List<SecurityAlert>> getCriticalSecurityAlerts() async {
    try {
      return await getWhere(
        column: 'severity',
        value: 'critical',
        orderBy: 'detected_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get security alerts with rollback suggestions
  Future<List<SecurityAlert>> getSecurityAlertsWithRollback() async {
    try {
      return await getWhere(
        column: 'rollback_suggested',
        value: true,
        orderBy: 'detected_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get recent security alerts (last N days)
  Future<List<SecurityAlert>> getRecentSecurityAlerts({int days = 7}) async {
    try {
      final cutoffDate =
          DateTime.now().subtract(Duration(days: days)).toIso8601String();

      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .gte('detected_at', cutoffDate)
            .order('detected_at', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update security alert
  /// Satisfies Requirements: 3.4 (Security alert updates)
  Future<void> updateSecurityAlert(SecurityAlert alert) async {
    try {
      // Check if alert exists
      final existing = await getById(alert.id);
      if (existing == null) {
        throw AppError.notFound('Security alert not found');
      }

      await update(alert.id, alert);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update security alert status
  /// Satisfies Requirements: 3.4 (Status management)
  Future<void> updateSecurityAlertStatus(String alertId, String status,
      {String? assignedTo}) async {
    try {
      final alert = await getSecurityAlert(alertId);
      if (alert == null) {
        throw AppError.notFound('Security alert not found');
      }

      final updatedAlert = alert.copyWith(
        status: status,
        assignedTo: assignedTo ?? alert.assignedTo,
        resolvedAt: status == 'resolved' ? DateTime.now() : null,
      );

      await updateSecurityAlert(updatedAlert);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Assign security alert to user
  Future<void> assignSecurityAlert(String alertId, String assigneeId) async {
    try {
      final alert = await getSecurityAlert(alertId);
      if (alert == null) {
        throw AppError.notFound('Security alert not found');
      }

      final updatedAlert = alert.copyWith(
        assignedTo: assigneeId,
        status: alert.status == 'new' ? 'investigating' : alert.status,
      );

      await updateSecurityAlert(updatedAlert);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Add evidence to security alert
  /// Satisfies Requirements: 3.4 (JSONB data handling)
  Future<void> addEvidence(
      String alertId, Map<String, dynamic> evidenceData) async {
    try {
      final alert = await getSecurityAlert(alertId);
      if (alert == null) {
        throw AppError.notFound('Security alert not found');
      }

      // Parse existing evidence or create new
      Map<String, dynamic> existingEvidence = {};
      if (alert.evidence != null && alert.evidence!.isNotEmpty) {
        try {
          existingEvidence =
              jsonDecode(alert.evidence!) as Map<String, dynamic>;
        } catch (e) {
          // If parsing fails, start with empty evidence
          existingEvidence = {};
        }
      }

      // Add timestamp to new evidence
      evidenceData['timestamp'] = DateTime.now().toIso8601String();

      // Merge evidence
      final evidenceList = existingEvidence['items'] as List<dynamic>? ?? [];
      evidenceList.add(evidenceData);
      existingEvidence['items'] = evidenceList;
      existingEvidence['last_updated'] = DateTime.now().toIso8601String();

      final updatedAlert = alert.copyWith(
        evidence: jsonEncode(existingEvidence),
      );

      await updateSecurityAlert(updatedAlert);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Delete security alert
  /// Satisfies Requirements: 3.4 (Security alert management)
  Future<void> deleteSecurityAlert(String id) async {
    try {
      // Check if alert exists
      final existing = await getById(id);
      if (existing == null) {
        throw AppError.notFound('Security alert not found');
      }

      await delete(id);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch all security alerts for real-time updates
  /// Satisfies Requirements: 3.4 (Real-time notifications)
  Stream<List<SecurityAlert>> watchAllSecurityAlerts() {
    return watchAll(orderBy: 'detected_at', ascending: false);
  }

  /// Watch security alerts by severity for real-time updates
  Stream<List<SecurityAlert>> watchSecurityAlertsBySeverity(String severity) {
    try {
      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('severity', severity)
          .order('detected_at', ascending: false)
          .map((data) => data
              .map((item) => fromMap(item as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch unresolved security alerts for real-time updates
  Stream<List<SecurityAlert>> watchUnresolvedSecurityAlerts() {
    try {
      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .in_('status', ['new', 'investigating'])
          .order('severity', ascending: false)
          .order('detected_at', ascending: false)
          .map((data) => data
              .map((item) => fromMap(item as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch a specific security alert for real-time updates
  Stream<SecurityAlert?> watchSecurityAlert(String id) {
    return watchById(id);
  }

  /// Get security alert statistics
  Future<Map<String, dynamic>> getSecurityAlertStatistics() async {
    try {
      final allAlerts = await getAllSecurityAlerts();

      final stats = <String, dynamic>{
        'total': allAlerts.length,
        'new': allAlerts.where((a) => a.status == 'new').length,
        'investigating':
            allAlerts.where((a) => a.status == 'investigating').length,
        'resolved': allAlerts.where((a) => a.status == 'resolved').length,
        'false_positive':
            allAlerts.where((a) => a.status == 'false_positive').length,
        'critical': allAlerts.where((a) => a.severity == 'critical').length,
        'high': allAlerts.where((a) => a.severity == 'high').length,
        'medium': allAlerts.where((a) => a.severity == 'medium').length,
        'low': allAlerts.where((a) => a.severity == 'low').length,
        'with_rollback': allAlerts.where((a) => a.rollbackSuggested).length,
        'typeDistribution': <String, int>{},
        'averageResolutionTime': _calculateAverageResolutionTime(allAlerts),
      };

      // Calculate type distribution
      for (final alert in allAlerts) {
        final typeStats = stats['typeDistribution'] as Map<String, int>;
        typeStats[alert.type] = (typeStats[alert.type] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Search security alerts by text
  Future<List<SecurityAlert>> searchSecurityAlerts(String searchTerm) async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .or('title.ilike.%$searchTerm%,description.ilike.%$searchTerm%,ai_explanation.ilike.%$searchTerm%')
            .order('detected_at', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get security alerts in date range
  Future<List<SecurityAlert>> getSecurityAlertsInDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .gte('detected_at', startDate.toIso8601String())
            .lte('detected_at', endDate.toIso8601String())
            .order('detected_at', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
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

  /// Calculate average resolution time for resolved alerts
  double _calculateAverageResolutionTime(List<SecurityAlert> alerts) {
    final resolvedAlerts = alerts
        .where((a) => a.status == 'resolved' && a.resolvedAt != null)
        .toList();

    if (resolvedAlerts.isEmpty) return 0.0;

    final totalMinutes = resolvedAlerts
        .map((a) => a.resolvedAt!.difference(a.detectedAt).inMinutes)
        .reduce((a, b) => a + b);

    return totalMinutes / resolvedAlerts.length;
  }
}
