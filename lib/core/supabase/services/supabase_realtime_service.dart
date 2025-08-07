import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';
import '../supabase_error_handler.dart';

/// Real-time subscription management for database changes
/// Provides table-specific and record-specific watching capabilities
/// Requirements: 10.1, 10.3, 10.4 - Real-time subscription management
class SupabaseRealtimeService {
  static final SupabaseRealtimeService _instance =
      SupabaseRealtimeService._internal();
  static SupabaseRealtimeService get instance => _instance;

  SupabaseRealtimeService._internal();

  /// Get the Supabase client instance
  SupabaseClient get _client => SupabaseService.instance.client;

  /// Map to track active subscriptions
  final Map<String, RealtimeChannel> _subscriptions = {};

  /// Map to track subscription controllers
  final Map<String, StreamController> _controllers = {};

  /// Map to track subscription listeners
  final Map<String, StreamSubscription> _listeners = {};

  /// Connection state tracking
  bool _isConnected = false;
  String? _lastError;

  /// Get connection status
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;

  /// Initialize real-time service
  Future<void> initialize() async {
    try {
      debugPrint('🔄 Initializing Supabase Realtime Service...');

      // Listen to connection state changes
      _client.realtime.onOpen(() {
        _isConnected = true;
        _lastError = null;
        debugPrint('✅ Realtime connection opened');
      });

      _client.realtime.onClose((event) {
        _isConnected = false;
        debugPrint('❌ Realtime connection closed: $event');
      });

      _client.realtime.onError((error) {
        _isConnected = false;
        _lastError = error.toString();
        debugPrint('❌ Realtime connection error: $error');
      });

      debugPrint('✅ Supabase Realtime Service initialized');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('❌ Failed to initialize Realtime Service: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch all records in a table for real-time updates
  Stream<List<T>> watchTable<T>({
    required String tableName,
    required T Function(Map<String, dynamic>) fromMap,
    String? filter,
    String? orderBy,
    bool ascending = true,
  }) {
    try {
      final subscriptionKey = 'table_${tableName}_${filter ?? 'all'}';

      // Return existing stream if already subscribed
      if (_controllers.containsKey(subscriptionKey)) {
        return _controllers[subscriptionKey]!.stream.cast<List<T>>();
      }

      // Create new stream controller
      final controller = StreamController<List<T>>.broadcast(
        onCancel: () => _unsubscribeFromTable(subscriptionKey),
      );
      _controllers[subscriptionKey] = controller;

      // Initial data fetch
      _fetchInitialTableData<T>(
        tableName: tableName,
        fromMap: fromMap,
        filter: filter,
        orderBy: orderBy,
        ascending: ascending,
        controller: controller,
      );

      // Set up real-time subscription
      _subscribeToTable<T>(
        subscriptionKey: subscriptionKey,
        tableName: tableName,
        fromMap: fromMap,
        filter: filter,
        controller: controller,
      );

      return controller.stream;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch a specific record for real-time updates
  Stream<T?> watchRecord<T>({
    required String tableName,
    required String recordId,
    required T Function(Map<String, dynamic>) fromMap,
  }) {
    try {
      final subscriptionKey = 'record_${tableName}_$recordId';

      // Return existing stream if already subscribed
      if (_controllers.containsKey(subscriptionKey)) {
        return _controllers[subscriptionKey]!.stream.cast<T?>();
      }

      // Create new stream controller
      final controller = StreamController<T?>.broadcast(
        onCancel: () => _unsubscribeFromRecord(subscriptionKey),
      );
      _controllers[subscriptionKey] = controller;

      // Initial data fetch
      _fetchInitialRecordData<T>(
        tableName: tableName,
        recordId: recordId,
        fromMap: fromMap,
        controller: controller,
      );

      // Set up real-time subscription
      _subscribeToRecord<T>(
        subscriptionKey: subscriptionKey,
        tableName: tableName,
        recordId: recordId,
        fromMap: fromMap,
        controller: controller,
      );

      return controller.stream;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Fetch initial data for table subscription
  Future<void> _fetchInitialTableData<T>({
    required String tableName,
    required T Function(Map<String, dynamic>) fromMap,
    String? filter,
    String? orderBy,
    bool ascending = true,
    required StreamController<List<T>> controller,
  }) async {
    try {
      dynamic query = _client.from(tableName).select();

      if (filter != null) {
        // Apply basic filter (can be extended for more complex filters)
        final filterParts = filter.split('=');
        if (filterParts.length == 2) {
          query = query.eq(filterParts[0].trim(), filterParts[1].trim());
        }
      }

      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      final response = await query;
      final data = (response as List<dynamic>)
          .map((item) => fromMap(item as Map<String, dynamic>))
          .toList();

      if (!controller.isClosed) {
        controller.add(data);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(SupabaseErrorHandler.handleError(e));
      }
    }
  }

  /// Fetch initial data for record subscription
  Future<void> _fetchInitialRecordData<T>({
    required String tableName,
    required String recordId,
    required T Function(Map<String, dynamic>) fromMap,
    required StreamController<T?> controller,
  }) async {
    try {
      final response = await _client
          .from(tableName)
          .select()
          .eq('id', recordId)
          .maybeSingle();

      final data = response != null ? fromMap(response) : null;

      if (!controller.isClosed) {
        controller.add(data);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(SupabaseErrorHandler.handleError(e));
      }
    }
  }

  /// Subscribe to table changes
  void _subscribeToTable<T>({
    required String subscriptionKey,
    required String tableName,
    required T Function(Map<String, dynamic>) fromMap,
    String? filter,
    required StreamController<List<T>> controller,
  }) {
    try {
      final channel = _client.realtime.channel(subscriptionKey);

      // Configure the channel for table changes
      var subscription = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: tableName,
        callback: (payload) {
          _handleTableChange<T>(
            payload: payload,
            tableName: tableName,
            fromMap: fromMap,
            filter: filter,
            controller: controller,
          );
        },
      );

      // Note: Filtering is handled at the application level
      // Real-time subscriptions receive all changes for the table

      // Subscribe to the channel
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('✅ Subscribed to table: $tableName');
        } else if (error != null) {
          debugPrint('❌ Subscription error for $tableName: $error');
          if (!controller.isClosed) {
            controller.addError(SupabaseErrorHandler.handleError(error));
          }
        }
      });

      _subscriptions[subscriptionKey] = channel;
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(SupabaseErrorHandler.handleError(e));
      }
    }
  }

  /// Subscribe to record changes
  void _subscribeToRecord<T>({
    required String subscriptionKey,
    required String tableName,
    required String recordId,
    required T Function(Map<String, dynamic>) fromMap,
    required StreamController<T?> controller,
  }) {
    try {
      final channel = _client.realtime.channel(subscriptionKey);

      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: tableName,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: recordId,
        ),
        callback: (payload) {
          _handleRecordChange<T>(
            payload: payload,
            fromMap: fromMap,
            controller: controller,
          );
        },
      );

      // Subscribe to the channel
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('✅ Subscribed to record: $tableName/$recordId');
        } else if (error != null) {
          debugPrint('❌ Subscription error for $tableName/$recordId: $error');
          if (!controller.isClosed) {
            controller.addError(SupabaseErrorHandler.handleError(error));
          }
        }
      });

      _subscriptions[subscriptionKey] = channel;
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(SupabaseErrorHandler.handleError(e));
      }
    }
  }

  /// Handle table change events
  void _handleTableChange<T>({
    required PostgresChangePayload payload,
    required String tableName,
    required T Function(Map<String, dynamic>) fromMap,
    String? filter,
    required StreamController<List<T>> controller,
  }) {
    try {
      debugPrint('📡 Table change event: ${payload.eventType} on $tableName');

      // Refetch all data when changes occur
      // This is a simple approach - could be optimized to handle individual changes
      _fetchInitialTableData<T>(
        tableName: tableName,
        fromMap: fromMap,
        filter: filter,
        controller: controller,
      );
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(SupabaseErrorHandler.handleError(e));
      }
    }
  }

  /// Handle record change events
  void _handleRecordChange<T>({
    required PostgresChangePayload payload,
    required T Function(Map<String, dynamic>) fromMap,
    required StreamController<T?> controller,
  }) {
    try {
      debugPrint('📡 Record change event: ${payload.eventType}');

      T? data;
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          if (payload.newRecord != null) {
            data = fromMap(payload.newRecord!);
          }
          break;
        case PostgresChangeEvent.delete:
          data = null;
          break;
        default:
          return;
      }

      if (!controller.isClosed) {
        controller.add(data);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(SupabaseErrorHandler.handleError(e));
      }
    }
  }

  /// Unsubscribe from table changes
  void _unsubscribeFromTable(String subscriptionKey) {
    try {
      final channel = _subscriptions[subscriptionKey];
      if (channel != null) {
        channel.unsubscribe();
        _subscriptions.remove(subscriptionKey);
        debugPrint('🔌 Unsubscribed from table: $subscriptionKey');
      }

      final controller = _controllers[subscriptionKey];
      if (controller != null && !controller.isClosed) {
        controller.close();
        _controllers.remove(subscriptionKey);
      }
    } catch (e) {
      debugPrint('❌ Error unsubscribing from table: $e');
    }
  }

  /// Unsubscribe from record changes
  void _unsubscribeFromRecord(String subscriptionKey) {
    try {
      final channel = _subscriptions[subscriptionKey];
      if (channel != null) {
        channel.unsubscribe();
        _subscriptions.remove(subscriptionKey);
        debugPrint('🔌 Unsubscribed from record: $subscriptionKey');
      }

      final controller = _controllers[subscriptionKey];
      if (controller != null && !controller.isClosed) {
        controller.close();
        _controllers.remove(subscriptionKey);
      }
    } catch (e) {
      debugPrint('❌ Error unsubscribing from record: $e');
    }
  }

  /// Unsubscribe from all subscriptions
  Future<void> unsubscribeAll() async {
    try {
      debugPrint('🔌 Unsubscribing from all real-time subscriptions...');

      // Close all controllers
      for (final controller in _controllers.values) {
        if (!controller.isClosed) {
          await controller.close();
        }
      }
      _controllers.clear();

      // Unsubscribe from all channels
      for (final channel in _subscriptions.values) {
        channel.unsubscribe();
      }
      _subscriptions.clear();

      // Cancel all listeners
      for (final listener in _listeners.values) {
        await listener.cancel();
      }
      _listeners.clear();

      debugPrint('✅ All real-time subscriptions closed');
    } catch (e) {
      debugPrint('❌ Error closing subscriptions: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get subscription status
  Map<String, dynamic> getSubscriptionStatus() {
    return {
      'isConnected': _isConnected,
      'lastError': _lastError,
      'activeSubscriptions': _subscriptions.length,
      'subscriptionKeys': _subscriptions.keys.toList(),
    };
  }

  /// Reconnect all subscriptions
  Future<void> reconnectAll() async {
    try {
      debugPrint('🔄 Reconnecting all real-time subscriptions...');

      // Store current subscription info
      final subscriptionInfo = <String, Map<String, dynamic>>{};
      for (final key in _subscriptions.keys) {
        subscriptionInfo[key] = {
          'key': key,
          'controller': _controllers[key],
        };
      }

      // Close all current subscriptions
      await unsubscribeAll();

      // Wait a moment for cleanup
      await Future.delayed(const Duration(milliseconds: 500));

      // Recreate subscriptions would require storing more context
      // For now, just log that reconnection is needed
      debugPrint('⚠️  Manual subscription recreation needed after reconnect');
    } catch (e) {
      debugPrint('❌ Error reconnecting subscriptions: $e');
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Dispose the service and clean up resources
  Future<void> dispose() async {
    try {
      await unsubscribeAll();
      _isConnected = false;
      _lastError = null;
      debugPrint('✅ Supabase Realtime Service disposed');
    } catch (e) {
      debugPrint('❌ Error disposing Realtime Service: $e');
    }
  }
}
