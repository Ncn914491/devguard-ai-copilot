import 'package:flutter/material.dart';
import '../../core/database/models/security_alert.dart';
import '../../core/database/services/security_alert_service.dart';
import '../../core/supabase/services/supabase_realtime_service.dart';
import 'dart:async';

/// Simple security screen for demo purposes
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _securityAlertService = SecurityAlertService.instance;
  final _realtimeService = SupabaseRealtimeService.instance;
  List<SecurityAlert> _alerts = [];
  bool _isLoading = true;

  // Real-time subscription
  StreamSubscription<List<SecurityAlert>>? _alertsSubscription;

  @override
  void initState() {
    super.initState();
    _loadSecurityData();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _alertsSubscription?.cancel();
    super.dispose();
  }

  /// Set up real-time subscriptions for security alerts
  void _setupRealtimeSubscriptions() {
    try {
      // Subscribe to security alerts changes
      _alertsSubscription = _realtimeService
          .watchTable<SecurityAlert>(
        tableName: 'security_alerts',
        fromMap: (map) => SecurityAlert.fromMap(map),
        orderBy: 'detected_at',
        ascending: false,
      )
          .listen(
        (alerts) {
          if (mounted) {
            setState(() {
              _alerts = alerts;
              _isLoading = false;
            });

            // Show notification for new critical alerts
            _checkForNewCriticalAlerts(alerts);
          }
        },
        onError: (error) {
          debugPrint('Real-time security alerts error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error setting up real-time security subscriptions: $e');
      // Fall back to manual refresh if real-time fails
    }
  }

  /// Check for new critical alerts and show notifications
  void _checkForNewCriticalAlerts(List<SecurityAlert> newAlerts) {
    final criticalAlerts = newAlerts
        .where((alert) =>
            alert.severity.toLowerCase() == 'critical' && alert.status == 'new')
        .toList();

    if (criticalAlerts.isNotEmpty && mounted) {
      // Show snackbar for critical alerts
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${criticalAlerts.length} new critical security alert${criticalAlerts.length > 1 ? 's' : ''} detected!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              // Scroll to top to show new alerts
            },
          ),
        ),
      );
    }
  }

  Future<void> _loadSecurityData() async {
    try {
      final alerts = await _securityAlertService.getAllSecurityAlerts();
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.security,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security Dashboard',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Text(
                      'Real-time security monitoring and threat detection',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Security status cards
            Row(
              children: [
                Expanded(
                  child: _buildStatusCard(
                    'Active Alerts',
                    _alerts.where((a) => a.status == 'new').length.toString(),
                    'Require attention',
                    Colors.red,
                    Icons.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatusCard(
                    'Resolved',
                    _alerts
                        .where((a) => a.status == 'resolved')
                        .length
                        .toString(),
                    'This month',
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatusCard(
                    'System Health',
                    'Good',
                    'All systems operational',
                    Colors.blue,
                    Icons.health_and_safety,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Alerts section
            Text(
              'Recent Security Alerts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 16),

            // Alerts list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _alerts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 64,
                                color: Colors.green.withOpacity(0.6),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'All Clear',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No security alerts detected',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _alerts.length,
                          itemBuilder: (context, index) {
                            final alert = _alerts[index];
                            return _buildAlertCard(alert);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
      String title, String value, String subtitle, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(SecurityAlert alert) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _getSeverityIcon(alert.severity),
        title: Text(alert.title),
        subtitle: Text(alert.description),
        trailing: _getStatusChip(alert.status),
        onTap: () => _showAlertDetails(alert),
      ),
    );
  }

  Widget _getSeverityIcon(String severity) {
    IconData icon;
    Color color;

    switch (severity.toLowerCase()) {
      case 'critical':
        icon = Icons.error;
        color = Colors.red;
        break;
      case 'high':
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case 'medium':
        icon = Icons.info;
        color = Colors.blue;
        break;
      case 'low':
        icon = Icons.info_outline;
        color = Colors.green;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 20);
  }

  Widget _getStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'new':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      case 'investigating':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'resolved':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showAlertDetails(SecurityAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Alert Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${alert.title}'),
            const SizedBox(height: 8),
            Text('Description: ${alert.description}'),
            const SizedBox(height: 8),
            Text('Severity: ${alert.severity}'),
            const SizedBox(height: 8),
            Text('Status: ${alert.status}'),
            if (alert.aiExplanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('AI Analysis: ${alert.aiExplanation}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
