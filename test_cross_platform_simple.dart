import 'package:flutter_test/flutter_test.dart';
import 'package:devguard_ai_copilot/core/utils/platform_utils.dart';
import 'package:devguard_ai_copilot/core/utils/responsive_utils.dart';
import 'package:devguard_ai_copilot/core/services/cross_platform_storage_service.dart';

/// Simple cross-platform test runner that won't cause infinite loops
void main() {
  group('Cross-Platform Core Tests', () {
    test('Platform detection works correctly', () {
      // Test platform detection
      expect(PlatformUtils.platformName, isA<String>());
      expect(PlatformUtils.platformName.isNotEmpty, isTrue);

      // Test platform capabilities
      expect(PlatformUtils.supportsEmbeddedTerminal, isA<bool>());
      expect(PlatformUtils.supportsFileSystem, isA<bool>());
      expect(PlatformUtils.supportsNativeGit, isA<bool>());

      // Test storage path
      final storagePath = PlatformUtils.getStoragePath();
      expect(storagePath, isA<String>());
      expect(storagePath.isNotEmpty, isTrue);
    });

    test('Responsive utilities work correctly', () {
      // Test device type detection logic
      expect(ResponsiveUtils.mobileBreakpoint, equals(600));
      expect(ResponsiveUtils.tabletBreakpoint, equals(1024));

      // Test responsive calculations
      expect(
          ResponsiveUtils.mobileBreakpoint < ResponsiveUtils.tabletBreakpoint,
          isTrue);
    });

    test('Cross-platform storage service initializes', () async {
      final storage = CrossPlatformStorageService.instance;
      expect(storage, isNotNull);

      // Test basic functionality without actual initialization
      // to avoid platform-specific issues in test environment
      expect(() => storage.getStorageInfo(), returnsNormally);
    });

    test('Platform-specific features are correctly identified', () {
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

    test('Platform categorization is mutually exclusive', () {
      final platformFlags = [
        PlatformUtils.isWeb,
        PlatformUtils.isAndroid,
        PlatformUtils.isIOS,
        PlatformUtils.isWindows,
        PlatformUtils.isMacOS,
        PlatformUtils.isLinux,
      ];

      // Exactly one platform should be true
      final trueCount = platformFlags.where((flag) => flag).length;
      expect(trueCount, equals(1));

      // Mobile and desktop should be mutually exclusive
      if (PlatformUtils.isMobile) {
        expect(PlatformUtils.isDesktop, isFalse);
      }
      if (PlatformUtils.isDesktop) {
        expect(PlatformUtils.isMobile, isFalse);
      }
    });
  });

  group('Cross-Platform Storage Tests', () {
    late CrossPlatformStorageService storage;

    setUp(() {
      storage = CrossPlatformStorageService.instance;
    });

    test('Storage service provides platform information', () {
      final info = storage.getStorageInfo();

      expect(info, isA<Map<String, dynamic>>());
      expect(info['platform'], equals(PlatformUtils.platformName));
      expect(info['storage_path'], isA<String>());
      expect(info['supports_file_system'],
          equals(PlatformUtils.supportsFileSystem));
    });

    test('Storage service handles null values gracefully', () {
      // Test null handling without actual storage operations
      expect(() => storage.getString('non_existent_key'), returnsNormally);
      expect(storage.getString('non_existent_key'), isNull);

      expect(() => storage.getBool('non_existent_key'), returnsNormally);
      expect(storage.getBool('non_existent_key'), isNull);

      expect(() => storage.getInt('non_existent_key'), returnsNormally);
      expect(storage.getInt('non_existent_key'), isNull);

      expect(() => storage.getObject('non_existent_key'), returnsNormally);
      expect(storage.getObject('non_existent_key'), isNull);
    });
  });

  group('Error Handling Tests', () {
    test('Platform utils handle edge cases', () {
      // Test that platform detection doesn't throw
      expect(() => PlatformUtils.platformName, returnsNormally);
      expect(() => PlatformUtils.getStoragePath(), returnsNormally);

      // Test boolean properties
      expect(() => PlatformUtils.isMobile, returnsNormally);
      expect(() => PlatformUtils.isDesktop, returnsNormally);
      expect(() => PlatformUtils.isWeb, returnsNormally);
    });

    test('Responsive utils handle edge cases', () {
      // Test that responsive utilities don't throw
      expect(() => ResponsiveUtils.mobileBreakpoint, returnsNormally);
      expect(() => ResponsiveUtils.tabletBreakpoint, returnsNormally);

      // Test that breakpoints are reasonable
      expect(ResponsiveUtils.mobileBreakpoint, greaterThan(0));
      expect(ResponsiveUtils.tabletBreakpoint,
          greaterThan(ResponsiveUtils.mobileBreakpoint));
    });
  });
}
