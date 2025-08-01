import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../database_service.dart';
import '../models/specification.dart';
import '../../ai/gemini_service.dart';
import 'audit_log_service.dart';
import 'team_member_service.dart';

class SpecService {
  static final SpecService _instance = SpecService._internal();
  static SpecService get instance => _instance;
  SpecService._internal();

  final _uuid = const Uuid();
  final _geminiService = GeminiService.instance;
  final _auditService = AuditLogService.instance;
  final _teamMemberService = TeamMemberService.instance;

  Future<Database> get _db async => await DatabaseService.instance.database;

  /// Process natural language specification and create structured git actions
  /// Satisfies Requirements: 1.1, 1.2, 1.4 (Natural language processing and git action generation)
  Future<Specification> processSpecification(String naturalLanguageInput, {String? userId}) async {
    if (naturalLanguageInput.trim().isEmpty) {
      throw Exception('Specification input cannot be empty');
    }
    
    final specId = _uuid.v4();
    
    try {
      // Process with AI service
      final aiResult = await _geminiService.processSpecification(naturalLanguageInput);
      
      // Create specification record
      final specification = Specification(
        id: specId,
        rawInput: naturalLanguageInput,
        aiInterpretation: aiResult.interpretation,
        suggestedBranchName: aiResult.branchName,
        suggestedCommitMessage: aiResult.commitMessage,
        placeholderDiff: aiResult.placeholderDiff,
        status: 'draft',
        assignedTo: await _suggestAssignee(aiResult),
        createdAt: DateTime.now(),
      );

      // Store in database
      await _createSpecification(specification);

      // Log AI interpretation for audit trail (Requirement 9.1, 9.2)
      await _auditService.logAction(
        actionType: 'specification_processed',
        description: 'AI processed natural language specification',
        aiReasoning: 'Converted natural language input into structured git actions: ${aiResult.branchName}',
        contextData: {
          'spec_id': specId,
          'input_length': naturalLanguageInput.length,
          'branch_name': aiResult.branchName,
          'commit_message': aiResult.commitMessage,
          'complexity': aiResult.estimatedComplexity,
          'required_skills': aiResult.requiredSkills,
        },
        userId: userId,
      );

      return specification;
    } catch (e) {
      // Log error for transparency (Requirement 9.1)
      await _auditService.logAction(
        actionType: 'specification_processing_failed',
        description: 'Failed to process specification: ${e.toString()}',
        contextData: {'spec_id': specId, 'error': e.toString()},
        userId: userId,
      );
      rethrow;
    }
  }

  /// Create a new specification in the database
  /// Satisfies Requirements: 9.1 (Audit logging for all actions)
  Future<String> _createSpecification(Specification specification) async {
    final db = await _db;
    await db.insert('specifications', specification.toMap());
    
    // Log specification creation
    await _auditService.logAction(
      actionType: 'specification_created',
      description: 'Created specification: ${specification.suggestedBranchName}',
      contextData: {
        'spec_id': specification.id,
        'status': specification.status,
        'assigned_to': specification.assignedTo,
      },
    );

    return specification.id;
  }

  /// Get specification by ID
  /// Satisfies Requirements: 1.4 (Specification tracking and retrieval)
  Future<Specification?> getSpecification(String id) async {
    final db = await _db;
    final maps = await db.query(
      'specifications',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Specification.fromMap(maps.first);
    }
    return null;
  }

  /// Get all specifications
  /// Satisfies Requirements: 1.4 (Specification management and tracking)
  Future<List<Specification>> getAllSpecifications() async {
    final db = await _db;
    final maps = await db.query('specifications', orderBy: 'created_at DESC');
    return maps.map((map) => Specification.fromMap(map)).toList();
  }

  /// Get specifications by status
  /// Satisfies Requirements: 1.4 (Specification workflow tracking)
  Future<List<Specification>> getSpecificationsByStatus(String status) async {
    final db = await _db;
    final maps = await db.query(
      'specifications',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Specification.fromMap(map)).toList();
  }

  /// Approve a specification
  /// Satisfies Requirements: 1.5, 9.4 (Human approval and audit tracking)
  Future<void> approveSpecification(String specId, String approvedBy) async {
    final db = await _db;
    final specification = await getSpecification(specId);
    if (specification == null) return;

    final approvedSpec = specification.copyWith(
      status: 'approved',
      approvedAt: DateTime.now(),
      approvedBy: approvedBy,
    );

    await db.update(
      'specifications',
      approvedSpec.toMap(),
      where: 'id = ?',
      whereArgs: [specId],
    );

    // Log approval for audit trail (Requirement 9.4)
    await _auditService.logAction(
      actionType: 'specification_approved',
      description: 'Approved specification: ${specification.suggestedBranchName}',
      contextData: {
        'spec_id': specId,
        'approved_by': approvedBy,
        'branch_name': specification.suggestedBranchName,
      },
      requiresApproval: false, // Already approved
      approvedBy: approvedBy,
      userId: approvedBy,
    );
  }

