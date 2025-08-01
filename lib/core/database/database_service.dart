import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static DatabaseService get instance => _instance;
  
  Database? _database;
  
  DatabaseService._internal();
  
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }
  
  Future<void> initialize() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }
  
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'devguard.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // Security Alerts table
    await db.execute('''
      CREATE TABLE security_alerts (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        severity TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        ai_explanation TEXT NOT NULL,
        trigger_data TEXT,
        status TEXT NOT NULL DEFAULT 'new',
        assigned_to TEXT,
        detected_at INTEGER NOT NULL,
        resolved_at INTEGER,
        rollback_suggested INTEGER NOT NULL DEFAULT 0,
        evidence TEXT
      )
    ''');
    
    // Audit Logs table
    await db.execute('''
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        action_type TEXT NOT NULL,
        description TEXT NOT NULL,
        ai_reasoning TEXT,
        context_data TEXT,
        user_id TEXT,
        timestamp INTEGER NOT NULL,
        requires_approval INTEGER NOT NULL DEFAULT 0,
        approved INTEGER DEFAULT 0,
        approved_by TEXT,
        approved_at INTEGER
      )
    ''');
    
    // Deployments table
    await db.execute('''
      CREATE TABLE deployments (
        id TEXT PRIMARY KEY,
        environment TEXT NOT NULL,
        version TEXT NOT NULL,
        status TEXT NOT NULL,
        pipeline_config TEXT,
        snapshot_id TEXT,
        deployed_by TEXT NOT NULL,
        deployed_at INTEGER NOT NULL,
        rollback_available INTEGER NOT NULL DEFAULT 1,
        health_checks TEXT,
        logs TEXT
      )
    ''');
    
    // Snapshots table
    await db.execute('''
      CREATE TABLE snapshots (
        id TEXT PRIMARY KEY,
        environment TEXT NOT NULL,
        git_commit TEXT NOT NULL,
        database_backup TEXT,
        config_files TEXT,
        created_at INTEGER NOT NULL,
        verified INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // Honeytokens table
    await db.execute('''
      CREATE TABLE honeytokens (
        id TEXT PRIMARY KEY,
        token_type TEXT NOT NULL,
        token_value TEXT NOT NULL,
        table_name TEXT NOT NULL,
        column_name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        accessed_at INTEGER,
        access_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // Configuration monitoring table
    await db.execute('''
      CREATE TABLE config_monitoring (
        id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        file_hash TEXT NOT NULL,
        last_modified INTEGER NOT NULL,
        monitored_since INTEGER NOT NULL,
        change_detected_at INTEGER
      )
    ''');
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
  }
  
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}