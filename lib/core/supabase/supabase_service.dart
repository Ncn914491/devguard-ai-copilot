import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'supabase_config.dart';

/// Connection states for Supabase client
enum SupabaseConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  reconnecting,
}

/// Central service for managing Supabase client initialization and configuration
/// Provides singleton access to Supabase client with proper error handling
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  static SupabaseService get instance => _instance;

  SupabaseService._internal();

  SupabaseClient? _client;
  bool _isInitialized = false;
  SupabaseConnectionState _connectionState =
      SupabaseConnectionState.disconnected;
  String? _lastError;
  DateTime? _lastConnectionAttempt;

  /// Get the Supabase client instance
  SupabaseClient get client {
    if (!_isInitialized || _client == null) {
      throw Exception(
          'Supabase client not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Check if Supabase is initialized
  bool get isInitialized => _isInitialized;

  /// Get current connection state
  SupabaseConnectionState get connectionState => _connectionState;

  /// Get last error message
  String? get lastError => _lastError;

  /// Check if client is connected and ready
  bool get isConnected =>
      _isInitialized && _connectionState == SupabaseConnectionState.connected;

  /// Get connection status summary
  Map<String, dynamic> get connectionStatus => {
        'isInitialized': _isInitialized,
        'connectionState': _connectionState.toString(),
        'lastError': _lastError,
        'lastConnectionAttempt': _lastConnectionAttempt?.toIso8601String(),
        'hasValidSession': currentSession != null,
      };

  /// Initialize Supabase client with environment configuration
  Future<void> initialize() async {
    _connectionState = SupabaseConnectionState.connecting;
    _lastConnectionAttempt = DateTime.now();
    _lastError = null;

    try {
      // Load environment variables if not already loaded
      if (!SupabaseConfig.validateConfig()) {
        await dotenv.load(fileName: '.env');
      }

      // Validate configuration
      if (!SupabaseConfig.validateConfig()) {
        throw Exception(
            'Supabase configuration is incomplete. Check environment variables.');
      }

      final supabaseUrl = SupabaseConfig.supabaseUrl;
      final supabaseAnonKey = SupabaseConfig.supabaseAnonKey;

      debugPrint('🔄 Initializing Supabase...');
      debugPrint('🔗 URL: ${supabaseUrl.substring(0, 30)}...');

      // Initialize Supabase
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );

      _client = Supabase.instance.client;
      _isInitialized = true;

      debugPrint('✅ Supabase initialized successfully');
      debugPrint('🔗 Connected to: $supabaseUrl');
      debugPrint('📊 Config: ${SupabaseConfig.getConfigSummary()}');

      // Test connection
      await _testConnection();

      _connectionState = SupabaseConnectionState.connected;
      debugPrint('✅ Supabase connection established');
    } catch (e) {
      _lastError = e.toString();
      _connectionState = SupabaseConnectionState.error;
      _isInitialized = false;

      debugPrint('❌ Supabase initialization failed: $e');
      debugPrint('📊 Config: ${SupabaseConfig.getConfigSummary()}');
      rethrow;
    }
  }

  /// Test Supabase connection
  Future<void> _testConnection() async {
    try {
      // Simple query to test connection
      await _client!.from('users').select('count').limit(1);
      debugPrint('✅ Supabase connection test successful');
    } catch (e) {
      debugPrint('⚠️  Supabase connection test failed: $e');
      // Don't throw here as tables might not exist yet during initial setup
    }
  }

  /// Get current user from Supabase Auth
  User? get currentUser => _client?.auth.currentUser;

  /// Get current session from Supabase Auth
  Session? get currentSession => _client?.auth.currentSession;

  /// Reconnect to Supabase with retry logic
  Future<void> reconnect({int maxRetries = 3}) async {
    if (_connectionState == SupabaseConnectionState.connecting ||
        _connectionState == SupabaseConnectionState.reconnecting) {
      return; // Already attempting to connect
    }

    _connectionState = SupabaseConnectionState.reconnecting;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('🔄 Reconnection attempt $attempt/$maxRetries');
        await initialize();
        return; // Success
      } catch (e) {
        _lastError = e.toString();
        debugPrint('❌ Reconnection attempt $attempt failed: $e');

        if (attempt < maxRetries) {
          final delay = Duration(seconds: attempt * 2); // Exponential backoff
          debugPrint('⏳ Waiting ${delay.inSeconds}s before retry...');
          await Future.delayed(delay);
        }
      }
    }

    _connectionState = SupabaseConnectionState.error;
    throw Exception(
        'Failed to reconnect after $maxRetries attempts. Last error: $_lastError');
  }

  /// Check if reconnection is needed and attempt it
  Future<bool> ensureConnection() async {
    if (isConnected) return true;

    try {
      if (!_isInitialized) {
        await initialize();
      } else {
        await reconnect();
      }
      return true;
    } catch (e) {
      debugPrint('❌ Failed to ensure connection: $e');
      return false;
    }
  }

  /// Reset connection state (useful for testing)
  void reset() {
    _client = null;
    _isInitialized = false;
    _connectionState = SupabaseConnectionState.disconnected;
    _lastError = null;
    _lastConnectionAttempt = null;
  }

  /// Dispose resources
  void dispose() {
    _client = null;
    _isInitialized = false;
    _connectionState = SupabaseConnectionState.disconnected;
  }
}
