/// Validation result class for form validation
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, String> fieldErrors;
  final List<String> issues;
  final List<String> suggestions;

  ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.fieldErrors = const {},
    this.issues = const [],
    this.suggestions = const [],
  });

  /// Create a successful validation result
  factory ValidationResult.success() {
    return ValidationResult(isValid: true);
  }

  /// Create a failed validation result with errors
  factory ValidationResult.failure(List<String> errors,
      {Map<String, String>? fieldErrors,
      List<String>? issues,
      List<String>? suggestions}) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      fieldErrors: fieldErrors ?? {},
      issues: issues ?? errors,
      suggestions: suggestions ?? [],
    );
  }

  /// Create a failed validation result with a single error
  factory ValidationResult.singleError(String error) {
    return ValidationResult(
      isValid: false,
      errors: [error],
      issues: [error],
    );
  }

  /// Create a failed validation result with field-specific errors
  factory ValidationResult.fieldErrors(Map<String, String> fieldErrors) {
    return ValidationResult(
      isValid: false,
      fieldErrors: fieldErrors,
      errors: fieldErrors.values.toList(),
      issues: fieldErrors.values.toList(),
    );
  }

  /// Get error message for a specific field
  String? getFieldError(String fieldName) {
    return fieldErrors[fieldName];
  }

  /// Check if a specific field has an error
  bool hasFieldError(String fieldName) {
    return fieldErrors.containsKey(fieldName);
  }

  /// Get all error messages as a single string
  String get errorMessage {
    if (errors.isEmpty) return '';
    return errors.join('\n');
  }

  @override
  String toString() {
    if (isValid) return 'ValidationResult: Valid';
    return 'ValidationResult: Invalid - ${errors.join(', ')}';
  }
}
