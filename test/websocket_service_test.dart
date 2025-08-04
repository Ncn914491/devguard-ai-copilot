import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:async';
import '../lib/core/api/websocket_service.dart';

// Generate mocks
@GenerateMocks([])
import 'websocket_service_test.mocks.dart';

void main() {
  group('WebSocketService Tests', () {
    late WebSocketService webSocketService;

    setUp(() {
      webSocketService = WebSocketService.instance;
    });

    test('should connect to WebSocket server successfully', () async {
      // Arrange
      const url = 'ws://localhost:8080/ws';

      // Act
      final result = await webSocketService.connect(url);

      // Assert
      expect(result, isTrue);
      expect(webSocketService.isConnected, isTrue);
    });

    test('should disconnect from WebSocket server', () async {
      // Arrange
      const url = 'ws://localhost:8080/ws';
      await webSocketService.connect(url);

      // Act
      await webSocketService.disconnect();

      // Assert
      expect(webSocketService.isConnected, isFalse);
    });

    test('should send message through WebSocket', () async {
      // Arrange
      const url = 'ws://localhost:8080/ws';
      await webSocketService.connect(url);

      final message = {
        'type': 'notification',
        'data': {'title': 'Test', 'message': 'Test message'}
      };

      // Act
      final result = await webSocketService.sendMessage(message);

      // Assert
      expect(result, isTrue);
    });

    test('should receive messages from WebSocket', () async {
      // Arrange
      const url = 'ws://localhost:8080/ws';
      await webSocketService.connect(url);

      final receivedMessages = <Map<String, dynamic>>[];
      webSocketService.messageStream.listen((message) {
        receivedMessages.add(message);
      });

      // Act
      // Simulate receiving a message (in real scenario, this would come from server)
      final testMessage = {
        'type': 'deployment_update',
        'data': {'status': 'completed', 'deploymentId': 'deploy123'}
      };

      // Assert
      expect(
          webSocketService.messageStream, isA<Stream<Map<String, dynamic>>>());
    });

    test('should handle connection errors gracefully', () async {
      // Arrange
      const invalidUrl = 'ws://invalid-url:9999/ws';

      // Act & Assert
      expect(
        () => webSocketService.connect(invalidUrl),
        throwsA(isA<Exception>()),
      );
    });

    test('should reconnect automatically on connection loss', () async {
      // Arrange
      const url = 'ws://localhost:8080/ws';
      await webSocketService.connect(url);

      // Act
      // Simulate connection loss
      await webSocketService.simulateConnectionLoss();

      // Wait for reconnection attempt
      await Future.delayed(Duration(seconds: 2));

      // Assert
      expect(webSocketService.isReconnecting, isTrue);
    });

    test('should subscribe to specific channels', () async {
      // Arrange
      const url = 'ws://localhost:8080/ws';
      await webSocketService.connect(url);
      const channel = 'deployments';

      // Act
      final result = await webSocketService.subscribeToChannel(channel);

      // Assert
      expect(result, isTrue);
      expect(webSocketService.subscribedChannels, contains(channel));
    });

    test('should unsubscribe from channels', () async {
      // Arrange
      const url = 'ws://localhost:8080/ws';
      await webSocketService.connect(url);
      const channel = 'deployments';
      await webSocketService.subscribeToChannel(channel);

      // Act
      final result = await webSocketService.unsubscribeFromChannel(channel);

      // Assert
      expect(result, isTrue);
      expect(webSocketService.subscribedChannels, isNot(contains(channel)));
    });

    test('should send heartbeat messages', () async {
      // Arrange
      const url = 'ws://localhost:8080/ws';
      await webSocketService.connect(url);

      // Act
      final result = await webSocketService.sendHeartbeat();

      // Assert
      expect(result, isTrue);
    });

    test('should handle different message types', () async {
      // Arrange
      const url = 'ws://localhost:8080/ws';
      await webSocketService.connect(url);

      final notificationMessage = {
        'type': 'notification',
        'data': {'title': 'Test Notification'}
      };

      final deploymentMessage = {
        'type': 'deployment_update',
        'data': {'status': 'in_progress'}
      };

      final securityMessage = {
        'type': 'security_alert',
        'data': {'severity': 'high', 'description': 'Suspicious activity'}
      };

      // Act
      final notificationResult =
          await webSocketService.sendMessage(notificationMessage);
      final deploymentResult =
          await webSocketService.sendMessage(deploymentMessage);
      final securityResult =
          await webSocketService.sendMessage(securityMessage);

      // Assert
      expect(notificationResult, isTrue);
      expect(deploymentResult, isTrue);
      expect(securityResult, isTrue);
    });

    test('should validate message format', () {
      // Arrange
      final validMessage = {
        'type': 'notification',
        'data': {'title': 'Test'}
      };

      final invalidMessage = {'invalid': 'structure'};

      // Act & Assert
      expect(webSocketService.isValidMessage(validMessage), isTrue);
      expect(webSocketService.isValidMessage(invalidMessage), isFalse);
    });

    test('should get connection status', () {
      // Act
      final status = webSocketService.getConnectionStatus();

      // Assert
      expect(status, isA<Map<String, dynamic>>());
      expect(status.containsKey('connected'), isTrue);
      expect(status.containsKey('url'), isTrue);
      expect(status.containsKey('subscribedChannels'), isTrue);
    });

    test('should handle message queue when disconnected', () async {
      // Arrange
      final message = {
        'type': 'notification',
        'data': {'title': 'Queued Message'}
      };

      // Act
      final result = await webSocketService.sendMessage(message);

      // Assert
      expect(result, isFalse); // Should fail when not connected
      expect(webSocketService.queuedMessages, contains(message));
    });

    test('should process queued messages on reconnection', () async {
      // Arrange
      final message = {
        'type': 'notification',
        'data': {'title': 'Queued Message'}
      };

      await webSocketService
          .sendMessage(message); // This will queue the message

      // Act
      const url = 'ws://localhost:8080/ws';
      await webSocketService.connect(url);

      // Assert
      expect(webSocketService.queuedMessages, isEmpty);
    });

    test('should limit message queue size', () async {
      // Arrange
      const maxQueueSize = 100;

      // Act
      for (int i = 0; i < maxQueueSize + 10; i++) {
        await webSocketService.sendMessage({
          'type': 'test',
          'data': {'index': i}
        });
      }

      // Assert
      expect(webSocketService.queuedMessages.length,
          lessThanOrEqualTo(maxQueueSize));
    });
  });
}
