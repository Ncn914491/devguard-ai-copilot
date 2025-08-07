import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/platform_utils.dart';
import '../supabase/services/supabase_storage_service.dart';
import '../auth/auth_service.dart';
import 'package:logging/logging.dart';

class CrossPlatformStorageService {
  static final _logger = Logger('CrossPlatformStorageService');
  static CrossPlatformStorageService? _instance;
  static CrossPlatformStorageService get instance =>
      _instance ??= CrossPlatformStorageService._();

  CrossPlatformStorageService._();

  late SharedPreferences _prefs;
  Box? _hiveBox;
  bool _initialized = false;

  // Supabase integration for cloud storage
  final _storageService = SupabaseStorageService.instance;
  final _authService = AuthService.instance;
  static const String userDataBucket = 'user-data';

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize SharedPreferences for simple key-value storage
      _prefs = await SharedPreferences.getInstance();

      // Initialize Hive for complex data storage
      if (!kIsWeb) {
        await Hive.initFlutter(PlatformUtils.getStoragePath());
      } else {
        await Hive.initFlutter();
      }

      _hiveBox = await Hive.openBox('devguard_storage');

      _initialized = true;
      _logger.info(
          'Cross-platform storage initialized for ${PlatformUtils.platformName}');
    } catch (e) {
      _logger.severe('Failed to initialize storage: $e');
      rethrow;
    }
  }

  // Simple key-value operations
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  String? getString(String key) {
    return _prefs.getString(key);
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  // Complex data operations using Hive
  Future<void> setObject(String key, Map<String, dynamic> value) async {
    await _hiveBox?.put(key, value);
  }

  Map<String, dynamic>? getObject(String key) {
    final value = _hiveBox?.get(key);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> setList(String key, List<dynamic> value) async {
    await _hiveBox?.put(key, value);
  }

  List<dynamic>? getList(String key) {
    final value = _hiveBox?.get(key);
    if (value is List) {
      return List<dynamic>.from(value);
    }
    return null;
  }

  // Session management
  Future<void> saveSession(Map<String, dynamic> sessionData) async {
    await setObject('user_session', sessionData);
  }

  Map<String, dynamic>? getSession() {
    return getObject('user_session');
  }

  Future<void> clearSession() async {
    await _hiveBox?.delete('user_session');
    await _prefs.remove('auth_token');
  }

  // Authentication token management
  Future<void> saveAuthToken(String token) async {
    await setString('auth_token', token);
  }

  String? getAuthToken() {
    return getString('auth_token');
  }

  // Project data persistence
  Future<void> saveProjectData(
      String projectId, Map<String, dynamic> data) async {
    await setObject('project_$projectId', data);
  }

  Map<String, dynamic>? getProjectData(String projectId) {
    return getObject('project_$projectId');
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs.clear();
    await _hiveBox?.clear();
  }

  // Cloud storage operations using Supabase Storage

  /// Save user data to cloud storage
  Future<void> saveUserDataToCloud(
      String key, Map<String, dynamic> data) async {
    try {
      if (!_authService.isAuthenticated) {
        _logger.warning('Cannot save to cloud: user not authenticated');
        return;
      }

      final userId = _authService.currentUser!.id;
      final fileName = '$key.json';
      final filePath = '$userId/$fileName';

      // Create temporary file with JSON data
      final tempFile = File('${Directory.systemTemp.path}/temp_$fileName');
      await tempFile.writeAsString(jsonEncode(data));

      try {
        // Upload to Supabase Storage
        await _storageService.uploadFile(
          userDataBucket,
          filePath,
          tempFile,
        );

        _logger.info('User data saved to cloud: $key');
      } finally {
        // Clean up temporary file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      _logger.severe('Failed to save user data to cloud: $e');
    }
  }

  /// Load user data from cloud storage
  Future<Map<String, dynamic>?> loadUserDataFromCloud(String key) async {
    try {
      if (!_authService.isAuthenticated) {
        _logger.warning('Cannot load from cloud: user not authenticated');
        return null;
      }

      final userId = _authService.currentUser!.id;
      final fileName = '$key.json';
      final filePath = '$userId/$fileName';

      // Download from Supabase Storage
      final data = await _storageService.downloadFile(userDataBucket, filePath);
      final jsonString = String.fromCharCodes(data);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      _logger.info('User data loaded from cloud: $key');
      return jsonData;
    } catch (e) {
      _logger.warning('Failed to load user data from cloud: $e');
      return null;
    }
  }

  /// Sync local data with cloud storage
  Future<void> syncWithCloud() async {
    try {
      if (!_authService.isAuthenticated) {
        _logger.warning('Cannot sync with cloud: user not authenticated');
        return;
      }

      _logger.info('Starting cloud sync...');

      // Sync session data
      final sessionData = getSession();
      if (sessionData != null) {
        await saveUserDataToCloud('session', sessionData);
      }

      // Sync project data
      final hiveKeys = _hiveBox?.keys.toList() ?? [];
      for (final key in hiveKeys) {
        if (key.toString().startsWith('project_')) {
          final projectData = getObject(key.toString());
          if (projectData != null) {
            await saveUserDataToCloud(key.toString(), projectData);
          }
        }
      }

      _logger.info('Cloud sync completed');
    } catch (e) {
      _logger.severe('Cloud sync failed: $e');
    }
  }

  /// Restore data from cloud storage
  Future<void> restoreFromCloud() async {
    try {
      if (!_authService.isAuthenticated) {
        _logger.warning('Cannot restore from cloud: user not authenticated');
        return;
      }

      _logger.info('Starting cloud restore...');

      final userId = _authService.currentUser!.id;

      // List user files in cloud storage
      final files = await _storageService.listFiles(
        userDataBucket,
        prefix: '$userId/',
      );

      for (final file in files) {
        try {
          final fileName = file.name.split('/').last;
          final key = fileName.replaceAll('.json', '');

          final cloudData = await loadUserDataFromCloud(key);
          if (cloudData != null) {
            if (key == 'session') {
              await saveSession(cloudData);
            } else {
              await setObject(key, cloudData);
            }
          }
        } catch (e) {
          _logger.warning('Failed to restore file ${file.name}: $e');
        }
      }

      _logger.info('Cloud restore completed');
    } catch (e) {
      _logger.severe('Cloud restore failed: $e');
    }
  }

  /// Upload file to user's cloud storage
  Future<String?> uploadUserFile(File file, String fileName) async {
    try {
      if (!_authService.isAuthenticated) {
        _logger.warning('Cannot upload file: user not authenticated');
        return null;
      }

      final userId = _authService.currentUser!.id;
      final filePath = '$userId/files/$fileName';

      await _storageService.uploadFile(
        userDataBucket,
        filePath,
        file,
      );

      _logger.info('User file uploaded: $fileName');
      return filePath;
    } catch (e) {
      _logger.severe('Failed to upload user file: $e');
      return null;
    }
  }

  /// Download file from user's cloud storage
  Future<File?> downloadUserFile(String fileName) async {
    try {
      if (!_authService.isAuthenticated) {
        _logger.warning('Cannot download file: user not authenticated');
        return null;
      }

      final userId = _authService.currentUser!.id;
      final filePath = '$userId/files/$fileName';

      final data = await _storageService.downloadFile(userDataBucket, filePath);

      // Save to local temporary file
      final tempFile = File('${Directory.systemTemp.path}/$fileName');
      await tempFile.writeAsBytes(data);

      _logger.info('User file downloaded: $fileName');
      return tempFile;
    } catch (e) {
      _logger.severe('Failed to download user file: $e');
      return null;
    }
  }

  // Get storage info for debugging
  Map<String, dynamic> getStorageInfo() {
    return {
      'platform': PlatformUtils.platformName,
      'storage_path': PlatformUtils.getStoragePath(),
      'hive_keys': _hiveBox?.keys.toList() ?? [],
      'prefs_keys': _prefs.getKeys().toList(),
      'supports_file_system': PlatformUtils.supportsFileSystem,
      'cloud_storage_enabled': _authService.isAuthenticated,
      'user_id': _authService.currentUser?.id,
    };
  }
}
