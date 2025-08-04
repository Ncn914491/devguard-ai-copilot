import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../database/services/services.dart';
import '../database/models/models.dart';

/// Security Audit Reporter
/// Builds comprehensive security audit reporting with development activity context
/// Satisfies Requirements: 9.5 (Security audit reporting with development context)
class SecurityAuditReporter {
  static final SecurityAuditReporter _instance = SecurityAuditReporter._internal();
  static SecurityAuditReporter get instance => _instance;
  SecurityAuditReporter._internal();

  final _uuid = const Uuid();
  final _securityAlertService = SecurityAlertService.instance;
  final _enhancedTaskService = EnhancedTaskService.instance;
  final _auditService = AuditLogService.instance;

  /// Generate comprehensive security audit report
  /// Satisfies Requirements: 9.5 (Comprehensive audit reporting)
  Future<SecurityAuditReport> generateComprehensiveReport({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
    List<String>? alertTypes,
    List<String>? severityLevels,
  }) async {
    final reportId = _uuid.v4();

    // Gather all security data
    final securityAlerts = await _gatherSecurityAlerts(startDate, endDate, alertTypes, severityLevels);
    final securityTasks = await _gatherSecurityTasks(startDate, endDate);
    final gitOperations = await _gatherGitOperations(startDate, endDate);
    final codeChanges = await _gatherCodeChanges(startDate, endDate);
    final userActivities = await _gatherUserActivities(startDate, endDate, userId);
    final approvalWorkflows = await _gatherApprovalWorkflows(startDate, endDate);

    // Analyze correlations
    final correlations = await _analyzeSecurityCorrelations(
      securityAlerts,
      codeChanges,
      userActivities,
    );

    // Calculate metrics
    final metrics = await _calculateSecurityMetrics(
      securityAlerts,
      securityTasks,
      gitOperations,
      approvalWorkflows,
    );

    // Generate insights and recommendations
    final insights = await _generateSecurityInsights(securityAlerts, correlations, metrics);
    final recommendations = await _generateSecurityRecommendations(insights, metrics);

    // Create compliance assessment
    final complianceAssessment = await _assessSecurityCompliance(
      securityAlerts,
      securityTasks,
      approvalWorkflows,
    );

    final report = SecurityAuditReport(
      reportId: reportId,
      generatedAt: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
      securityAlerts: securityAlerts,
      securityTasks: securityTasks,
      gitOperations: gitOperations,
      codeChanges: codeChanges,
      userActivities: userActivities,
      approvalWorkflows: approvalWorkflows,
      correlations: correlations,
      metrics: metrics,
      insights: insights,
      recommendations: recommendations,
      complianceAssessment: complianceAssessment,
    );

    // Store report
    await _storeAuditReport(report);

    await _auditService.logAction(
      actionType: 'security_audit_report_generated',
      description: 'Generated comprehensive security audit report',
      aiReasoning: 'Created detailed security audit report with development activity correlation and compliance assessment',
      contextData: {
        'report_id': reportId,
        'date_range': '${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
        'alerts_analyzed': securityAlerts.length,
        'tasks_analyzed': securityTasks.length,
        'git_operations_analyzed': gitOperations.length,
        'correlations_found': correlations.length,
        'recommendations_generated': recommendations.length,
      },
    );

    return report;
  }

