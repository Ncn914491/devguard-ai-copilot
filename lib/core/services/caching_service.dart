import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// High-performance caching service with TTL, LRU eviction, and memory management
/// Satisfies Requirements: 10.1, 10.2 (Efficient caching strategies)
class CachingService {
  static final CachingService _instance = CachingService._internal();
  static CachingService get instance => _instance;
  CachingService._internal();

  // Cache storage with metadata
  final Map<String, CacheEntry> _cache = {};
  final Map<String, DateTime> _accessTimes = {};

  // Configuration
  static const int maxCacheSize = 1000;
  static const Duration defaultTTL = Duration(minutes: 15);
  static const Duration sessionTTL = Duration(hours: 2);
  static const Duration repositoryTTL = Duration(minutes: 30);
  static const Duration taskTTL = Duration(minutes: 10);

  // Cache statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  Timer? _cleanupTimer;
  bool _isInitialized = false;

  /// Initialize caching service with periodic cleanup
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Start periodic cleanup every 5 minutes
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _performCleanup();
    });

    _isInitialized = true;
    debugPrint('CachingService initialized with max size: $maxCacheSize');
  }

  /// Store value in cache with optional TTL
  void put(String key, dynamic value, {Duration? ttl}) {
    final effectiveTTL = ttl ?? _getTTLForKey(key);
    final expiresAt = DateTime.now().add(effectiveTTL);

    // Check if we need to evict entries
    if (_cache.length >= maxCacheSize) {
      _evictLRU();
    }

    _cache[key] = CacheEntry(
      value: value,
      expiresAt: expiresAt,
      createdAt: DateTime.now(),
    );
    _accessTimes[key] = DateTime.now();

    debugPrint('Cache PUT: $key (TTL: ${effectiveTTL.inMinutes}m)');
  }

  /// Retrieve value from cache
  T? get<T>(String key) {
    final entry = _cache[key];

    if (entry == null) {
      _misses++;
      return null;
    }

    // Check if expired
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      _accessTimes.remove(key);
      _misses++;
      return null;
    }

    // Update access time for LRU
    _accessTimes[key] = DateTime.now();
    _hits++;

    return entry.value as T?;
  }

  /// Check if key exists and is not expired
  bool containsKey(String key) {
    final entry = _cache[key];
    if (entry == null) return false;

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      _accessTimes.remove(key);
      return false;
    }

    return true;
  }

  /// Remove specific key from cache
  void remove(String key) {
    _cache.remove(key);
    _accessTimes.remove(key);
  }

  /// Clear all cache entries
  void clear() {
    _cache.clear();
    _accessTimes.clear();
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final totalRequests = _hits + _misses;
    final hitRate = totalRequests > 0 ? (_hits / totalRequests * 100) : 0.0;

    return {
      'size': _cache.length,
      'max_size': maxCacheSize,
      'hits': _hits,
      'misses': _misses,
      'evictions': _evictions,
      'hit_rate': hitRate.toStringAsFixed(2),
      'memory_usage_mb': _estimateMemoryUsage(),
    };
  }

  /// User session caching methods
  void putUserSession(String userId, Map<String, dynamic> sessionData) {
    put('session:$userId', sessionData, ttl: sessionTTL);
  }

  Map<String, dynamic>? getUserSession(String userId) {
    return get<Map<String, dynamic>>('session:$userId');
  }

  void removeUserSession(String userId) {
    remove('session:$userId');
  }

  /// Repository data caching methods
  void putRepositoryData(String repoId, Map<String, dynamic> repoData) {
    put('repo:$repoId', repoData, ttl: repositoryTTL);
  }

  Map<String, dynamic>? getRepositoryData(String repoId) {
    return get<Map<String, dynamic>>('repo:$repoId');
  }

  void putRepositoryFiles(String repoId, List<Map<String, dynamic>> files) {
    put('repo_files:$repoId', files, ttl: repositoryTTL);
  }

  List<Map<String, dynamic>>? getRepositoryFiles(String repoId) {
    return get<List<Map<String, dynamic>>>('repo_files:$repoId');
  }

  void putFileContent(String repoId, String filePath, String content) {
    put('file:$repoId:$filePath', content, ttl: repositoryTTL);
  }

  String? getFileContent(String repoId, String filePath) {
    return get<String>('file:$repoId:$filePath');
  }

  /// Task data caching methods
  void putTaskData(String taskId, Map<String, dynamic> taskData) {
    put('task:$taskId', taskData, ttl: taskTTL);
  }

  Map<String, dynamic>? getTaskData(String taskId) {
    return get<Map<String, dynamic>>('task:$taskId');
  }

  void putTaskList(String userId, List<Map<String, dynamic>> tasks) {
    put('tasks:$userId', tasks, ttl: taskTTL);
  }

  List<Map<String, dynamic>>? getTaskList(String userId) {
    return get<List<Map<String, dynamic>>>('tasks:$userId');
  }

  /// User data caching methods
  void putUserData(String userId, Map<String, dynamic> userData) {
    put('user:$userId', userData, ttl: sessionTTL);
  }

  Map<String, dynamic>? getUserData(String userId) {
    return get<Map<String, dynamic>>('user:$userId');
  }

  void putUserList(List<Map<String, dynamic>> users) {
    put('users:all', users, ttl: const Duration(minutes: 5));
  }

  List<Map<String, dynamic>>? getUserList() {
    return get<List<Map<String, dynamic>>>('users:all');
  }

  /// Dashboard component caching
  void putDashboardData(
      String userId, String component, Map<String, dynamic> data) {
    put('dashboard:$userId:$component', data, ttl: const Duration(minutes: 5));
  }

  Map<String, dynamic>? getDashboardData(String userId, String component) {
    return get<Map<String, dynamic>>('dashboard:$userId:$component');
  }

  /// Search results caching
  void putSearchResults(
      String query, String repoId, List<Map<String, dynamic>> results) {
    put('search:$repoId:${query.hashCode}', results,
        ttl: const Duration(minutes: 10));
  }

  List<Map<String, dynamic>>? getSearchResults(String query, String repoId) {
    return get<List<Map<String, dynamic>>>('search:$repoId:${query.hashCode}');
  }

  /// Git status caching
  void putGitStatus(String repoId, Map<String, dynamic> status) {
    put('git_status:$repoId', status, ttl: const Duration(minutes: 2));
  }

  Map<String, dynamic>? getGitStatus(String repoId) {
    return get<Map<String, dynamic>>('git_status:$repoId');
  }

  /// Private helper methods

  /// Get appropriate TTL based on key type
  Duration _getTTLForKey(String key) {
    if (key.startsWith('session:')) return sessionTTL;
    if (key.startsWith('repo:') || key.startsWith('file:'))
      return repositoryTTL;
    if (key.startsWith('task:')) return taskTTL;
    if (key.startsWith('git_status:')) return const Duration(minutes: 2);
    if (key.startsWith('search:')) return const Duration(minutes: 10);
    return defaultTTL;
  }

  /// Evict least recently used entries
  void _evictLRU() {
    if (_accessTimes.isEmpty) return;

    // Find the least recently used key
    String? lruKey;
    DateTime? oldestAccess;

    for (final entry in _accessTimes.entries) {
      if (oldestAccess == null || entry.value.isBefore(oldestAccess)) {
        oldestAccess = entry.value;
        lruKey = entry.key;
      }
    }

    if (lruKey != null) {
      _cache.remove(lruKey);
      _accessTimes.remove(lruKey);
      _evictions++;
      debugPrint('Cache LRU evicted: $lruKey');
    }
  }

  /// Perform periodic cleanup of expired entries
  void _performCleanup() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cache.entries) {
      if (now.isAfter(entry.value.expiresAt)) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
      _accessTimes.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      debugPrint(
          'Cache cleanup: removed ${expiredKeys.length} expired entries');
    }
  }

  /// Estimate memory usage in MB
  double _estimateMemoryUsage() {
    int totalBytes = 0;

    for (final entry in _cache.values) {
      try {
        final jsonString = jsonEncode(entry.value);
        totalBytes += jsonString.length * 2; // Rough estimate for UTF-16
      } catch (e) {
        totalBytes += 1024; // Default estimate for non-serializable objects
      }
    }

    return totalBytes / (1024 * 1024); // Convert to MB
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    clear();
    _isInitialized = false;
  }
}

/// Cache entry with metadata
class CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  final DateTime createdAt;

  CacheEntry({
    required this.value,
    required this.expiresAt,
    required this.createdAt,
  });
}