  /// Update specification status
  /// Satisfies Requirements: 1.4 (Specification workflow management)
  Future<void> updateSpecificationStatus(String specId, String status, {String? userId}) async {
    final db = await _db;
    final specification = await getSpecification(specId);
    if (specification == null) return;

    final updatedSpec = specification.copyWith(status: status);
    await db.update(
      'specifications',
      updatedSpec.toMap(),
      where: 'id = ?',
      whereArgs: [specId],
    );

    // Log status change (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'specification_status_updated',
      description: 'Updated specification status: ${specification.suggestedBranchName} -> $status',
      contextData: {
        'spec_id': specId,
        'old_status': specification.status,
        'new_status': status,
      },
      userId: userId,
    );
  }

  /// Validate specification for ambiguity or completeness
  /// Satisfies Requirements: 1.5 (Clarification request for ambiguous specs)
  Future<ValidationResult> validateSpecification(String naturalLanguageInput) async {
    final issues = <String>[];
    final suggestions = <String>[];

    // Check for ambiguous terms (only standalone words, not parts of other words)
    final ambiguousTerms = [' it ', ' this ', ' that ', ' something ', ' stuff '];
    final inputWithSpaces = ' ${naturalLanguageInput.toLowerCase()} ';
    for (final term in ambiguousTerms) {
      if (inputWithSpaces.contains(term)) {
        issues.add('Specification contains ambiguous term: "${term.trim()}"');
        suggestions.add('Please be more specific about what "${term.trim()}" refers to');
      }
    }

    // Check for missing context
    if (naturalLanguageInput.length < 10) {
      issues.add('Specification is too brief');
      suggestions.add('Please provide more details about what you want to implement');
    }

    // Check for technical requirements (only suggest, don't mark as invalid)
    final technicalKeywords = ['database', 'api', 'ui', 'security', 'performance', 'authentication', 'user', 'system'];
    final hasTechnicalContext = technicalKeywords.any(
      (keyword) => naturalLanguageInput.toLowerCase().contains(keyword)
    );

    if (!hasTechnicalContext && naturalLanguageInput.length < 50) {
      suggestions.add('Consider specifying technical requirements (database, API, UI, etc.)');
    }

    final isValid = issues.isEmpty;
    
    // Log validation attempt (Requirement 9.1)
    await _auditService.logAction(
      actionType: 'specification_validated',
      description: 'Validated specification input',
      aiReasoning: isValid 
          ? 'Specification passed validation checks'
          : 'Specification failed validation: ${issues.join(", ")}',
      contextData: {
        'input_length': naturalLanguageInput.length,
        'is_valid': isValid,
        'issues_count': issues.length,
        'suggestions_count': suggestions.length,
      },
    );

    return ValidationResult(
      isValid: isValid,
      issues: issues,
      suggestions: suggestions,
    );
  }

  /// Suggest assignee based on AI analysis and team expertise
  /// Satisfies Requirements: 5.2 (AI-suggested assignments based on expertise)
  Future<String?> _suggestAssignee(SpecificationResult aiResult) async {
    if (aiResult.requiredSkills.isEmpty) return null;

    try {
      final availableMembers = await _teamMemberService.getAvailableMembers();
      
      // Find team member with matching expertise and lowest workload
      String? bestMatch;
      int lowestWorkload = 999;

      for (final member in availableMembers) {
        final matchingSkills = member.expertise.where(
          (skill) => aiResult.requiredSkills.any(
            (required) => skill.toLowerCase().contains(required.toLowerCase())
          )
        ).length;

        if (matchingSkills > 0 && member.workload < lowestWorkload) {
          bestMatch = member.id;
          lowestWorkload = member.workload;
        }
      }

      return bestMatch;
    } catch (e) {
      // If team member lookup fails, return null
      return null;
    }
  }

  /// Delete specification
  /// Satisfies Requirements: 9.1 (Audit logging for all actions)
  Future<void> deleteSpecification(String id) async {
    final db = await _db;
    final specification = await getSpecification(id);
    
    await db.delete(
      'specifications',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Log deletion for audit trail
    await _auditService.logAction(
      actionType: 'specification_deleted',
      description: 'Deleted specification: ${specification?.suggestedBranchName ?? id}',
      contextData: {'spec_id': id},
    );
  }

  /// Get specifications assigned to a team member
  /// Satisfies Requirements: 5.2, 5.3 (Assignment tracking)
  Future<List<Specification>> getSpecificationsByAssignee(String assigneeId) async {
    final db = await _db;
    final maps = await db.query(
      'specifications',
      where: 'assigned_to = ?',
      whereArgs: [assigneeId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Specification.fromMap(map)).toList();
  }
}

/// Result class for specification validation
class ValidationResult {
  final bool isValid;
  final List<String> issues;
  final List<String> suggestions;

  ValidationResult({
    required this.isValid,
    required this.issues,
    required this.suggestions,
  });
}