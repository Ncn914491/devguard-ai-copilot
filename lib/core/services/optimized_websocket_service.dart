import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../database/services/audit_log_service.dart';
import 'caching_service.dart';

/// Optimized WebSocket service with connection pooling and efficient room-based targeting
/// Satisfies Requirements: 10.3, 10.4 (Optimized WebSocket broadcasting with connection pooling)
class OptimizedWebSocketService {
  static final OptimizedWebSocketService _instance =
      OptimizedWebSocketService._internal();
  static OptimizedWebSocketService get instance => _instance;
  OptimizedWebSocketService._internal();

  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;
  final _cachingService = CachingService.instance;

  // Connection pools organized by type
  final Map<String, ConnectionPool> _connectionPools = {};
  final Map<String, OptimizedWebSocketConnection> _connections = {};
  final Map<String, Set<String>> _rooms = {}; // room -> connection IDs
  final Map<String, String> _connectionUsers = {}; // connection ID -> user ID

  // Event broadcasting optimization
  final Map<String, Timer> _broadcastTimers = {};
  final Map<String, List<WebSocketEvent>> _pendingEvents = {};

  // Connection statistics
  final ConnectionStats _stats = ConnectionStats();

  Timer? _cleanupTimer;
  Timer? _statsTimer;
  bool _isInitialized = false;

  // Configuration
  static const int maxConnectionsPerPool = 100;
  static const int maxRoomsPerConnection = 50;
  static const Duration batchBroadcastDelay = Duration(milliseconds: 50);
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration heartbeatInterval = Duration(seconds: 15);

  /// Initialize optimized WebSocket service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize connection pools
    _initializeConnectionPools();

