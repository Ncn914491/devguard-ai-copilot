import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devguard_ai_copilot/core/utils/platform_utils.dart';
import 'package:devguard_ai_copilot/core/services/cross_platform_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Platform-Specific Tests', () {
    test('PlatformUtils correctly identifies current platform', () {
      // These tests will pass different values based on the actual platform
      expect(PlatformUtils.platformName, isA<String>());
      expect(PlatformUtils.platformName.isNotEmpty, isTrue);

      // At least one platform should be true
      final platformFlags = [
        PlatformUtils.isWeb,
        PlatformUtils.isAndroid,
        PlatformUtils.isIOS,
        PlatformUtils.isWindows,
        PlatformUtils.isMacOS,
        PlatformUtils.isLinux,
      ];
      expect(platformFlags.any((flag) => flag), isTrue);

      // Mobile and desktop should be mutually exclusive
      if (PlatformUtils.isMobile) {
        expect(PlatformUtils.isDesktop, isFalse);
      }
      if (PlatformUtils.isDesktop) {
        expect(PlatformUtils.isMobile, isFalse);
      }
    });

    test('Platform capabilities are correctly reported', () {
      if (PlatformUtils.isWeb) {
        expect(PlatformUtils.supportsEmbeddedTerminal, isFalse);
        expect(PlatformUtils.supportsFileSystem, isFalse);
        expect(PlatformUtils.supportsNativeGit, isFalse);
      } else if (PlatformUtils.isDesktop) {
        expect(PlatformUtils.supportsEmbeddedTerminal, isTrue);
        expect(PlatformUtils.supportsFileSystem, isTrue);
        expect(PlatformUtils.supportsNativeGit, isTrue);
      } else if (PlatformUtils.isMobile) {
        expect(PlatformUtils.supportsEmbeddedTerminal, isFalse);
        expect(PlatformUtils.supportsFileSystem, isTrue);
        expect(PlatformUtils.supportsNativeGit, isFalse);
      }
    });

    test('Storage path is appropriate for platform', () {
      final storagePath = PlatformUtils.getStoragePath();
      expect(storagePath, isA<String>());
      expect(storagePath.isNotEmpty, isTrue);

      if (PlatformUtils.isWeb) {
        expect(storagePath, equals('web_storage'));
      } else if (PlatformUtils.isAndroid) {
        expect(storagePath, contains('android'));
      } else if (PlatformUtils.isWindows) {
        expect(storagePath, contains('DevGuard'));
      }
    });

    group('Cross-Platform Storage Tests', () {
      late CrossPlatformStorageService storage;

      setUp(() async {
        storage = CrossPlatformStorageService.instance;
        await storage.initialize();
      });

      test('String storage works on all platforms', () async {
        const key = 'test_string';
        const value = 'test_value';

        await storage.setString(key, value);
        final retrieved = storage.getString(key);

        expect(retrieved, equals(value));
      });

      test('Boolean storage works on all platforms', () async {
        const key = 'test_bool';
        const value = true;

        await storage.setBool(key, value);
        final retrieved = storage.getBool(key);

        expect(retrieved, equals(value));
      });

      test('Integer storage works on all platforms', () async {
        const key = 'test_int';
        const value = 42;

        await storage.setInt(key, value);
        final retrieved = storage.getInt(key);

        expect(retrieved, equals(value));
      });

      test('Object storage works on all platforms', () async {
        const key = 'test_object';
        final value = {
          'name': 'test',
          'value': 123,
          'active': true,
          'items': ['a', 'b', 'c'],
        };

        await storage.setObject(key, value);
        final retrieved = storage.getObject(key);

        expect(retrieved, isNotNull);
        expect(retrieved!['name'], equals('test'));
        expect(retrieved['value'], equals(123));
        expect(retrieved['active'], equals(true));
        expect(retrieved['items'], equals(['a', 'b', 'c']));
      });

      test('List storage works on all platforms', () async {
        const key = 'test_list';
        final value = ['item1', 'item2', 'item3'];

        await storage.setList(key, value);
        final retrieved = storage.getList(key);

        expect(retrieved, equals(value));
      });

      test('Session management works on all platforms', () async {
        final sessionData = {
          'user_id': 'user123',
          'username': 'testuser',
          'login_time': DateTime.now().toIso8601String(),
          'permissions': ['read', 'write'],
        };

        await storage.saveSession(sessionData);
        final retrieved = storage.getSession();

        expect(retrieved, isNotNull);
        expect(retrieved!['user_id'], equals('user123'));
        expect(retrieved['username'], equals('testuser'));
        expect(retrieved['permissions'], equals(['read', 'write']));
      });

      test('Auth token management works on all platforms', () async {
        const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test';

        await storage.saveAuthToken(token);
        final retrieved = storage.getAuthToken();

        expect(retrieved, equals(token));
      });

      test('Project data persistence works on all platforms', () async {
        const projectId = 'project123';
        final projectData = {
          'name': 'Test Project',
          'description': 'A test project',
          'created_at': '2024-01-01T00:00:00Z',
          'settings': {
            'auto_deploy': true,
            'notifications': false,
          },
        };

        await storage.saveProjectData(projectId, projectData);
        final retrieved = storage.getProjectData(projectId);

        expect(retrieved, isNotNull);
        expect(retrieved!['name'], equals('Test Project'));
        expect(retrieved['settings']['auto_deploy'], equals(true));
      });

      test('Storage info provides platform details', () {
        final info = storage.getStorageInfo();

        expect(info, isA<Map<String, dynamic>>());
        expect(info['platform'], equals(PlatformUtils.platformName));
        expect(info['storage_path'], isA<String>());
        expect(info['supports_file_system'],
            equals(PlatformUtils.supportsFileSystem));
        expect(info['hive_keys'], isA<List>());
        expect(info['prefs_keys'], isA<List>());
      });

      test('Clear operations work on all platforms', () async {
        // Set some data
        await storage.setString('temp_key', 'temp_value');
        await storage.saveSession({'user': 'temp'});

        // Clear session
        await storage.clearSession();
        expect(storage.getSession(), isNull);
        expect(storage.getAuthToken(), isNull);

        // String data should still exist
        expect(storage.getString('temp_key'), equals('temp_value'));

        // Clear all
        await storage.clearAll();
        expect(storage.getString('temp_key'), isNull);
      });

      tearDown(() async {
        // Clean up test data
        await storage.clearAll();
      });
    });

    group('Platform-Specific Feature Tests', () {
      test('Web-specific features', () {
        if (PlatformUtils.isWeb) {
          // Test web-specific functionality
          expect(PlatformUtils.supportsEmbeddedTerminal, isFalse);
          expect(PlatformUtils.supportsFileSystem, isFalse);

          // Web should use browser storage
          final storagePath = PlatformUtils.getStoragePath();
          expect(storagePath, equals('web_storage'));
        }
      });

      test('Android-specific features', () {
        if (PlatformUtils.isAndroid) {
          // Test Android-specific functionality
          expect(PlatformUtils.isMobile, isTrue);
          expect(PlatformUtils.supportsFileSystem, isTrue);
          expect(PlatformUtils.supportsNativeGit, isFalse);

          // Android should use app-specific directory
          final storagePath = PlatformUtils.getStoragePath();
          expect(storagePath, contains('/data/data/'));
        }
      });

      test('Windows-specific features', () {
        if (PlatformUtils.isWindows) {
          // Test Windows-specific functionality
          expect(PlatformUtils.isDesktop, isTrue);
          expect(PlatformUtils.supportsEmbeddedTerminal, isTrue);
          expect(PlatformUtils.supportsNativeGit, isTrue);

          // Windows should use APPDATA directory
          final storagePath = PlatformUtils.getStoragePath();
          expect(storagePath, contains('DevGuard'));
        }
      });
    });
  });
}