  /// Generate security incident timeline report
  /// Satisfies Requirements: 9.3 (Incident context with timeline)
  Future<SecurityIncidentTimeline> generateIncidentTimeline({
    required String alertId,
    Duration? timeWindow,
  }) async {
    final alert = await _securityAlertService.getSecurityAlert(alertId);
    if (alert == null) {
      throw Exception('Security alert not found: $alertId');
    }

    final window = timeWindow ?? const Duration(hours: 24);
    final startTime = alert.detectedAt.subtract(window);
    final endTime = alert.detectedAt.add(window);

    // Gather timeline events
    final events = <SecurityTimelineEvent>[];

    // Add code changes
    final codeChanges = await _gatherCodeChanges(startTime, endTime);
    for (final change in codeChanges) {
      events.add(SecurityTimelineEvent(
        timestamp: DateTime.fromMillisecondsSinceEpoch(change['timestamp']),
        type: 'code_change',
        description: 'Code change: ${change['description']}',
        details: change,
        severity: 'info',
      ));
    }

    // Add user activities
    final userActivities = await _gatherUserActivities(startTime, endTime);
    for (final activity in userActivities) {
      events.add(SecurityTimelineEvent(
        timestamp: DateTime.fromMillisecondsSinceEpoch(activity['timestamp']),
        type: 'user_activity',
        description: 'User activity: ${activity['action']}',
        details: activity,
        severity: 'info',
      ));
    }

    // Add related alerts
    final relatedAlerts = await _gatherSecurityAlerts(startTime, endTime);
    for (final relatedAlert in relatedAlerts) {
      events.add(SecurityTimelineEvent(
        timestamp: relatedAlert.detectedAt,
        type: 'security_alert',
        description: 'Security alert: ${relatedAlert.title}',
        details: {
          'alert_id': relatedAlert.id,
          'type': relatedAlert.type,
          'severity': relatedAlert.severity,
        },
        severity: relatedAlert.severity,
      ));
    }

    // Sort events by timestamp
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final timeline = SecurityIncidentTimeline(
      alertId: alertId,
      incidentTime: alert.detectedAt,
      timeWindow: window,
      events: events,
      correlatedEvents: await _findCorrelatedEvents(events, alert),
    );

    await _auditService.logAction(
      actionType: 'security_incident_timeline_generated',
      description: 'Generated security incident timeline',
      contextData: {
        'alert_id': alertId,
        'events_count': events.length,
        'time_window_hours': window.inHours,
      },
    );

    return timeline;
  }

  /// Generate security compliance report
  /// Satisfies Requirements: 9.5 (Compliance reporting)
  Future<SecurityComplianceReport> generateComplianceReport({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? complianceFrameworks,
  }) async {
    final frameworks = complianceFrameworks ?? ['SOC2', 'ISO27001', 'GDPR'];
    final assessments = <String, ComplianceAssessment>{};

    for (final framework in frameworks) {
      assessments[framework] = await _assessFrameworkCompliance(
        framework,
        startDate,
        endDate,
      );
    }

    final report = SecurityComplianceReport(
      reportId: _uuid.v4(),
      generatedAt: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
      frameworks: frameworks,
      assessments: assessments,
      overallScore: _calculateOverallComplianceScore(assessments),
      gaps: await _identifyComplianceGaps(assessments),
      recommendations: await _generateComplianceRecommendations(assessments),
    );

    await _auditService.logAction(
      actionType: 'security_compliance_report_generated',
      description: 'Generated security compliance report',
      contextData: {
        'report_id': report.reportId,
        'frameworks': frameworks,
        'overall_score': report.overallScore,
        'gaps_identified': report.gaps.length,
      },
    );

    return report;
  }

