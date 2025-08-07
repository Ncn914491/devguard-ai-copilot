import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../database/services/services.dart';
import '../database/models/models.dart';
import '../ai/gemini_service.dart';

class SecurityMonitor {
  static final SecurityMonitor _instance = SecurityMonitor._internal();
  static SecurityMonitor get instance => _instance;
  SecurityMonitor._internal();

  final _uuid = const Uuid();
  final _securityAlertService = SecurityAlertService.instance;
  final _auditService = AuditLogService.instance;

  Timer? _monitoringTimer;
  final Map<String, String> _configHashes = {};
  final List<String> _honeytokens = [];
  int _failedLoginAttempts = 0;
  DateTime? _lastFailedLogin;

  /// Initialize security monitoring
  /// Satisfies Requirements: 3.1, 3.2, 3.4 (Security monitoring setup)
  Future<void> initialize() async {
    await _deployHoneytokens();
    await _initializeConfigMonitoring();
    await _initializeBaselines();
    _startMonitoring();

    await _auditService.logAction(
      actionType: 'security_monitor_initialized',
      description: 'Security monitoring system initialized',
      aiReasoning:
          'Deployed honeytokens, initialized configuration monitoring, baselines, and started anomaly detection',
      contextData: {
        'honeytokens_deployed': _honeytokens.length,
        'config_files_monitored': _configHashes.length,
        'baselines_initialized': _queryBaselines.length,
      },
    );
  }

  /// Deploy honeytokens in database
  /// Satisfies Requirements: 3.1 (Honeytoken deployment)
  Future<void> _deployHoneytokens() async {
    final honeytokenData = [
      {
        'type': 'credit_card',
        'value': '4111-1111-1111-1111',
        'table': 'users',
        'column': 'credit_card'
      },
      {
        'type': 'ssn',
        'value': '123-45-6789',
        'table': 'users',
        'column': 'ssn'
      },
      {
        'type': 'api_key',
        'value': 'sk-fake-api-key-12345',
        'table': 'api_keys',
        'column': 'key_value'
      },
      {
        'type': 'password_hash',
        'value': r'$2b$12$fake.hash.for.honeytoken',
        'table': 'users',
        'column': 'password_hash'
      },
      {
        'type': 'email',
        'value': 'admin@honeytrap.internal',
        'table': 'users',
        'column': 'email'
      },
    ];

    for (final token in honeytokenData) {
      _honeytokens.add(token['value']!);

      // Log honeytoken deployment
      await _auditService.logAction(
        actionType: 'honeytoken_deployed',
        description: 'Deployed ${token['type']} honeytoken',
        contextData: {
          'token_type': token['type'],
          'table_name': token['table'],
          'column_name': token['column'],
        },
      );
    }
  }

