import 'package:flutter/material.dart';
import '../../core/supabase/services/supabase_realtime_service.dart';
import '../../core/database/models/models.dart';
import 'dart:async';

/// Real-time notification widget that shows live updates
/// Requirements: 10.2, 10.5 - Real-time UI updates and notifications
class RealtimeNotificationWidget extends StatefulWidget {
  final String userId;
  final String userRole;

  const RealtimeNotificationWidget({
    super.key,
    required this.userId,
    required this.userRole,
  });

  @override
  State<RealtimeNotificationWidget> createState() =>
      _RealtimeNotificationWidgetState();
}

class _RealtimeNotificationWidgetState
    extends State<RealtimeNotificationWidget> {
  final _realtimeService = SupabaseRealtimeService.instance;

  // Subscriptions
  StreamSubscription<List<SecurityAlert>>? _securityAlertsSubscription;
  StreamSubscription<List<Task>>? _tasksSubscription;
  StreamSubscription<List<TeamMember>>? _teamMembersSubscription;

  // Notification state
  List<RealtimeNotification> _notifications = [];
  bool _hasUnreadNotifications = false;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _securityAlertsSubscription?.cancel();
    _tasksSubscription?.cancel();
    _teamMembersSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeSubscriptions() {
    try {
      // Subscribe to security alerts
      _securityAlertsSubscription = _realtimeService
          .watchTable<SecurityAlert>(
            tableName: 'security_alerts',
            fromMap: (map) => SecurityAlert.fromMap(map),
            orderBy: 'detected_at',
            ascending: false,
          )
          .listen(
            (alerts) => _handleSecurityAlertsUpdate(alerts),
            onError: (error) =>
                debugPrint('Security alerts subscription error: $error'),
          );

      // Subscribe to tasks assigned to user
      _tasksSubscription = _realtimeService
          .watchTable<Task>(
            tableName: 'tasks',
            fromMap: (map) => Task.fromMap(map),
            filter: 'assignee_id=${widget.userId}',
            orderBy: 'created_at',
            ascending: false,
          )
          .listen(
            (tasks) => _handleTasksUpdate(tasks),
            onError: (error) => debugPrint('Tasks subscription error: $error'),
          );

      // Subscribe to team member changes (for admins and leads)
      if (widget.userRole == 'admin' || widget.userRole == 'lead_developer') {
        _teamMembersSubscription = _realtimeService
            .watchTable<TeamMember>(
              tableName: 'team_members',
              fromMap: (map) => TeamMember.fromMap(map),
              orderBy: 'updated_at',
              ascending: false,
            )
            .listen(
              (members) => _handleTeamMembersUpdate(members),
              onError: (error) =>
                  debugPrint('Team members subscription error: $error'),
            );
      }
    } catch (e) {
      debugPrint('Error setting up realtime subscriptions: $e');
    }
  }

  void _handleSecurityAlertsUpdate(List<SecurityAlert> alerts) {
    final newCriticalAlerts = alerts
        .where((alert) =>
            alert.severity.toLowerCase() == 'critical' &&
            alert.status == 'new' &&
            _isRecentAlert(alert.detectedAt))
        .toList();

    for (final alert in newCriticalAlerts) {
      _addNotification(RealtimeNotification(
        id: alert.id,
        type: NotificationType.securityAlert,
        title: 'Critical Security Alert',
        message: alert.title,
        timestamp: alert.detectedAt,
        severity: NotificationSeverity.critical,
        data: {'alertId': alert.id},
      ));
    }
  }

  void _handleTasksUpdate(List<Task> tasks) {
    final newHighPriorityTasks = tasks
        .where((task) =>
            (task.priority == 'high' || task.priority == 'critical') &&
            task.status == 'to_do' &&
            _isRecentTask(task.createdAt))
        .toList();

    for (final task in newHighPriorityTasks) {
      _addNotification(RealtimeNotification(
        id: task.id,
        type: NotificationType.taskAssigned,
        title: 'High Priority Task Assigned',
        message: task.title,
        timestamp: task.createdAt,
        severity: task.priority == 'critical'
            ? NotificationSeverity.critical
            : NotificationSeverity.high,
        data: {'taskId': task.id},
      ));
    }
  }

  void _handleTeamMembersUpdate(List<TeamMember> members) {
    final recentlyActiveMembers = members
        .where((member) =>
            member.status == 'active' && _isRecentUpdate(member.updatedAt))
        .toList();

    for (final member in recentlyActiveMembers) {
      _addNotification(RealtimeNotification(
        id: member.id,
        type: NotificationType.teamMemberStatusChange,
        title: 'Team Member Status Update',
        message: '${member.name} is now ${member.status}',
        timestamp: member.updatedAt,
        severity: NotificationSeverity.info,
        data: {'memberId': member.id},
      ));
    }
  }

  void _addNotification(RealtimeNotification notification) {
    if (mounted) {
      setState(() {
        _notifications.insert(0, notification);
        _hasUnreadNotifications = true;

        // Keep only last 20 notifications
        if (_notifications.length > 20) {
          _notifications = _notifications.take(20).toList();
        }
      });

      // Show snackbar for critical notifications
      if (notification.severity == NotificationSeverity.critical) {
        _showCriticalNotificationSnackbar(notification);
      }
    }
  }

  void _showCriticalNotificationSnackbar(RealtimeNotification notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(notification.message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () => _handleNotificationTap(notification),
        ),
      ),
    );
  }

  void _handleNotificationTap(RealtimeNotification notification) {
    // Handle navigation based on notification type
    switch (notification.type) {
      case NotificationType.securityAlert:
        // Navigate to security screen
        break;
      case NotificationType.taskAssigned:
        // Navigate to task details
        break;
      case NotificationType.teamMemberStatusChange:
        // Navigate to team screen
        break;
    }
  }

  bool _isRecentAlert(DateTime timestamp) {
    return DateTime.now().difference(timestamp).inMinutes < 5;
  }

  bool _isRecentTask(DateTime timestamp) {
    return DateTime.now().difference(timestamp).inMinutes < 10;
  }

  bool _isRecentUpdate(DateTime timestamp) {
    return DateTime.now().difference(timestamp).inMinutes < 15;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<RealtimeNotification>(
      icon: Stack(
        children: [
          const Icon(Icons.notifications_outlined),
          if (_hasUnreadNotifications)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: const BoxConstraints(
                  minWidth: 12,
                  minHeight: 12,
                ),
                child: Text(
                  '${_notifications.length > 9 ? '9+' : _notifications.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onSelected: _handleNotificationTap,
      onOpened: () {
        setState(() {
          _hasUnreadNotifications = false;
        });
      },
      itemBuilder: (context) {
        if (_notifications.isEmpty) {
          return [
            const PopupMenuItem<RealtimeNotification>(
              enabled: false,
              child: ListTile(
                leading: Icon(Icons.notifications_none),
                title: Text('No notifications'),
                subtitle: Text('You\'re all caught up!'),
              ),
            ),
          ];
        }

        return _notifications.map((notification) {
          return PopupMenuItem<RealtimeNotification>(
            value: notification,
            child: ListTile(
              leading: _getNotificationIcon(notification),
              title: Text(
                notification.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.message),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(notification.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        }).toList();
      },
    );
  }

  Widget _getNotificationIcon(RealtimeNotification notification) {
    switch (notification.type) {
      case NotificationType.securityAlert:
        return Icon(
          Icons.security,
          color: notification.severity == NotificationSeverity.critical
              ? Colors.red
              : Colors.orange,
        );
      case NotificationType.taskAssigned:
        return Icon(
          Icons.task_alt,
          color: notification.severity == NotificationSeverity.critical
              ? Colors.red
              : Colors.blue,
        );
      case NotificationType.teamMemberStatusChange:
        return const Icon(Icons.people, color: Colors.green);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Real-time notification data model
class RealtimeNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationSeverity severity;
  final Map<String, dynamic> data;

  RealtimeNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.severity,
    this.data = const {},
  });
}

enum NotificationType {
  securityAlert,
  taskAssigned,
  teamMemberStatusChange,
}

enum NotificationSeverity {
  info,
  low,
  medium,
  high,
  critical,
}
