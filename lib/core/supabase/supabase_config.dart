import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration class for Supabase settings
/// Manages environment-specific configuration and validation
class SupabaseConfig {
  static const String _supabaseUrlKey = 'SUPABASE_URL';
  static const String _supabaseAnonKeyKey = 'SUPABASE_ANON_KEY';
  static const String _supabaseServiceRoleKeyKey = 'SUPABASE_SERVICE_ROLE_KEY';

  /// Get Supabase URL from environment
  static String get supabaseUrl {
    final url = dotenv.env[_supabaseUrlKey];
    if (url == null || url.isEmpty) {
      throw Exception('$_supabaseUrlKey not found in environment variables');
    }
    return url;
  }

  /// Get Supabase anonymous key from environment
  static String get supabaseAnonKey {
    final key = dotenv.env[_supabaseAnonKeyKey];
    if (key == null || key.isEmpty) {
      throw Exception(
          '$_supabaseAnonKeyKey not found in environment variables');
    }
    return key;
  }

  /// Get Supabase service role key from environment (for admin operations)
  static String? get supabaseServiceRoleKey {
    return dotenv.env[_supabaseServiceRoleKeyKey];
  }

  /// Validate that all required Supabase configuration is present
  static bool validateConfig() {
    try {
      supabaseUrl;
      supabaseAnonKey;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get configuration summary for debugging
  static Map<String, dynamic> getConfigSummary() {
    return {
      'supabase_url_configured':
          dotenv.env[_supabaseUrlKey]?.isNotEmpty ?? false,
      'supabase_anon_key_configured':
          dotenv.env[_supabaseAnonKeyKey]?.isNotEmpty ?? false,
      'supabase_service_role_key_configured':
          dotenv.env[_supabaseServiceRoleKeyKey]?.isNotEmpty ?? false,
      'supabase_url':
          dotenv.env[_supabaseUrlKey]?.substring(0, 30) ?? 'Not configured',
    };
  }
}
