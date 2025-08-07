import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper class to apply database schema migrations
class SchemaApplicator {
  static const String _schemaFilePath =
      'lib/core/supabase/migrations/001_initial_schema.sql';

  /// Apply the initial schema migration to Supabase
  static Future<void> applyInitialSchema() async {
    try {
      // Read the schema file
      final schemaFile = File(_schemaFilePath);
      if (!await schemaFile.exists()) {
        throw Exception('Schema file not found at $_schemaFilePath');
      }

      final schemaContent = await schemaFile.readAsString();

      // Split the schema into individual statements
      final statements = _splitSqlStatements(schemaContent);

      print('Applying ${statements.length} schema statements...');

      // Execute each statement
      for (int i = 0; i < statements.length; i++) {
        final statement = statements[i].trim();
        if (statement.isEmpty || statement.startsWith('--')) {
          continue; // Skip empty lines and comments
        }

        try {
          print('Executing statement ${i + 1}/${statements.length}');
          await Supabase.instance.client.rpc('exec_sql', params: {
            'sql': statement,
          });
        } catch (e) {
          print('Error executing statement ${i + 1}: $statement');
          print('Error: $e');
          rethrow;
        }
      }

      print('Schema migration completed successfully!');
    } catch (e) {
      print('Schema migration failed: $e');
      rethrow;
    }
  }

  /// Split SQL content into individual statements
  static List<String> _splitSqlStatements(String sql) {
    // Remove comments and split by semicolons
    final lines = sql.split('\n');
    final cleanedLines = <String>[];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isNotEmpty && !trimmedLine.startsWith('--')) {
        cleanedLines.add(line);
      }
    }

    final cleanedSql = cleanedLines.join('\n');
    return cleanedSql.split(';').where((s) => s.trim().isNotEmpty).toList();
  }

  /// Verify that all tables were created successfully
  static Future<void> verifySchema() async {
    try {
      final expectedTables = [
        'users',
        'team_members',
        'tasks',
        'security_alerts',
        'audit_logs',
        'deployments',
        'snapshots',
        'specifications'
      ];

      print('Verifying schema...');

      for (final table in expectedTables) {
        try {
          // Try to query the table to verify it exists
          await Supabase.instance.client.from(table).select('*').limit(1);
          print('✓ Table $table exists');
        } catch (e) {
          print('✗ Table $table verification failed: $e');
          throw Exception('Schema verification failed for table: $table');
        }
      }

      print('Schema verification completed successfully!');
    } catch (e) {
      print('Schema verification failed: $e');
      rethrow;
    }
  }

  /// Get table information for debugging
  static Future<void> getTableInfo() async {
    try {
      final result = await Supabase.instance.client.rpc('get_table_info');
      print('Database tables:');
      print(result);
    } catch (e) {
      print('Failed to get table info: $e');
    }
  }
}