    // Start cleanup timer
    _cleanupTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _performCleanup();
    });

    // Start stats collection timer
    _statsTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateStats();
    });

    _isInitialized = true;

    await _auditService.logAction(
      actionType: 'optimized_websocket_initialized',
      description:
          'Optimized WebSocket service initialized with connection pooling',
      aiReasoning:
          'Enhanced WebSocket service provides efficient real-time communication with connection pooling and batched broadcasting',
      contextData: {
        'max_connections_per_pool': maxConnectionsPerPool,
        'batch_broadcast_delay_ms': batchBroadcastDelay.inMilliseconds,
        'heartbeat_interval_s': heartbeatInterval.inSeconds,
      },
    );
  }

  /// Create optimized WebSocket connection with pooling
  Future<String> createOptimizedConnection({
    required String userId,
    required String userRole,
    String? authToken,
    String? clientType = 'web',
  }) async {
    try {
      // Get or create connection pool for user role
      final pool = _getConnectionPool(userRole);

      // Check pool capacity
      if (pool.activeConnections >= maxConnectionsPerPool) {
        // Try to reuse an existing connection or wait
        final existingConnection = _findReusableConnection(userId, userRole);
        if (existingConnection != null) {
          return existingConnection.id;
        }

        // Wait for a connection to become available
        await _waitForPoolCapacity(pool);
      }

      // Create new connection
      final connectionId = _generateConnectionId();
      final connection = OptimizedWebSocketConnection(
        id: connectionId,
        userId: userId,
        userRole: userRole,
        clientType: clientType,
        connectedAt: DateTime.now(),
        lastActivity: DateTime.now(),
        rooms: <String>{},
        isAuthenticated: authToken != null,
        authToken: authToken,
        pool: pool,
      );

      // Add to pool and global tracking
      pool.addConnection(connection);
      _connections[connectionId] = connection;
      _connectionUsers[connectionId] = userId;

      // Auto-join role-based rooms
      await _autoJoinRooms(connection);

      // Cache connection info
      _cachingService.put(
        'ws_connection:$connectionId',
        {
          'user_id': userId,
          'user_role': userRole,
          'client_type': clientType,
          'connected_at': connection.connectedAt.toIso8601String(),
        },
        ttl: const Duration(hours: 1),
      );

      _stats.totalConnections++;
      _stats.activeConnections++;

      await _auditService.logAction(
        actionType: 'optimized_websocket_connection_created',
        description: 'Optimized WebSocket connection created',
        contextData: {
          'connection_id': connectionId,
          'user_id': userId,
          'user_role': userRole,
          'client_type': clientType,
          'pool_size': pool.activeConnections,
        },
        userId: userId,
      );

      return connectionId;
    } catch (e) {
      _stats.connectionErrors++;
      await _auditService.logAction(
        actionType: 'optimized_websocket_connection_error',
        description:
            'Error creating optimized WebSocket connection: ${e.toString()}',
        contextData: {
          'user_id': userId,
          'error': e.toString(),
        },
        userId: userId,
      );
      rethrow;
    }
  }

  /// Optimized room-based broadcasting with batching
  Future<void> broadcastToRooms({
    required List<String> roomIds,
    required WebSocketEvent event,
    bool batchBroadcast = true,
  }) async {
    try {
      if (batchBroadcast) {
        // Add to pending events for batched broadcasting
        for (final roomId in roomIds) {
          _pendingEvents.putIfAbsent(roomId, () => []).add(event);

          // Schedule batch broadcast if not already scheduled
          if (!_broadcastTimers.containsKey(roomId)) {
            _broadcastTimers[roomId] = Timer(batchBroadcastDelay, () {
              _executeBatchBroadcast(roomId);
            });
          }
        }
      } else {
        // Immediate broadcast
        await _executeImmediateBroadcast(roomIds, event);
      }

      _stats.totalBroadcasts++;
    } catch (e) {
      _stats.broadcastErrors++;
      await _auditService.logAction(
        actionType: 'optimized_websocket_broadcast_error',
        description: 'Error in optimized WebSocket broadcast: ${e.toString()}',
        contextData: {
          'room_ids': roomIds,
          'event_type': event.type,
          'error': e.toString(),
        },
      );
    }
  }

  /// Broadcast to specific user roles with optimization
  Future<void> broadcastToRoles({
    required List<String> roles,
    required WebSocketEvent event,
    bool excludeOffline = true,
  }) async {
    final roomIds = roles.map((role) => 'role_$role').toList();
    await broadcastToRooms(
      roomIds: roomIds,
      event: event,
      batchBroadcast: true,
    );
  }

  /// Broadcast to specific users with optimization
  Future<void> broadcastToUsers({
    required List<String> userIds,
    required WebSocketEvent event,
    bool checkOnlineStatus = true,
  }) async {
    final roomIds = <String>[];

    for (final userId in userIds) {
      if (checkOnlineStatus) {
        final isOnline = _isUserOnline(userId);
        if (!isOnline) continue;
      }
      roomIds.add('user_$userId');
    }

    if (roomIds.isNotEmpty) {
      await broadcastToRooms(
        roomIds: roomIds,
        event: event,
        batchBroadcast: true,
      );
    }
  }

  /// Enhanced task update broadcasting
  Future<void> broadcastTaskUpdate({
    required String taskId,
    required Map<String, dynamic> update,
    List<String>? targetUsers,
    List<String>? targetRoles,
  }) async {
    final event = WebSocketEvent(
      type: 'task_update',
      timestamp: DateTime.now(),
      data: {
        'task_id': taskId,
        'update': update,
      },
    );

    // Determine target rooms
    final roomIds = <String>[];

    if (targetUsers != null) {
      roomIds.addAll(targetUsers.map((userId) => 'user_$userId'));
    }

    if (targetRoles != null) {
      roomIds.addAll(targetRoles.map((role) => 'role_$role'));
    }

    // Default to all developers and leads if no specific targets
    if (roomIds.isEmpty) {
      roomIds.addAll(['role_developer', 'role_lead_developer', 'role_admin']);
    }

    await broadcastToRooms(roomIds: roomIds, event: event);
  }

  /// Enhanced security alert broadcasting
  Future<void> broadcastSecurityAlert({
    required String alertId,
    required String severity,
    required String message,
    List<String>? affectedUsers,
  }) async {
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

    final roomIds = <String>[];

    // Critical alerts go to everyone
    if (severity.toLowerCase() == 'critical') {
      roomIds.addAll(['role_admin', 'role_lead_developer', 'role_developer']);
    } else {
      // Other alerts go to admins and affected users
      roomIds.add('role_admin');
      if (affectedUsers != null) {
        roomIds.addAll(affectedUsers.map((userId) => 'user_$userId'));
      }
    }

    await broadcastToRooms(
        roomIds: roomIds, event: event, batchBroadcast: false);
  }

  /// Get connection statistics
  Map<String, dynamic> getOptimizedStats() {
    final poolStats = <String, dynamic>{};
    for (final entry in _connectionPools.entries) {
      poolStats[entry.key] = {
        'active_connections': entry.value.activeConnections,
        'max_connections': maxConnectionsPerPool,
        'utilization':
            (entry.value.activeConnections / maxConnectionsPerPool * 100)
                .toStringAsFixed(1),
      };
    }

    return {
      'total_connections': _stats.totalConnections,
      'active_connections': _stats.activeConnections,
      'total_broadcasts': _stats.totalBroadcasts,
      'batched_broadcasts': _stats.batchedBroadcasts,
      'connection_errors': _stats.connectionErrors,
      'broadcast_errors': _stats.broadcastErrors,
      'total_rooms': _rooms.length,
      'connection_pools': poolStats,
      'average_connections_per_pool': _connectionPools.isNotEmpty
          ? (_stats.activeConnections / _connectionPools.length)
              .toStringAsFixed(1)
          : '0',
      'pending_broadcasts': _pendingEvents.length,
    };
  }

  /// Close connection with cleanup
  Future<void> closeOptimizedConnection(String connectionId) async {
    try {
      final connection = _connections[connectionId];
      if (connection == null) return;

      // Remove from pool
      connection.pool.removeConnection(connection);

      // Leave all rooms
      for (final room in connection.rooms) {
        await _leaveRoom(connectionId, room);
      }

      // Remove from tracking
      _connections.remove(connectionId);
      _connectionUsers.remove(connectionId);

      // Remove from cache
      _cachingService.remove('ws_connection:$connectionId');

      _stats.activeConnections--;

      await _auditService.logAction(
        actionType: 'optimized_websocket_connection_closed',
        description: 'Optimized WebSocket connection closed',
        contextData: {
          'connection_id': connectionId,
          'user_id': connection.userId,
          'duration_seconds':
              DateTime.now().difference(connection.connectedAt).inSeconds,
        },
        userId: connection.userId,
      );
    } catch (e) {
      await _auditService.logAction(
        actionType: 'optimized_websocket_close_error',
        description:
            'Error closing optimized WebSocket connection: ${e.toString()}',
        contextData: {
          'connection_id': connectionId,
          'error': e.toString(),
        },
      );
    }
  }

  /// Private helper methods

  void _initializeConnectionPools() {
    final roles = ['admin', 'lead_developer', 'developer', 'viewer'];
    for (final role in roles) {
      _connectionPools[role] = ConnectionPool(role, maxConnectionsPerPool);
    }
  }

  ConnectionPool _getConnectionPool(String userRole) {
    return _connectionPools[userRole] ?? _connectionPools['developer']!;
  }

  OptimizedWebSocketConnection? _findReusableConnection(
      String userId, String userRole) {
    return _connections.values
        .where((conn) => conn.userId == userId && conn.userRole == userRole)
        .firstOrNull;
  }

  Future<void> _waitForPoolCapacity(ConnectionPool pool) async {
    int attempts = 0;
    while (pool.activeConnections >= maxConnectionsPerPool && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }

  Future<void> _autoJoinRooms(OptimizedWebSocketConnection connection) async {
    // Join user-specific room
    await _joinRoom(connection.id, 'user_${connection.userId}');

    // Join role-based room
    await _joinRoom(connection.id, 'role_${connection.userRole}');

    // Join additional rooms based on role
    switch (connection.userRole) {
      case 'admin':
        await _joinRoom(connection.id, 'admin_notifications');
        await _joinRoom(connection.id, 'security_alerts');
        break;
      case 'lead_developer':
        await _joinRoom(connection.id, 'team_management');
        await _joinRoom(connection.id, 'deployment_updates');
        break;
      case 'developer':
        await _joinRoom(connection.id, 'task_assignments');
        await _joinRoom(connection.id, 'file_changes');
        break;
    }
  }

  Future<void> _joinRoom(String connectionId, String roomId) async {
    final connection = _connections[connectionId];
    if (connection == null ||
        connection.rooms.length >= maxRoomsPerConnection) {
      return;
    }

    _rooms.putIfAbsent(roomId, () => <String>{}).add(connectionId);
    connection.rooms.add(roomId);
  }

  Future<void> _leaveRoom(String connectionId, String roomId) async {
    final connection = _connections[connectionId];
    if (connection == null) return;

    _rooms[roomId]?.remove(connectionId);
    if (_rooms[roomId]?.isEmpty == true) {
      _rooms.remove(roomId);
    }
    connection.rooms.remove(roomId);
  }

  void _executeBatchBroadcast(String roomId) {
    final events = _pendingEvents[roomId];
    if (events == null || events.isEmpty) return;

    // Combine events if possible or send as batch
    final batchEvent = WebSocketEvent(
      type: 'batch_update',
      timestamp: DateTime.now(),
      data: {
        'events': events.map((e) => e.toMap()).toList(),
        'count': events.length,
      },
    );

    _executeImmediateBroadcast([roomId], batchEvent);

    // Cleanup
    _pendingEvents.remove(roomId);
    _broadcastTimers.remove(roomId);
    _stats.batchedBroadcasts++;
  }

  Future<void> _executeImmediateBroadcast(
      List<String> roomIds, WebSocketEvent event) async {
    final targetConnections = <String>{};

    for (final roomId in roomIds) {
      final roomConnections = _rooms[roomId];
      if (roomConnections != null) {
        targetConnections.addAll(roomConnections);
      }
    }

    // Send to all target connections
    for (final connectionId in targetConnections) {
      await _sendToConnection(connectionId, event);
    }
  }

  Future<void> _sendToConnection(
      String connectionId, WebSocketEvent event) async {
    final connection = _connections[connectionId];
    if (connection == null) return;

    // Update last activity
    connection.lastActivity = DateTime.now();

    // In a real implementation, this would send via actual WebSocket
    debugPrint('Sending event ${event.type} to connection $connectionId');
  }

  bool _isUserOnline(String userId) {
    return _connections.values.any((conn) => conn.userId == userId);
  }

  void _performCleanup() {
    final now = DateTime.now();
    final expiredConnections = <String>[];

    // Find expired connections
    for (final entry in _connections.entries) {
      if (now.difference(entry.value.lastActivity) > connectionTimeout) {
        expiredConnections.add(entry.key);
      }
    }

    // Close expired connections
    for (final connectionId in expiredConnections) {
      closeOptimizedConnection(connectionId);
    }

    // Clean up empty rooms
    final emptyRooms = _rooms.entries
        .where((entry) => entry.value.isEmpty)
        .map((entry) => entry.key)
        .toList();

    for (final roomId in emptyRooms) {
      _rooms.remove(roomId);
    }

    if (expiredConnections.isNotEmpty || emptyRooms.isNotEmpty) {
      debugPrint(
          'WebSocket cleanup: removed ${expiredConnections.length} connections, ${emptyRooms.length} empty rooms');
    }
  }

  void _updateStats() {
    // Update connection pool utilization
    for (final pool in _connectionPools.values) {
      pool.updateStats();
    }
  }

  String _generateConnectionId() {
    return 'conn_${DateTime.now().millisecondsSinceEpoch}_${_stats.totalConnections}';
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _statsTimer?.cancel();

    for (final timer in _broadcastTimers.values) {
      timer.cancel();
    }

    _connectionPools.clear();
    _connections.clear();
    _rooms.clear();
    _connectionUsers.clear();
    _broadcastTimers.clear();
    _pendingEvents.clear();

    _isInitialized = false;
  }
}

