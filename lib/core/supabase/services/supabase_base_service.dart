import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../supabase_service.dart';
import '../supabase_error_handler.dart';

// Export error handling classes for use by subclasses
export '../supabase_error_handler.dart'
    show AppError, RetryPolicy, SupabaseErrorHandler;

/// Abstract base service for all Supabase database operations
/// Provides common CRUD operations pattern with error handling and validation
/// Requirements: 1.2, 1.4 - Common database operations with proper error handling
abstract class SupabaseBaseService<T> {
  final _uuid = const Uuid();

  /// Get the Supabase client instance
  SupabaseClient get _client => SupabaseService.instance.client;

  /// Table name for this service - must be implemented by subclasses
  String get tableName;

  /// Convert map to model instance - must be implemented by subclasses
  T fromMap(Map<String, dynamic> map);

  /// Convert model instance to map - must be implemented by subclasses
  Map<String, dynamic> toMap(T item);

  /// Generate a new UUID for records
  String generateId() => _uuid.v4();

  /// Create a new record
  /// Returns the ID of the created record
  Future<String> create(T item) async {
    try {
      final data = toMap(item);

      // Ensure ID is present
      if (!data.containsKey('id') || data['id'] == null || data['id'].isEmpty) {
        data['id'] = generateId();
      }

      // Add timestamps
      final now = DateTime.now().toIso8601String();
      data['created_at'] = now;
      data['updated_at'] = now;

      // Validate data before insertion
      _validateData(data);

      final response = await RetryPolicy.withRetry(
        () => _client.from(tableName).insert(data).select('id').single(),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      return response['id'] as String;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get a record by ID
  Future<T?> getById(String id) async {
    try {
      if (id.isEmpty) {
        throw AppError.validation('ID cannot be empty');
      }

      final response = await RetryPolicy.withRetry(
        () => _client.from(tableName).select().eq('id', id).maybeSingle(),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      if (response == null) {
        return null;
      }

      return fromMap(response);
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get all records with optional ordering
  Future<List<T>> getAll({
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic query = _client.from(tableName).select();

      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 1000) - 1);
      }

      final response = await RetryPolicy.withRetry(
        () => query,
        shouldRetry: RetryPolicy.isRetryableError,
      );

      return (response as List<dynamic>)
          .map((item) => fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Update a record by ID
  Future<void> update(String id, T item) async {
    try {
      if (id.isEmpty) {
        throw AppError.validation('ID cannot be empty');
      }

      final data = toMap(item);

      // Update timestamp
      data['updated_at'] = DateTime.now().toIso8601String();

      // Remove ID from update data to prevent conflicts
      data.remove('id');
      data.remove('created_at'); // Don't update creation timestamp

      // Validate data before update
      _validateData(data);

      await RetryPolicy.withRetry(
        () => _client.from(tableName).update(data).eq('id', id),
        shouldRetry: RetryPolicy.isRetryableError,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Delete a record by ID
  Future<void> delete(String id) async {
    try {
      if (id.isEmpty) {
        throw AppError.validation('ID cannot be empty');
      }

      await RetryPolicy.withRetry(
        () => _client.from(tableName).delete().eq('id', id),
        shouldRetry: RetryPolicy.isRetryableError,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch all records for real-time updates
  Stream<List<T>> watchAll({
    String? orderBy,
    bool ascending = true,
  }) {
    try {
      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .order(orderBy ?? 'created_at', ascending: ascending)
          .map((data) => data
              .map((item) => fromMap(item as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Watch a specific record for real-time updates
  Stream<T?> watchById(String id) {
    try {
      if (id.isEmpty) {
        throw AppError.validation('ID cannot be empty');
      }

      return _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('id', id)
          .map((data) {
            if (data.isEmpty) return null;
            return fromMap(data.first as Map<String, dynamic>);
          });
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Get records with custom filter
  Future<List<T>> getWhere({
    required String column,
    required dynamic value,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    try {
      dynamic query = _client.from(tableName).select().eq(column, value);

      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await RetryPolicy.withRetry(
        () => query,
        shouldRetry: RetryPolicy.isRetryableError,
      );

      return (response as List<dynamic>)
          .map((item) => fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Count records with optional filter
  Future<int> count({String? column, dynamic value}) async {
    try {
      dynamic query = _client.from(tableName).select('*');

      if (column != null && value != null) {
        query = query.eq(column, value);
      }

      final response = await RetryPolicy.withRetry(
        () => query,
        shouldRetry: RetryPolicy.isRetryableError,
      );

      // Return the length of the response list as count
      return (response as List<dynamic>).length;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Batch create multiple records
  Future<List<String>> createBatch(List<T> items) async {
    try {
      if (items.isEmpty) {
        return [];
      }

      final dataList = items.map((item) {
        final data = toMap(item);

        // Ensure ID is present
        if (!data.containsKey('id') ||
            data['id'] == null ||
            data['id'].isEmpty) {
          data['id'] = generateId();
        }

        // Add timestamps
        final now = DateTime.now().toIso8601String();
        data['created_at'] = now;
        data['updated_at'] = now;

        // Validate data
        _validateData(data);

        return data;
      }).toList();

      final response = await RetryPolicy.withRetry(
        () => _client.from(tableName).insert(dataList).select('id'),
        shouldRetry: RetryPolicy.isRetryableError,
      );

      return (response as List<dynamic>)
          .map((item) => item['id'] as String)
          .toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Batch delete multiple records
  Future<void> deleteBatch(List<String> ids) async {
    try {
      if (ids.isEmpty) {
        return;
      }

      // Validate all IDs
      for (final id in ids) {
        if (id.isEmpty) {
          throw AppError.validation('All IDs must be non-empty');
        }
      }

      await RetryPolicy.withRetry(
        () => _client.from(tableName).delete().inFilter('id', ids),
        shouldRetry: RetryPolicy.isRetryableError,
      );
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Validate data before database operations
  /// Override in subclasses for custom validation
  void _validateData(Map<String, dynamic> data) {
    // Basic validation - ensure required fields are present
    if (!data.containsKey('id') ||
        data['id'] == null ||
        data['id'].toString().isEmpty) {
      throw AppError.validation('ID is required');
    }

    // Additional validation can be implemented in subclasses
    validateData(data);
  }

  /// Custom validation hook for subclasses
  /// Override this method to add service-specific validation
  void validateData(Map<String, dynamic> data) {
    // Default implementation does nothing
    // Subclasses can override for custom validation
  }

  /// Execute a custom query with error handling
  Future<List<Map<String, dynamic>>> executeQuery(
    PostgrestFilterBuilder query,
  ) async {
    try {
      final response = await RetryPolicy.withRetry(
        () => query,
        shouldRetry: RetryPolicy.isRetryableError,
      );

      return (response as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }

  /// Check if a record exists
  Future<bool> exists(String id) async {
    try {
      if (id.isEmpty) {
        return false;
      }

      final count = await this.count(column: 'id', value: id);
      return count > 0;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }
}
