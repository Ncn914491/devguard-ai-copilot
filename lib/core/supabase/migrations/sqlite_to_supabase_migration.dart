import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../database/database_service.dart';
import '../../database/models/team_member.dart';
import '../../database/models/task.dart';
import '../../database/models/security_alert.dart';
import '../../database/models/audit_log.dart';
import '../../database/models/deployment.dart';
import '../../database/models/snapshot.dart';
import '../../database/models/specification.dart';
import '../supabase_service.dart';

/// Data migration service for migrating from SQLite to Supabase
/// Handles data export, transformation, and import with validation
class SQLiteToSupabaseMigration {
  final DatabaseService _sqliteDb = DatabaseService.instance;
  final SupabaseService _supabaseService = SupabaseService.instance;
  final Uuid _uuid = const Uuid();

  // Migration progress tracking
  int _totalRecords = 0;
  int _processedRecords = 0;
  final List<String> _migrationLog = [];
  final Map<String, String> _idMappings =
      {}; // SQLite ID -> Supabase UUID mapping

  /// Get migration progress (0.0 to 1.0)
  double get progress =>
      _totalRecords > 0 ? _processedRecords / _totalRecords : 0.0;

  /// Get migration log entries
  List<String> get migrationLog => List.unmodifiable(_migrationLog);