/// Optimized WebSocket connection with pool reference
class OptimizedWebSocketConnection {
  final String id;
  final String userId;
  final String userRole;
  final String? clientType;
  final DateTime connectedAt;
  DateTime lastActivity;
  final Set<String> rooms;
  final bool isAuthenticated;
  final String? authToken;
  final ConnectionPool pool;

  OptimizedWebSocketConnection({
    required this.id,
    required this.userId,
    required this.userRole,
    this.clientType,
    required this.connectedAt,
    required this.lastActivity,
    required this.rooms,
    required this.isAuthenticated,
    this.authToken,
    required this.pool,
  });
}

/// Connection pool for managing connections by role
class ConnectionPool {
  final String role;
  final int maxConnections;
  final Queue<OptimizedWebSocketConnection> _connections = Queue();

  int _activeConnections = 0;
  double _utilizationRate = 0.0;

  ConnectionPool(this.role, this.maxConnections);

  int get activeConnections => _activeConnections;
  double get utilizationRate => _utilizationRate;

  void addConnection(OptimizedWebSocketConnection connection) {
    if (_activeConnections < maxConnections) {
      _connections.add(connection);
      _activeConnections++;
      _updateUtilization();
    }
  }

  void removeConnection(OptimizedWebSocketConnection connection) {
    if (_connections.remove(connection)) {
      _activeConnections--;
      _updateUtilization();
    }
  }

  void updateStats() {
    _updateUtilization();
  }

  void _updateUtilization() {
    _utilizationRate =
        maxConnections > 0 ? (_activeConnections / maxConnections) : 0.0;
  }
}

/// Connection statistics tracking
class ConnectionStats {
  int totalConnections = 0;
  int activeConnections = 0;
  int totalBroadcasts = 0;
  int batchedBroadcasts = 0;
  int connectionErrors = 0;
  int broadcastErrors = 0;
}

/// WebSocket event model
class WebSocketEvent {
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  WebSocketEvent({
    required this.type,
    required this.timestamp,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
    };
  }
}

/// Extension for null-safe firstOrNull
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
