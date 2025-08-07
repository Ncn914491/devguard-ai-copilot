import 'dart:async';
import 'package:uuid/uuid.dart';
import '../database/services/services.dart';

/// Git Security Enforcer
/// Enforces security policies in git operations and code access
/// Satisfies Requirements: 9.2 (Security policy enforcement in git operations)
class GitSecurityEnforcer {
  static final GitSecurityEnforcer _instance = GitSecurityEnforcer._internal();
  static GitSecurityEnforcer get instance => _instance;
  GitSecurityEnforcer._internal();

  final _auditService = AuditLogService.instance;

  /// Enforce security policies before git commit
  /// Satisfies Requirements: 9.2 (Git operation security enforcement)
  Future<GitSecurityResult> enforceCommitSecurity({
    required String userId,
    required String userRole,
    required List<String> modifiedFiles,
    required String commitMessage,
    required Map<String, String> fileChanges,
  }) async {
    final violations = <String>[];
    final warnings = <String>[];

    // Check commit message security
    final messageCheck = _checkCommitMessageSecurity(commitMessage);
    violations.addAll(messageCheck.violations);
    warnings.addAll(messageCheck.warnings);

    // Check file modifications
    final fileCheck = await _checkFileModificationSecurity(modifiedFiles, fileChanges, userRole);
    violations.addAll(fileCheck.violations);
    warnings.addAll(fileCheck.warnings);

    // Check for sensitive data exposure
    final sensitiveDataCheck = _checkSensitiveDataExposure(fileChanges);
    violations.addAll(sensitiveDataCheck.violations);
    warnings.addAll(sensitiveDataCheck.warnings);

    final result = GitSecurityResult(
      allowed: violations.isEmpty,
      violations: violations,
      warnings: warnings,
      requiresApproval: violations.isNotEmpty || (warnings.isNotEmpty && userRole == 'developer'),
    );

    await _auditService.logAction(
      actionType: 'git_commit_security_check',
      description: 'Security enforcement for git commit',
      contextData: {
        'user_id': userId,
        'user_role': userRole,
        'files_modified': modifiedFiles.length,
        'violations': violations.length,
        'warnings': warnings.length,
        'allowed': result.allowed,
      },
      userId: userId,
    );

    return result;
  }

  /// Enforce security policies before git push
  /// Satisfies Requirements: 9.2 (Push operation security)
  Future<GitSecurityResult> enforcePushSecurity({
    required String userId,
    required String userRole,
    required String branchName,
    required List<String> commitHashes,
  }) async {
    final violations = <String>[];
    final warnings = <String>[];

    // Check branch security
    final branchCheck = _checkBranchSecurity(branchName, userRole);
    violations.addAll(branchCheck.violations);
    warnings.addAll(branchCheck.warnings);

    // Check push permissions
    if (!_hasUserPushPermission(userRole, branchName)) {
      violations.add('User does not have push permission for branch: $branchName');
    }

    // Check for force push restrictions
    if (branchName == 'main' || branchName == 'master') {
      if (userRole != 'admin') {
        violations.add('Only admins can push to protected branch: $branchName');
      }
    }

    final result = GitSecurityResult(
      allowed: violations.isEmpty,
      violations: violations,
      warnings: warnings,
      requiresApproval: violations.isNotEmpty,
    );

    await _auditService.logAction(
      actionType: 'git_push_security_check',
      description: 'Security enforcement for git push',
      contextData: {
        'user_id': userId,
        'user_role': userRole,
        'branch_name': branchName,
        'commits_count': commitHashes.length,
        'violations': violations.length,
        'allowed': result.allowed,
      },
      userId: userId,
    );

    return result;
  }

  /// Enforce security policies for code access
  /// Satisfies Requirements: 9.2 (Code access security)
  Future<CodeAccessResult> enforceCodeAccess({
    required String userId,
    required String userRole,
    required String filePath,
    required String accessType, // 'read', 'write', 'execute'
  }) async {
    final violations = <String>[];
    final warnings = <String>[];

    // Check file access permissions
    final fileAccessCheck = _checkFileAccessPermissions(filePath, userRole, accessType);
    violations.addAll(fileAccessCheck.violations);
    warnings.addAll(fileAccessCheck.warnings);

    // Check for sensitive file access
    if (_isSensitiveFile(filePath)) {
      if (accessType == 'write' && userRole == 'developer') {
        violations.add('Developers cannot modify sensitive file: $filePath');
      } else if (accessType == 'read' && userRole == 'viewer' && _isHighlySensitiveFile(filePath)) {
        violations.add('Viewers cannot access highly sensitive file: $filePath');
      }
    }

    final result = CodeAccessResult(
      allowed: violations.isEmpty,
      violations: violations,
      warnings: warnings,
      requiresApproval: violations.isNotEmpty,
    );

    await _auditService.logAction(
      actionType: 'code_access_security_check',
      description: 'Security enforcement for code access',
      contextData: {
        'user_id': userId,
        'user_role': userRole,
        'file_path': filePath,
        'access_type': accessType,
        'violations': violations.length,
        'allowed': result.allowed,
      },
      userId: userId,
    );

    return result;
  }

