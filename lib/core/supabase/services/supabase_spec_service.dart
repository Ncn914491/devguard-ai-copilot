import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/models/specification.dart';
import '../supabase_error_handler.dart';
import 'supabase_base_service.dart';

/// Supabase implementation of specification service
/// Replaces SQLite queries with supabase.from('specifications') operations
/// Requirements: 1.2, 1.4, 3.7 - Specification management with approval workflow
class SupabaseSpecService extends SupabaseBaseService<Specification> {
  static final SupabaseSpecService _instance = SupabaseSpecService._internal();
  static SupabaseSpecService get instance => _instance;
  SupabaseSpecService._internal();

  @override
  String get tableName => 'specifications';

  @override
  Specification fromMap(Map<String, dynamic> map) {
    return Specification(
      id: map['id'] ?? '',
      rawInput: map['raw_input'] ?? '',
      aiInterpretation: map['ai_interpretation'] ?? '',
      suggestedBranchName: map['suggested_branch_name'] ?? '',
      suggestedCommitMessage: map['suggested_commit_message'] ?? '',
      placeholderDiff: map['placeholder_diff'],
      status: map['status'] ?? 'draft',
      assignedTo: map['assigned_to'],
      createdAt: _parseDateTime(map['created_at']),
      approvedAt: map['approved_at'] != null
          ? _parseDateTime(map['approved_at'])
          : null,
      approvedBy: map['approved_by'],
    );
  }

  @override
  Map<String, dynamic> toMap(Specification item) {
    return {
      'id': item.id,
      'raw_input': item.rawInput,
      'ai_interpretation': item.aiInterpretation,
      'suggested_branch_name': item.suggestedBranchName,
      'suggested_commit_message': item.suggestedCommitMessage,
      'placeholder_diff': item.placeholderDiff,
      'status': item.status,
      'assigned_to': item.assignedTo,
      'created_at': item.createdAt.toIso8601String(),
      'approved_at': item.approvedAt?.toIso8601String(),
      'approved_by': item.approvedBy,
    };
  }

  @override
  void validateData(Map<String, dynamic> data) {
    // Validate required fields
    if (data['raw_input'] == null ||
        data['raw_input'].toString().trim().isEmpty) {
      throw AppError.validation('Raw input is required');
    }

    if (data['ai_interpretation'] == null ||
        data['ai_interpretation'].toString().trim().isEmpty) {
      throw AppError.validation('AI interpretation is required');
    }

    if (data['suggested_branch_name'] == null ||
        data['suggested_branch_name'].toString().trim().isEmpty) {
      throw AppError.validation('Suggested branch name is required');
    }

    if (data['suggested_commit_message'] == null ||
        data['suggested_commit_message'].toString().trim().isEmpty) {
      throw AppError.validation('Suggested commit message is required');
    }

    if (data['created_at'] == null) {
      throw AppError.validation('Creation timestamp is required');
    }

    // Validate status
    const validStatuses = ['draft', 'approved', 'in_progress', 'completed'];
    if (!validStatuses.contains(data['status'])) {
      throw AppError.validation(
          'Invalid status. Must be one of: ${validStatuses.join(', ')}');
    }

    // Validate branch name format
    final branchName = data['suggested_branch_name'].toString();
    if (!RegExp(r'^[a-zA-Z0-9._/-]+$').hasMatch(branchName)) {
      throw AppError.validation('Branch name contains invalid characters');
    }

    // Validate approval logic
    if (data['status'] == 'approved') {
      if (data['approved_by'] == null ||
          data['approved_by'].toString().trim().isEmpty) {
        throw AppError.validation(
            'Approved by is required when status is approved');
      }
      if (data['approved_at'] == null) {
        data['approved_at'] = DateTime.now().toIso8601String();
      }
    }

    // Validate raw input length
    if (data['raw_input'].toString().length > 10000) {
      throw AppError.validation(
          'Raw input is too long (maximum 10,000 characters)');
    }

    // Validate AI interpretation length
    if (data['ai_interpretation'].toString().length > 20000) {
      throw AppError.validation(
          'AI interpretation is too long (maximum 20,000 characters)');
    }
  }

