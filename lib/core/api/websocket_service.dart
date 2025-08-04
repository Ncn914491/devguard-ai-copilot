import 'dart:async';
import 'dart:math';
import '../auth/auth_service.dart';
import '../database/services/audit_log_service.dart';

/// WebSocket service for real-time updates and notifications
/// Satisfies Requirements: 4.1, 4.2, 4.3, 4.4, 4.5 (Real-time communication)
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  static WebSocketService get instance => _instance;
  WebSocketService._internal();

  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;

  // Connection management
  final Map<String, WebSocketConnection> _connections = {};
  final Map<String, Set<String>> _rooms = {}; // room -> connection IDs
  final Map<String, String> _connectionUsers = {}; // connection ID -> user ID
  final Map<String, DateTime> _connectionHeartbeats = {};

  // Event streams
  final StreamController<WebSocketEvent> _eventController =
      StreamController<WebSocketEvent>.broadcast();
  final StreamController<Map<String, dynamic>> _taskUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? _heartbeatTimer;
  bool _isInitialized = false;

  /// Get initialization status
  bool get isInitialized => _isInitialized;

  /// Get event stream
  Stream<WebSocketEvent> get eventStream => _eventController.stream;

  /// Get task update stream
  Stream<Map<String, dynamic>> get onTaskUpdate => _taskUpdateController.stream;

  /// Initialize WebSocket service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Start heartbeat timer
    _startHeartbeatTimer();

    _isInitialized = true;

    await _auditService.logAction(
      actionType: 'websocket_service_initialized',
      description: 'WebSocket service initialized for real-time communication',
      aiReasoning:
          'WebSocket service enables real-time updates for tasks, deployments, and collaboration',
      contextData: {
        'heartbeat_interval': 30,
        'max_connections': 1000,
      },
    );
  }

  /// Create new WebSocket connection with authentication
  /// Requirement 4.1: WebSocket service with authentication
  Future<String> createConnection(String userId, {String? authToken}) async {
    try {
      // Validate user
      if (userId.trim().isEmpty) {
        throw Exception('User ID is required for WebSocket connection');
      }

      // Authenticate connection if token provided
      bool isAuthenticated = false;
      String? userRole;

      if (authToken != null) {
        isAuthenticated = await _authenticateConnection(authToken);
        if (isAuthenticated) {
          final user = _authService.currentUser;
          userRole = user?.role;
        }
      }

      // Generate connection ID
      final connectionId = _generateConnectionId();

      // Create connection
      final connection = WebSocketConnection(
        id: connectionId,
        userId: userId,
        connectedAt: DateTime.now(),
        lastActivity: DateTime.now(),
        rooms: <String>{},
        isAuthenticated: isAuthenticated,
        userRole: userRole,
        authToken: authToken,
      );

      // Store connection
      _connections[connectionId] = connection;
      _connectionUsers[connectionId] = userId;
      _connectionHeartbeats[connectionId] = DateTime.now();

      // Join user to their personal room
      await _joinRoom(connectionId, 'user_$userId');

      // Join user to role-based room if authenticated
      if (isAuthenticated && userRole != null) {
        await _joinRoom(connectionId, 'role_$userRole');

        // Join to additional rooms based on role
        switch (userRole) {
          case 'admin':
            await _joinRoom(connectionId, 'admin_notifications');
            await _joinRoom(connectionId, 'security_alerts');
            await _joinRoom(connectionId, 'deployment_updates');
            break;
          case 'lead_developer':
            await _joinRoom(connectionId, 'team_management');
            await _joinRoom(connectionId, 'deployment_updates');
            await _joinRoom(connectionId, 'task_assignments');
            break;
          case 'developer':
            await _joinRoom(connectionId, 'task_assignments');
            await _joinRoom(connectionId, 'file_changes');
            await _joinRoom(connectionId, 'git_operations');
            break;
          case 'viewer':
            await _joinRoom(connectionId, 'public_updates');
            break;
        }
      }

      // Join to general team room for all authenticated users
      if (isAuthenticated) {
        await _joinRoom(connectionId, 'team_general');
      }

      // Broadcast user online status
      await _broadcastUserStatus(userId, 'online');

      await _auditService.logAction(
        actionType: 'websocket_connection_created',
        description: 'WebSocket connection established',
        contextData: {
          'connection_id': connectionId,
          'user_id': userId,
          'is_authenticated': isAuthenticated,
          'user_role': userRole,
          'total_connections': _connections.length,
        },
        userId: userId,
      );

      return connectionId;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_connection_error',
        description: 'Error creating WebSocket connection: ${e.toString()}',
        contextData: {
          'user_id': userId,
          'error': e.toString(),
        },
        userId: userId,
      );
      rethrow;
    }
  }

  /// Close WebSocket connection
  Future<void> closeConnection(String connectionId) async {
    try {
      final connection = _connections[connectionId];
      if (connection == null) return;

      final userId = connection.userId;

      // Leave all rooms
      for (final room in connection.rooms) {
        await _leaveRoom(connectionId, room);
      }

      // Remove connection
      _connections.remove(connectionId);
      _connectionUsers.remove(connectionId);
      _connectionHeartbeats.remove(connectionId);

      // Broadcast user offline status if no other connections
      final userConnections =
          _connections.values.where((c) => c.userId == userId).length;

      if (userConnections == 0) {
        await _broadcastUserStatus(userId, 'offline');
      }

      await _auditService.logAction(
        actionType: 'websocket_connection_closed',
        description: 'WebSocket connection closed',
        contextData: {
          'connection_id': connectionId,
          'user_id': userId,
          'duration_seconds':
              DateTime.now().difference(connection.connectedAt).inSeconds,
          'remaining_connections': _connections.length,
        },
        userId: userId,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_connection_close_error',
        description: 'Error closing WebSocket connection: ${e.toString()}',
        contextData: {
          'connection_id': connectionId,
          'error': e.toString(),
        },
      );
    }
  }

  /// Join room
  Future<void> joinRoom(String connectionId, String roomId) async {
    await _joinRoom(connectionId, roomId);
  }

  /// Leave room
  Future<void> leaveRoom(String connectionId, String roomId) async {
    await _leaveRoom(connectionId, roomId);
  }

  /// Broadcast task update
  /// Requirement 4.2: Real-time task assignment and status update notifications
  Future<void> broadcastTaskUpdate({
    required String taskId,
    required Map<String, dynamic> update,
    List<String>? targetUsers,
  }) async {
    try {
      final event = WebSocketEvent(
        type: 'task_update',
        timestamp: DateTime.now(),
        data: {
          'task_id': taskId,
          'update': update,
        },
      );

      // Use enhanced role-based broadcasting
      await _broadcastToRoleBasedRooms(
        event: event,
        targetUsers: targetUsers ?? ['team'],
        targetRoles: ['developer', 'lead_developer'],
        includeAdmins: true,
      );

      await _auditService.logAction(
        actionType: 'websocket_task_update_broadcast',
        description: 'Broadcasted task update via WebSocket',
        contextData: {
          'task_id': taskId,
          'update_type': update['action'],
          'target_users': targetUsers,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_task_update_error',
        description: 'Error broadcasting task update: ${e.toString()}',
        contextData: {
          'task_id': taskId,
          'error': e.toString(),
        },
      );
    }
  }

  /// Broadcast security alert
  /// Requirement 4.5: Security alert notifications
  Future<void> broadcastSecurityAlert({
    required String alertId,
    required String severity,
    required String message,
    List<String>? affectedUsers,
  }) async {
    try {
      final event = WebSocketEvent(
        type: 'security_alert',
        timestamp: DateTime.now(),
        data: {
          'alert_id': alertId,
          'severity': severity,
          'message': message,
          'affected_users': affectedUsers,
        },
      );

      // Use enhanced role-based broadcasting
      // Critical alerts go to everyone, others go to admins and affected users
      final isCritical = severity.toLowerCase() == 'critical';

      await _broadcastToRoleBasedRooms(
        event: event,
        targetUsers: isCritical ? ['all'] : affectedUsers,
        targetRoles: ['admin'],
        includeAdmins: true,
      );

      await _auditService.logAction(
        actionType: 'websocket_security_alert_broadcast',
        description: 'Broadcasted security alert via WebSocket',
        contextData: {
          'alert_id': alertId,
          'severity': severity,
          'is_critical': isCritical,
          'affected_users': affectedUsers,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_security_alert_error',
        description: 'Error broadcasting security alert: ${e.toString()}',
        contextData: {
          'alert_id': alertId,
          'error': e.toString(),
        },
      );
    }
  }

  /// Broadcast deployment status
  /// Requirement 4.3: Deployment status broadcasting
  Future<void> broadcastDeploymentStatus({
    required String deploymentId,
    required String status,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final event = WebSocketEvent(
        type: 'deployment_status',
        timestamp: DateTime.now(),
        data: {
          'deployment_id': deploymentId,
          'status': status,
          'message': message,
          'metadata': metadata,
        },
      );

      // Use enhanced role-based broadcasting
      // Failed deployments notify everyone, others notify admins and leads
      final isFailed = status.toLowerCase().contains('fail') ||
          status.toLowerCase().contains('error');

      await _broadcastToRoleBasedRooms(
        event: event,
        targetUsers: isFailed ? ['team'] : null,
        targetRoles: ['admin', 'lead_developer'],
        includeAdmins: true,
      );

      await _auditService.logAction(
        actionType: 'websocket_deployment_status_broadcast',
        description: 'Broadcasted deployment status via WebSocket',
        contextData: {
          'deployment_id': deploymentId,
          'status': status,
          'is_failed': isFailed,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_deployment_status_error',
        description: 'Error broadcasting deployment status: ${e.toString()}',
        contextData: {
          'deployment_id': deploymentId,
          'error': e.toString(),
        },
      );
    }
  }

  /// Broadcast team member status
  Future<void> broadcastTeamMemberStatus({
    required String userId,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final event = WebSocketEvent(
        type: 'team_member_status',
        timestamp: DateTime.now(),
        data: {
          'user_id': userId,
          'status': status,
          'metadata': metadata,
        },
      );

      // Send to all team members
      await _broadcastToRoom('role_admin', event);
      await _broadcastToRoom('role_lead_developer', event);
      await _broadcastToRoom('role_developer', event);

      await _auditService.logAction(
        actionType: 'websocket_team_member_status_broadcast',
        description: 'Broadcasted team member status via WebSocket',
        contextData: {
          'user_id': userId,
          'status': status,
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_team_member_status_error',
        description: 'Error broadcasting team member status: ${e.toString()}',
        contextData: {
          'user_id': userId,
          'error': e.toString(),
        },
      );
    }
  }

  /// Broadcast file change
  Future<void> broadcastFileChange({
    required String repositoryId,
    required String filePath,
    required Map<String, dynamic> change,
    List<String>? targetUsers,
  }) async {
    try {
      final event = WebSocketEvent(
        type: 'file_change',
        timestamp: DateTime.now(),
        data: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'change': change,
        },
      );

      if (targetUsers != null) {
        for (final userId in targetUsers) {
          await _broadcastToRoom('user_$userId', event);
        }
      } else {
        // Send to all developers
        await _broadcastToRoom('role_developer', event);
        await _broadcastToRoom('role_lead_developer', event);
        await _broadcastToRoom('role_admin', event);
      }

      await _auditService.logAction(
        actionType: 'websocket_file_change_broadcast',
        description: 'Broadcasted file change via WebSocket',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'change_type': change['action'],
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_file_change_error',
        description: 'Error broadcasting file change: ${e.toString()}',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'error': e.toString(),
        },
      );
    }
  }

  /// Broadcast file lock status
  Future<void> broadcastFileLock({
    required String repositoryId,
    required String filePath,
    required Map<String, dynamic> lock,
    List<String>? targetUsers,
  }) async {
    try {
      final event = WebSocketEvent(
        type: 'file_lock',
        timestamp: DateTime.now(),
        data: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'lock': lock,
        },
      );

      if (targetUsers != null) {
        for (final userId in targetUsers) {
          await _broadcastToRoom('user_$userId', event);
        }
      } else {
        // Send to all developers
        await _broadcastToRoom('role_developer', event);
        await _broadcastToRoom('role_lead_developer', event);
        await _broadcastToRoom('role_admin', event);
      }

      await _auditService.logAction(
        actionType: 'websocket_file_lock_broadcast',
        description: 'Broadcasted file lock via WebSocket',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'lock_action': lock['action'],
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_file_lock_error',
        description: 'Error broadcasting file lock: ${e.toString()}',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'error': e.toString(),
        },
      );
    }
  }

  /// Broadcast merge conflict resolution
  Future<void> broadcastConflictResolution({
    required String repositoryId,
    required String filePath,
    required Map<String, dynamic> resolution,
    List<String>? targetUsers,
  }) async {
    try {
      final event = WebSocketEvent(
        type: 'conflict_resolution',
        timestamp: DateTime.now(),
        data: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'resolution': resolution,
        },
      );

      if (targetUsers != null) {
        for (final userId in targetUsers) {
          await _broadcastToRoom('user_$userId', event);
        }
      } else {
        // Send to all developers
        await _broadcastToRoom('role_developer', event);
        await _broadcastToRoom('role_lead_developer', event);
        await _broadcastToRoom('role_admin', event);
      }

      await _auditService.logAction(
        actionType: 'websocket_conflict_resolution_broadcast',
        description: 'Broadcasted conflict resolution via WebSocket',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'resolution_type': resolution['resolution_type'],
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_conflict_resolution_error',
        description: 'Error broadcasting conflict resolution: ${e.toString()}',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'error': e.toString(),
        },
      );
    }
  }

  /// Broadcast repository update
  Future<void> broadcastRepositoryUpdate({
    required String repositoryId,
    required Map<String, dynamic> update,
    List<String>? targetUsers,
  }) async {
    try {
      final event = WebSocketEvent(
        type: 'repository_update',
        timestamp: DateTime.now(),
        data: {
          'repository_id': repositoryId,
          'update': update,
        },
      );

      if (targetUsers != null) {
        for (final userId in targetUsers) {
          await _broadcastToRoom('user_$userId', event);
        }
      } else {
        // Send to all developers
        await _broadcastToRoom('role_developer', event);
        await _broadcastToRoom('role_lead_developer', event);
        await _broadcastToRoom('role_admin', event);
      }

      await _auditService.logAction(
        actionType: 'websocket_repository_update_broadcast',
        description: 'Broadcasted repository update via WebSocket',
        contextData: {
          'repository_id': repositoryId,
          'update_type': update['action'],
        },
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_repository_update_error',
        description: 'Error broadcasting repository update: ${e.toString()}',
        contextData: {
          'repository_id': repositoryId,
          'error': e.toString(),
        },
      );
    }
  }

  /// Handle heartbeat from connection
  Future<void> handleHeartbeat(String connectionId) async {
    final connection = _connections[connectionId];
    if (connection != null) {
      _connectionHeartbeats[connectionId] = DateTime.now();

      // Update last activity
      final updatedConnection = connection.copyWith(
        lastActivity: DateTime.now(),
      );
      _connections[connectionId] = updatedConnection;
    }
  }

  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    final now = DateTime.now();
    final activeConnections = _connections.values
        .where((c) => now.difference(c.lastActivity).inMinutes < 5)
        .length;

    return {
      'total_connections': _connections.length,
      'active_connections': activeConnections,
      'total_rooms': _rooms.length,
      'unique_users': _connectionUsers.values.toSet().length,
    };
  }

  /// Private helper methods

  /// Authenticate WebSocket connection
  /// Requirement 4.1: WebSocket service with authentication
  Future<bool> _authenticateConnection(String authToken) async {
    try {
      // In a real implementation, this would validate the JWT token
      // For now, we'll do a basic validation
      if (authToken.isEmpty || !authToken.startsWith('Bearer ')) {
        return false;
      }

      final token = authToken.substring(7); // Remove 'Bearer ' prefix

      // Validate token format (simplified)
      if (token.length < 10) {
        return false;
      }

      // In a real implementation, you would:
      // 1. Decode and validate JWT token
      // 2. Check token expiration
      // 3. Verify token signature
      // 4. Load user from database

      await _auditService.logAction(
        actionType: 'websocket_authentication_attempt',
        description: 'WebSocket connection authentication attempted',
        contextData: {
          'token_length': token.length,
          'success': true,
        },
      );

      return true;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_authentication_error',
        description: 'WebSocket authentication error: ${e.toString()}',
        contextData: {
          'error': e.toString(),
        },
      );
      return false;
    }
  }

  /// Enhanced room-based broadcasting with role targeting
  /// Requirement 4.1: Room-based targeting
  Future<void> _broadcastToRoleBasedRooms({
    required WebSocketEvent event,
    List<String>? targetRoles,
    List<String>? targetUsers,
    bool includeAdmins = false,
  }) async {
    final Set<String> targetConnectionIds = <String>{};

    // Add specific users
    if (targetUsers != null) {
      for (final userId in targetUsers) {
        if (userId == 'all') {
          targetConnectionIds.addAll(_connections.keys);
        } else if (userId == 'team') {
          // Add all authenticated team members
          final teamConnections = _connections.values
              .where((c) => c.isAuthenticated)
              .map((c) => c.id);
          targetConnectionIds.addAll(teamConnections);
        } else if (userId.startsWith('role_')) {
          // Add users with specific role
          final role = userId.substring(5);
          final roleConnections = _connections.values
              .where((c) => c.userRole == role)
              .map((c) => c.id);
          targetConnectionIds.addAll(roleConnections);
        } else {
          // Add specific user
          final userConnections = _connections.values
              .where((c) => c.userId == userId)
              .map((c) => c.id);
          targetConnectionIds.addAll(userConnections);
        }
      }
    }

    // Add specific roles
    if (targetRoles != null) {
      for (final role in targetRoles) {
        final roleConnections = _connections.values
            .where((c) => c.userRole == role)
            .map((c) => c.id);
        targetConnectionIds.addAll(roleConnections);
      }
    }

    // Always include admins for critical notifications
    if (includeAdmins) {
      final adminConnections = _connections.values
          .where((c) => c.userRole == 'admin')
          .map((c) => c.id);
      targetConnectionIds.addAll(adminConnections);
    }

    // Send to all target connections
    for (final connectionId in targetConnectionIds) {
      await _sendToConnection(connectionId, event);
    }

    await _auditService.logAction(
      actionType: 'websocket_role_based_broadcast',
      description: 'Role-based WebSocket broadcast completed',
      contextData: {
        'event_type': event.type,
        'target_roles': targetRoles,
        'target_users': targetUsers,
        'include_admins': includeAdmins,
        'connections_reached': targetConnectionIds.length,
      },
    );
  }

  /// Enhanced presence management
  /// Requirement 4.4: Team member presence indicators
  Future<void> updateUserPresence({
    required String userId,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userConnections =
          _connections.values.where((c) => c.userId == userId).toList();

      if (userConnections.isEmpty && status != 'offline') {
        // User is not connected but trying to set online status
        return;
      }

      final presenceEvent = WebSocketEvent(
        type: 'user_presence_update',
        timestamp: DateTime.now(),
        data: {
          'user_id': userId,
          'status': status,
          'metadata': metadata,
          'connection_count': userConnections.length,
        },
      );

      // Broadcast to team members
      await _broadcastToRoleBasedRooms(
        event: presenceEvent,
        targetUsers: ['team'],
      );

      await _auditService.logAction(
        actionType: 'websocket_presence_updated',
        description: 'User presence updated',
        contextData: {
          'user_id': userId,
          'status': status,
          'connection_count': userConnections.length,
        },
        userId: userId,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_presence_update_error',
        description: 'Error updating user presence: ${e.toString()}',
        contextData: {
          'user_id': userId,
          'error': e.toString(),
        },
        userId: userId,
      );
      rethrow;
    }
  }

  /// Get online users with presence information
  /// Requirement 4.4: Team member presence indicators
  Map<String, dynamic> getOnlineUsers() {
    final onlineUsers = <String, Map<String, dynamic>>{};
    final now = DateTime.now();

    for (final connection in _connections.values) {
      final isActive = now.difference(connection.lastActivity).inMinutes < 5;
      final userId = connection.userId;

      if (!onlineUsers.containsKey(userId)) {
        onlineUsers[userId] = {
          'user_id': userId,
          'status': isActive ? 'online' : 'away',
          'last_activity': connection.lastActivity.toIso8601String(),
          'connection_count': 0,
          'is_authenticated': connection.isAuthenticated,
          'role': connection.userRole,
        };
      }

      final userData = onlineUsers[userId]!;
      userData['connection_count'] = (userData['connection_count'] as int) + 1;

      // Update to most recent activity
      final lastActivity = DateTime.parse(userData['last_activity'] as String);
      if (connection.lastActivity.isAfter(lastActivity)) {
        userData['last_activity'] = connection.lastActivity.toIso8601String();
        userData['status'] = isActive ? 'online' : 'away';
      }
    }

    return {
      'online_users': onlineUsers,
      'total_unique_users': onlineUsers.length,
      'total_connections': _connections.length,
      'timestamp': now.toIso8601String(),
    };
  }

  /// Join room implementation
  Future<void> _joinRoom(String connectionId, String roomId) async {
    final connection = _connections[connectionId];
    if (connection == null) return;

    // Add connection to room
    _rooms.putIfAbsent(roomId, () => <String>{}).add(connectionId);

    // Update connection rooms
    final updatedConnection = connection.copyWith(
      rooms: {...connection.rooms, roomId},
    );
    _connections[connectionId] = updatedConnection;

    await _auditService.logAction(
      actionType: 'websocket_room_joined',
      description: 'Connection joined room: $roomId',
      contextData: {
        'connection_id': connectionId,
        'room_id': roomId,
        'room_size': _rooms[roomId]?.length ?? 0,
      },
      userId: connection.userId,
    );
  }

  /// Leave room implementation
  Future<void> _leaveRoom(String connectionId, String roomId) async {
    final connection = _connections[connectionId];
    if (connection == null) return;

    // Remove connection from room
    _rooms[roomId]?.remove(connectionId);
    if (_rooms[roomId]?.isEmpty == true) {
      _rooms.remove(roomId);
    }

    // Update connection rooms
    final updatedRooms = Set<String>.from(connection.rooms);
    updatedRooms.remove(roomId);

    final updatedConnection = connection.copyWith(rooms: updatedRooms);
    _connections[connectionId] = updatedConnection;

    await _auditService.logAction(
      actionType: 'websocket_room_left',
      description: 'Connection left room: $roomId',
      contextData: {
        'connection_id': connectionId,
        'room_id': roomId,
        'room_size': _rooms[roomId]?.length ?? 0,
      },
      userId: connection.userId,
    );
  }

  /// Broadcast to specific room
  Future<void> _broadcastToRoom(String roomId, WebSocketEvent event) async {
    final connectionIds = _rooms[roomId];
    if (connectionIds == null || connectionIds.isEmpty) return;

    for (final connectionId in connectionIds) {
      await _sendToConnection(connectionId, event);
    }
  }

  /// Broadcast to all connections
  Future<void> _broadcastToAll(WebSocketEvent event) async {
    for (final connectionId in _connections.keys) {
      await _sendToConnection(connectionId, event);
    }
  }

  /// Send event to specific connection
  Future<void> _sendToConnection(
      String connectionId, WebSocketEvent event) async {
    final connection = _connections[connectionId];
    if (connection == null) return;

    try {
      // In a real implementation, this would send via actual WebSocket
      // For now, we'll add to the event stream
      _eventController.add(event.copyWith(
        metadata: {
          'connection_id': connectionId,
          'user_id': connection.userId,
        },
      ));

      // If it's a task update, also add to task update stream
      if (event.type == 'task_update') {
        _taskUpdateController.add(event.data);
      }

      // Update connection activity
      final updatedConnection = connection.copyWith(
        lastActivity: DateTime.now(),
      );
      _connections[connectionId] = updatedConnection;
    } catch (e) {
      await _auditService.logAction(
        actionType: 'websocket_send_error',
        description: 'Error sending WebSocket event: ${e.toString()}',
        contextData: {
          'connection_id': connectionId,
          'event_type': event.type,
          'error': e.toString(),
        },
        userId: connection.userId,
      );
    }
  }

  /// Broadcast user status change
  Future<void> _broadcastUserStatus(String userId, String status) async {
    await broadcastTeamMemberStatus(
      userId: userId,
      status: status,
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Start heartbeat timer
  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnectionHealth();
    });
  }

  /// Check connection health and remove stale connections
  void _checkConnectionHealth() {
    final now = DateTime.now();
    final staleConnections = <String>[];

    for (final entry in _connectionHeartbeats.entries) {
      final connectionId = entry.key;
      final lastHeartbeat = entry.value;

      // Consider connection stale if no heartbeat for 2 minutes
      if (now.difference(lastHeartbeat).inMinutes > 2) {
        staleConnections.add(connectionId);
      }
    }

    // Remove stale connections
    for (final connectionId in staleConnections) {
      closeConnection(connectionId);
    }
  }

  /// Generate unique connection ID
  String _generateConnectionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = random.nextInt(10000);
    return 'ws_${timestamp}_$randomSuffix';
  }

  /// Dispose resources
  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _connections.clear();
    _rooms.clear();
    _connectionUsers.clear();
    _connectionHeartbeats.clear();

    _eventController.close();
    _taskUpdateController.close();
    _isInitialized = false;
  }
}

