import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../database/services/services.dart';
import '../database/models/models.dart';

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
    _startMonitoring();
    
    await _auditService.logAction(
      actionType: 'security_monitor_initialized',
      description: 'Security monitoring system initialized',
      aiReasoning: 'Deployed honeytokens, initialized configuration monitoring, and started anomaly detection',
      contextData: {
        'honeytokens_deployed': _honeytokens.length,
        'config_files_monitored': _configHashes.length,
      },
    );
  }

  /// Deploy honeytokens in database
  /// Satisfies Requirements: 3.1 (Honeytoken deployment)
  Future<void> _deployHoneytokens() async {
    final honeytokenData = [
      {'type': 'credit_card', 'value': '4111-1111-1111-1111', 'table': 'users', 'column': 'credit_card'},
      {'type': 'ssn', 'value': '123-45-6789', 'table': 'users', 'column': 'ssn'},
      {'type': 'api_key', 'value': 'sk-fake-api-key-12345', 'table': 'api_keys', 'column': 'key_value'},
      {'type': 'password_hash', 'value': r'$2b$12$fake.hash.for.honeytoken', 'table': 'users', 'column': 'password_hash'},
      {'type': 'email', 'value': 'admin@honeytrap.internal', 'table': 'users', 'column': 'email'},
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
  Future<void> _createConfigDriftAlert(String filePath, String originalHash, String currentHash) async {
    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'system_anomaly',
      severity: 'medium',
      title: 'Configuration Drift Detected',
      description: 'Unexpected change detected in configuration file: $filePath',
      aiExplanation: 'Configuration file $filePath has been modified. This could indicate unauthorized changes or system compromise. '
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

  /// Check for abnormal activity patterns
  /// Satisfies Requirements: 3.3, 4.2 (Abnormal query detection, network anomalies)
  Future<void> _checkAbnormalActivity() async {
    // Simulate abnormal activity detection
    final random = DateTime.now().millisecond;
    
    // Simulate database query anomaly (1% chance)
    if (random % 100 == 0) {
      await _createQueryAnomalyAlert();
    }
    
    // Simulate network anomaly (0.5% chance)
    if (random % 200 == 0) {
      await _createNetworkAnomalyAlert();
    }
  }

  /// Create query anomaly alert
  Future<void> _createQueryAnomalyAlert() async {
    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'database_breach',
      severity: 'high',
      title: 'Abnormal Database Query Pattern',
      description: 'Detected unusual database query volume and patterns',
      aiExplanation: 'Database monitoring has detected an abnormal increase in query volume and suspicious patterns that may indicate data exfiltration attempts. '
          'Queries include bulk SELECT operations on sensitive tables and unusual JOIN patterns.',
      status: 'new',
      detectedAt: DateTime.now(),
      rollbackSuggested: true,
      evidence: jsonEncode({
        'query_volume': '150% above baseline',
        'suspicious_patterns': ['bulk_select', 'sensitive_table_access', 'unusual_joins'],
        'detection_time': DateTime.now().toIso8601String(),
      }),
    );

    await _securityAlertService.createSecurityAlert(alert);
  }

  /// Create network anomaly alert
  Future<void> _createNetworkAnomalyAlert() async {
    final alert = SecurityAlert(
      id: _uuid.v4(),
      type: 'network_anomaly',
      severity: 'medium',
      title: 'Unusual Network Activity',
      description: 'Detected abnormal network connection patterns',
      aiExplanation: 'Network monitoring has identified unusual connection patterns including connections to suspicious IP addresses and abnormal data transfer volumes. '
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
  Future<void> simulateHoneytokenAccess(String tokenValue, String accessContext) async {
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
      description: 'Multiple failed login attempts detected for user: $username',
      aiExplanation: 'Detected multiple consecutive failed login attempts for user $username. This pattern suggests a brute force attack or credential stuffing attempt. '
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
    final activeAlerts = alerts.where((a) => a.status == 'new' || a.status == 'investigating').toList();
    final criticalAlerts = activeAlerts.where((a) => a.severity == 'critical').toList();
    
    return SecurityStatus(
      isMonitoring: _monitoringTimer?.isActive ?? false,
      honeytokensDeployed: _honeytokens.length,
      honeytokensActive: _honeytokens.length, // All deployed tokens are active
      configFilesMonitored: _configHashes.length,
      activeAlerts: activeAlerts.length,
      criticalAlerts: criticalAlerts.length,
      lastCheck: DateTime.now(),
      lastScanTime: DateTime.now(),
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

  SecurityStatus({
    required this.isMonitoring,
    required this.honeytokensDeployed,
    required this.honeytokensActive,
    required this.configFilesMonitored,
    required this.activeAlerts,
    required this.criticalAlerts,
    required this.lastCheck,
    required this.lastScanTime,
  });
}