  /// Check commit message for security issues
  SecurityCheckResult _checkCommitMessageSecurity(String message) {
    final violations = <String>[];
    final warnings = <String>[];

    // Check for sensitive information in commit message
    final sensitivePatterns = [
      RegExp(r'password\s*[:=]\s*\S+', caseSensitive: false),
      RegExp(r'secret\s*[:=]\s*\S+', caseSensitive: false),
      RegExp(r'token\s*[:=]\s*\S+', caseSensitive: false),
      RegExp(r'api[_-]?key\s*[:=]\s*\S+', caseSensitive: false),
    ];

    for (final pattern in sensitivePatterns) {
      if (pattern.hasMatch(message)) {
        violations.add('Commit message contains sensitive information');
        break;
      }
    }

    // Check for proper commit message format
    if (message.length < 10) {
      warnings.add('Commit message is too short - should be descriptive');
    }

    return SecurityCheckResult(violations: violations, warnings: warnings);
  }

  /// Check file modifications for security issues
  Future<SecurityCheckResult> _checkFileModificationSecurity(
    List<String> files,
    Map<String, String> changes,
    String userRole,
  ) async {
    final violations = <String>[];
    final warnings = <String>[];

    for (final file in files) {
      // Check sensitive file modifications
      if (_isSensitiveFile(file)) {
        if (userRole == 'developer') {
          violations.add('Developer cannot modify sensitive file: $file');
        } else if (userRole == 'lead_developer') {
          warnings.add('Lead developer modifying sensitive file: $file');
        }
      }

      // Check for configuration file changes
      if (_isConfigurationFile(file)) {
        if (userRole != 'admin' && userRole != 'lead_developer') {
          violations.add('Insufficient permissions to modify configuration file: $file');
        }
      }

      // Check file content for security issues
      final content = changes[file] ?? '';
      final contentCheck = _checkFileContentSecurity(content, file);
      violations.addAll(contentCheck.violations);
      warnings.addAll(contentCheck.warnings);
    }

    return SecurityCheckResult(violations: violations, warnings: warnings);
  }

  /// Check for sensitive data exposure in file changes
  SecurityCheckResult _checkSensitiveDataExposure(Map<String, String> fileChanges) {
    final violations = <String>[];
    final warnings = <String>[];

    final sensitivePatterns = [
      RegExp(r'password\s*[:=]\s*["\'][^"\']+["\']', caseSensitive: false),
      RegExp(r'secret\s*[:=]\s*["\'][^"\']+["\']', caseSensitive: false),
      RegExp(r'api_key\s*[:=]\s*["\'][^"\']+["\']', caseSensitive: false),
      RegExp(r'token\s*[:=]\s*["\'][^"\']+["\']', caseSensitive: false),
      RegExp(r'private_key\s*[:=]\s*["\'][^"\']+["\']', caseSensitive: false),
    ];

    for (final entry in fileChanges.entries) {
      final content = entry.value;
      for (final pattern in sensitivePatterns) {
        if (pattern.hasMatch(content)) {
          violations.add('Sensitive data detected in file: ${entry.key}');
          break;
        }
      }
    }

    return SecurityCheckResult(violations: violations, warnings: warnings);
  }

  /// Check branch security
  SecurityCheckResult _checkBranchSecurity(String branchName, String userRole) {
    final violations = <String>[];
    final warnings = <String>[];

    // Check protected branches
    final protectedBranches = ['main', 'master', 'production', 'release'];
    if (protectedBranches.contains(branchName.toLowerCase())) {
      if (userRole == 'developer') {
        violations.add('Developers cannot push to protected branch: $branchName');
      } else if (userRole == 'lead_developer') {
        warnings.add('Lead developer pushing to protected branch: $branchName');
      }
    }

    // Check security branch naming
    if (branchName.startsWith('security/') && userRole == 'developer') {
      violations.add('Only lead developers and admins can create security branches');
    }

    return SecurityCheckResult(violations: violations, warnings: warnings);
  }