/// WebSocket connection model
class WebSocketConnection {
  final String id;
  final String userId;
  final DateTime connectedAt;
  final DateTime lastActivity;
  final Set<String> rooms;
  final bool isAuthenticated;
  final String? userRole;
  final String? authToken;

  WebSocketConnection({
    required this.id,
    required this.userId,
    required this.connectedAt,
    required this.lastActivity,
    required this.rooms,
    this.isAuthenticated = false,
    this.userRole,
    this.authToken,
  });

  WebSocketConnection copyWith({
    String? id,
    String? userId,
    DateTime? connectedAt,
    DateTime? lastActivity,
    Set<String>? rooms,
    bool? isAuthenticated,
    String? userRole,
    String? authToken,
  }) {
    return WebSocketConnection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      connectedAt: connectedAt ?? this.connectedAt,
      lastActivity: lastActivity ?? this.lastActivity,
      rooms: rooms ?? this.rooms,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userRole: userRole ?? this.userRole,
      authToken: authToken ?? this.authToken,
    );
  }
}

/// WebSocket event model
class WebSocketEvent {
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final Map<String, dynamic>? metadata;

  WebSocketEvent({
    required this.type,
    required this.timestamp,
    required this.data,
    this.metadata,
  });

  WebSocketEvent copyWith({
    String? type,
    DateTime? timestamp,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
  }) {
    return WebSocketEvent(
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
      'metadata': metadata,
    };
  }

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
      data: json['data'],
      metadata: json['metadata'],
    );
  }
}
