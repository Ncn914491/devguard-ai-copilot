import 'dart:async';
import 'dart:math';
import '../api/websocket_service.dart';
import '../database/services/audit_log_service.dart';
import '../auth/auth_service.dart';

/// Notification types enumeration
enum NotificationType {
  taskAssignment,
  taskStatusUpdate,
  joinRequestApproval,
  joinRequestRejection,
  securityAlert,
  deploymentStatus,
  gitOperation,
  teamMemberStatus,
  fileChange,
  repositoryUpdate,
}

/// Notification priority levels
enum NotificationPriority {
  low,
  medium,
  high,
  critical,
}

/// Notification event model
class NotificationEvent {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final List<String> targetUsers;
  final NotificationPriority priority;
  final DateTime timestamp;
  final bool isRead;
  final DateTime? readAt;

  NotificationEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.targetUsers,
    required this.priority,
    required this.timestamp,
    this.isRead = false,
    this.readAt,
  });

  NotificationEvent copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    List<String>? targetUsers,
    NotificationPriority? priority,
    DateTime? timestamp,
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      targetUsers: targetUsers ?? this.targetUsers,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'title': title,
      'message': message,
      'data': data,
      'target_users': targetUsers,
      'priority': priority.toString(),
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
    };
  }
}

/// Comprehensive notification service for real-time communication
/// Satisfies Requirements: 4.1, 4.2, 4.3, 4.4, 4.5 (Real-time communication)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  NotificationService._internal();

  final _webSocketService = WebSocketService.instance;
  final _auditService = AuditLogService.instance;
  final _authService = AuthService.instance;

  // Notification queues and streams
  final StreamController<NotificationEvent> _notificationController =
      StreamController<NotificationEvent>.broadcast();
  final Map<String, List<NotificationEvent>> _userNotifications = {};
  final Map<String, DateTime> _lastReadTimestamps = {};

  bool _isInitialized = false;

  /// Get initialization status
  bool get isInitialized => _isInitialized;

  /// Get notification stream
  Stream<NotificationEvent> get notificationStream =>
      _notificationController.stream;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Ensure WebSocket service is initialized
    if (!_webSocketService.isInitialized) {
      await _webSocketService.initialize();
    }

    _isInitialized = true;

    await _auditService.logAction(
      actionType: 'notification_service_initialized',
      description:
          'Notification service initialized for real-time communication',
      aiReasoning:
          'Notification service provides comprehensive real-time updates for tasks, security, deployments, and team collaboration',
      contextData: {
        'websocket_integration': true,
        'notification_types': [
          'task_assignment',
          'join_request_approval',
          'security_alert',
          'deployment_status',
          'git_operation',
          'team_member_status'
        ],
      },
    );
  }

  /// Send task assignment notification
  /// Requirement 4.2: Real-time task assignment notifications
  Future<void> notifyTaskAssignment({
    required String taskId,
    required String taskTitle,
    required String assigneeId,
    required String assignerId,
    String? message,
  }) async {
    try {
      final notification = NotificationEvent(
        id: _generateNotificationId(),
        type: NotificationType.taskAssignment,
        title: 'New Task Assigned',
        message: message ?? 'You have been assigned to task: $taskTitle',
        data: {
          'task_id': taskId,
          'task_title': taskTitle,
          'assigner_id': assignerId,
          'assignee_id': assigneeId,
        },
        targetUsers: [assigneeId],
        priority: NotificationPriority.high,
        timestamp: DateTime.now(),
      );

      await _sendNotification(notification);

      // Also broadcast via WebSocket for real-time updates
      await _webSocketService.broadcastTaskUpdate(
        taskId: taskId,
        update: {
          'action': 'assigned',
          'assignee_id': assigneeId,
          'assigner_id': assignerId,
          'task_title': taskTitle,
        },
        targetUsers: [assigneeId, assignerId],
      );

      await _auditService.logAction(
        actionType: 'notification_task_assignment_sent',
        description: 'Task assignment notification sent',
        contextData: {
          'task_id': taskId,
          'assignee_id': assigneeId,
          'assigner_id': assignerId,
        },
        userId: assignerId,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_task_assignment_error',
        description:
            'Error sending task assignment notification: ${e.toString()}',
        contextData: {
          'task_id': taskId,
          'assignee_id': assigneeId,
          'error': e.toString(),
        },
        userId: assignerId,
      );
      rethrow;
    }
  }

  /// Send task status update notification
  /// Requirement 4.2: Real-time task status update notifications
  Future<void> notifyTaskStatusUpdate({
    required String taskId,
    required String taskTitle,
    required String oldStatus,
    required String newStatus,
    required String updatedById,
    List<String>? targetUsers,
  }) async {
    try {
      final notification = NotificationEvent(
        id: _generateNotificationId(),
        type: NotificationType.taskStatusUpdate,
        title: 'Task Status Updated',
        message:
            'Task "$taskTitle" status changed from $oldStatus to $newStatus',
        data: {
          'task_id': taskId,
          'task_title': taskTitle,
          'old_status': oldStatus,
          'new_status': newStatus,
          'updated_by_id': updatedById,
        },
        targetUsers: targetUsers ?? ['team'],
        priority: NotificationPriority.medium,
        timestamp: DateTime.now(),
      );

      await _sendNotification(notification);

      // Broadcast via WebSocket
      await _webSocketService.broadcastTaskUpdate(
        taskId: taskId,
        update: {
          'action': 'status_updated',
          'old_status': oldStatus,
          'new_status': newStatus,
          'updated_by_id': updatedById,
        },
        targetUsers: targetUsers,
      );

      await _auditService.logAction(
        actionType: 'notification_task_status_update_sent',
        description: 'Task status update notification sent',
        contextData: {
          'task_id': taskId,
          'old_status': oldStatus,
          'new_status': newStatus,
          'updated_by_id': updatedById,
        },
        userId: updatedById,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_task_status_update_error',
        description:
            'Error sending task status update notification: ${e.toString()}',
        contextData: {
          'task_id': taskId,
          'error': e.toString(),
        },
        userId: updatedById,
      );
      rethrow;
    }
  }

  /// Send join request approval notification
  /// Requirement 4.4: Join request approval notifications
  Future<void> notifyJoinRequestApproval({
    required String requestId,
    required String applicantEmail,
    required String applicantName,
    required String approvedById,
    String? message,
  }) async {
    try {
      final notification = NotificationEvent(
        id: _generateNotificationId(),
        type: NotificationType.joinRequestApproval,
        title: 'Join Request Approved',
        message: message ??
            'Your join request has been approved! Welcome to the team.',
        data: {
          'request_id': requestId,
          'applicant_email': applicantEmail,
          'applicant_name': applicantName,
          'approved_by_id': approvedById,
        },
        targetUsers: [applicantEmail], // Use email as identifier for non-users
        priority: NotificationPriority.high,
        timestamp: DateTime.now(),
      );

      await _sendNotification(notification);

      await _auditService.logAction(
        actionType: 'notification_join_request_approval_sent',
        description: 'Join request approval notification sent',
        contextData: {
          'request_id': requestId,
          'applicant_email': applicantEmail,
          'approved_by_id': approvedById,
        },
        userId: approvedById,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_join_request_approval_error',
        description:
            'Error sending join request approval notification: ${e.toString()}',
        contextData: {
          'request_id': requestId,
          'error': e.toString(),
        },
        userId: approvedById,
      );
      rethrow;
    }
  }

  /// Send join request rejection notification
  /// Requirement 4.4: Join request rejection notifications
  Future<void> notifyJoinRequestRejection({
    required String requestId,
    required String applicantEmail,
    required String applicantName,
    required String rejectedById,
    String? reason,
  }) async {
    try {
      final notification = NotificationEvent(
        id: _generateNotificationId(),
        type: NotificationType.joinRequestRejection,
        title: 'Join Request Update',
        message: reason ??
            'Your join request has been reviewed. Please contact the team for more information.',
        data: {
          'request_id': requestId,
          'applicant_email': applicantEmail,
          'applicant_name': applicantName,
          'rejected_by_id': rejectedById,
          'reason': reason,
        },
        targetUsers: [applicantEmail],
        priority: NotificationPriority.medium,
        timestamp: DateTime.now(),
      );

      await _sendNotification(notification);

      await _auditService.logAction(
        actionType: 'notification_join_request_rejection_sent',
        description: 'Join request rejection notification sent',
        contextData: {
          'request_id': requestId,
          'applicant_email': applicantEmail,
          'rejected_by_id': rejectedById,
          'reason': reason,
        },
        userId: rejectedById,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_join_request_rejection_error',
        description:
            'Error sending join request rejection notification: ${e.toString()}',
        contextData: {
          'request_id': requestId,
          'error': e.toString(),
        },
        userId: rejectedById,
      );
      rethrow;
    }
  }

  /// Send security alert notification
  /// Requirement 4.3: Security alert notifications
  Future<void> notifySecurityAlert({
    required String alertId,
    required String severity,
    required String message,
    required String alertType,
    List<String>? affectedUsers,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notification = NotificationEvent(
        id: _generateNotificationId(),
        type: NotificationType.securityAlert,
        title: 'Security Alert - ${severity.toUpperCase()}',
        message: message,
        data: {
          'alert_id': alertId,
          'severity': severity,
          'alert_type': alertType,
          'affected_users': affectedUsers,
          'metadata': metadata,
        },
        targetUsers: affectedUsers ?? ['all'],
        priority: _getPriorityFromSeverity(severity),
        timestamp: DateTime.now(),
      );

      await _sendNotification(notification);

      // Broadcast via WebSocket
      await _webSocketService.broadcastSecurityAlert(
        alertId: alertId,
        severity: severity,
        message: message,
        affectedUsers: affectedUsers,
      );

      await _auditService.logAction(
        actionType: 'notification_security_alert_sent',
        description: 'Security alert notification sent',
        contextData: {
          'alert_id': alertId,
          'severity': severity,
          'alert_type': alertType,
          'affected_users': affectedUsers,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_security_alert_error',
        description:
            'Error sending security alert notification: ${e.toString()}',
        contextData: {
          'alert_id': alertId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Send deployment status notification
  /// Requirement 4.3: Deployment status notifications
  Future<void> notifyDeploymentStatus({
    required String deploymentId,
    required String status,
    required String projectName,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notification = NotificationEvent(
        id: _generateNotificationId(),
        type: NotificationType.deploymentStatus,
        title: 'Deployment ${status.toUpperCase()}',
        message: message ?? 'Deployment of $projectName is $status',
        data: {
          'deployment_id': deploymentId,
          'status': status,
          'project_name': projectName,
          'metadata': metadata,
        },
        targetUsers: ['admin', 'lead_developer'],
        priority: _getPriorityFromDeploymentStatus(status),
        timestamp: DateTime.now(),
      );

      await _sendNotification(notification);

      // Broadcast via WebSocket
      await _webSocketService.broadcastDeploymentStatus(
        deploymentId: deploymentId,
        status: status,
        message: message,
        metadata: metadata,
      );

      await _auditService.logAction(
        actionType: 'notification_deployment_status_sent',
        description: 'Deployment status notification sent',
        contextData: {
          'deployment_id': deploymentId,
          'status': status,
          'project_name': projectName,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_deployment_status_error',
        description:
            'Error sending deployment status notification: ${e.toString()}',
        contextData: {
          'deployment_id': deploymentId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Send git operation notification
  /// Requirement 4.3: Git operation feedback notifications
  Future<void> notifyGitOperation({
    required String repositoryId,
    required String operation,
    required String userId,
    required bool success,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notification = NotificationEvent(
        id: _generateNotificationId(),
        type: NotificationType.gitOperation,
        title: 'Git Operation ${success ? 'Completed' : 'Failed'}',
        message: message ??
            'Git $operation ${success ? 'completed successfully' : 'failed'}',
        data: {
          'repository_id': repositoryId,
          'operation': operation,
          'user_id': userId,
          'success': success,
          'metadata': metadata,
        },
        targetUsers: [userId],
        priority:
            success ? NotificationPriority.low : NotificationPriority.medium,
        timestamp: DateTime.now(),
      );

      await _sendNotification(notification);

      // Broadcast file changes if it's a successful commit/push
      if (success && (operation == 'commit' || operation == 'push')) {
        await _webSocketService.broadcastRepositoryUpdate(
          repositoryId: repositoryId,
          update: {
            'action': operation,
            'user_id': userId,
            'success': success,
            'metadata': metadata,
          },
        );
      }

      await _auditService.logAction(
        actionType: 'notification_git_operation_sent',
        description: 'Git operation notification sent',
        contextData: {
          'repository_id': repositoryId,
          'operation': operation,
          'user_id': userId,
          'success': success,
        },
        userId: userId,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_git_operation_error',
        description:
            'Error sending git operation notification: ${e.toString()}',
        contextData: {
          'repository_id': repositoryId,
          'operation': operation,
          'error': e.toString(),
        },
        userId: userId,
      );
      rethrow;
    }
  }

  /// Send team member status notification
  /// Requirement 4.4: Team member presence indicators
  Future<void> notifyTeamMemberStatus({
    required String userId,
    required String status,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notification = NotificationEvent(
        id: _generateNotificationId(),
        type: NotificationType.teamMemberStatus,
        title: 'Team Member ${status.toUpperCase()}',
        message: '${userName ?? 'Team member'} is now $status',
        data: {
          'user_id': userId,
          'status': status,
          'user_name': userName,
          'metadata': metadata,
        },
        targetUsers: ['team'],
        priority: NotificationPriority.low,
        timestamp: DateTime.now(),
      );

      await _sendNotification(notification);

      // Broadcast via WebSocket
      await _webSocketService.broadcastTeamMemberStatus(
        userId: userId,
        status: status,
        metadata: metadata,
      );

      await _auditService.logAction(
        actionType: 'notification_team_member_status_sent',
        description: 'Team member status notification sent',
        contextData: {
          'user_id': userId,
          'status': status,
          'user_name': userName,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_team_member_status_error',
        description:
            'Error sending team member status notification: ${e.toString()}',
        contextData: {
          'user_id': userId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Send file change notification
  /// Requirement 4.3: File change notifications for collaboration
  Future<void> notifyFileChange({
    required String repositoryId,
    required String filePath,
    required String changeType,
    required String userId,
    String? content,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notification = NotificationEvent(
        id: _generateNotificationId(),
        type: NotificationType.fileChange,
        title: 'File ${changeType.toUpperCase()}',
        message: 'File $filePath was $changeType',
        data: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'change_type': changeType,
          'user_id': userId,
          'content': content,
          'metadata': metadata,
        },
        targetUsers: ['team'],
        priority: NotificationPriority.low,
        timestamp: DateTime.now(),
      );

      await _sendNotification(notification);

      // Broadcast via WebSocket
      await _webSocketService.broadcastFileChange(
        repositoryId: repositoryId,
        filePath: filePath,
        change: {
          'action': changeType,
          'user_id': userId,
          'content': content,
          'metadata': metadata,
        },
      );

      await _auditService.logAction(
        actionType: 'notification_file_change_sent',
        description: 'File change notification sent',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'change_type': changeType,
          'user_id': userId,
        },
        userId: userId,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_file_change_error',
        description: 'Error sending file change notification: ${e.toString()}',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'error': e.toString(),
        },
        userId: userId,
      );
      rethrow;
    }
  }

  /// Get notifications for a user
  Future<List<NotificationEvent>> getUserNotifications(String userId) async {
    try {
      final notifications = _userNotifications[userId] ?? [];

      await _auditService.logAction(
        actionType: 'notification_user_notifications_retrieved',
        description: 'Retrieved user notifications',
        contextData: {
          'user_id': userId,
          'notification_count': notifications.length,
        },
        userId: userId,
      );

      return notifications;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_user_notifications_error',
        description: 'Error retrieving user notifications: ${e.toString()}',
        contextData: {
          'user_id': userId,
          'error': e.toString(),
        },
        userId: userId,
      );
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(
      String notificationId, String userId) async {
    try {
      final userNotifications = _userNotifications[userId] ?? [];
      final notificationIndex =
          userNotifications.indexWhere((n) => n.id == notificationId);

      if (notificationIndex != -1) {
        final notification = userNotifications[notificationIndex];
        final updatedNotification = notification.copyWith(
          isRead: true,
          readAt: DateTime.now(),
        );

        userNotifications[notificationIndex] = updatedNotification;
        _userNotifications[userId] = userNotifications;

        _lastReadTimestamps[userId] = DateTime.now();
      }

      await _auditService.logAction(
        actionType: 'notification_marked_as_read',
        description: 'Notification marked as read',
        contextData: {
          'notification_id': notificationId,
          'user_id': userId,
        },
        userId: userId,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_mark_read_error',
        description: 'Error marking notification as read: ${e.toString()}',
        contextData: {
          'notification_id': notificationId,
          'user_id': userId,
          'error': e.toString(),
        },
        userId: userId,
      );
      rethrow;
    }
  }

  /// Get unread notification count for user
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final notifications = _userNotifications[userId] ?? [];
      final unreadCount = notifications.where((n) => !n.isRead).length;

      return unreadCount;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_unread_count_error',
        description: 'Error getting unread notification count: ${e.toString()}',
        contextData: {
          'user_id': userId,
          'error': e.toString(),
        },
        userId: userId,
      );
      return 0;
    }
  }

  /// Clear all notifications for user
  Future<void> clearUserNotifications(String userId) async {
    try {
      _userNotifications[userId] = [];
      _lastReadTimestamps[userId] = DateTime.now();

      await _auditService.logAction(
        actionType: 'notification_user_notifications_cleared',
        description: 'User notifications cleared',
        contextData: {
          'user_id': userId,
        },
        userId: userId,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'notification_clear_error',
        description: 'Error clearing user notifications: ${e.toString()}',
        contextData: {
          'user_id': userId,
          'error': e.toString(),
        },
        userId: userId,
      );
      rethrow;
    }
  }

  /// Private helper methods

  /// Send notification to users
  Future<void> _sendNotification(NotificationEvent notification) async {
    // Add to notification stream
    _notificationController.add(notification);

    // Store in user notification queues
    for (final userId in notification.targetUsers) {
      if (userId == 'all' || userId == 'team' || userId.startsWith('role_')) {
        // Handle special target groups
        await _handleSpecialTargetGroup(userId, notification);
      } else {
        // Add to specific user's notifications
        _userNotifications.putIfAbsent(userId, () => []).add(notification);
      }
    }
  }

  /// Handle special target groups (all, team, roles)
  Future<void> _handleSpecialTargetGroup(
      String targetGroup, NotificationEvent notification) async {
    // In a real implementation, this would query the user database
    // For now, we'll simulate by adding to all connected users
    final connectedUsers =
        _webSocketService.getConnectionStats()['unique_users'] as int? ?? 0;

    // This is a simplified implementation - in reality you'd query user database
    // based on roles and active status
    if (targetGroup == 'all') {
      // Add to all users (simplified)
      for (int i = 1; i <= connectedUsers; i++) {
        final userId = 'user_$i';
        _userNotifications.putIfAbsent(userId, () => []).add(notification);
      }
    } else if (targetGroup == 'team') {
      // Add to team members (simplified)
      for (int i = 1; i <= connectedUsers; i++) {
        final userId = 'user_$i';
        _userNotifications.putIfAbsent(userId, () => []).add(notification);
      }
    }
    // Role-based targeting would be handled similarly
  }

  /// Generate unique notification ID
  String _generateNotificationId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = random.nextInt(10000);
    return 'notif_${timestamp}_$randomSuffix';
  }

  /// Get priority from security alert severity
  NotificationPriority _getPriorityFromSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return NotificationPriority.critical;
      case 'high':
        return NotificationPriority.high;
      case 'medium':
        return NotificationPriority.medium;
      case 'low':
      default:
        return NotificationPriority.low;
    }
  }

  /// Get priority from deployment status
  NotificationPriority _getPriorityFromDeploymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'failed':
      case 'error':
        return NotificationPriority.high;
      case 'success':
      case 'completed':
        return NotificationPriority.medium;
      case 'in_progress':
      case 'pending':
      default:
        return NotificationPriority.low;
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationController.close();
    _userNotifications.clear();
    _lastReadTimestamps.clear();
    _isInitialized = false;
  }
}
