import 'package:flutter/material.dart';
import '../../core/security/security_monitor.dart';
import '../../core/database/services/services.dart';
import '../../core/database/models/models.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _securityMonitor = SecurityMonitor.instance;
  final _securityAlertService = SecurityAlertService.instance;
  
  SecurityStatus? _securityStatus;
  List<SecurityAlert> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityData();
  }

  Future<void> _loadSecurityData() async {
    setState(() => _isLoading = true);
    
    try {
      final status = await _securityMonitor.getSecurityStatus();
      final alerts = await _securityAlertService.getAllSecurityAlerts();
      
      setState(() {
        _securityStatus = status;
        _alerts = alerts.take(10).toList(); // Show latest 10 alerts
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading security data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Security Monitoring',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monitor database access, configuration changes, and security alerts',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Security Status
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_securityStatus != null) ...[
            Row(
              children: [
                Expanded(
                  child: _SecurityStatusCard(
                    title: 'Database Security',
                    status: _securityStatus!.honeytokensDeployed > 0 ? 'Protected' : 'Vulnerable',
                    description: '${_securityStatus!.honeytokensDeployed} honeytokens deployed and monitoring active',
                    color: _securityStatus!.honeytokensDeployed > 0 ? Colors.green : Colors.red,
                    icon: Icons.storage_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SecurityStatusCard(
                    title: 'Configuration Monitoring',
                    status: _securityStatus!.isMonitoring ? 'Active' : 'Inactive',
                    description: 'Monitoring ${_securityStatus!.configFilesMonitored} configuration files',
                    color: _securityStatus!.isMonitoring ? Colors.blue : Colors.orange,
                    icon: Icons.settings_outlined,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _SecurityStatusCard(
                    title: 'Active Alerts',
                    status: '${_securityStatus!.activeAlerts}',
                    description: '${_securityStatus!.criticalAlerts} critical alerts requiring attention',
                    color: _securityStatus!.criticalAlerts > 0 ? Colors.red : Colors.green,
                    icon: Icons.warning_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SecurityStatusCard(
                    title: 'System Status',
                    status: _securityStatus!.isMonitoring ? 'Monitoring' : 'Offline',
                    description: 'Last check: ${_formatTime(_securityStatus!.lastCheck)}',
                    color: _securityStatus!.isMonitoring ? Colors.blue : Colors.grey,
                    icon: Icons.monitor_heart_outlined,
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 32),
          
          // Alerts Section
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Security Alerts',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _loadSecurityData,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _alerts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 48,
                                    color: Colors.green.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No security alerts',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Your system is secure and all monitoring is active',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _alerts.length,
                              itemBuilder: (context, index) {
                                return _SecurityAlertCard(alert: _alerts[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityStatusCard extends StatelessWidget {
  final String title;
  final String status;
  final String description;
  final Color color;
  final IconData icon;
  
  const _SecurityStatusCard({
    required this.title,
    required this.status,
    required this.description,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
cl
ass _SecurityAlertCard extends StatelessWidget {
  final SecurityAlert alert;
  
  const _SecurityAlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getSeverityIcon(alert.severity),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _getStatusChip(context, alert.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'AI Analysis: ${alert.aiExplanation}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Detected: ${_formatTime(alert.detectedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const Spacer(),
                if (alert.rollbackSuggested)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Rollback Suggested',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getSeverityIcon(String severity) {
    switch (severity) {
      case 'critical':
        return const Icon(Icons.error, color: Colors.red, size: 20);
      case 'high':
        return const Icon(Icons.warning, color: Colors.orange, size: 20);
      case 'medium':
        return const Icon(Icons.info, color: Colors.blue, size: 20);
      case 'low':
        return const Icon(Icons.info_outline, color: Colors.grey, size: 20);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey, size: 20);
    }
  }

  Widget _getStatusChip(BuildContext context, String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'new':
        backgroundColor = Colors.red.withOpacity(0.2);
        textColor = Colors.red.shade700;
        break;
      case 'investigating':
        backgroundColor = Colors.orange.withOpacity(0.2);
        textColor = Colors.orange.shade700;
        break;
      case 'resolved':
        backgroundColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green.shade700;
        break;
      case 'false_positive':
        backgroundColor = Colors.grey.withOpacity(0.2);
        textColor = Colors.grey.shade700;
        break;
      default:
        backgroundColor = Theme.of(context).colorScheme.surfaceVariant;
        textColor = Theme.of(context).colorScheme.onSurfaceVariant;
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
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}