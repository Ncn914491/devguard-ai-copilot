import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../lib/core/supabase/supabase_config.dart';

void main() {
  group('Supabase Setup Tests', () {
    setUpAll(() async {
      // Load environment variables for testing
      await dotenv.load(fileName: '.env');
    });

    test('should load Supabase configuration from environment', () {
      expect(SupabaseConfig.validateConfig(), isTrue);
      expect(SupabaseConfig.supabaseUrl, isNotEmpty);
      expect(SupabaseConfig.supabaseAnonKey, isNotEmpty);
    });

    test('should provide configuration summary', () {
      final summary = SupabaseConfig.getConfigSummary();
      expect(summary['supabase_url_configured'], isTrue);
      expect(summary['supabase_anon_key_configured'], isTrue);
      expect(summary['supabase_url'], contains('https://'));
    });

    test('should validate Supabase URL format', () {
      final url = SupabaseConfig.supabaseUrl;
      expect(url, startsWith('https://'));
      expect(url, contains('.supabase.co'));
    });

    test('should have service role key configured', () {
      final serviceKey = SupabaseConfig.supabaseServiceRoleKey;
      expect(serviceKey, isNotNull);
      expect(serviceKey, isNotEmpty);
    });
  });
}
