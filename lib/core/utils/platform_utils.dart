import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart' as universal_io;

class PlatformUtils {
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Returns true if the platform supports embedded terminal
  static bool get supportsEmbeddedTerminal {
    return isDesktop;
  }

  /// Returns true if the platform supports file system operations
  static bool get supportsFileSystem {
    return !isWeb;
  }

  /// Returns true if the platform supports native git operations
  static bool get supportsNativeGit {
    return isDesktop;
  }

  /// Returns appropriate storage path for the platform
  static String getStoragePath() {
    if (isWeb) return 'web_storage';
    if (isAndroid) return '/data/data/com.devguard.ai_copilot/files';
    if (isWindows) {
      return '${universal_io.Platform.environment['APPDATA']}/DevGuard';
    }
    if (isMacOS) {
      return '${universal_io.Platform.environment['HOME']}/Library/Application Support/DevGuard';
    }
    if (isLinux) {
      return '${universal_io.Platform.environment['HOME']}/.devguard';
    }
    return './devguard_data';
  }

  /// Returns appropriate downloads path for the platform
  static String getDownloadsPath() {
    if (isWeb) return 'downloads'; // Web downloads are handled by browser
    if (isAndroid) return '/storage/emulated/0/Download';
    if (isWindows) {
      return '${universal_io.Platform.environment['USERPROFILE']}/Downloads';
    }
    if (isMacOS) {
      return '${universal_io.Platform.environment['HOME']}/Downloads';
    }
    if (isLinux) {
      return '${universal_io.Platform.environment['HOME']}/Downloads';
    }
    return './downloads';
  }
}