  /// Create a new specification
  /// Satisfies Requirements: 3.7 (Specification creation)
  Future<String> createSpecification(Specification specification) async {
    try {
      return await create(specification);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get specification by ID
  /// Satisfies Requirements: 3.7 (Specification retrieval)
  Future<Specification?> getSpecification(String id) async {
    return await getById(id);
  }

  /// Get all specifications
  /// Satisfies Requirements: 3.7 (Specification listing)
  Future<List<Specification>> getAllSpecifications() async {
    return await getAll(orderBy: 'created_at', ascending: false);
  }

  /// Get specifications by status
  /// Satisfies Requirements: 3.7 (Status-based filtering)
  Future<List<Specification>> getSpecificationsByStatus(String status) async {
    try {
      return await getWhere(
        column: 'status',
        value: status,
        orderBy: 'created_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get specifications assigned to a user
  Future<List<Specification>> getSpecificationsByAssignee(
      String assigneeId) async {
    try {
      return await getWhere(
        column: 'assigned_to',
        value: assigneeId,
        orderBy: 'created_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get draft specifications
  Future<List<Specification>> getDraftSpecifications() async {
    try {
      return await getWhere(
        column: 'status',
        value: 'draft',
        orderBy: 'created_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get approved specifications
  Future<List<Specification>> getApprovedSpecifications() async {
    try {
      return await getWhere(
        column: 'status',
        value: 'approved',
        orderBy: 'approved_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get specifications in progress
  Future<List<Specification>> getInProgressSpecifications() async {
    try {
      return await getWhere(
        column: 'status',
        value: 'in_progress',
        orderBy: 'created_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get completed specifications
  Future<List<Specification>> getCompletedSpecifications() async {
    try {
      return await getWhere(
        column: 'status',
        value: 'completed',
        orderBy: 'created_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get specifications approved by a user
  Future<List<Specification>> getSpecificationsApprovedBy(
      String approverId) async {
    try {
      return await getWhere(
        column: 'approved_by',
        value: approverId,
        orderBy: 'approved_at',
        ascending: false,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get recent specifications (last N days)
  Future<List<Specification>> getRecentSpecifications({int days = 7}) async {
    try {
      final cutoffDate =
          DateTime.now().subtract(Duration(days: days)).toIso8601String();

      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .gte('created_at', cutoffDate)
            .order('created_at', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update specification
  /// Satisfies Requirements: 3.7 (Specification updates)
  Future<void> updateSpecification(Specification specification) async {
    try {
      // Check if specification exists
      final existing = await getById(specification.id);
      if (existing == null) {
        throw AppError.notFound('Specification not found');
      }

      await update(specification.id, specification);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update specification status
  Future<void> updateSpecificationStatus(
      String specificationId, String status) async {
    try {
      final specification = await getSpecification(specificationId);
      if (specification == null) {
        throw AppError.notFound('Specification not found');
      }

      final updatedSpecification = specification.copyWith(status: status);
      await updateSpecification(updatedSpecification);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Assign specification to user
  Future<void> assignSpecification(
      String specificationId, String assigneeId) async {
    try {
      final specification = await getSpecification(specificationId);
      if (specification == null) {
        throw AppError.notFound('Specification not found');
      }

      final updatedSpecification = specification.copyWith(
        assignedTo: assigneeId,
        status: specification.status == 'draft'
            ? 'in_progress'
            : specification.status,
      );

      await updateSpecification(updatedSpecification);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Approve specification
  /// Satisfies Requirements: 3.7 (Approval workflow)
  Future<void> approveSpecification(
      String specificationId, String approvedBy) async {
    try {
      final specification = await getSpecification(specificationId);
      if (specification == null) {
        throw AppError.notFound('Specification not found');
      }

      if (specification.status == 'approved') {
        throw AppError.validation('Specification is already approved');
      }

      final updatedSpecification = specification.copyWith(
        status: 'approved',
        approvedBy: approvedBy,
        approvedAt: DateTime.now(),
      );

      await updateSpecification(updatedSpecification);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Reject specification (move back to draft)
  Future<void> rejectSpecification(String specificationId) async {
    try {
      final specification = await getSpecification(specificationId);
      if (specification == null) {
        throw AppError.notFound('Specification not found');
      }

      final updatedSpecification = specification.copyWith(
        status: 'draft',
        approvedBy: null,
        approvedAt: null,
      );

      await updateSpecification(updatedSpecification);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Mark specification as completed
  Future<void> completeSpecification(String specificationId) async {
    try {
      final specification = await getSpecification(specificationId);
      if (specification == null) {
        throw AppError.notFound('Specification not found');
      }

      if (specification.status != 'in_progress') {
        throw AppError.validation(
            'Only in-progress specifications can be completed');
      }

      final updatedSpecification = specification.copyWith(status: 'completed');
      await updateSpecification(updatedSpecification);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update placeholder diff
  Future<void> updatePlaceholderDiff(
      String specificationId, String placeholderDiff) async {
    try {
      final specification = await getSpecification(specificationId);
      if (specification == null) {
        throw AppError.notFound('Specification not found');
      }

      final updatedSpecification =
          specification.copyWith(placeholderDiff: placeholderDiff);
      await updateSpecification(updatedSpecification);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Delete specification
  /// Satisfies Requirements: 3.7 (Specification management)
  Future<void> deleteSpecification(String id) async {
    try {
      // Check if specification exists
      final existing = await getById(id);
      if (existing == null) {
        throw AppError.notFound('Specification not found');
      }

      await delete(id);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Search specifications by text
  Future<List<Specification>> searchSpecifications(String searchTerm) async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .or('raw_input.ilike.%$searchTerm%,ai_interpretation.ilike.%$searchTerm%,suggested_branch_name.ilike.%$searchTerm%,suggested_commit_message.ilike.%$searchTerm%')
            .order('created_at', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get specifications in date range
  Future<List<Specification>> getSpecificationsInDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final response = await executeQuery(
        _client
            .from(tableName)
            .select()
            .gte('created_at', startDate.toIso8601String())
            .lte('created_at', endDate.toIso8601String())
            .order('created_at', ascending: false),
      );

      return response.map((item) => fromMap(item)).toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch all specifications for real-time updates
  /// Satisfies Requirements: 3.7 (Real-time specification monitoring)
  Stream<List<Specification>> watchAllSpecifications() {
    return watchAll(orderBy: 'created_at', ascending: false);
  }

  /// Watch specifications by status for real-time updates
  Stream<List<Specification>> watchSpecificationsByStatus(String status) {
    try {
      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('status', status)
          .order('created_at', ascending: false)
          .map((data) => data
              .map((item) => fromMap(item as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch specifications by assignee for real-time updates
  Stream<List<Specification>> watchSpecificationsByAssignee(String assigneeId) {
    try {
      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('assigned_to', assigneeId)
          .order('created_at', ascending: false)
          .map((data) => data
              .map((item) => fromMap(item as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch a specific specification for real-time updates
  Stream<Specification?> watchSpecification(String id) {
    return watchById(id);
  }

  /// Get specification statistics
  Future<Map<String, dynamic>> getSpecificationStatistics() async {
    try {
      final allSpecs = await getAllSpecifications();

      final stats = <String, dynamic>{
        'total': allSpecs.length,
        'draft': allSpecs.where((s) => s.status == 'draft').length,
        'approved': allSpecs.where((s) => s.status == 'approved').length,
        'in_progress': allSpecs.where((s) => s.status == 'in_progress').length,
        'completed': allSpecs.where((s) => s.status == 'completed').length,
        'assigned': allSpecs
            .where((s) => s.assignedTo != null && s.assignedTo!.isNotEmpty)
            .length,
        'unassigned': allSpecs
            .where((s) => s.assignedTo == null || s.assignedTo!.isEmpty)
            .length,
        'with_diff': allSpecs
            .where((s) =>
                s.placeholderDiff != null && s.placeholderDiff!.isNotEmpty)
            .length,
        'assigneeDistribution': <String, int>{},
        'approverDistribution': <String, int>{},
        'averageApprovalTime': 0.0,
        'completionRate': 0.0,
        'specsPerDay': 0.0,
      };

      // Calculate assignee distribution
      for (final spec in allSpecs) {
        if (spec.assignedTo != null && spec.assignedTo!.isNotEmpty) {
          final assigneeStats =
              stats['assigneeDistribution'] as Map<String, int>;
          assigneeStats[spec.assignedTo!] =
              (assigneeStats[spec.assignedTo!] ?? 0) + 1;
        }
      }

      // Calculate approver distribution
      for (final spec in allSpecs) {
        if (spec.approvedBy != null && spec.approvedBy!.isNotEmpty) {
          final approverStats =
              stats['approverDistribution'] as Map<String, int>;
          approverStats[spec.approvedBy!] =
              (approverStats[spec.approvedBy!] ?? 0) + 1;
        }
      }

      // Calculate average approval time
      final approvedSpecs = allSpecs
          .where((s) => s.status == 'approved' && s.approvedAt != null)
          .toList();
      if (approvedSpecs.isNotEmpty) {
        final totalApprovalTime = approvedSpecs
            .map((s) => s.approvedAt!.difference(s.createdAt).inHours)
            .reduce((a, b) => a + b);
        stats['averageApprovalTime'] = totalApprovalTime / approvedSpecs.length;
      }

      // Calculate completion rate
      final completedCount = stats['completed'] as int;
      final totalCount = stats['total'] as int;
      stats['completionRate'] =
          totalCount > 0 ? (completedCount / totalCount) * 100 : 0.0;

      // Calculate specifications per day over last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentSpecs =
          allSpecs.where((s) => s.createdAt.isAfter(thirtyDaysAgo)).length;
      stats['specsPerDay'] = recentSpecs / 30.0;

      return stats;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get workflow metrics (draft -> approved -> completed)
  Future<Map<String, dynamic>> getWorkflowMetrics() async {
    try {
      final allSpecs = await getAllSpecifications();

      final metrics = <String, dynamic>{
        'total_created': allSpecs.length,
        'approval_rate': 0.0,
        'completion_rate': 0.0,
        'average_time_to_approval': 0.0,
        'average_time_to_completion': 0.0,
        'workflow_efficiency': 0.0,
      };

      if (allSpecs.isEmpty) return metrics;

      // Calculate approval rate
      final approvedOrCompleted = allSpecs
          .where((s) => ['approved', 'completed'].contains(s.status))
          .length;
      metrics['approval_rate'] = (approvedOrCompleted / allSpecs.length) * 100;

      // Calculate completion rate
      final completed = allSpecs.where((s) => s.status == 'completed').length;
      metrics['completion_rate'] = (completed / allSpecs.length) * 100;

      // Calculate average time to approval
      final approvedSpecs =
          allSpecs.where((s) => s.approvedAt != null).toList();
      if (approvedSpecs.isNotEmpty) {
        final totalApprovalTime = approvedSpecs
            .map((s) => s.approvedAt!.difference(s.createdAt).inHours)
            .reduce((a, b) => a + b);
        metrics['average_time_to_approval'] =
            totalApprovalTime / approvedSpecs.length;
      }

      // Calculate workflow efficiency (completed / total created)
      metrics['workflow_efficiency'] = metrics['completion_rate'];

      return metrics;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
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
