import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  static GeminiService get instance => _instance;
  GeminiService._internal();

  late GenerativeModel _model;
  bool _initialized = false;

  /// Initialize the Gemini service with API key
  /// For demo purposes, we'll use a mock implementation if no API key is provided
  Future<void> initialize({String? apiKey}) async {
    final key = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY');
    if (key.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: key,
      );
      _initialized = true;
    } else {
      // Mock mode for development/demo
      _initialized = false;
    }
  }

  /// Process natural language specification and return structured git actions
  /// Satisfies Requirements: 1.1, 1.2 (Natural language parsing and git action generation)
  Future<SpecificationResult> processSpecification(String naturalLanguageInput) async {
    if (!_initialized) {
      // Mock implementation for demo purposes
      return _mockProcessSpecification(naturalLanguageInput);
    }

    try {
      final prompt = _buildSpecificationPrompt(naturalLanguageInput);
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text != null) {
        return _parseSpecificationResponse(response.text!, naturalLanguageInput);
      } else {
        throw Exception('No response from Gemini API');
      }
    } catch (e) {
      // Fallback to mock implementation on error
      return _mockProcessSpecification(naturalLanguageInput);
    }
  }

  /// Build the prompt for specification processing
  String _buildSpecificationPrompt(String input) {
    return '''
You are a DevOps AI assistant that converts natural language specifications into structured git actions.

Given the following specification:
"$input"

Please analyze this specification and provide a JSON response with the following structure:
{
  "interpretation": "A clear interpretation of what the user wants to implement",
  "branchName": "A git branch name following kebab-case convention (e.g., feature/user-authentication)",
  "commitMessage": "A descriptive commit message following conventional commits format",
  "placeholderDiff": "A text description of the expected code changes (not actual code)",
  "suggestedAssignee": "If the specification mentions a specific person or role, suggest who should work on this",
  "estimatedComplexity": "low|medium|high",
  "requiredSkills": ["list", "of", "required", "skills"]
}

Focus on:
1. Clear, actionable interpretation
2. Proper git naming conventions
3. Descriptive commit messages
4. Realistic implementation expectations

Respond only with valid JSON.
''';
  }

  /// Parse the Gemini API response into a SpecificationResult
  SpecificationResult _parseSpecificationResponse(String response, String originalInput) {
    try {
      final jsonResponse = json.decode(response);
      
      return SpecificationResult(
        interpretation: jsonResponse['interpretation'] ?? 'AI interpretation not available',
        branchName: jsonResponse['branchName'] ?? _generateDefaultBranchName(originalInput),
        commitMessage: jsonResponse['commitMessage'] ?? _generateDefaultCommitMessage(originalInput),
        placeholderDiff: jsonResponse['placeholderDiff'],
        suggestedAssignee: jsonResponse['suggestedAssignee'],
        estimatedComplexity: jsonResponse['estimatedComplexity'] ?? 'medium',
        requiredSkills: List<String>.from(jsonResponse['requiredSkills'] ?? []),
      );
    } catch (e) {
      // If JSON parsing fails, create a basic result
      return SpecificationResult(
        interpretation: 'AI processed the specification: $originalInput',
        branchName: _generateDefaultBranchName(originalInput),
        commitMessage: _generateDefaultCommitMessage(originalInput),
        placeholderDiff: 'Implementation details to be determined during development',
        suggestedAssignee: null,
        estimatedComplexity: 'medium',
        requiredSkills: [],
      );
    }
  }

  /// Mock implementation for development/demo purposes
  /// Satisfies Requirements: 1.1, 1.5 (Specification processing with clarification)
  SpecificationResult _mockProcessSpecification(String input) {
    final lowerInput = input.toLowerCase();
    
    // Analyze input for keywords to provide intelligent suggestions
    String branchName;
    String commitMessage;
    String interpretation;
    String complexity = 'medium';
    List<String> skills = [];
    
    if (lowerInput.contains('security') || lowerInput.contains('auth') || lowerInput.contains('encryption') || lowerInput.contains('oauth')) {
      branchName = 'feature/security-enhancement';
      commitMessage = 'feat: implement security enhancement';
      interpretation = 'Implementing security-related functionality including authentication and authorization improvements';
      complexity = 'high';
      skills = ['security', 'authentication', 'backend'];
    } else if (lowerInput.contains('ui') || lowerInput.contains('interface') || lowerInput.contains('dashboard')) {
      branchName = 'feature/ui-improvement';
      commitMessage = 'feat: enhance user interface';
      interpretation = 'Improving user interface components and dashboard functionality';
      complexity = 'medium';
      skills = ['frontend', 'ui/ux', 'flutter'];
    } else if (lowerInput.contains('database') || lowerInput.contains('data')) {
      branchName = 'feature/database-update';
      commitMessage = 'feat: update database schema and operations';
      interpretation = 'Implementing database schema changes and data management improvements';
      complexity = 'medium';
      skills = ['database', 'backend', 'sql'];
    } else if (lowerInput.contains('api') || lowerInput.contains('service')) {
      branchName = 'feature/api-integration';
      commitMessage = 'feat: integrate new API service';
      interpretation = 'Adding new API integration and service layer functionality';
      complexity = 'medium';
      skills = ['api', 'backend', 'integration'];
    } else {
      // Generic feature
      final words = input.split(' ').take(3).join('-').toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
      branchName = 'feature/$words';
      commitMessage = 'feat: implement $words';
      interpretation = 'Implementing the requested feature: $input';
      skills = ['development'];
    }

    return SpecificationResult(
      interpretation: interpretation,
      branchName: branchName,
      commitMessage: commitMessage,
      placeholderDiff: 'Changes will include:\n- Implementation of core functionality\n- Unit tests\n- Documentation updates\n- Integration with existing systems',
      suggestedAssignee: null,
      estimatedComplexity: complexity,
      requiredSkills: skills,
    );
  }

  /// Generate a default branch name from input
  String _generateDefaultBranchName(String input) {
    final words = input.split(' ').take(3).join('-').toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
    return 'feature/$words';
  }

  /// Generate a default commit message from input
  String _generateDefaultCommitMessage(String input) {
    final shortDescription = input.length > 50 ? '${input.substring(0, 47)}...' : input;
    return 'feat: $shortDescription';
  }

  /// Check if the service is initialized and ready
  bool get isInitialized => _initialized;
}

/// Result class for specification processing
class SpecificationResult {
  final String interpretation;
  final String branchName;
  final String commitMessage;
  final String? placeholderDiff;
  final String? suggestedAssignee;
  final String estimatedComplexity;
  final List<String> requiredSkills;

  SpecificationResult({
    required this.interpretation,
    required this.branchName,
    required this.commitMessage,
    this.placeholderDiff,
    this.suggestedAssignee,
    required this.estimatedComplexity,
    required this.requiredSkills,
  });
}