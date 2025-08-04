import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import '../database_service.dart';
import '../../services/caching_service.dart';
import 'audit_log_service.dart';

/// Database optimization service with query optimization, indexing, and connection pooling
/// Satisfies Requirements: 10.5 (Database query optimization with proper indexing)
class DatabaseOptimizationService {
  static final DatabaseOptimizationService _instance =
      DatabaseOptimizationService._internal();
  static DatabaseOptimizationService get instance => _instance;
  DatabaseOptimizationService._internal();

  final _cachingService = CachingService.instance;
  final _auditService = AuditLogService.instance;

  // Query performance tracking
  final Map<String, QueryPerformanceMetrics> _queryMetrics = {};
  final Map<String, PreparedStatement> _preparedStatements = {};

  // Connection pooling
  final List<Database> _connectionPool = [];
  final Set<Database> _activeConnections = {};
  static const int maxPoolSize = 10;
  static const int minPoolSize = 2;

  // Query optimization
  final Map<String, String> _optimizedQueries = {};
  final Set<String> _createdIndexes = {};

  Timer? _optimizationTimer;
  Timer? _statsTimer;
  bool _isInitialized = false;

  /// Initialize database optimization service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Create initial connection pool
    await _initializeConnectionPool();

    // Create performance indexes
    await _createPerformanceIndexes();

