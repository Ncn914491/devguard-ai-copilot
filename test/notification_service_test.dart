import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/core/services/notification_service.dart';
import '../lib/core/api/websocket_service.dart';

// Generate mocks
@GenerateMocks([WebSocketService])
import 'notification_service_test.mocks.dart';

void main() {
  group('NotificationService Tests', () {
    late NotificationService notificationService;
    late MockWebSocketService mockWebSocketService;

    setUp(() {
      notificationService = NotificationService.instance;
      mockWebSocketService = MockWebSocketService();
    });

    test('should send real-time notification successfully', () async {
      // Arrange
      const userId = 'user123';
      const title = 'Test Notification';
      const message = 'This is a test notification';
      const type = NotificationType.info;

      when(mockWebSocketService.sendMessage(any)).thenAnswer((_) async => true);

      // Act
      final result = await notificationService.sendNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
      );

      // Assert
      expect(result, isTrue);
    });

    test('should send deployment notification', () async {
      // Arrange
      const deploymentId = 'deploy123';
      const status = 'success';
      const environment = 'production';

      // Act
      final result = await notificationService.sendDeploymentNotification(
        deploymentId: deploymentId,
        status: status,
        environment: environment,
      );

      // Assert
      expect(result, isTrue);
    });

    test('should send security alert notification', () async {
      // Arrange
      const alertId = 'alert123';
      const severity = 'high';
      const description = 'Suspicious activity detected';

      // Act
      final result = await notificationService.sendSecurityAlert(
        alertId: alertId,
        severity: severity,
        description: description,
      );

      // Assert
      expect(result, isTrue);
    });

    test('should send task assignment notification', () async {
      // Arrange
      const taskId = 'task123';
      const assigneeId = 'user456';
      const taskTitle = 'Fix critical bug';

      // Act
      final result = await notificationService.sendTaskAssignmentNotification(
        taskId: taskId,
        assigneeId: assigneeId,
        taskTitle: taskTitle,
      );

      // Assert
      expect(result, isTrue);
    });

    test('should send team member join notification', () async {
      // Arrange
      const memberName = 'John Doe';
      const memberEmail = 'john@example.com';
      const role = 'Developer';

      // Act
      final result = await notificationService.sendTeamMemberJoinNotification(
        memberName: memberName,
        memberEmail: memberEmail,
        role: role,
      );

      // Assert
      expect(result, isTrue);
    });

    test('should get notification history for user', () async {
      // Arrange
      const userId = 'user123';

      // Act
      final notifications =
          await notificationService.getNotificationHistory(userId);

      // Assert
      expect(notifications, isA<List<Map<String, dynamic>>>());
    });

    test('should mark notification as read', () async {
      // Arrange
      const notificationId = 'notif123';
      const userId = 'user123';

      // Act
      final result =
          await notificationService.markAsRead(notificationId, userId);

      // Assert
      expect(result, isTrue);
    });

    test('should get unread notification count', () async {
      // Arrange
      const userId = 'user123';

      // Act
      final count = await notificationService.getUnreadCount(userId);

      // Assert
      expect(count, isA<int>());
      expect(count, greaterThanOrEqualTo(0));
    });

    test('should subscribe to notification channel', () async {
      // Arrange
      const userId = 'user123';
      const channel = 'deployments';

      // Act
      final result =
          await notificationService.subscribeToChannel(userId, channel);

      // Assert
      expect(result, isTrue);
    });

    test('should unsubscribe from notification channel', () async {
      // Arrange
      const userId = 'user123';
      const channel = 'deployments';

      // Act
      final result =
          await notificationService.unsubscribeFromChannel(userId, channel);

      // Assert
      expect(result, isTrue);
    });

    test('should validate notification data', () {
      // Arrange
      const validTitle = 'Valid Title';
      const validMessage = 'Valid message content';
      const emptyTitle = '';
      const emptyMessage = '';

      // Act & Assert
      expect(
          notificationService.isValidNotificationData(validTitle, validMessage),
          isTrue);
      expect(
          notificationService.isValidNotificationData(emptyTitle, validMessage),
          isFalse);
      expect(
          notificationService.isValidNotificationData(validTitle, emptyMessage),
          isFalse);
    });

    test('should format notification payload correctly', () {
      // Arrange
      const userId = 'user123';
      const title = 'Test Title';
      const message = 'Test Message';
      const type = NotificationType.warning;

      // Act
      final payload = notificationService.formatNotificationPayload(
        userId: userId,
        title: title,
        message: message,
        type: type,
      );

      // Assert
      expect(payload, isA<Map<String, dynamic>>());
      expect(payload['userId'], equals(userId));
      expect(payload['title'], equals(title));
      expect(payload['message'], equals(message));
      expect(payload['type'], equals(type.toString()));
      expect(payload['timestamp'], isNotNull);
    });
  });
}

enum NotificationType {
  info,
  warning,
  error,
  success,
}
