import 'package:flutter/material.dart';
import '../../core/database/services/services.dart';
import '../../core/database/models/models.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final _auditService = AuditLogService.instance;
  
  List<AuditLog> _auditLogs = [];
  Map<String, int> _auditStats = {};
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAuditData();
  }

  Future<void> _loadAuditData() async {
    setState(() => _isLoading = true);
    
    try {
      final logs = await _auditService.getAllAuditLogs();
      final stats = await _auditService.getAuditStatistics();
      
      setState(() {
        _auditLogs = logs;
        _auditStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audit data: $e')),
        );
      }
    }
  }

  Future<void> _filterLogs(String filter) async {
    setState(() {
      _selectedFilter = filter;
      _isLoading = true;
    });

    try {
      List<AuditLog> logs;
      switch (filter) {
        case 'ai_actions':
          logs = await _auditService.getAIActions();
          break;
        case 'pending_approvals':
          logs = await _auditService.getLogsRequiringApproval();
          break;
        case 'approved':
          logs = await _auditService.getApprovedLogs();
          break;
        case 'critical':
          logs = await _auditService.getCriticalActions();
          break;
        default:
          logs = await _auditService.getAllAuditLogs();
      }
      
      setState(() {
        _auditLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error filtering audit logs: $e')),
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
          Row(
            children: [
              Text(
                'Audit Trail',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadAuditData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Complete transparency and audit trail for all AI actions and system changes',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Statistics Cards
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildStatisticsCards(),
          
          const SizedBox(height: 32),
          
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All Logs'),
                const SizedBox(width: 8),
                _buildFilterChip('ai_actions', 'AI Actions'),
                const SizedBox(width: 8),
                _buildFilterChip('pending_approvals', 'Pending Approvals'),
                const SizedBox(width: 8),
                _buildFilterChip('approved', 'Approved'),
                const SizedBox(width: 8),
                _buildFilterChip('critical', 'Critical Actions'),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Audit Logs List
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audit Logs',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _auditLogs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_outlined,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No audit logs found',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _auditLogs.length,
                              itemBuilder: (context, index) {
                                return _AuditLogCard(auditLog: _auditLogs[index]);
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

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total Logs',
            value: '${_auditStats['total_logs'] ?? 0}',
            subtitle: 'All audit entries',
            color: Colors.blue,
            icon: Icons.list_alt,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'AI Actions',
            value: '${_auditStats['ai_actions'] ?? 0}',
            subtitle: 'AI-driven decisions',
            color: Colors.purple,
            icon: Icons.smart_toy,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Pending Approvals',
            value: '${_auditStats['pending_approvals'] ?? 0}',
            subtitle: 'Awaiting human review',
            color: Colors.orange,
            icon: Icons.pending_actions,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Approved Actions',
            value: '${_auditStats['approved_actions'] ?? 0}',
            subtitle: 'Human-approved',
            color: Colors.green,
            icon: Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _filterLogs(value);
        }
      },
      backgroundColor: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
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
                Icon(icon, size: 20, color: color),
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
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
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

class _AuditLogCard extends StatelessWidget {
  final AuditLog auditLog;
  
  const _AuditLogCard({required this.auditLog});

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
                _getActionIcon(auditLog.actionType),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    auditLog.description,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _getStatusChip(context, auditLog),
              ],
            ),
            const SizedBox(height: 8),
            
            // Action Type and User
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    auditLog.actionType.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (auditLog.userId != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'by ${auditLog.userId}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _formatTime(auditLog.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            
            // AI Reasoning (if available)
            if (auditLog.aiReasoning != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI Reasoning',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      auditLog.aiReasoning!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Approval Information
            if (auditLog.requiresApproval) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    auditLog.approved ? Icons.check_circle : Icons.pending,
                    size: 16,
                    color: auditLog.approved ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    auditLog.approved 
                        ? 'Approved by ${auditLog.approvedBy} at ${_formatTime(auditLog.approvedAt!)}'
                        : 'Pending approval',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: auditLog.approved ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getActionIcon(String actionType) {
    switch (actionType) {
      case 'specification_processed':
      case 'specification_created':
        return const Icon(Icons.description, color: Colors.blue, size: 20);
      case 'security_alert_created':
      case 'honeytoken_accessed':
        return const Icon(Icons.security, color: Colors.red, size: 20);
      case 'deployment_created':
      case 'deployment_failed':
        return const Icon(Icons.rocket_launch, color: Colors.green, size: 20);
      case 'rollback_requested':
      case 'rollback_completed':
        return const Icon(Icons.undo, color: Colors.orange, size: 20);
      case 'team_member_created':
      case 'assignments_updated':
        return const Icon(Icons.people, color: Colors.purple, size: 20);
      default:
        return const Icon(Icons.info, color: Colors.grey, size: 20);
    }
  }

  Widget _getStatusChip(BuildContext context, AuditLog auditLog) {
    if (auditLog.requiresApproval) {
      if (auditLog.approved) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'APPROVED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'PENDING',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
        );
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'LOGGED',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
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