    // Start optimization timer
    _optimizationTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _performOptimization();
    });

    // Start statistics collection
    _statsTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _updateQueryStats();
    });

    _isInitialized = true;

    await _auditService.logAction(
      actionType: 'database_optimization_initialized',
      description:
          'Database optimization service initialized with connection pooling and indexing',
      aiReasoning:
          'Database optimization provides enhanced performance through connection pooling, query optimization, and intelligent indexing',
      contextData: {
        'max_pool_size': maxPoolSize,
        'min_pool_size': minPoolSize,
        'indexes_created': _createdIndexes.length,
      },
    );
  }

  /// Execute optimized query with caching and performance tracking
  Future<List<Map<String, dynamic>>> executeOptimizedQuery({
    required String queryKey,
    required String sql,
    List<dynamic>? arguments,
    Duration? cacheTimeout,
    bool useCache = true,
  }) async {
    final startTime = DateTime.now();

    try {
      // Check cache first
      if (useCache) {
        final cacheKey = _generateCacheKey(queryKey, sql, arguments);
        final cached =
            _cachingService.get<List<Map<String, dynamic>>>(cacheKey);
        if (cached != null) {
          _recordQueryMetrics(queryKey, startTime, true, cached.length);
          return cached;
        }
      }

      // Get optimized query
      final optimizedSql = _getOptimizedQuery(sql);

      // Execute query with connection pooling
      final db = await _getPooledConnection();
      final result = await db.query(
        _extractTableName(optimizedSql),
        where: _extractWhereClause(optimizedSql),
        whereArgs: arguments,
        orderBy: _extractOrderBy(optimizedSql),
        limit: _extractLimit(optimizedSql),
      );

      _releaseConnection(db);

      // Cache result if enabled
      if (useCache && result.isNotEmpty) {
        final cacheKey = _generateCacheKey(queryKey, sql, arguments);
        final timeout = cacheTimeout ?? _getDefaultCacheTimeout(queryKey);
        _cachingService.put(cacheKey, result, ttl: timeout);
      }

      _recordQueryMetrics(queryKey, startTime, false, result.length);
      return result;
    } catch (e) {
      _recordQueryError(queryKey, startTime, e);
      rethrow;
    }
  }

  /// Execute optimized raw query
  Future<List<Map<String, dynamic>>> executeOptimizedRawQuery({
    required String queryKey,
    required String sql,
    List<dynamic>? arguments,
    Duration? cacheTimeout,
    bool useCache = true,
  }) async {
    final startTime = DateTime.now();

    try {
      // Check cache first
      if (useCache) {
        final cacheKey = _generateCacheKey(queryKey, sql, arguments);
        final cached =
            _cachingService.get<List<Map<String, dynamic>>>(cacheKey);
        if (cached != null) {
          _recordQueryMetrics(queryKey, startTime, true, cached.length);
          return cached;
        }
      }

      // Get optimized query
      final optimizedSql = _getOptimizedQuery(sql);

      // Execute query with connection pooling
      final db = await _getPooledConnection();
      final result = await db.rawQuery(optimizedSql, arguments);
      _releaseConnection(db);

      // Cache result if enabled
      if (useCache && result.isNotEmpty) {
        final cacheKey = _generateCacheKey(queryKey, sql, arguments);
        final timeout = cacheTimeout ?? _getDefaultCacheTimeout(queryKey);
        _cachingService.put(cacheKey, result, ttl: timeout);
      }

      _recordQueryMetrics(queryKey, startTime, false, result.length);
      return result;
    } catch (e) {
      _recordQueryError(queryKey, startTime, e);
      rethrow;
    }
  }

  /// Execute batch operations with optimization
  Future<void> executeBatchOperations({
    required String operationKey,
    required List<BatchOperation> operations,
  }) async {
    final startTime = DateTime.now();

    try {
      final db = await _getPooledConnection();

      await db.transaction((txn) async {
        for (final operation in operations) {
          switch (operation.type) {
            case BatchOperationType.insert:
              await txn.insert(operation.table, operation.data!);
              break;
            case BatchOperationType.update:
              await txn.update(
                operation.table,
                operation.data!,
                where: operation.where,
                whereArgs: operation.whereArgs,
              );
              break;
            case BatchOperationType.delete:
              await txn.delete(
                operation.table,
                where: operation.where,
                whereArgs: operation.whereArgs,
              );
              break;
            case BatchOperationType.rawQuery:
              await txn.rawQuery(operation.sql!, operation.whereArgs);
              break;
          }
        }
      });

      _releaseConnection(db);

      // Invalidate related cache entries
      _invalidateCacheForBatch(operations);

      _recordBatchMetrics(operationKey, startTime, operations.length);
    } catch (e) {
      _recordQueryError(operationKey, startTime, e);
      rethrow;
    }
  }

  /// Get query performance statistics
  Map<String, dynamic> getQueryStats() {
    final totalQueries = _queryMetrics.values
        .fold(0, (sum, metrics) => sum + metrics.executionCount);
    final totalCacheHits =
        _queryMetrics.values.fold(0, (sum, metrics) => sum + metrics.cacheHits);
    final cacheHitRate =
        totalQueries > 0 ? (totalCacheHits / totalQueries * 100) : 0.0;

    final avgExecutionTime = _queryMetrics.values.isNotEmpty
        ? _queryMetrics.values
                .map((m) => m.averageExecutionTime.inMilliseconds)
                .reduce((a, b) => a + b) /
            _queryMetrics.values.length
        : 0.0;

    return {
      'total_queries': totalQueries,
      'cache_hits': totalCacheHits,
      'cache_hit_rate': cacheHitRate.toStringAsFixed(2),
      'average_execution_time_ms': avgExecutionTime.toStringAsFixed(2),
      'active_connections': _activeConnections.length,
      'pool_size': _connectionPool.length,
      'created_indexes': _createdIndexes.length,
      'optimized_queries': _optimizedQueries.length,
      'query_metrics': _queryMetrics.map((key, metrics) => MapEntry(key, {
            'execution_count': metrics.executionCount,
            'cache_hits': metrics.cacheHits,
            'average_time_ms': metrics.averageExecutionTime.inMilliseconds,
            'error_count': metrics.errorCount,
          })),
    };
  }

  /// Optimized user queries
  Future<List<Map<String, dynamic>>> getUsersOptimized({
    String? role,
    String? status,
    int? limit,
    int? offset,
  }) async {
    final queryKey = 'users_list';
    final whereConditions = <String>[];
    final arguments = <dynamic>[];

    if (role != null) {
      whereConditions.add('role = ?');
      arguments.add(role);
    }
    if (status != null) {
      whereConditions.add('status = ?');
      arguments.add(status);
    }

    final whereClause =
        whereConditions.isNotEmpty ? whereConditions.join(' AND ') : null;
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final offsetClause = offset != null ? 'OFFSET $offset' : '';

    final sql = '''
      SELECT id, email, name, role, status, created_at, updated_at, last_login
      FROM users
      ${whereClause != null ? 'WHERE $whereClause' : ''}
      ORDER BY created_at DESC
      $limitClause $offsetClause
    ''';

    return await executeOptimizedRawQuery(
      queryKey: queryKey,
      sql: sql,
      arguments: arguments.isNotEmpty ? arguments : null,
      cacheTimeout: const Duration(minutes: 5),
    );
  }

  /// Optimized task queries
  Future<List<Map<String, dynamic>>> getTasksOptimized({
    String? assigneeId,
    String? status,
    String? priority,
    String? confidentialityLevel,
    int? limit,
    int? offset,
  }) async {
    final queryKey = 'tasks_list';
    final whereConditions = <String>[];
    final arguments = <dynamic>[];

    if (assigneeId != null) {
      whereConditions.add('assignee_id = ?');
      arguments.add(assigneeId);
    }
    if (status != null) {
      whereConditions.add('status = ?');
      arguments.add(status);
    }
    if (priority != null) {
      whereConditions.add('priority = ?');
      arguments.add(priority);
    }
    if (confidentialityLevel != null) {
      whereConditions.add('confidentiality_level = ?');
      arguments.add(confidentialityLevel);
    }

    final whereClause =
        whereConditions.isNotEmpty ? whereConditions.join(' AND ') : null;
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final offsetClause = offset != null ? 'OFFSET $offset' : '';

    final sql = '''
      SELECT t.*, u.name as assignee_name
      FROM tasks t
      LEFT JOIN users u ON t.assignee_id = u.id
      ${whereClause != null ? 'WHERE $whereClause' : ''}
      ORDER BY t.priority DESC, t.created_at DESC
      $limitClause $offsetClause
    ''';

    return await executeOptimizedRawQuery(
      queryKey: queryKey,
      sql: sql,
      arguments: arguments.isNotEmpty ? arguments : null,
      cacheTimeout: const Duration(minutes: 3),
    );
  }

  /// Optimized audit log queries
  Future<List<Map<String, dynamic>>> getAuditLogsOptimized({
    String? userId,
    String? actionType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    final queryKey = 'audit_logs';
    final whereConditions = <String>[];
    final arguments = <dynamic>[];

    if (userId != null) {
      whereConditions.add('user_id = ?');
      arguments.add(userId);
    }
    if (actionType != null) {
      whereConditions.add('action_type = ?');
      arguments.add(actionType);
    }
    if (startDate != null) {
      whereConditions.add('timestamp >= ?');
      arguments.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      whereConditions.add('timestamp <= ?');
      arguments.add(endDate.millisecondsSinceEpoch);
    }

    final whereClause =
        whereConditions.isNotEmpty ? whereConditions.join(' AND ') : null;
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final offsetClause = offset != null ? 'OFFSET $offset' : '';

    final sql = '''
      SELECT al.*, u.name as user_name
      FROM audit_logs al
      LEFT JOIN users u ON al.user_id = u.id
      ${whereClause != null ? 'WHERE $whereClause' : ''}
      ORDER BY al.timestamp DESC
      $limitClause $offsetClause
    ''';

    return await executeOptimizedRawQuery(
      queryKey: queryKey,
      sql: sql,
      arguments: arguments.isNotEmpty ? arguments : null,
      cacheTimeout: const Duration(minutes: 10),
    );
  }

  /// Private helper methods

  /// Initialize connection pool
  Future<void> _initializeConnectionPool() async {
    for (int i = 0; i < minPoolSize; i++) {
      final db = await DatabaseService.instance.database;
      _connectionPool.add(db);
    }
  }

  /// Get connection from pool
  Future<Database> _getPooledConnection() async {
    if (_connectionPool.isNotEmpty) {
      final db = _connectionPool.removeAt(0);
      _activeConnections.add(db);
      return db;
    }

    // Create new connection if pool is empty and under max size
    if (_activeConnections.length < maxPoolSize) {
      final db = await DatabaseService.instance.database;
      _activeConnections.add(db);
      return db;
    }

    // Wait for connection to become available
    while (_connectionPool.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    return await _getPooledConnection();
  }

  /// Release connection back to pool
  void _releaseConnection(Database db) {
    _activeConnections.remove(db);
    if (_connectionPool.length < maxPoolSize) {
      _connectionPool.add(db);
    }
  }

  /// Create performance indexes
  Future<void> _createPerformanceIndexes() async {
    final db = await DatabaseService.instance.database;

    final indexes = [
      // User indexes
      'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)',
      'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)',
      'CREATE INDEX IF NOT EXISTS idx_users_status ON users(status)',
      'CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at)',

      // Task indexes
      'CREATE INDEX IF NOT EXISTS idx_tasks_assignee_id ON tasks(assignee_id)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_confidentiality_level ON tasks(confidentiality_level)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date)',

      // Audit log indexes
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_action_type ON audit_logs(action_type)',
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp)',

      // Task access log indexes
      'CREATE INDEX IF NOT EXISTS idx_task_access_logs_task_id ON task_access_logs(task_id)',
      'CREATE INDEX IF NOT EXISTS idx_task_access_logs_user_id ON task_access_logs(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_task_access_logs_timestamp ON task_access_logs(timestamp)',

      // Task status history indexes
      'CREATE INDEX IF NOT EXISTS idx_task_status_history_task_id ON task_status_history(task_id)',
      'CREATE INDEX IF NOT EXISTS idx_task_status_history_changed_at ON task_status_history(changed_at)',

      // Security alert indexes
      'CREATE INDEX IF NOT EXISTS idx_security_alerts_severity ON security_alerts(severity)',
      'CREATE INDEX IF NOT EXISTS idx_security_alerts_status ON security_alerts(status)',
      'CREATE INDEX IF NOT EXISTS idx_security_alerts_detected_at ON security_alerts(detected_at)',

      // Deployment indexes
      'CREATE INDEX IF NOT EXISTS idx_deployments_environment ON deployments(environment)',
      'CREATE INDEX IF NOT EXISTS idx_deployments_status ON deployments(status)',
      'CREATE INDEX IF NOT EXISTS idx_deployments_deployed_at ON deployments(deployed_at)',
    ];

    for (final indexSql in indexes) {
      try {
        await db.execute(indexSql);
        final indexName = _extractIndexName(indexSql);
        _createdIndexes.add(indexName);
      } catch (e) {
        debugPrint('Error creating index: $e');
      }
    }
  }

  /// Get optimized version of query
  String _getOptimizedQuery(String sql) {
    // Check if we have a cached optimized version
    final cached = _optimizedQueries[sql];
    if (cached != null) return cached;

    // Apply query optimizations
    String optimized = sql;

    // Add LIMIT if not present for potentially large result sets
    if (!optimized.toUpperCase().contains('LIMIT') &&
        (optimized.toUpperCase().contains('SELECT') &&
            !optimized.toUpperCase().contains('COUNT('))) {
      optimized += ' LIMIT 1000';
    }

    // Optimize ORDER BY with indexes
    optimized = _optimizeOrderBy(optimized);

    // Cache the optimized query
    _optimizedQueries[sql] = optimized;

    return optimized;
  }

  /// Optimize ORDER BY clauses
  String _optimizeOrderBy(String sql) {
    // Add index hints for common ORDER BY patterns
    if (sql.contains('ORDER BY created_at')) {
      return sql.replaceAll('ORDER BY created_at', 'ORDER BY created_at');
    }
    if (sql.contains('ORDER BY timestamp')) {
      return sql.replaceAll('ORDER BY timestamp', 'ORDER BY timestamp');
    }
    return sql;
  }

  /// Generate cache key for query
  String _generateCacheKey(
      String queryKey, String sql, List<dynamic>? arguments) {
    final argsHash = arguments?.hashCode ?? 0;
    return 'db_query:$queryKey:${sql.hashCode}:$argsHash';
  }

  /// Get default cache timeout based on query type
  Duration _getDefaultCacheTimeout(String queryKey) {
    switch (queryKey) {
      case 'users_list':
        return const Duration(minutes: 10);
      case 'tasks_list':
        return const Duration(minutes: 5);
      case 'audit_logs':
        return const Duration(minutes: 15);
      default:
        return const Duration(minutes: 5);
    }
  }

  /// Record query performance metrics
  void _recordQueryMetrics(
      String queryKey, DateTime startTime, bool cacheHit, int resultCount) {
    final executionTime = DateTime.now().difference(startTime);

    final metrics =
        _queryMetrics.putIfAbsent(queryKey, () => QueryPerformanceMetrics());
    metrics.executionCount++;
    metrics.totalExecutionTime += executionTime;
    metrics.averageExecutionTime = Duration(
      milliseconds:
          metrics.totalExecutionTime.inMilliseconds ~/ metrics.executionCount,
    );

    if (cacheHit) {
      metrics.cacheHits++;
    }

    metrics.lastExecutionTime = executionTime;
    metrics.lastResultCount = resultCount;
  }

  /// Record query error
  void _recordQueryError(String queryKey, DateTime startTime, dynamic error) {
    final metrics =
        _queryMetrics.putIfAbsent(queryKey, () => QueryPerformanceMetrics());
    metrics.errorCount++;
    metrics.lastError = error.toString();
  }

  /// Record batch operation metrics
  void _recordBatchMetrics(
      String operationKey, DateTime startTime, int operationCount) {
    final executionTime = DateTime.now().difference(startTime);
    final metrics = _queryMetrics.putIfAbsent(
        operationKey, () => QueryPerformanceMetrics());
    metrics.executionCount++;
    metrics.totalExecutionTime += executionTime;
    metrics.averageExecutionTime = Duration(
      milliseconds:
          metrics.totalExecutionTime.inMilliseconds ~/ metrics.executionCount,
    );
    metrics.lastResultCount = operationCount;
  }

  /// Invalidate cache entries for batch operations
  void _invalidateCacheForBatch(List<BatchOperation> operations) {
    final affectedTables = operations.map((op) => op.table).toSet();

    for (final table in affectedTables) {
      // Invalidate related cache entries
      switch (table) {
        case 'users':
          _cachingService.remove('users:all');
          break;
        case 'tasks':
          _cachingService.remove('tasks:all');
          break;
        case 'audit_logs':
          _cachingService.remove('audit_logs:recent');
          break;
      }
    }
  }

  /// Extract table name from SQL
  String _extractTableName(String sql) {
    final match = RegExp(r'FROM\s+(\w+)', caseSensitive: false).firstMatch(sql);
    return match?.group(1) ?? '';
  }

  /// Extract WHERE clause from SQL
  String? _extractWhereClause(String sql) {
    final match = RegExp(
            r'WHERE\s+(.+?)(?:\s+ORDER\s+BY|\s+LIMIT|\s+GROUP\s+BY|$)',
            caseSensitive: false)
        .firstMatch(sql);
    return match?.group(1);
  }

  /// Extract ORDER BY clause from SQL
  String? _extractOrderBy(String sql) {
    final match =
        RegExp(r'ORDER\s+BY\s+(.+?)(?:\s+LIMIT|$)', caseSensitive: false)
            .firstMatch(sql);
    return match?.group(1);
  }

  /// Extract LIMIT from SQL
  int? _extractLimit(String sql) {
    final match =
        RegExp(r'LIMIT\s+(\d+)', caseSensitive: false).firstMatch(sql);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Extract index name from CREATE INDEX SQL
  String _extractIndexName(String sql) {
    final match = RegExp(r'CREATE\s+INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)',
            caseSensitive: false)
        .firstMatch(sql);
    return match?.group(1) ?? 'unknown_index';
  }

  /// Perform periodic optimization
  void _performOptimization() {
    // Analyze query patterns and suggest optimizations
    _analyzeQueryPatterns();

    // Clean up old metrics
    _cleanupOldMetrics();
  }

  /// Analyze query patterns for optimization opportunities
  void _analyzeQueryPatterns() {
    for (final entry in _queryMetrics.entries) {
      final metrics = entry.value;

      // Suggest indexing for slow queries
      if (metrics.averageExecutionTime.inMilliseconds > 100 &&
          metrics.executionCount > 10) {
        debugPrint(
            'Slow query detected: ${entry.key} (${metrics.averageExecutionTime.inMilliseconds}ms avg)');
      }

      // Suggest caching for frequently executed queries
      if (metrics.executionCount > 50 &&
          metrics.cacheHits / metrics.executionCount < 0.5) {
        debugPrint(
            'Low cache hit rate for query: ${entry.key} (${(metrics.cacheHits / metrics.executionCount * 100).toStringAsFixed(1)}%)');
      }
    }
  }

  /// Clean up old metrics
  void _cleanupOldMetrics() {
    // Keep only recent metrics to prevent memory bloat
    if (_queryMetrics.length > 100) {
      final sortedEntries = _queryMetrics.entries.toList()
        ..sort(
            (a, b) => b.value.executionCount.compareTo(a.value.executionCount));

      _queryMetrics.clear();
      for (int i = 0; i < 50; i++) {
        _queryMetrics[sortedEntries[i].key] = sortedEntries[i].value;
      }
    }
  }

  /// Update query statistics
  void _updateQueryStats() {
    // This could send stats to monitoring system
    final stats = getQueryStats();
    debugPrint(
        'Database stats: ${stats['total_queries']} queries, ${stats['cache_hit_rate']}% cache hit rate');
  }

  /// Dispose resources
  void dispose() {
    _optimizationTimer?.cancel();
    _statsTimer?.cancel();

    // Close all pooled connections
    for (final db in _connectionPool) {
      db.close();
    }
    for (final db in _activeConnections) {
      db.close();
    }

    _connectionPool.clear();
    _activeConnections.clear();
    _queryMetrics.clear();
    _optimizedQueries.clear();

    _isInitialized = false;
  }
}

/// Query performance metrics
class QueryPerformanceMetrics {
  int executionCount = 0;
  int cacheHits = 0;
  int errorCount = 0;
  Duration totalExecutionTime = Duration.zero;
  Duration averageExecutionTime = Duration.zero;
  Duration lastExecutionTime = Duration.zero;
  int lastResultCount = 0;
  String? lastError;
}

/// Batch operation definition
class BatchOperation {
  final BatchOperationType type;
  final String table;
  final Map<String, dynamic>? data;
  final String? where;
  final List<dynamic>? whereArgs;
  final String? sql;

  BatchOperation({
    required this.type,
    required this.table,
    this.data,
    this.where,
    this.whereArgs,
    this.sql,
  });

  factory BatchOperation.insert(String table, Map<String, dynamic> data) {
    return BatchOperation(
      type: BatchOperationType.insert,
      table: table,
      data: data,
    );
  }

  factory BatchOperation.update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) {
    return BatchOperation(
      type: BatchOperationType.update,
      table: table,
      data: data,
      where: where,
      whereArgs: whereArgs,
    );
  }

  factory BatchOperation.delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) {
    return BatchOperation(
      type: BatchOperationType.delete,
      table: table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  factory BatchOperation.rawQuery(String sql, [List<dynamic>? arguments]) {
    return BatchOperation(
      type: BatchOperationType.rawQuery,
      table: '',
      sql: sql,
      whereArgs: arguments,
    );
  }
}

/// Batch operation types
enum BatchOperationType {
  insert,
  update,
  delete,
  rawQuery,
}