  /// Check if user has push permission
  bool _hasUserPushPermission(String userRole, String branchName) {
    switch (userRole) {
      case 'admin':
        return true;
      case 'lead_developer':
        return true;
      case 'developer':
        return !['main', 'master', 'production'].contains(branchName.toLowerCase());
      case 'viewer':
        return false;
      default:
        return false;
    }
  }

  /// Check file access permissions
  SecurityCheckResult _checkFileAccessPermissions(String filePath, String userRole, String accessType) {
    final violations = <String>[];
    final warnings = <String>[];

    // Check sensitive file access
    if (_isSensitiveFile(filePath)) {
      if (accessType == 'write') {
        switch (userRole) {
          case 'developer':
            violations.add('Developers cannot write to sensitive file: $filePath');
            break;
          case 'lead_developer':
            warnings.add('Lead developer writing to sensitive file: $filePath');
            break;
        }
      }
    }

    // Check configuration file access
    if (_isConfigurationFile(filePath) && accessType == 'write') {
      if (userRole == 'developer' || userRole == 'viewer') {
        violations.add('Insufficient permissions to write configuration file: $filePath');
      }
    }

    return SecurityCheckResult(violations: violations, warnings: warnings);
  }

  /// Check if file is sensitive
  bool _isSensitiveFile(String filePath) {
    final sensitivePatterns = [
      '.env',
      'config/database',
      'config/security',
      'secrets/',
      'keys/',
      'certificates/',
      'auth/',
      'security/',
    ];

    return sensitivePatterns.any((pattern) => filePath.contains(pattern));
  }

  /// Check if file is highly sensitive
  bool _isHighlySensitiveFile(String filePath) {
    final highlySensitivePatterns = [
      'secrets/',
      'keys/',
      'certificates/',
      '.env.production',
      'config/security.json',
    ];

    return highlySensitivePatterns.any((pattern) => filePath.contains(pattern));
  }

  /// Check if file is a configuration file
  bool _isConfigurationFile(String filePath) {
    final configPatterns = [
      'config/',
      '.env',
      'settings.json',
      'app.config',
      'database.json',
    ];

    return configPatterns.any((pattern) => filePath.contains(pattern));
  }

  /// Check file content for security issues
  SecurityCheckResult _checkFileContentSecurity(String content, String filePath) {
    final violations = <String>[];
    final warnings = <String>[];

    // Check for hardcoded credentials
    final credentialPatterns = [
      RegExp(r'password\s*=\s*["\'][^"\']+["\']', caseSensitive: false),
      RegExp(r'secret\s*=\s*["\'][^"\']+["\']', caseSensitive: false),
      RegExp(r'api_key\s*=\s*["\'][^"\']+["\']', caseSensitive: false),
    ];

    for (final pattern in credentialPatterns) {
      if (pattern.hasMatch(content)) {
        violations.add('Hardcoded credentials detected in: $filePath');
        break;
      }
    }

    // Check for SQL injection vulnerabilities
    if (content.contains('SELECT') && content.contains('\$')) {
      warnings.add('Potential SQL injection vulnerability in: $filePath');
    }

    // Check for XSS vulnerabilities
    if (content.contains('innerHTML') || content.contains('document.write')) {
      warnings.add('Potential XSS vulnerability in: $filePath');
    }

    return SecurityCheckResult(violations: violations, warnings: warnings);
  }
}

/// Security check result
class SecurityCheckResult {
  final List<String> violations;
  final List<String> warnings;

  SecurityCheckResult({
    required this.violations,
    required this.warnings,
  });
}

/// Git security result
class GitSecurityResult {
  final bool allowed;
  final List<String> violations;
  final List<String> warnings;
  final bool requiresApproval;

  GitSecurityResult({
    required this.allowed,
    required this.violations,
    required this.warnings,
    required this.requiresApproval,
  });
}

/// Code access result
class CodeAccessResult {
  final bool allowed;
  final List<String> violations;
  final List<String> warnings;
  final bool requiresApproval;

  CodeAccessResult({
    required this.allowed,
    required this.violations,
    required this.warnings,
    required this.requiresApproval,
  });
}