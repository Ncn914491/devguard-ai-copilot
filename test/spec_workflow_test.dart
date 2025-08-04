import 'package:flutter_test/flutter_test.dart';
import 'package:devguard_ai_copilot/core/database/database_service.dart';
import 'package:devguard_ai_copilot/core/database/models/models.dart';
import 'package:devguard_ai_copilot/core/database/services/services.dart';
import 'package:devguard_ai_copilot/core/ai/gemini_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Natural Language Specification Workflow Tests', () {
    late DatabaseService databaseService;
    late SpecService specService;
    late AuditLogService auditLogService;
    late GeminiService geminiService;
    const uuid = Uuid();

    setUpAll(() async {
      databaseService = DatabaseService.instance;
      await databaseService.initialize();

      specService = SpecService.instance;
      auditLogService = AuditLogService.instance;
      geminiService = GeminiService.instance;

      // Initialize Gemini service in mock mode
      await geminiService.initialize();
    });

    tearDownAll(() async {
      await databaseService.close();
    });

    group('Gemini AI Service Tests', () {
      test('should process natural language specification', () async {
        // Requirement 1.1: Natural language specification parsing
        const input =
            'Add user authentication with email and password validation';

        final result = await geminiService.processSpecification(input);

        expect(result.interpretation, isNotEmpty);
        expect(result.branchName, contains('feature/'));
        expect(result.commitMessage, startsWith('feat:'));
        expect(result.estimatedComplexity, isIn(['low', 'medium', 'high']));
      });

      test('should handle security-related specifications', () async {
        // Requirement 1.1: Context-aware processing
        const input =
            'Implement OAuth2 authentication and secure API endpoints';

        final result = await geminiService.processSpecification(input);

        expect(result.branchName, contains('security'));
        expect(result.estimatedComplexity, equals('high'));
        expect(result.requiredSkills, contains('security'));
      });

      test('should handle UI-related specifications', () async {
        // Requirement 1.1: Context-aware processing
        const input = 'Create a responsive dashboard with charts and tables';

        final result = await geminiService.processSpecification(input);

        expect(result.branchName, contains('ui'));
        expect(result.requiredSkills, contains('frontend'));
      });
    });

    group('Specification Service Tests', () {
      test('should create specification from natural language input', () async {
        // Requirement 1.1, 1.2: Natural language processing and git action generation
        const input = 'Implement user profile management with avatar upload';
        const userId = 'test-user-1';

        final spec =
            await specService.processSpecification(input, userId: userId);

        expect(spec.id, isNotEmpty);
        expect(spec.rawInput, equals(input));
        expect(spec.aiInterpretation, isNotEmpty);
        expect(spec.suggestedBranchName, startsWith('feature/'));
        expect(spec.suggestedCommitMessage, startsWith('feat:'));
        expect(spec.status, equals('draft'));
        expect(spec.createdAt, isNotNull);
      });

      test('should validate specification input', () async {
        // Requirement 1.5: Clarification request for ambiguous specs
        const ambiguousInput = 'Fix it';

        final validation =
            await specService.validateSpecification(ambiguousInput);

        expect(validation.isValid, isFalse);
        expect(validation.issues, isNotEmpty);
        expect(validation.suggestions, isNotEmpty);
        expect(validation.issues.first, contains('ambiguous'));
      });

      test('should pass validation for clear specifications', () async {
        // Requirement 1.5: Validation of clear specifications
        const clearInput =
            'Implement user authentication system with email login, password reset, and session management';

        final validation = await specService.validateSpecification(clearInput);

        expect(validation.isValid, isTrue);
        expect(validation.issues, isEmpty);
      });

      test('should approve specification', () async {
        // Requirement 1.5, 9.4: Human approval and audit tracking
        const input = 'Add search functionality to the product catalog';
        const userId = 'test-user-2';
        const approverId = 'approver-1';

        final spec =
            await specService.processSpecification(input, userId: userId);
        await specService.approveSpecification(spec.id, approverId);

        final approvedSpec = await specService.getSpecification(spec.id);
        expect(approvedSpec!.status, equals('approved'));
        expect(approvedSpec.approvedBy, equals(approverId));
        expect(approvedSpec.approvedAt, isNotNull);
      });

      test('should update specification status', () async {
        // Requirement 1.4: Specification workflow management
        const input = 'Implement data export functionality';
        const userId = 'test-user-3';

        final spec =
            await specService.processSpecification(input, userId: userId);
        await specService.updateSpecificationStatus(spec.id, 'in_progress',
            userId: userId);

        final updatedSpec = await specService.getSpecification(spec.id);
        expect(updatedSpec!.status, equals('in_progress'));
      });

      test('should retrieve specifications by status', () async {
        // Requirement 1.4: Specification tracking and retrieval
        const input1 = 'Add notification system';
        const input2 = 'Implement caching layer';
        const userId = 'test-user-4';

        final spec1 =
            await specService.processSpecification(input1, userId: userId);
        final spec2 =
            await specService.processSpecification(input2, userId: userId);

        await specService.approveSpecification(spec1.id, userId);
        // spec2 remains in draft

        final draftSpecs = await specService.getSpecificationsByStatus('draft');
        final approvedSpecs =
            await specService.getSpecificationsByStatus('approved');

        expect(draftSpecs.any((s) => s.id == spec2.id), isTrue);
        expect(approvedSpecs.any((s) => s.id == spec1.id), isTrue);
      });

      test('should delete specification', () async {
        // Requirement 9.1: Audit logging for all actions
        const input = 'Add temporary feature for testing';
        const userId = 'test-user-5';

        final spec =
            await specService.processSpecification(input, userId: userId);
        await specService.deleteSpecification(spec.id);

        final deletedSpec = await specService.getSpecification(spec.id);
        expect(deletedSpec, isNull);
      });
    });

    group('Audit Trail Tests', () {
      test('should log specification processing in audit trail', () async {
        // Requirement 9.1, 9.2: AI action logging with context and reasoning
        const input = 'Implement real-time chat functionality';
        const userId = 'audit-test-user';

        final initialLogCount =
            (await auditLogService.getAuditStatistics())['total_logs']!;

        await specService.processSpecification(input, userId: userId);

        final finalLogCount =
            (await auditLogService.getAuditStatistics())['total_logs']!;
        expect(finalLogCount, greaterThan(initialLogCount));

        // Check for specific audit log entries
        final aiActions = await auditLogService.getAIActions();
        expect(
            aiActions.any((log) => log.actionType == 'specification_processed'),
            isTrue);
      });

      test('should log specification approval in audit trail', () async {
        // Requirement 9.4: Human approval recording
        const input = 'Add file upload with virus scanning';
        const userId = 'audit-user-2';
        const approverId = 'audit-approver';

        final spec =
            await specService.processSpecification(input, userId: userId);
        await specService.approveSpecification(spec.id, approverId);

        final approvalLogs = await auditLogService
            .getAuditLogsByActionType('specification_approved');
        expect(
            approvalLogs.any((log) =>
                log.contextData?.contains(spec.id) == true &&
                log.approvedBy == approverId),
            isTrue);
      });

      test('should log validation attempts', () async {
        // Requirement 9.1: Complete audit logging
        const input = 'Make the thing work better';

        await specService.validateSpecification(input);

        final validationLogs = await auditLogService
            .getAuditLogsByActionType('specification_validated');
        expect(validationLogs, isNotEmpty);
        expect(validationLogs.first.aiReasoning, contains('validation'));
      });
    });

    group('Integration Tests', () {
      test('should complete full spec-to-code workflow', () async {
        // Requirements 1.1-1.5: Complete natural language specification processing
        const input =
            'Create API endpoint for user profile updates with validation';
        const userId = 'integration-user';
        const approverId = 'integration-approver';

        // Step 1: Validate input
        final validation = await specService.validateSpecification(input);
        expect(validation.isValid, isTrue);

        // Step 2: Process specification
        final spec =
            await specService.processSpecification(input, userId: userId);
        expect(spec.status, equals('draft'));
        expect(spec.suggestedBranchName, isNotEmpty);
        expect(spec.suggestedCommitMessage, isNotEmpty);

        // Step 3: Approve specification
        await specService.approveSpecification(spec.id, approverId);
        final approvedSpec = await specService.getSpecification(spec.id);
        expect(approvedSpec!.status, equals('approved'));

        // Step 4: Update to in progress
        await specService.updateSpecificationStatus(spec.id, 'in_progress',
            userId: userId);

        // Step 5: Complete
        await specService.updateSpecificationStatus(spec.id, 'completed',
            userId: userId);

        final completedSpec = await specService.getSpecification(spec.id);
        expect(completedSpec!.status, equals('completed'));

        // Verify audit trail
        final auditStats = await auditLogService.getAuditStatistics();
        expect(auditStats['total_logs'], greaterThan(0));
      });

      test('should handle team member assignment suggestions', () async {
        // Requirement 5.2: AI-suggested assignments based on expertise
        // First create a team member with relevant expertise
        final teamMemberService = TeamMemberService.instance;
        final member = TeamMember(
          id: uuid.v4(),
          name: 'Security Expert',
          email: 'security@test.com',
          role: 'developer',
          status: 'active',
          assignments: [],
          expertise: ['security', 'authentication', 'backend'],
          workload: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await teamMemberService.createTeamMember(member);

        // Process a security-related specification
        const input = 'Implement OAuth2 authentication with JWT tokens';
        const userId = 'assignment-test-user';

        final spec =
            await specService.processSpecification(input, userId: userId);

        // The AI should suggest the security expert based on expertise matching
        // Note: This might be null if no matching expertise is found
        expect(spec.assignedTo, isNotNull);
        // Verify the assigned member has security expertise
        final assignedMember =
            await teamMemberService.getTeamMember(spec.assignedTo!);
        expect(assignedMember!.expertise, contains('security'));
      });

      test('should maintain data consistency across services', () async {
        // Requirement 9.1: Data integrity and audit consistency
        const input = 'Add multi-language support with translation management';
        const userId = 'consistency-user';

        final initialAuditCount =
            (await auditLogService.getAuditStatistics())['total_logs']!;

        final spec =
            await specService.processSpecification(input, userId: userId);

        // Verify specification was created
        final retrievedSpec = await specService.getSpecification(spec.id);
        expect(retrievedSpec, isNotNull);
        expect(retrievedSpec!.rawInput, equals(input));

        // Verify audit logs were created
        final finalAuditCount =
            (await auditLogService.getAuditStatistics())['total_logs']!;
        expect(finalAuditCount, greaterThan(initialAuditCount));

        // Verify audit logs contain correct context
        final recentLogs = await auditLogService
            .getAuditLogsByActionType('specification_processed');
        expect(
            recentLogs.any((log) => log.contextData?.contains(spec.id) == true),
            isTrue);
      });
    });

    group('Error Handling Tests', () {
      test('should handle empty specification input gracefully', () async {
        // Requirement 1.5: Input validation and error handling
        expect(
          () => specService.processSpecification(''),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle specification not found', () async {
        // Requirement 1.4: Error handling for missing specifications
        const nonExistentId = 'non-existent-spec-id';

        final spec = await specService.getSpecification(nonExistentId);
        expect(spec, isNull);
      });

      test('should log processing failures', () async {
        // Requirement 9.1: Error logging for transparency
        const invalidInput = ''; // This should cause a failure
        const userId = 'error-test-user';

        try {
          await specService.processSpecification(invalidInput, userId: userId);
        } catch (e) {
          // Expected to fail
        }

        // Check that failure was logged
        final errorLogs = await auditLogService
            .getAuditLogsByActionType('specification_processing_failed');
        expect(errorLogs, isNotEmpty);
      });
    });
  });
}
