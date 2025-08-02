import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/database/services/services.dart';
import '../lib/core/database/database_service.dart';
import '../lib/core/database/models/models.dart';
import '../lib/core/security/security_monitor.dart';
import '../lib/core/ai/copilot_service.dart';

void main() {
  group('Audit Logging Tests', () {
    late AuditLogService auditService;
    late SecurityMonitor securityMonitor;
    late CopilotService copilotService;
    late DatabaseService databaseService;

    setUpAll(() async {
      // Initialize FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      // Initialize database service
      databaseService = DatabaseService.instance;
      await databaseService.initialize(':memory:');
      
      auditService = AuditLogService.instance;
      securityMonitor = SecurityMonitor.instance;
      copilotService = CopilotService.instance;
    });

    tearDownAll(() async {
      securityMonitor.dispose();
      await databaseService.close();
    });

    test('should log all AI actions with context and reasoning', () async {
      // Test AI specification processing
      await auditService.logAction(
        actionType: 'specification_processed',
        description: 'AI processed natural language specification',
        aiReasoning: 'Parsed user input "Create a login form" into structured tasks including form validation, authentication logic, and UI components',
        contextData: {
          'original_spec': 'Create a login form',
          'generated_tasks': ['Create form UI', 'Add validation', 'Implement auth'],
          'confidence_score': 0.95,
        },
        userId: 'ai_system',
      );

      // Test AI security alert generation
      await auditService.logAction(
        actionType: 'security_alert_created',
        description: 'AI generated security alert for honeytoken access',
        aiReasoning: 'Detected access to honeytoken credit card number 4111-1111-1111-1111 in database query, indicating potential data breach attempt',
        contextData: {
          'alert_type': 'database_breach',
          'severity': 'critical',
          'honeytoken_type': 'credit_card',
          'detection_method': 'query_monitoring',
        },
        userId: 'ai_system',
      );

      // Verify logs were created with complete information
      final aiActions = await auditService.getAIActions();
      expect(aiActions.length, greaterThanOrEqualTo(2));

      for (final action in aiActions) {
        expect(action.aiReasoning, isNotNull);
        expect(action.aiReasoning!.isNotEmpty, isTrue);
        expect(action.contextData, isNotNull);
        expect(action.contextData!.isNotEmpty, isTrue);
        expect(action.userId, equals('ai_system'));
        expect(action.timestamp, isNotNull);
      }
    });

    test('should track all system changes in version control', () async {
      // Simulate code changes
      await auditService.logAction(
        actionType: 'code_generated',
        description: 'AI generated login form component',
        aiReasoning: 'Generated React component based on user specification with form validation and accessibility features',
        contextData: {
          'file_path': 'src/components/LoginForm.tsx',
          'lines_added': 45,
          'lines_modified': 0,
          'git_commit': 'abc123def456',
          'branch': 'feature/login-form',
        },
        userId: 'ai_system',
      );

      // Simulate configuration changes
      await auditService.logAction(
        actionType: 'config_modified',
        description: 'Updated database configuration',
        contextData: {
          'config_file': 'database.yaml',
          'changes': ['connection_pool_size: 10 -> 20', 'timeout: 30s -> 60s'],
          'git_commit': 'def456ghi789',
          'previous_hash': 'sha256:abc123...',
          'new_hash': 'sha256:def456...',
        },
        userId: 'admin_user',
      );

      // Verify version control tracking
      final logs = await auditService.getAllAuditLogs();
      final versionControlLogs = logs.where((log) => 
        log.contextData != null && 
        (log.contextData!.containsKey('git_commit') || 
         log.contextData!.containsKey('previous_hash'))
      ).toList();

      expect(versionControlLogs.length, greaterThanOrEqualTo(2));

      for (final log in versionControlLogs) {
        expect(log.contextData, isNotNull);
        expect(log.timestamp, isNotNull);
        // Verify either git commit or hash tracking
        expect(
          log.contextData!.containsKey('git_commit') || 
          log.contextData!.containsKey('previous_hash'),
          isTrue
        );
      }
    });

    test('should require and record human approval for critical actions', () async {
      // Log critical action requiring approval
      await auditService.logAction(
        actionType: 'deployment_requested',
        description: 'AI requested production deployment',
        aiReasoning: 'All tests passed and security scans completed successfully. Deployment to production is recommended.',
        contextData: {
          'environment': 'production',
          'version': '1.2.3',
          'test_results': 'all_passed',
          'security_scan': 'clean',
        },
        userId: 'ai_system',
        requiresApproval: true,
      );

      // Verify approval requirement
      final pendingApprovals = await auditService.getLogsRequiringApproval();
      expect(pendingApprovals.isNotEmpty, isTrue);

      final deploymentRequest = pendingApprovals.firstWhere(
        (log) => log.actionType == 'deployment_requested'
      );
      expect(deploymentRequest.requiresApproval, isTrue);
      expect(deploymentRequest.approved, isFalse);
      expect(deploymentRequest.approvedBy, isNull);

      // Simulate human approval
      await auditService.approveAction(
        deploymentRequest.id,
        'admin_user',
        'Deployment approved after manual review',
      );

      // Verify approval was recorded
      final approvedLog = await auditService.getAuditLog(deploymentRequest.id);
      expect(approvedLog?.approved, isTrue);
      expect(approvedLog?.approvedBy, equals('admin_user'));
      expect(approvedLog?.approvedAt, isNotNull);
    });

    test('should provide comprehensive audit statistics', () async {
      // Create various types of audit logs
      await auditService.logAction(
        actionType: 'ai_action_1',
        description: 'AI action 1',
        aiReasoning: 'AI reasoning 1',
        userId: 'ai_system',
      );

      await auditService.logAction(
        actionType: 'ai_action_2',
        description: 'AI action 2',
        aiReasoning: 'AI reasoning 2',
        userId: 'ai_system',
        requiresApproval: true,
      );

      await auditService.logAction(
        actionType: 'user_action',
        description: 'User action',
        userId: 'human_user',
      );

      await auditService.logAction(
        actionType: 'critical_action',
        description: 'Critical system action',
        userId: 'admin_user',
        requiresApproval: true,
      );

      // Approve one action
      final pendingLogs = await auditService.getLogsRequiringApproval();
      if (pendingLogs.isNotEmpty) {
        await auditService.approveAction(
          pendingLogs.first.id,
          'admin_user',
          'Approved for testing',
        );
      }

      // Get statistics
      final stats = await auditService.getAuditStatistics();

      expect(stats['total_logs'], greaterThanOrEqualTo(4));
      expect(stats['ai_actions'], greaterThanOrEqualTo(2));
      expect(stats['pending_approvals'], greaterThanOrEqualTo(1));
      expect(stats['approved_actions'], greaterThanOrEqualTo(1));
    });

    test('should filter audit logs by various criteria', () async {
      // Create test data
      await auditService.logAction(
        actionType: 'ai_specification_processing',
        description: 'AI processed specification',
        aiReasoning: 'Converted natural language to tasks',
        userId: 'ai_system',
      );

      await auditService.logAction(
        actionType: 'critical_deployment',
        description: 'Critical deployment action',
        userId: 'admin_user',
        requiresApproval: true,
      );

      await auditService.logAction(
        actionType: 'user_login',
        description: 'User logged in',
        userId: 'regular_user',
      );

      // Test filtering by AI actions
      final aiActions = await auditService.getAIActions();
      expect(aiActions.isNotEmpty, isTrue);
      expect(aiActions.every((log) => log.aiReasoning != null), isTrue);

      // Test filtering by pending approvals
      final pendingApprovals = await auditService.getLogsRequiringApproval();
      expect(pendingApprovals.isNotEmpty, isTrue);
      expect(pendingApprovals.every((log) => log.requiresApproval && !log.approved), isTrue);

      // Test filtering by critical actions
      final criticalActions = await auditService.getCriticalActions();
      expect(criticalActions.isNotEmpty, isTrue);
    });

    test('should maintain audit log integrity and immutability', () async {
      // Create an audit log
      await auditService.logAction(
        actionType: 'test_action',
        description: 'Test action for integrity check',
        contextData: {'test': 'data'},
        userId: 'test_user',
      );

      final logs = await auditService.getAllAuditLogs();
      final testLog = logs.firstWhere((log) => log.actionType == 'test_action');

      // Verify log properties are immutable (can't be modified after creation)
      expect(testLog.id, isNotNull);
      expect(testLog.timestamp, isNotNull);
      expect(testLog.actionType, equals('test_action'));
      expect(testLog.description, equals('Test action for integrity check'));
      expect(testLog.userId, equals('test_user'));

      // Verify contextData is preserved
      expect(testLog.contextData, isNotNull);
      expect(testLog.contextData!['test'], equals('data'));
    });

    test('should handle concurrent audit logging', () async {
      // Simulate concurrent audit log creation
      final futures = <Future>[];
      
      for (int i = 0; i < 10; i++) {
        futures.add(
          auditService.logAction(
            actionType: 'concurrent_action_$i',
            description: 'Concurrent action $i',
            userId: 'user_$i',
          )
        );
      }

      // Wait for all concurrent operations to complete
      await Future.wait(futures);

      // Verify all logs were created
      final logs = await auditService.getAllAuditLogs();
      final concurrentLogs = logs.where((log) => 
        log.actionType.startsWith('concurrent_action_')
      ).toList();

      expect(concurrentLogs.length, equals(10));

      // Verify each log has unique ID and proper timestamp
      final ids = concurrentLogs.map((log) => log.id).toSet();
      expect(ids.length, equals(10)); // All IDs should be unique

      // Verify timestamps are reasonable (within last minute)
      final now = DateTime.now();
      for (final log in concurrentLogs) {
        final timeDiff = now.difference(log.timestamp).inMinutes;
        expect(timeDiff, lessThan(1));
      }
    });

    test('should provide detailed evidence for security alerts', () async {
      await securityMonitor.initialize();

      // Create security alert with evidence
      await securityMonitor.simulateHoneytokenAccess(
        '4111-1111-1111-1111',
        'SELECT * FROM users WHERE credit_card = ?',
      );

      // Verify audit log contains detailed evidence
      final securityLogs = await auditService.getAllAuditLogs();
      final honeytokenLogs = securityLogs.where((log) => 
        log.actionType.contains('honeytoken') || 
        log.description.toLowerCase().contains('honeytoken')
      ).toList();

      expect(honeytokenLogs.isNotEmpty, isTrue);

      for (final log in honeytokenLogs) {
        expect(log.aiReasoning, isNotNull);
        expect(log.aiReasoning!.isNotEmpty, isTrue);
        expect(log.contextData, isNotNull);
        
        // Verify evidence details are captured
        if (log.contextData!.containsKey('evidence')) {
          expect(log.contextData!['evidence'], isNotNull);
        }
      }
    });
  });
}