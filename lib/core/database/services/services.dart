// Export all Supabase database services
export '../../supabase/services/supabase_audit_log_service.dart';
export '../../supabase/services/supabase_deployment_service.dart';
export '../../supabase/services/supabase_task_service.dart';
export '../../supabase/services/supabase_security_alert_service.dart';
export '../../supabase/services/supabase_snapshot_service.dart';
export '../../supabase/services/supabase_spec_service.dart';
export '../../supabase/services/supabase_team_member_service.dart';
export '../../supabase/services/supabase_base_service.dart';

// Export error handling
export '../../supabase/supabase_error_handler.dart';

// Service aliases for backward compatibility
class AuditLogService {
  static final AuditLogService _instance = AuditLogService._internal();
  static AuditLogService get instance => _instance;
  AuditLogService._internal();

  Future<void> logAction({
    required String actionType,
    required String description,
    String? aiReasoning,
    Map<String, dynamic>? contextData,
    String? userId,
  }) async {
    // Mock implementation for now
    print('Audit Log: $actionType - $description');
  }
}

class TaskService {
  static final TaskService _instance = TaskService._internal();
  static TaskService get instance => _instance;
  TaskService._internal();
}

class TeamMemberService {
  static final TeamMemberService _instance = TeamMemberService._internal();
  static TeamMemberService get instance => _instance;
  TeamMemberService._internal();
}

class SpecService {
  static final SpecService _instance = SpecService._internal();
  static SpecService get instance => _instance;
  SpecService._internal();

  Future<void> approveSpecification(String id) async {
    print('Approving spec: $id');
  }

  Future<void> updateSpecificationStatus(String id, String status) async {
    print('Updating spec $id status to: $status');
  }
}