  /// Main migration method - orchestrates the entire migration process
  Future<MigrationResult> migrateFromSQLite({
    bool dryRun = false,
    bool skipValidation = false,
  }) async {
    final startTime = DateTime.now();
    _migrationLog.clear();
    _idMappings.clear();
    _totalRecords = 0;
    _processedRecords = 0;

    try {
      _log('🚀 Starting SQLite to Supabase migration...');
      _log('📊 Dry run: $dryRun');
      _log('⚡ Skip validation: $skipValidation');

      // Step 1: Initialize services
      await _initializeServices();

      // Step 2: Export data from SQLite
      _log('📤 Exporting data from SQLite...');
      final sqliteData = await _exportSQLiteData();
      _totalRecords = _calculateTotalRecords(sqliteData);
      _log('📊 Total records to migrate: $_totalRecords');

      // Step 3: Transform data for PostgreSQL compatibility
      _log('🔄 Transforming data for PostgreSQL...');
      final transformedData = await _transformData(sqliteData);

      // Step 4: Validate data integrity (unless skipped)
      if (!skipValidation) {
        _log('✅ Validating data integrity...');
        await _validateData(transformedData);
      }

      // Step 5: Import to Supabase (unless dry run)
      if (!dryRun) {
        _log('📥 Importing data to Supabase...');
        await _importToSupabase(transformedData);

        // Step 6: Verify migration
        _log('🔍 Verifying migration...');
        await _verifyMigration(sqliteData, transformedData);
      } else {
        _log('🏃 Dry run completed - no data imported');
      }

      final duration = DateTime.now().difference(startTime);
      _log('✅ Migration completed successfully in ${duration.inSeconds}s');

      return MigrationResult(
        success: true,
        recordsMigrated: _processedRecords,
        duration: duration,
        log: List.from(_migrationLog),
        idMappings: Map.from(_idMappings),
      );
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      _log('❌ Migration failed: $e');
      _log('📍 Stack trace: $stackTrace');

      return MigrationResult(
        success: false,
        recordsMigrated: _processedRecords,
        duration: duration,
        log: List.from(_migrationLog),
        error: e.toString(),
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Initialize required services
  Future<void> _initializeServices() async {
    // Initialize SQLite database
    await _sqliteDb.initialize();
    _log('✅ SQLite database initialized');

    // Initialize Supabase
    if (!_supabaseService.isInitialized) {
      await _supabaseService.initialize();
    }
    _log('✅ Supabase service initialized');
  }

  /// Export all data from SQLite database
  Future<SQLiteExportData> _exportSQLiteData() async {
    final db = await _sqliteDb.database;

    // Export team members
    final teamMembersData = await db.query('team_members');
    final teamMembers =
        teamMembersData.map((row) => TeamMember.fromMap(row)).toList();
    _log('📤 Exported ${teamMembers.length} team members');

    // Export tasks
    final tasksData = await db.query('tasks');
    final tasks = tasksData.map((row) => Task.fromMap(row)).toList();
    _log('📤 Exported ${tasks.length} tasks');

    // Export security alerts
    final securityAlertsData = await db.query('security_alerts');
    final securityAlerts =
        securityAlertsData.map((row) => SecurityAlert.fromMap(row)).toList();
    _log('📤 Exported ${securityAlerts.length} security alerts');

    // Export audit logs
    final auditLogsData = await db.query('audit_logs');
    final auditLogs =
        auditLogsData.map((row) => AuditLog.fromMap(row)).toList();
    _log('📤 Exported ${auditLogs.length} audit logs');

    // Export deployments
    final deploymentsData = await db.query('deployments');
    final deployments =
        deploymentsData.map((row) => Deployment.fromMap(row)).toList();
    _log('📤 Exported ${deployments.length} deployments');

    // Export snapshots
    final snapshotsData = await db.query('snapshots');
    final snapshots =
        snapshotsData.map((row) => Snapshot.fromMap(row)).toList();
    _log('📤 Exported ${snapshots.length} snapshots');

    // Export specifications
    final specificationsData = await db.query('specifications');
    final specifications =
        specificationsData.map((row) => Specification.fromMap(row)).toList();
    _log('📤 Exported ${specifications.length} specifications');

    return SQLiteExportData(
      teamMembers: teamMembers,
      tasks: tasks,
      securityAlerts: securityAlerts,
      auditLogs: auditLogs,
      deployments: deployments,
      snapshots: snapshots,
      specifications: specifications,
    );
  }

  /// Transform SQLite data to Supabase-compatible format
  Future<SupabaseImportData> _transformData(SQLiteExportData sqliteData) async {
    // Create default admin user for migration
    final adminUser = _createDefaultAdminUser();

    // Transform team members (create users first)
    final users = <Map<String, dynamic>>[];
    final teamMembers = <Map<String, dynamic>>[];

    for (final member in sqliteData.teamMembers) {
      final userId = _uuid.v4();
      _idMappings[member.id] = userId;

      // Create user record
      users.add({
        'id': userId,
        'email': member.email,
        'name': member.name,
        'role': _mapRole(member.role),
        'status': _mapUserStatus(member.status),
        'created_at': member.createdAt.toIso8601String(),
        'updated_at': member.updatedAt.toIso8601String(),
      });

      // Create team member record
      teamMembers.add({
        'id': _uuid.v4(),
        'user_id': userId,
        'name': member.name,
        'email': member.email,
        'role': member.role,
        'status': member.status,
        'assignments': member.assignments,
        'expertise': member.expertise,
        'workload': member.workload,
        'created_at': member.createdAt.toIso8601String(),
        'updated_at': member.updatedAt.toIso8601String(),
      });
    }

    // Add admin user
    users.add(adminUser);
    _processedRecords += users.length;

    // Transform tasks
    final tasks = <Map<String, dynamic>>[];
    for (final task in sqliteData.tasks) {
      final taskId = _uuid.v4();
      _idMappings[task.id] = taskId;

      tasks.add({
        'id': taskId,
        'title': task.title,
        'description': task.description,
        'type': _mapTaskType(task.type),
        'priority': _mapTaskPriority(task.priority),
        'status': _mapTaskStatus(task.status),
        'assignee_id': _idMappings[task.assigneeId],
        'reporter_id': adminUser['id'], // Default to admin for migration
        'estimated_hours': task.estimatedHours,
        'actual_hours': task.actualHours,
        'related_commits': task.relatedCommits,
        'related_pull_requests': task.relatedPullRequests,
        'dependencies': task.dependencies
            .map((id) => _idMappings[id])
            .where((id) => id != null)
            .toList(),
        'blocked_by': task.blockedBy
            .map((id) => _idMappings[id])
            .where((id) => id != null)
            .toList(),
        'confidentiality_level':
            _mapConfidentialityLevel(task.confidentialityLevel),
        'authorized_users': task.authorizedUsers
            .map((id) => _idMappings[id])
            .where((id) => id != null)
            .toList(),
        'authorized_roles': task.authorizedRoles,
        'created_at': task.createdAt.toIso8601String(),
        'due_date': task.dueDate.toIso8601String(),
        'completed_at': task.completedAt?.toIso8601String(),
      });
    }
    _processedRecords += tasks.length;

    // Transform security alerts
    final securityAlerts = <Map<String, dynamic>>[];
    for (final alert in sqliteData.securityAlerts) {
      final alertId = _uuid.v4();
      _idMappings[alert.id] = alertId;

      securityAlerts.add({
        'id': alertId,
        'type': alert.type,
        'severity': _mapAlertSeverity(alert.severity),
        'title': alert.title,
        'description': alert.description,
        'ai_explanation': alert.aiExplanation,
        'trigger_data':
            alert.triggerData != null ? jsonDecode(alert.triggerData!) : {},
        'status': _mapAlertStatus(alert.status),
        'assigned_to':
            alert.assignedTo != null ? _idMappings[alert.assignedTo!] : null,
        'detected_at': alert.detectedAt.toIso8601String(),
        'resolved_at': alert.resolvedAt?.toIso8601String(),
        'rollback_suggested': alert.rollbackSuggested,
        'evidence': alert.evidence != null ? jsonDecode(alert.evidence!) : {},
      });
    }
    _processedRecords += securityAlerts.length;

    // Transform audit logs
    final auditLogs = <Map<String, dynamic>>[];
    for (final log in sqliteData.auditLogs) {
      final logId = _uuid.v4();
      _idMappings[log.id] = logId;

      auditLogs.add({
        'id': logId,
        'action_type': log.actionType,
        'description': log.description,
        'ai_reasoning': log.aiReasoning,
        'context_data':
            log.contextData != null ? jsonDecode(log.contextData!) : {},
        'user_id': log.userId != null ? _idMappings[log.userId!] : null,
        'timestamp': log.timestamp.toIso8601String(),
        'requires_approval': log.requiresApproval,
        'approved': log.approved,
        'approved_by':
            log.approvedBy != null ? _idMappings[log.approvedBy!] : null,
        'approved_at': log.approvedAt?.toIso8601String(),
      });
    }
    _processedRecords += auditLogs.length;

    // Transform deployments
    final deployments = <Map<String, dynamic>>[];
    for (final deployment in sqliteData.deployments) {
      final deploymentId = _uuid.v4();
      _idMappings[deployment.id] = deploymentId;

      deployments.add({
        'id': deploymentId,
        'environment': deployment.environment,
        'version': deployment.version,
        'status': _mapDeploymentStatus(deployment.status),
        'initiated_by': adminUser['id'], // Default to admin for migration
        'commit_hash':
            _generateCommitHash(), // Generate placeholder commit hash
        'branch': 'main', // Default branch
        'deployment_config': deployment.pipelineConfig != null
            ? jsonDecode(deployment.pipelineConfig!)
            : {},
        'deployment_logs': deployment.logs,
        'health_check_status': deployment.healthChecks,
        'started_at': deployment.deployedAt.toIso8601String(),
        'created_at': deployment.deployedAt.toIso8601String(),
      });
    }
    _processedRecords += deployments.length;

    // Transform snapshots
    final snapshots = <Map<String, dynamic>>[];
    for (final snapshot in sqliteData.snapshots) {
      final snapshotId = _uuid.v4();
      _idMappings[snapshot.id] = snapshotId;

      snapshots.add({
        'id': snapshotId,
        'name': 'Migration Snapshot ${snapshot.id}',
        'description': 'Migrated from SQLite',
        'commit_hash': snapshot.gitCommit.isNotEmpty
            ? snapshot.gitCommit
            : _generateCommitHash(),
        'branch': 'main',
        'author_id': adminUser['id'],
        'file_changes': {'config_files': snapshot.configFiles},
        'metadata': {
          'original_id': snapshot.id,
          'environment': snapshot.environment,
          'database_backup': snapshot.databaseBackup,
          'verified': snapshot.verified,
        },
        'is_automated': true,
        'created_at': snapshot.createdAt.toIso8601String(),
      });
    }
    _processedRecords += snapshots.length;

    // Transform specifications
    final specifications = <Map<String, dynamic>>[];
    for (final spec in sqliteData.specifications) {
      final specId = _uuid.v4();
      _idMappings[spec.id] = specId;

      specifications.add({
        'id': specId,
        'title': spec.rawInput.length > 200
            ? spec.rawInput.substring(0, 200)
            : spec.rawInput,
        'description': spec.aiInterpretation.length > 500
            ? spec.aiInterpretation.substring(0, 500)
            : spec.aiInterpretation,
        'content': spec.aiInterpretation,
        'type': 'feature',
        'status': _mapSpecStatus(spec.status),
        'priority': 'medium',
        'author_id': adminUser['id'],
        'assignee_id':
            spec.assignedTo != null ? _idMappings[spec.assignedTo!] : null,
        'attachments': {
          'suggested_branch_name': spec.suggestedBranchName,
          'suggested_commit_message': spec.suggestedCommitMessage,
          'placeholder_diff': spec.placeholderDiff,
        },
        'created_at': spec.createdAt.toIso8601String(),
        'approved_at': spec.approvedAt?.toIso8601String(),
      });
    }
    _processedRecords += specifications.length;

    _log('🔄 Data transformation completed');
    _log(
        '📊 Transformed records: Users(${users.length}), TeamMembers(${teamMembers.length}), Tasks(${tasks.length}), SecurityAlerts(${securityAlerts.length}), AuditLogs(${auditLogs.length}), Deployments(${deployments.length}), Snapshots(${snapshots.length}), Specifications(${specifications.length})');

    return SupabaseImportData(
      users: users,
      teamMembers: teamMembers,
      tasks: tasks,
      securityAlerts: securityAlerts,
      auditLogs: auditLogs,
      deployments: deployments,
      snapshots: snapshots,
      specifications: specifications,
    );
  }

  /// Validate data integrity before import
  Future<void> _validateData(SupabaseImportData data) async {
    final validationErrors = <String>[];

    // Validate users
    for (final user in data.users) {
      if (user['email'] == null || !_isValidEmail(user['email'])) {
        validationErrors.add('Invalid email for user: ${user['id']}');
      }
      if (user['name'] == null || user['name'].toString().length < 2) {
        validationErrors.add('Invalid name for user: ${user['id']}');
      }
    }

    // Validate tasks
    for (final task in data.tasks) {
      if (task['title'] == null || task['title'].toString().length < 3) {
        validationErrors.add('Invalid title for task: ${task['id']}');
      }
      if (task['assignee_id'] != null &&
          !data.users.any((u) => u['id'] == task['assignee_id'])) {
        validationErrors.add('Invalid assignee_id for task: ${task['id']}');
      }
    }

    // Validate security alerts
    for (final alert in data.securityAlerts) {
      if (alert['title'] == null || alert['title'].toString().length < 5) {
        validationErrors
            .add('Invalid title for security alert: ${alert['id']}');
      }
    }

    if (validationErrors.isNotEmpty) {
      _log('❌ Validation failed with ${validationErrors.length} errors:');
      for (final error in validationErrors) {
        _log('  - $error');
      }
      throw Exception('Data validation failed: ${validationErrors.join(', ')}');
    }

    _log('✅ Data validation passed');
  }

  /// Import transformed data to Supabase
  Future<void> _importToSupabase(SupabaseImportData data) async {
    final client = _supabaseService.client;

    try {
      // Import users first (required for foreign keys)
      if (data.users.isNotEmpty) {
        await client.from('users').insert(data.users);
        _log('✅ Imported ${data.users.length} users');
      }

      // Import team members
      if (data.teamMembers.isNotEmpty) {
        await client.from('team_members').insert(data.teamMembers);
        _log('✅ Imported ${data.teamMembers.length} team members');
      }

      // Import tasks
      if (data.tasks.isNotEmpty) {
        await client.from('tasks').insert(data.tasks);
        _log('✅ Imported ${data.tasks.length} tasks');
      }

      // Import security alerts
      if (data.securityAlerts.isNotEmpty) {
        await client.from('security_alerts').insert(data.securityAlerts);
        _log('✅ Imported ${data.securityAlerts.length} security alerts');
      }

      // Import audit logs
      if (data.auditLogs.isNotEmpty) {
        await client.from('audit_logs').insert(data.auditLogs);
        _log('✅ Imported ${data.auditLogs.length} audit logs');
      }

      // Import deployments
      if (data.deployments.isNotEmpty) {
        await client.from('deployments').insert(data.deployments);
        _log('✅ Imported ${data.deployments.length} deployments');
      }

      // Import snapshots
      if (data.snapshots.isNotEmpty) {
        await client.from('snapshots').insert(data.snapshots);
        _log('✅ Imported ${data.snapshots.length} snapshots');
      }

      // Import specifications
      if (data.specifications.isNotEmpty) {
        await client.from('specifications').insert(data.specifications);
        _log('✅ Imported ${data.specifications.length} specifications');
      }
    } catch (e) {
      _log('❌ Import failed: $e');
      rethrow;
    }
  }

  /// Verify migration by comparing record counts and key data
  Future<void> _verifyMigration(
      SQLiteExportData sqliteData, SupabaseImportData supabaseData) async {
    final client = _supabaseService.client;
    final verificationErrors = <String>[];

    try {
      // Verify users count (includes admin user)
      final usersCount = await client.from('users').select('count').count();
      final expectedUsersCount = supabaseData.users.length;
      if (usersCount != expectedUsersCount) {
        verificationErrors.add(
            'Users count mismatch: expected $expectedUsersCount, got $usersCount');
      }

      // Verify team members count
      final teamMembersCount =
          await client.from('team_members').select('count').count();
      if (teamMembersCount != sqliteData.teamMembers.length) {
        verificationErrors.add(
            'Team members count mismatch: expected ${sqliteData.teamMembers.length}, got $teamMembersCount');
      }

      // Verify tasks count
      final tasksCount = await client.from('tasks').select('count').count();
      if (tasksCount != sqliteData.tasks.length) {
        verificationErrors.add(
            'Tasks count mismatch: expected ${sqliteData.tasks.length}, got $tasksCount');
      }

      // Verify security alerts count
      final alertsCount =
          await client.from('security_alerts').select('count').count();
      if (alertsCount != sqliteData.securityAlerts.length) {
        verificationErrors.add(
            'Security alerts count mismatch: expected ${sqliteData.securityAlerts.length}, got $alertsCount');
      }

      // Verify audit logs count
      final auditLogsCount =
          await client.from('audit_logs').select('count').count();
      if (auditLogsCount != sqliteData.auditLogs.length) {
        verificationErrors.add(
            'Audit logs count mismatch: expected ${sqliteData.auditLogs.length}, got $auditLogsCount');
      }

      if (verificationErrors.isNotEmpty) {
        _log('❌ Migration verification failed:');
        for (final error in verificationErrors) {
          _log('  - $error');
        }
        throw Exception(
            'Migration verification failed: ${verificationErrors.join(', ')}');
      }

      _log('✅ Migration verification passed');
    } catch (e) {
      _log('❌ Migration verification error: $e');
      rethrow;
    }
  }

  // Helper methods for data transformation

  Map<String, dynamic> _createDefaultAdminUser() {
    final adminId = _uuid.v4();
    return {
      'id': adminId,
      'email': 'admin@devguard.local',
      'name': 'Migration Admin',
      'role': 'admin',
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  String _mapRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'admin';
      case 'lead_developer':
      case 'security_reviewer':
        return 'lead_developer';
      case 'developer':
        return 'developer';
      default:
        return 'developer';
    }
  }

  String _mapUserStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'active';
      case 'inactive':
      case 'offline':
        return 'inactive';
      case 'bench':
        return 'pending';
      default:
        return 'active';
    }
  }

  String _mapTaskType(String type) {
    switch (type.toLowerCase()) {
      case 'feature':
        return 'feature';
      case 'bug':
        return 'bug';
      case 'security':
        return 'security';
      case 'deployment':
        return 'maintenance';
      case 'research':
        return 'enhancement';
      default:
        return 'feature';
    }
  }

  String _mapTaskPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return 'low';
      case 'medium':
        return 'medium';
      case 'high':
        return 'high';
      case 'critical':
        return 'critical';
      default:
        return 'medium';
    }
  }

  String _mapTaskStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'todo';
      case 'in_progress':
        return 'in_progress';
      case 'review':
        return 'review';
      case 'testing':
        return 'testing';
      case 'completed':
        return 'done';
      case 'blocked':
        return 'blocked';
      default:
        return 'todo';
    }
  }

  String _mapConfidentialityLevel(String level) {
    switch (level.toLowerCase()) {
      case 'public':
        return 'public';
      case 'team':
        return 'team';
      case 'restricted':
        return 'restricted';
      case 'confidential':
        return 'confidential';
      default:
        return 'team';
    }
  }

  String _mapAlertSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return 'low';
      case 'medium':
        return 'medium';
      case 'high':
        return 'high';
      case 'critical':
        return 'critical';
      default:
        return 'medium';
    }
  }

  String _mapAlertStatus(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'new';
      case 'investigating':
        return 'investigating';
      case 'resolved':
        return 'resolved';
      case 'false_positive':
        return 'false_positive';
      default:
        return 'new';
    }
  }

  String _mapDeploymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'pending';
      case 'in_progress':
        return 'in_progress';
      case 'success':
        return 'success';
      case 'failed':
        return 'failed';
      case 'rolled_back':
        return 'rolled_back';
      default:
        return 'pending';
    }
  }

  String _mapSpecStatus(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'draft';
      case 'approved':
        return 'approved';
      case 'in_progress':
        return 'review';
      case 'completed':
        return 'implemented';
      default:
        return 'draft';
    }
  }

  String _generateCommitHash() {
    // Generate a placeholder 40-character commit hash
    return _uuid.v4().replaceAll('-', '') +
        _uuid.v4().replaceAll('-', '').substring(0, 8);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  int _calculateTotalRecords(SQLiteExportData data) {
    return data.teamMembers.length +
        data.tasks.length +
        data.securityAlerts.length +
        data.auditLogs.length +
        data.deployments.length +
        data.snapshots.length +
        data.specifications.length +
        1; // +1 for admin user
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    _migrationLog.add(logEntry);
    if (kDebugMode) {
      debugPrint(logEntry);
    }
  }
}