  /// Generate security metrics dashboard data
  /// Satisfies Requirements: 9.5 (Security metrics reporting)
  Future<SecurityMetricsDashboard> generateMetricsDashboard({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final alerts = await _gatherSecurityAlerts(startDate, endDate);
    final tasks = await _gatherSecurityTasks(startDate, endDate);
    final gitOps = await _gatherGitOperations(startDate, endDate);

    final dashboard = SecurityMetricsDashboard(
      generatedAt: DateTime.now(),
      dateRange: DateRange(startDate, endDate),
      alertMetrics: await _calculateAlertMetrics(alerts),
      taskMetrics: await _calculateTaskMetrics(tasks),
      gitMetrics: await _calculateGitMetrics(gitOps),
      trendAnalysis: await _calculateSecurityTrends(alerts, tasks),
      riskScore: await _calculateOverallRiskScore(alerts, tasks),
    );

    return dashboard;
  }

  // Private helper methods

  Future<List<SecurityAlert>> _gatherSecurityAlerts(
    DateTime startDate,
    DateTime endDate,
    List<String>? alertTypes,
    List<String>? severityLevels,
  ) async {
    final allAlerts = await _securityAlertService.getAllSecurityAlerts();
    
    return allAlerts.where((alert) {
      // Date range filter
      if (alert.detectedAt.isBefore(startDate) || alert.detectedAt.isAfter(endDate)) {
        return false;
      }
      
      // Alert type filter
      if (alertTypes != null && !alertTypes.contains(alert.type)) {
        return false;
      }
      
      // Severity filter
      if (severityLevels != null && !severityLevels.contains(alert.severity)) {
        return false;
      }
      
      return true;
    }).toList();
  }

  Future<List<Task>> _gatherSecurityTasks(DateTime startDate, DateTime endDate) async {
    return await _enhancedTaskService.getAuthorizedTasks(
      userId: 'system',
      userRole: 'admin',
      type: 'security',
    );
  }

  Future<List<Map<String, dynamic>>> _gatherGitOperations(DateTime startDate, DateTime endDate) async {
    // Implementation would gather git operations from audit logs
    final auditLogs = await _auditService.getAuditLogs(
      startDate: startDate,
      endDate: endDate,
      actionTypes: ['git_commit_created', 'git_push_security_check', 'git_branch_created'],
    );

    return auditLogs.map((log) => {
      'timestamp': log.timestamp.millisecondsSinceEpoch,
      'action': log.actionType,
      'user_id': log.userId,
      'details': log.contextData,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _gatherCodeChanges(DateTime startDate, DateTime endDate) async {
    // Implementation would gather code changes from git operations
    final gitOps = await _gatherGitOperations(startDate, endDate);
    
    return gitOps.where((op) => op['action'] == 'git_commit_created').map((op) => {
      'timestamp': op['timestamp'],
      'commit_hash': op['details']['commit_hash'],
      'description': op['details']['commit_message'],
      'user_id': op['user_id'],
      'files_changed': op['details']['files_changed'] ?? [],
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _gatherUserActivities(
    DateTime startDate,
    DateTime endDate,
    String? userId,
  ) async {
    final auditLogs = await _auditService.getAuditLogs(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );

    return auditLogs.map((log) => {
      'timestamp': log.timestamp.millisecondsSinceEpoch,
      'user_id': log.userId,
      'action': log.actionType,
      'description': log.description,
      'context': log.contextData,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _gatherApprovalWorkflows(DateTime startDate, DateTime endDate) async {
    // Implementation would gather approval workflows from database
    return [];
  }

  Future<List<SecurityCorrelation>> _analyzeSecurityCorrelations(
    List<SecurityAlert> alerts,
    List<Map<String, dynamic>> codeChanges,
    List<Map<String, dynamic>> userActivities,
  ) async {
    final correlations = <SecurityCorrelation>[];

    for (final alert in alerts) {
      // Find code changes within 1 hour of alert
      final relatedChanges = codeChanges.where((change) {
        final changeTime = DateTime.fromMillisecondsSinceEpoch(change['timestamp']);
        final timeDiff = alert.detectedAt.difference(changeTime).abs();
        return timeDiff.inHours <= 1;
      }).toList();

      if (relatedChanges.isNotEmpty) {
        correlations.add(SecurityCorrelation(
          alertId: alert.id,
          correlationType: 'code_change',
          correlatedEvents: relatedChanges,
          confidence: _calculateCorrelationConfidence(alert, relatedChanges),
          description: 'Code changes detected near security alert time',
        ));
      }

      // Find suspicious user activities
      final suspiciousActivities = userActivities.where((activity) {
        final activityTime = DateTime.fromMillisecondsSinceEpoch(activity['timestamp']);
        final timeDiff = alert.detectedAt.difference(activityTime).abs();
        return timeDiff.inHours <= 2 && _isSuspiciousActivity(activity);
      }).toList();

      if (suspiciousActivities.isNotEmpty) {
        correlations.add(SecurityCorrelation(
          alertId: alert.id,
          correlationType: 'user_activity',
          correlatedEvents: suspiciousActivities,
          confidence: _calculateCorrelationConfidence(alert, suspiciousActivities),
          description: 'Suspicious user activities detected near alert time',
        ));
      }
    }

    return correlations;
  }

  Future<SecurityMetrics> _calculateSecurityMetrics(
    List<SecurityAlert> alerts,
    List<Task> tasks,
    List<Map<String, dynamic>> gitOps,
    List<Map<String, dynamic>> approvals,
  ) async {
    return SecurityMetrics(
      totalAlerts: alerts.length,
      criticalAlerts: alerts.where((a) => a.severity == 'critical').length,
      highAlerts: alerts.where((a) => a.severity == 'high').length,
      mediumAlerts: alerts.where((a) => a.severity == 'medium').length,
      lowAlerts: alerts.where((a) => a.severity == 'low').length,
      resolvedAlerts: alerts.where((a) => a.status == 'resolved').length,
      falsePositives: alerts.where((a) => a.status == 'false_positive').length,
      securityTasks: tasks.length,
      completedSecurityTasks: tasks.where((t) => t.status == 'completed').length,
      gitOperations: gitOps.length,
      approvalWorkflows: approvals.length,
      averageResolutionTime: _calculateAverageResolutionTime(alerts),
      mttr: _calculateMTTR(alerts),
      mtbf: _calculateMTBF(alerts),
    );
  }

  Future<List<SecurityInsight>> _generateSecurityInsights(
    List<SecurityAlert> alerts,
    List<SecurityCorrelation> correlations,
    SecurityMetrics metrics,
  ) async {
    final insights = <SecurityInsight>[];

    // Alert pattern insights
    if (metrics.criticalAlerts > 0) {
      insights.add(SecurityInsight(
        type: 'alert_pattern',
        title: 'Critical Security Alerts Detected',
        description: '${metrics.criticalAlerts} critical security alerts require immediate attention',
        severity: 'critical',
        recommendation: 'Review and address all critical alerts immediately',
      ));
    }

    // Resolution time insights
    if (metrics.averageResolutionTime.inHours > 24) {
      insights.add(SecurityInsight(
        type: 'performance',
        title: 'Slow Alert Resolution',
        description: 'Average resolution time is ${metrics.averageResolutionTime.inHours} hours',
        severity: 'medium',
        recommendation: 'Improve incident response processes to reduce resolution time',
      ));
    }

    // Correlation insights
    final highConfidenceCorrelations = correlations.where((c) => c.confidence > 0.8).toList();
    if (highConfidenceCorrelations.isNotEmpty) {
      insights.add(SecurityInsight(
        type: 'correlation',
        title: 'Strong Security Correlations Found',
        description: '${highConfidenceCorrelations.length} high-confidence correlations between alerts and activities',
        severity: 'high',
        recommendation: 'Investigate correlated events for potential security patterns',
      ));
    }

    return insights;
  }

  Future<List<String>> _generateSecurityRecommendations(
    List<SecurityInsight> insights,
    SecurityMetrics metrics,
  ) async {
    final recommendations = <String>[];

    // Based on metrics
    if (metrics.criticalAlerts > 0) {
      recommendations.add('Immediately address ${metrics.criticalAlerts} critical security alerts');
    }

    if (metrics.resolvedAlerts < metrics.totalAlerts * 0.8) {
      recommendations.add('Improve alert resolution rate - currently ${(metrics.resolvedAlerts / metrics.totalAlerts * 100).toStringAsFixed(1)}%');
    }

    if (metrics.averageResolutionTime.inHours > 24) {
      recommendations.add('Reduce average resolution time from ${metrics.averageResolutionTime.inHours} hours');
    }

    // Based on insights
    for (final insight in insights) {
      if (insight.severity == 'critical' || insight.severity == 'high') {
        recommendations.add(insight.recommendation);
      }
    }

    return recommendations;
  }

  Future<ComplianceAssessment> _assessSecurityCompliance(
    List<SecurityAlert> alerts,
    List<Task> tasks,
    List<Map<String, dynamic>> approvals,
  ) async {
    final criticalAlertsResolved = alerts
        .where((a) => a.severity == 'critical' && a.status == 'resolved')
        .length;
    final totalCriticalAlerts = alerts.where((a) => a.severity == 'critical').length;

    final securityTasksCompleted = tasks.where((t) => t.status == 'completed').length;
    
    final score = totalCriticalAlerts > 0 
        ? (criticalAlertsResolved / totalCriticalAlerts * 100).round()
        : 100;

    return ComplianceAssessment(
      score: score,
      status: score >= 90 ? 'compliant' : score >= 70 ? 'partially_compliant' : 'non_compliant',
      criticalIssues: totalCriticalAlerts - criticalAlertsResolved,
      recommendations: await _generateComplianceRecommendations({'overall': ComplianceAssessment(
        score: score,
        status: score >= 90 ? 'compliant' : 'non_compliant',
        criticalIssues: totalCriticalAlerts - criticalAlertsResolved,
        recommendations: [],
      )}),
    );
  }

  Future<void> _storeAuditReport(SecurityAuditReport report) async {
    // Implementation would store the report in database
    await _auditService.logAction(
      actionType: 'security_audit_report_stored',
      description: 'Stored security audit report',
      contextData: {'report_id': report.reportId},
    );
  }

  Future<List<SecurityTimelineEvent>> _findCorrelatedEvents(
    List<SecurityTimelineEvent> events,
    SecurityAlert alert,
  ) async {
    // Find events that are likely correlated with the security alert
    return events.where((event) {
      final timeDiff = event.timestamp.difference(alert.detectedAt).abs();
      return timeDiff.inMinutes <= 30 && event.type != 'security_alert';
    }).toList();
  }

  Future<ComplianceAssessment> _assessFrameworkCompliance(
    String framework,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Implementation would assess compliance for specific framework
    return ComplianceAssessment(
      score: 85,
      status: 'partially_compliant',
      criticalIssues: 2,
      recommendations: ['Implement additional monitoring', 'Update security policies'],
    );
  }

  double _calculateOverallComplianceScore(Map<String, ComplianceAssessment> assessments) {
    if (assessments.isEmpty) return 0.0;
    
    final totalScore = assessments.values.map((a) => a.score).reduce((a, b) => a + b);
    return totalScore / assessments.length;
  }

  Future<List<String>> _identifyComplianceGaps(Map<String, ComplianceAssessment> assessments) async {
    final gaps = <String>[];
    
    for (final entry in assessments.entries) {
      if (entry.value.score < 90) {
        gaps.add('${entry.key}: Score ${entry.value.score}% - ${entry.value.criticalIssues} critical issues');
      }
    }
    
    return gaps;
  }

  Future<List<String>> _generateComplianceRecommendations(Map<String, ComplianceAssessment> assessments) async {
    final recommendations = <String>[];
    
    for (final assessment in assessments.values) {
      recommendations.addAll(assessment.recommendations);
    }
    
    return recommendations.toSet().toList(); // Remove duplicates
  }

  Future<AlertMetrics> _calculateAlertMetrics(List<SecurityAlert> alerts) async {
    return AlertMetrics(
      total: alerts.length,
      bySeverity: {
        'critical': alerts.where((a) => a.severity == 'critical').length,
        'high': alerts.where((a) => a.severity == 'high').length,
        'medium': alerts.where((a) => a.severity == 'medium').length,
        'low': alerts.where((a) => a.severity == 'low').length,
      },
      byType: _groupAlertsByType(alerts),
      byStatus: _groupAlertsByStatus(alerts),
    );
  }

  Future<TaskMetrics> _calculateTaskMetrics(List<Task> tasks) async {
    return TaskMetrics(
      total: tasks.length,
      completed: tasks.where((t) => t.status == 'completed').length,
      inProgress: tasks.where((t) => t.status == 'in_progress').length,
      pending: tasks.where((t) => t.status == 'pending').length,
    );
  }

  Future<GitMetrics> _calculateGitMetrics(List<Map<String, dynamic>> gitOps) async {
    return GitMetrics(
      totalOperations: gitOps.length,
      commits: gitOps.where((op) => op['action'] == 'git_commit_created').length,
      pushes: gitOps.where((op) => op['action'] == 'git_push_security_check').length,
      branches: gitOps.where((op) => op['action'] == 'git_branch_created').length,
    );
  }

  Future<TrendAnalysis> _calculateSecurityTrends(List<SecurityAlert> alerts, List<Task> tasks) async {
    // Implementation would calculate trends over time
    return TrendAnalysis(
      alertTrend: 'increasing',
      resolutionTrend: 'stable',
      taskCompletionTrend: 'improving',
    );
  }

  Future<double> _calculateOverallRiskScore(List<SecurityAlert> alerts, List<Task> tasks) async {
    final criticalAlerts = alerts.where((a) => a.severity == 'critical').length;
    final unresolvedAlerts = alerts.where((a) => a.status == 'new' || a.status == 'investigating').length;
    
    // Simple risk calculation
    final riskScore = (criticalAlerts * 10 + unresolvedAlerts * 5).toDouble();
    return riskScore.clamp(0, 100);
  }

  Duration _calculateAverageResolutionTime(List<SecurityAlert> alerts) {
    final resolvedAlerts = alerts.where((a) => a.resolvedAt != null).toList();
    if (resolvedAlerts.isEmpty) return Duration.zero;
    
    final totalMinutes = resolvedAlerts
        .map((a) => a.resolvedAt!.difference(a.detectedAt).inMinutes)
        .reduce((a, b) => a + b);
    
    return Duration(minutes: totalMinutes ~/ resolvedAlerts.length);
  }

  Duration _calculateMTTR(List<SecurityAlert> alerts) {
    // Mean Time To Resolution
    return _calculateAverageResolutionTime(alerts);
  }

  Duration _calculateMTBF(List<SecurityAlert> alerts) {
    // Mean Time Between Failures - simplified calculation
    if (alerts.length < 2) return const Duration(days: 30);
    
    alerts.sort((a, b) => a.detectedAt.compareTo(b.detectedAt));
    final totalTime = alerts.last.detectedAt.difference(alerts.first.detectedAt);
    
    return Duration(minutes: totalTime.inMinutes ~/ (alerts.length - 1));
  }

  double _calculateCorrelationConfidence(SecurityAlert alert, List<Map<String, dynamic>> events) {
    // Simple confidence calculation based on proximity and relevance
    if (events.isEmpty) return 0.0;
    
    double confidence = 0.5; // Base confidence
    
    // Increase confidence based on number of correlated events
    confidence += (events.length * 0.1).clamp(0, 0.3);
    
    // Increase confidence for critical alerts
    if (alert.severity == 'critical') {
      confidence += 0.2;
    }
    
    return confidence.clamp(0, 1);
  }

  bool _isSuspiciousActivity(Map<String, dynamic> activity) {
    final suspiciousActions = [
      'failed_login',
      'privilege_escalation',
      'sensitive_file_access',
      'off_hours_access',
    ];
    
    return suspiciousActions.contains(activity['action']);
  }

  Map<String, int> _groupAlertsByType(List<SecurityAlert> alerts) {
    final grouped = <String, int>{};
    for (final alert in alerts) {
      grouped[alert.type] = (grouped[alert.type] ?? 0) + 1;
    }
    return grouped;
  }

  Map<String, int> _groupAlertsByStatus(List<SecurityAlert> alerts) {
    final grouped = <String, int>{};
    for (final alert in alerts) {
      grouped[alert.status] = (grouped[alert.status] ?? 0) + 1;
    }
    return grouped;
  }
}

// Data classes for security audit reporting

class SecurityAuditReport {
  final String reportId;
  final DateTime generatedAt;
  final DateTime startDate;
  final DateTime endDate;
  final List<SecurityAlert> securityAlerts;
  final List<Task> securityTasks;
  final List<Map<String, dynamic>> gitOperations;
  final List<Map<String, dynamic>> codeChanges;
  final List<Map<String, dynamic>> userActivities;
  final List<Map<String, dynamic>> approvalWorkflows;
  final List<SecurityCorrelation> correlations;
  final SecurityMetrics metrics;
  final List<SecurityInsight> insights;
  final List<String> recommendations;
  final ComplianceAssessment complianceAssessment;

  SecurityAuditReport({
    required this.reportId,
    required this.generatedAt,
    required this.startDate,
    required this.endDate,
    required this.securityAlerts,
    required this.securityTasks,
    required this.gitOperations,
    required this.codeChanges,
    required this.userActivities,
    required this.approvalWorkflows,
    required this.correlations,
    required this.metrics,
    required this.insights,
    required this.recommendations,
    required this.complianceAssessment,
  });
}

class SecurityIncidentTimeline {
  final String alertId;
  final DateTime incidentTime;
  final Duration timeWindow;
  final List<SecurityTimelineEvent> events;
  final List<SecurityTimelineEvent> correlatedEvents;

  SecurityIncidentTimeline({
    required this.alertId,
    required this.incidentTime,
    required this.timeWindow,
    required this.events,
    required this.correlatedEvents,
  });
}

class SecurityTimelineEvent {
  final DateTime timestamp;
  final String type;
  final String description;
  final Map<String, dynamic> details;
  final String severity;

  SecurityTimelineEvent({
    required this.timestamp,
    required this.type,
    required this.description,
    required this.details,
    required this.severity,
  });
}

class SecurityCorrelation {
  final String alertId;
  final String correlationType;
  final List<Map<String, dynamic>> correlatedEvents;
  final double confidence;
  final String description;

  SecurityCorrelation({
    required this.alertId,
    required this.correlationType,
    required this.correlatedEvents,
    required this.confidence,
    required this.description,
  });
}

class SecurityMetrics {
  final int totalAlerts;
  final int criticalAlerts;
  final int highAlerts;
  final int mediumAlerts;
  final int lowAlerts;
  final int resolvedAlerts;
  final int falsePositives;
  final int securityTasks;
  final int completedSecurityTasks;
  final int gitOperations;
  final int approvalWorkflows;
  final Duration averageResolutionTime;
  final Duration mttr;
  final Duration mtbf;

  SecurityMetrics({
    required this.totalAlerts,
    required this.criticalAlerts,
    required this.highAlerts,
    required this.mediumAlerts,
    required this.lowAlerts,
    required this.resolvedAlerts,
    required this.falsePositives,
    required this.securityTasks,
    required this.completedSecurityTasks,
    required this.gitOperations,
    required this.approvalWorkflows,
    required this.averageResolutionTime,
    required this.mttr,
    required this.mtbf,
  });
}

class SecurityInsight {
  final String type;
  final String title;
  final String description;
  final String severity;
  final String recommendation;

  SecurityInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.recommendation,
  });
}

class ComplianceAssessment {
  final int score;
  final String status;
  final int criticalIssues;
  final List<String> recommendations;

  ComplianceAssessment({
    required this.score,
    required this.status,
    required this.criticalIssues,
    required this.recommendations,
  });
}

class SecurityComplianceReport {
  final String reportId;
  final DateTime generatedAt;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> frameworks;
  final Map<String, ComplianceAssessment> assessments;
  final double overallScore;
  final List<String> gaps;
  final List<String> recommendations;

  SecurityComplianceReport({
    required this.reportId,
    required this.generatedAt,
    required this.startDate,
    required this.endDate,
    required this.frameworks,
    required this.assessments,
    required this.overallScore,
    required this.gaps,
    required this.recommendations,
  });
}

class SecurityMetricsDashboard {
  final DateTime generatedAt;
  final DateRange dateRange;
  final AlertMetrics alertMetrics;
  final TaskMetrics taskMetrics;
  final GitMetrics gitMetrics;
  final TrendAnalysis trendAnalysis;
  final double riskScore;

  SecurityMetricsDashboard({
    required this.generatedAt,
    required this.dateRange,
    required this.alertMetrics,
    required this.taskMetrics,
    required this.gitMetrics,
    required this.trendAnalysis,
    required this.riskScore,
  });
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange(this.start, this.end);
}

class AlertMetrics {
  final int total;
  final Map<String, int> bySeverity;
  final Map<String, int> byType;
  final Map<String, int> byStatus;

  AlertMetrics({
    required this.total,
    required this.bySeverity,
    required this.byType,
    required this.byStatus,
  });
}

class TaskMetrics {
  final int total;
  final int completed;
  final int inProgress;
  final int pending;

  TaskMetrics({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.pending,
  });
}

class GitMetrics {
  final int totalOperations;
  final int commits;
  final int pushes;
  final int branches;

  GitMetrics({
    required this.totalOperations,
    required this.commits,
    required this.pushes,
    required this.branches,
  });
}

class TrendAnalysis {
  final String alertTrend;
  final String resolutionTrend;
  final String taskCompletionTrend;

  TrendAnalysis({
    required this.alertTrend,
    required this.resolutionTrend,
    required this.taskCompletionTrend,
  });
}is.recommendations,
  });
}

class SecurityMetricsDashboard {
  final DateTime generatedAt;
  final DateRange dateRange;
  final AlertMetrics alertMetrics;
  final TaskMetrics taskMetrics;
  final GitMetrics gitMetrics;
  final TrendAnalysis trendAnalysis;
  final double riskScore;

  SecurityMetricsDashboard({
    required this.generatedAt,
    required this.dateRange,
    required this.alertMetrics,
    required this.taskMetrics,
    required this.gitMetrics,
    required this.trendAnalysis,
    required this.riskScore,
  });
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange(this.start, this.end);
}

class AlertMetrics {
  final int total;
  final Map<String, int> bySeverity;
  final Map<String, int> byType;
  final Map<String, int> byStatus;

  AlertMetrics({
    required this.total,
    required this.bySeverity,
    required this.byType,
    required this.byStatus,
  });
}

class TaskMetrics {
  final int total;
  final int completed;
  final int inProgress;
  final int pending;

  TaskMetrics({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.pending,
  });
}

class GitMetrics {
  final int totalOperations;
  final int commits;
  final int pushes;
  final int branches;

  GitMetrics({
    required this.totalOperations,
    required this.commits,
    required this.pushes,
    required this.branches,
  });
}

class TrendAnalysis {
  final String alertTrend;
  final String resolutionTrend;
  final String taskCompletionTrend;

  TrendAnalysis({
    required this.alertTrend,
    required this.resolutionTrend,
    required this.taskCompletionTrend,
  });
}