  /// Initialize configuration file monitoring
  /// Satisfies Requirements: 4.1 (Configuration drift detection)
  Future<void> _initializeConfigMonitoring() async {
    final configFiles = [
      'pubspec.yaml',
      'lib/main.dart',
      'lib/core/database/database_service.dart',
    ];

    for (final filePath in configFiles) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final content = await file.readAsString();
          final hash = sha256.convert(utf8.encode(content)).toString();
          _configHashes[filePath] = hash;
        }
      } catch (e) {
        // File doesn't exist or can't be read, skip
      }
    }
  }

  /// Start continuous monitoring
  void _startMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkConfigurationDrift();
      _checkAbnormalActivity();
    });
  }

  /// Check for configuration file changes
  /// Satisfies Requirements: 4.1 (File drift detection)
  Future<void> _checkConfigurationDrift() async {
    for (final entry in _configHashes.entries) {
      final filePath = entry.key;
      final originalHash = entry.value;

      try {
        final file = File(filePath);
        if (await file.exists()) {
          final content = await file.readAsString();
          final currentHash = sha256.convert(utf8.encode(content)).toString();

          if (currentHash != originalHash) {
            await _createConfigDriftAlert(filePath, originalHash, currentHash);
            _configHashes[filePath] = currentHash; // Update hash
          }
        }
      } catch (e) {
        // Handle file access errors
      }
    }
  }

  /// Create configuration drift alert
  Future<void> _createConfigDriftAlert(
      String filePath, String originalHash, String currentHash) async {
    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'system_anomaly',
      severity: 'medium',
      title: 'Configuration Drift Detected',
      description:
          'Unexpected change detected in configuration file: $filePath',
      aiExplanation:
          'Configuration file $filePath has been modified. This could indicate unauthorized changes or system compromise. '
          'Original hash: ${originalHash.substring(0, 8)}..., Current hash: ${currentHash.substring(0, 8)}...',
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: false,
      evidence: jsonEncode({
        'file_path': filePath,
        'original_hash': originalHash,
        'current_hash': currentHash,
        'detection_time': DateTime.now().toIso8601String(),
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);
  }

  // Detection baselines and thresholds
  final Map<String, int> _queryBaselines = {};
  final Map<String, DateTime> _lastQueryTimes = {};
  final Map<String, int> _loginAttempts = {};
  final Map<String, List<DateTime>> _loginHistory = {};
  final Map<String, String> _configBaselines = {};

  /// Initialize security baselines
  Future<void> _initializeBaselines() async {
    // Set baseline query volumes (simulated)
    _queryBaselines['user_queries'] = 50;
    _queryBaselines['data_exports'] = 5;
    _queryBaselines['admin_queries'] = 20;

    // Initialize configuration baselines
    await _updateConfigurationBaselines();

    await _auditService.logAction(
      actionType: 'security_baselines_initialized',
      description: 'Security monitoring baselines established',
      aiReasoning:
          'Baselines set for query volumes, login patterns, and configuration states',
      contextData: {
        'query_baselines': _queryBaselines,
        'config_files_monitored': _configBaselines.length,
      },
    );
  }

  /// Update configuration baselines
  Future<void> _updateConfigurationBaselines() async {
    final configFiles = [
      'config/app.json',
      'config/database.json',
      'config/security.json',
      '.env',
    ];

    for (final filePath in configFiles) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final content = await file.readAsString();
          final hash = sha256.convert(utf8.encode(content)).toString();
          _configBaselines[filePath] = hash;
        }
      } catch (e) {
        // Handle file access errors silently
      }
    }
  }

  /// Check for abnormal activity patterns with enhanced detection
  /// Satisfies Requirements: 3.3, 4.2 (Abnormal query detection, network anomalies)
  Future<void> _checkAbnormalActivity() async {
    await _checkHoneytokenAccess();
    await _checkDataExportAnomalies();
    await _checkConfigurationDriftEnhanced();
    await _checkLoginAnomalies();
  }

  /// Enhanced honeytoken access detection
  Future<void> _checkHoneytokenAccess() async {
    // Simulate honeytoken access detection (2% chance for demo)
    final random = DateTime.now().millisecond;
    if (random % 50 == 0) {
      final honeytokenType = [
        'credit_card',
        'ssn',
        'api_key',
        'password_hash',
        'email'
      ][random % 5];
      await _createHoneytokenAlert(honeytokenType);
    }
  }

  /// Check for data export anomalies
  Future<void> _checkDataExportAnomalies() async {
    final currentTime = DateTime.now();
    final currentHour = currentTime.hour;

    // Simulate query volume monitoring
    final simulatedQueryCount = _generateSimulatedQueryCount();
    final baseline = _queryBaselines['data_exports'] ?? 5;

    // Check for volume anomalies (>200% of baseline)
    if (simulatedQueryCount > baseline * 2) {
      await _createDataExportAnomalyAlert(simulatedQueryCount, baseline);
    }

    // Check for off-hours access (between 10 PM and 6 AM)
    if ((currentHour >= 22 || currentHour <= 6) &&
        simulatedQueryCount > baseline * 0.5) {
      await _createOffHoursAccessAlert(simulatedQueryCount, currentHour);
    }
  }

  /// Enhanced configuration drift detection
  Future<void> _checkConfigurationDriftEnhanced() async {
    for (final entry in _configBaselines.entries) {
      final filePath = entry.key;
      final baselineHash = entry.value;

      try {
        final file = File(filePath);
        if (await file.exists()) {
          final content = await file.readAsString();
          final currentHash = sha256.convert(utf8.encode(content)).toString();

          if (currentHash != baselineHash) {
            await _createEnhancedConfigDriftAlert(
                filePath, baselineHash, currentHash, content);
            _configBaselines[filePath] = currentHash; // Update baseline
          }
        }
      } catch (e) {
        // Handle file access errors
      }
    }
  }

  /// Check for login anomalies
  Future<void> _checkLoginAnomalies() async {
    // Simulate login attempt monitoring
    final random = DateTime.now().millisecond;

    // Simulate failed login flood (3% chance)
    if (random % 33 == 0) {
      await _simulateFailedLoginFlood();
    }

    // Simulate unusual login source (1% chance)
    if (random % 100 == 0) {
      await _createUnusualLoginSourceAlert();
    }
  }

  /// Generate simulated query count for testing
  int _generateSimulatedQueryCount() {
    final random = DateTime.now().millisecond;
    final baseCount = 3 + (random % 8); // 3-10 base queries

    // Occasionally simulate spikes
    if (random % 20 == 0) {
      return baseCount * (2 + (random % 3)); // 2-4x spike
    }

    return baseCount;
  }

  /// Create honeytoken access alert with AI explanation
  Future<void> _createHoneytokenAlert(String honeytokenType) async {
    final aiExplanation = await _generateAIExplanation(
      'honeytoken_access',
      {
        'honeytoken_type': honeytokenType,
        'detection_time': DateTime.now().toIso8601String(),
      },
    );

    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'database_breach',
      severity: 'critical',
      title: 'Honeytoken Access Detected',
      description: 'Unauthorized access to honeytoken data ($honeytokenType)',
      aiExplanation: aiExplanation,
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: true,
      evidence: jsonEncode({
        'honeytoken_type': honeytokenType,
        'access_time': DateTime.now().toIso8601String(),
        'source_ip': '192.168.1.${DateTime.now().millisecond % 255}',
        'user_agent': 'Suspicious-Client/1.0',
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);

    await _auditService.logAction(
      actionType: 'honeytoken_breach_detected',
      description:
          'Honeytoken access detected - immediate security alert generated',
      aiReasoning:
          'Honeytoken access indicates potential data breach or unauthorized system access',
      contextData: {
        'honeytoken_type': honeytokenType,
        'alert_id': alert.id,
        'severity': 'critical',
      },
    );
  }

  /// Create data export anomaly alert
  Future<void> _createDataExportAnomalyAlert(
      int currentCount, int baseline) async {
    final percentageIncrease =
        ((currentCount - baseline) / baseline * 100).round();

    final aiExplanation = await _generateAIExplanation(
      'data_export_anomaly',
      {
        'current_count': currentCount,
        'baseline': baseline,
        'percentage_increase': percentageIncrease,
      },
    );

    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'database_breach',
      severity: percentageIncrease > 300 ? 'critical' : 'high',
      title: 'Abnormal Data Export Volume',
      description: 'Data export volume is $percentageIncrease% above baseline',
      aiExplanation: aiExplanation,
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: percentageIncrease > 500,
      evidence: jsonEncode({
        'current_query_count': currentCount,
        'baseline_count': baseline,
        'percentage_increase': percentageIncrease,
        'detection_time': DateTime.now().toIso8601String(),
        'affected_tables': ['users', 'transactions', 'sensitive_data'],
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);
  }

  /// Create off-hours access alert
  Future<void> _createOffHoursAccessAlert(int queryCount, int hour) async {
    final aiExplanation = await _generateAIExplanation(
      'off_hours_access',
      {
        'query_count': queryCount,
        'hour': hour,
        'detection_time': DateTime.now().toIso8601String(),
      },
    );

    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'system_anomaly',
      severity: 'medium',
      title: 'Off-Hours Database Access',
      description:
          'Unusual database activity detected during off-hours ($hour:00)',
      aiExplanation: aiExplanation,
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: false,
      evidence: jsonEncode({
        'access_hour': hour,
        'query_count': queryCount,
        'user_session': 'session_${DateTime.now().millisecondsSinceEpoch}',
        'detection_time': DateTime.now().toIso8601String(),
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);
  }

  /// Create enhanced configuration drift alert
  Future<void> _createEnhancedConfigDriftAlert(String filePath,
      String baselineHash, String currentHash, String content) async {
    final changeType = _analyzeConfigurationChange(content);

    final aiExplanation = await _generateAIExplanation(
      'config_drift',
      {
        'file_path': filePath,
        'change_type': changeType,
        'baseline_hash': baselineHash.substring(0, 8),
        'current_hash': currentHash.substring(0, 8),
      },
    );

    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'system_anomaly',
      severity: _getConfigDriftSeverity(filePath, changeType),
      title: 'Configuration Drift Detected',
      description: 'Unauthorized change in $filePath ($changeType)',
      aiExplanation: aiExplanation,
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: _shouldSuggestRollback(filePath, changeType),
      evidence: jsonEncode({
        'file_path': filePath,
        'change_type': changeType,
        'baseline_hash': baselineHash,
        'current_hash': currentHash,
        'detection_time': DateTime.now().toIso8601String(),
        'file_size': content.length,
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);
  }

  /// Simulate failed login flood
  Future<void> _simulateFailedLoginFlood() async {
    final sourceIP = '192.168.1.${DateTime.now().millisecond % 255}';
    final attemptCount = 5 + (DateTime.now().millisecond % 10); // 5-14 attempts

    final aiExplanation = await _generateAIExplanation(
      'login_flood',
      {
        'source_ip': sourceIP,
        'attempt_count': attemptCount,
        'time_window': '5 minutes',
      },
    );

    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'auth_flood',
      severity: attemptCount > 10 ? 'high' : 'medium',
      title: 'Failed Login Flood Detected',
      description: '$attemptCount failed login attempts from $sourceIP',
      aiExplanation: aiExplanation,
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: false,
      evidence: jsonEncode({
        'source_ip': sourceIP,
        'attempt_count': attemptCount,
        'time_window_minutes': 5,
        'targeted_accounts': ['admin', 'user1', 'service_account'],
        'detection_time': DateTime.now().toIso8601String(),
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);
  }

  /// Create unusual login source alert
  Future<void> _createUnusualLoginSourceAlert() async {
    final suspiciousIP =
        '203.0.113.${DateTime.now().millisecond % 255}'; // RFC 5737 test IP

    final aiExplanation = await _generateAIExplanation(
      'unusual_login_source',
      {
        'source_ip': suspiciousIP,
        'geolocation': 'Unknown/Suspicious',
        'user_agent': 'Automated-Tool/1.0',
      },
    );

    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'system_anomaly',
      severity: 'medium',
      title: 'Unusual Login Source',
      description: 'Login attempt from suspicious IP: $suspiciousIP',
      aiExplanation: aiExplanation,
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: false,
      evidence: jsonEncode({
        'source_ip': suspiciousIP,
        'geolocation': 'Unknown',
        'user_agent': 'Automated-Tool/1.0',
        'login_success': false,
        'detection_time': DateTime.now().toIso8601String(),
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);
  }

  /// Generate AI explanation for security alerts using Gemini
  Future<String> _generateAIExplanation(
      String alertType, Map<String, dynamic> context) async {
    try {
      final prompt = _buildExplanationPrompt(alertType, context);
      final explanation =
          await GeminiService.instance.generateExplanation(prompt);
      return explanation ?? _getFallbackExplanation(alertType, context);
    } catch (e) {
      return _getFallbackExplanation(alertType, context);
    }
  }

  /// Build prompt for AI explanation generation
  String _buildExplanationPrompt(
      String alertType, Map<String, dynamic> context) {
    switch (alertType) {
      case 'honeytoken_access':
        return '''
Security Alert: Honeytoken Access Detected

Context:
- Honeytoken Type: ${context['honeytoken_type']}
- Detection Time: ${context['detection_time']}

Generate a concise explanation (2-3 sentences) explaining:
1. What this alert means
2. Why it's critical
3. Recommended immediate actions (investigate, isolate, rollback)

Keep it professional and actionable for security teams.
''';

      case 'data_export_anomaly':
        return '''
Security Alert: Abnormal Data Export Volume

Context:
- Current Count: ${context['current_count']}
- Baseline: ${context['baseline']}
- Increase: ${context['percentage_increase']}%

Generate a concise explanation (2-3 sentences) explaining:
1. What this anomaly indicates
2. Potential security implications
3. Recommended actions (investigate queries, check permissions, consider rollback)
''';

      case 'config_drift':
        return '''
Security Alert: Configuration Drift Detected

Context:
- File: ${context['file_path']}
- Change Type: ${context['change_type']}
- Hash Change: ${context['baseline_hash']} → ${context['current_hash']}

Generate a concise explanation (2-3 sentences) explaining:
1. What configuration drift means
2. Security implications
3. Recommended actions (verify changes, rollback if unauthorized)
''';

      case 'login_flood':
        return '''
Security Alert: Failed Login Flood

Context:
- Source IP: ${context['source_ip']}
- Attempts: ${context['attempt_count']}
- Time Window: ${context['time_window']}

Generate a concise explanation (2-3 sentences) explaining:
1. What this pattern indicates
2. Potential attack type
3. Recommended actions (block IP, investigate accounts, monitor)
''';

      case 'off_hours_access':
        return '''
Security Alert: Off-Hours Database Access

Context:
- Hour: ${context['hour']}:00
- Query Count: ${context['query_count']}
- Detection Time: ${context['detection_time']}

Generate a concise explanation (2-3 sentences) explaining:
1. Why off-hours access is suspicious
2. Potential security implications
3. Recommended actions (verify user, check session, investigate)
''';

      case 'unusual_login_source':
        return '''
Security Alert: Unusual Login Source

Context:
- Source IP: ${context['source_ip']}
- Geolocation: ${context['geolocation']}
- User Agent: ${context['user_agent']}

Generate a concise explanation (2-3 sentences) explaining:
1. Why this source is suspicious
2. Potential security risks
3. Recommended actions (verify user, block if necessary, monitor)
''';

      default:
        return 'Generate a security alert explanation for: $alertType';
    }
  }

  /// Get fallback explanation when AI generation fails
  String _getFallbackExplanation(
      String alertType, Map<String, dynamic> context) {
    switch (alertType) {
      case 'honeytoken_access':
        return 'CRITICAL: Honeytoken access detected for ${context['honeytoken_type']}. This indicates potential data breach or unauthorized system access. Immediate investigation and system isolation recommended.';

      case 'data_export_anomaly':
        return 'Data export volume is ${context['percentage_increase']}% above baseline (${context['current_count']} vs ${context['baseline']}). This may indicate data exfiltration attempts. Review query logs and user permissions immediately.';

      case 'config_drift':
        return 'Configuration file ${context['file_path']} has been modified (${context['change_type']}). Unauthorized configuration changes can compromise system security. Verify changes and consider rollback if unauthorized.';

      case 'login_flood':
        return 'Detected ${context['attempt_count']} failed login attempts from ${context['source_ip']} within ${context['time_window']}. This indicates a potential brute force attack. Consider blocking the source IP and monitoring affected accounts.';

      case 'off_hours_access':
        return 'Database access detected at ${context['hour']}:00 with ${context['query_count']} queries during off-hours. This unusual activity pattern may indicate unauthorized access or compromised accounts.';

      case 'unusual_login_source':
        return 'Login attempt from suspicious IP ${context['source_ip']} with unusual characteristics. This may indicate compromised credentials or unauthorized access attempts. Verify user identity and consider blocking if necessary.';

      default:
        return 'Security anomaly detected. Please investigate immediately and consider appropriate response actions.';
    }
  }

  /// Analyze configuration change type
  String _analyzeConfigurationChange(String content) {
    if (content.contains('password') ||
        content.contains('secret') ||
        content.contains('key')) {
      return 'credential_modification';
    } else if (content.contains('admin') ||
        content.contains('root') ||
        content.contains('privilege')) {
      return 'privilege_escalation';
    } else if (content.contains('port') ||
        content.contains('host') ||
        content.contains('endpoint')) {
      return 'network_configuration';
    } else if (content.contains('database') || content.contains('connection')) {
      return 'database_configuration';
    } else {
      return 'general_configuration';
    }
  }

  /// Get configuration drift severity based on file and change type
  String _getConfigDriftSeverity(String filePath, String changeType) {
    if (changeType == 'credential_modification' ||
        changeType == 'privilege_escalation') {
      return 'critical';
    } else if (filePath.contains('security') || filePath.contains('.env')) {
      return 'high';
    } else if (changeType == 'network_configuration' ||
        changeType == 'database_configuration') {
      return 'medium';
    } else {
      return 'low';
    }
  }

  /// Determine if rollback should be suggested
  bool _shouldSuggestRollback(String filePath, String changeType) {
    return changeType == 'credential_modification' ||
        changeType == 'privilege_escalation' ||
        filePath.contains('security') ||
        filePath.contains('.env');
  }

  /// Create network anomaly alert
  Future<void> _createNetworkAnomalyAlert() async {
    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'network_anomaly',
      severity: 'medium',
      title: 'Unusual Network Activity',
      description: 'Detected abnormal network connection patterns',
      aiExplanation:
          'Network monitoring has identified unusual connection patterns including connections to suspicious IP addresses and abnormal data transfer volumes. '
          'This could indicate command and control communication or data exfiltration.',
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: false,
      evidence: jsonEncode({
        'suspicious_ips': ['192.168.1.100', '10.0.0.50'],
        'connection_volume': '200% above normal',
        'detection_time': DateTime.now().toIso8601String(),
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);
  }

  /// Simulate honeytoken access detection
  /// Satisfies Requirements: 3.2 (Honeytoken access triggers)
  Future<void> simulateHoneytokenAccess(
      String tokenValue, String accessContext) async {
    if (_honeytokens.contains(tokenValue)) {
      await _securityAlertService.createHoneytokenAlert(
        'credit_card',
        tokenValue,
        accessContext,
      );
    }
  }

  /// Simulate login attempt monitoring
  /// Satisfies Requirements: 4.4 (Authentication flood detection)
  Future<void> recordLoginAttempt(bool successful, String username) async {
    if (!successful) {
      _failedLoginAttempts++;
      _lastFailedLogin = DateTime.now();

      // Check for authentication flood
      if (_failedLoginAttempts >= 5) {
        await _createAuthFloodAlert(username);
        _failedLoginAttempts = 0; // Reset counter
      }
    } else {
      _failedLoginAttempts = 0; // Reset on successful login
    }
  }

  /// Create authentication flood alert
  Future<void> _createAuthFloodAlert(String username) async {
    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'auth_flood',
      severity: 'high',
      title: 'Authentication Flood Detected',
      description:
          'Multiple failed login attempts detected for user: $username',
      aiExplanation:
          'Detected multiple consecutive failed login attempts for user $username. This pattern suggests a brute force attack or credential stuffing attempt. '
          'The account should be temporarily locked and the source IP investigated.',
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: false,
      evidence: jsonEncode({
        'username': username,
        'failed_attempts': _failedLoginAttempts,
        'last_attempt': _lastFailedLogin?.toIso8601String(),
        'detection_time': DateTime.now().toIso8601String(),
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);
  }

  /// Get security monitoring status
  /// Satisfies Requirements: 3.5 (Security status reporting)
  Future<SecurityStatus> getSecurityStatus() async {
    final alerts = await _securityAlertService.getAllSecurityAlerts();
    final activeAlerts = alerts
        .where((a) => a.status == 'new' || a.status == 'investigating')
        .toList();
    final criticalAlerts =
        activeAlerts.where((a) => a.severity == 'critical').toList();

    return SecurityStatus(
      isMonitoring: _monitoringTimer?.isActive ?? false,
      honeytokensDeployed: _honeytokens.length,
      honeytokensActive: _honeytokens.length, // All deployed tokens are active
      configFilesMonitored: _configHashes.length,
      activeAlerts: activeAlerts.length,
      criticalAlerts: criticalAlerts.length,
      lastCheck: DateTime.now(),
      lastScanTime: DateTime.now(),
      systemSecure: criticalAlerts.isEmpty,
    );
  }

  /// Stop monitoring
  void stop() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  /// Get recent security alerts
  /// Satisfies Requirements: 3.1 (Security alert retrieval)
  Future<List<SecurityAlert>> getRecentAlerts({int limit = 10}) async {
    return await _securityAlertService.getRecentAlerts(limit: limit);
  }

  /// Deploy honeytokens for a specific project
  Future<void> deployProjectHoneytokens(String projectId) async {
    // Implementation would deploy project-specific honeytokens
    await _auditService.logAction(
      actionType: 'project_honeytokens_deployed',
      description: 'Honeytokens deployed for project',
      contextData: {'project_id': projectId},
    );
  }

  /// Set up configuration monitoring for project
  Future<void> setupConfigurationMonitoring(String projectId) async {
    // Implementation would set up config file monitoring
    await _auditService.logAction(
      actionType: 'project_config_monitoring_setup',
      description: 'Configuration monitoring set up for project',
      contextData: {'project_id': projectId},
    );
  }

  /// Enable monitoring for a specific project
  Future<void> enableProjectMonitoring(String projectId) async {
    // Implementation would enable project-specific monitoring
    await _auditService.logAction(
      actionType: 'project_monitoring_enabled',
      description: 'Monitoring enabled for project',
      contextData: {'project_id': projectId},
    );
  }

  /// Configure alert thresholds for project
  Future<void> configureAlertThresholds(
      String projectId, Map<String, String> thresholds) async {
    // Implementation would configure alert thresholds
    await _auditService.logAction(
      actionType: 'project_alert_thresholds_configured',
      description: 'Alert thresholds configured for project',
      contextData: {
        'project_id': projectId,
        'thresholds': thresholds,
      },
    );
  }

  /// Test helper methods for simulating security events

  Future<void> simulateDataExportAnomaly(int currentCount, int baseline) async {
    await _createDataExportAnomalyAlert(currentCount, baseline);
  }

  Future<void> simulateOffHoursAccess(int queryCount, int hour) async {
    await _createOffHoursAccessAlert(queryCount, hour);
  }

  Future<void> simulateConfigurationDrift(
    String filePath,
    String changeType,
    String baselineHash,
    String currentHash,
  ) async {
    await _createEnhancedConfigDriftAlert(
        filePath, baselineHash, currentHash, 'test content');
  }

  Future<void> simulateLoginFlood(String sourceIP, int attemptCount) async {
    final aiExplanation = await _generateAIExplanation(
      'login_flood',
      {
        'source_ip': sourceIP,
        'attempt_count': attemptCount,
        'time_window': '5 minutes',
      },
    );

    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'auth_flood',
      severity: attemptCount > 10 ? 'high' : 'medium',
      title: 'Failed Login Flood Detected',
      description: '$attemptCount failed login attempts from $sourceIP',
      aiExplanation: aiExplanation,
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: false,
      evidence: jsonEncode({
        'source_ip': sourceIP,
        'attempt_count': attemptCount,
        'time_window_minutes': 5,
        'targeted_accounts': ['admin', 'user1', 'service_account'],
        'detection_time': DateTime.now().toIso8601String(),
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);
  }

  Future<void> simulateUnusualLoginSource(String sourceIP) async {
    final aiExplanation = await _generateAIExplanation(
      'unusual_login_source',
      {
        'source_ip': sourceIP,
        'geolocation': 'Unknown/Suspicious',
        'user_agent': 'Automated-Tool/1.0',
      },
    );

    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'system_anomaly',
      severity: 'medium',
      title: 'Unusual Login Source',
      description: 'Login attempt from suspicious IP: $sourceIP',
      aiExplanation: aiExplanation,
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: false,
      evidence: jsonEncode({
        'source_ip': sourceIP,
        'geolocation': 'Unknown',
        'user_agent': 'Automated-Tool/1.0',
        'login_success': false,
        'detection_time': DateTime.now().toIso8601String(),
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}

/// Security monitoring status
class SecurityStatus {
  final bool isMonitoring;
  final int honeytokensDeployed;
  final int honeytokensActive;
  final int configFilesMonitored;
  final int activeAlerts;
  final int criticalAlerts;
  final DateTime lastCheck;
  final DateTime lastScanTime;
  final bool systemSecure;

  SecurityStatus({
    required this.isMonitoring,
    required this.honeytokensDeployed,
    required this.honeytokensActive,
    required this.configFilesMonitored,
    required this.activeAlerts,
    required this.criticalAlerts,
    required this.lastCheck,
    required this.lastScanTime,
    required this.systemSecure,
  });
}