/// Data structure for SQLite export
class SQLiteExportData {
  final List<TeamMember> teamMembers;
  final List<Task> tasks;
  final List<SecurityAlert> securityAlerts;
  final List<AuditLog> auditLogs;
  final List<Deployment> deployments;
  final List<Snapshot> snapshots;
  final List<Specification> specifications;

  SQLiteExportData({
    required this.teamMembers,
    required this.tasks,
    required this.securityAlerts,
    required this.auditLogs,
    required this.deployments,
    required this.snapshots,
    required this.specifications,
  });
}

/// Data structure for Supabase import
class SupabaseImportData {
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> teamMembers;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> securityAlerts;
  final List<Map<String, dynamic>> auditLogs;
  final List<Map<String, dynamic>> deployments;
  final List<Map<String, dynamic>> snapshots;
  final List<Map<String, dynamic>> specifications;

  SupabaseImportData({
    required this.users,
    required this.teamMembers,
    required this.tasks,
    required this.securityAlerts,
    required this.auditLogs,
    required this.deployments,
    required this.snapshots,
    required this.specifications,
  });
}

/// Migration result with detailed information
class MigrationResult {
  final bool success;
  final int recordsMigrated;
  final Duration duration;
  final List<String> log;
  final Map<String, String> idMappings;
  final String? error;
  final String? stackTrace;

  MigrationResult({
    required this.success,
    required this.recordsMigrated,
    required this.duration,
    required this.log,
    this.idMappings = const {},
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'recordsMigrated': recordsMigrated,
      'durationSeconds': duration.inSeconds,
      'logEntries': log.length,
      'idMappingsCount': idMappings.length,
      'error': error,
      'hasStackTrace': stackTrace != null,
    };
  }
}
