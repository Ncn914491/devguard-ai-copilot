import 'package:flutter/material.dart';
import '../../core/security/security_monitor.dart';
import '../../core/deployment/deployment_pipeline.dart';
import '../../core/database/services/services.dart';
import '../../core/database/models/models.dart';
import '../../core/gitops/git_integration.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _securityMonitor = SecurityMonitor.instance;
  final _deploymentPipeline = DeploymentPipeline.instance;
  final _specService = SpecService.instance;
  final _teamMemberService = TeamMemberService.instance;
  final _taskService = TaskService.instance;
  final _gitIntegration = GitIntegration.instance;

  SecurityStatus? _securityStatus;
  List<Deployment> _recentDeployments = [];
  List<Specification> _recentSpecs = [];
  List<TeamMember> _teamMembers = [];
  List<Task> _activeTasks = [];
  GitIntegrationStatus? _gitStatus;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load all dashboard data in parallel
      final results = await Future.wait([
        _securityMonitor.getSecurityStatus(),
        _deploymentPipeline.getRecentDeployments(limit: 5),
        _specService.getAllSpecifications(),
        _teamMemberService.getAllTeamMembers(),
        _taskService.getAllTasks(),
        _gitIntegration.getIntegrationStatus(),
      ]);

      setState(() {
        _securityStatus = results[0] as SecurityStatus;
        _recentDeployments = results[1] as List<Deployment>;
        _recentSpecs = (results[2] as List<Specification>).take(5).toList();
        _teamMembers = results[3] as List<TeamMember>;
        _activeTasks = (results[4] as List<Task>)
            .where((t) => t.status == 'in_progress' || t.status == 'review')
            .take(5)
            .toList();
        _gitStatus = results[5] as GitIntegrationStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('home_screen'),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context),
              const SizedBox(height: 32),

              // Error State
              if (_error != null) _buildErrorState(context),

              // Loading State
              if (_isLoading) _buildLoadingState(),

              // Dashboard Content
              if (!_isLoading && _error == null) ...[
                // Overview Cards
                _buildOverviewCards(context),
                const SizedBox(height: 32),

                // Main Dashboard Grid
                _buildDashboardGrid(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DevGuard AI Copilot Dashboard',
              key: const Key('app_title'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time overview of your development workflow and security status',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Dashboard',
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getSystemStatusColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getSystemStatusColor().withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getSystemStatusIcon(),
                    size: 16,
                    color: _getSystemStatusColor(),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getSystemStatusText(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getSystemStatusColor(),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load dashboard data',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(64.0),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading dashboard data...'),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;
        const cardCount = 4;

        if (isCompact) {
          // Stack cards vertically on small screens
          return Column(
            children: _buildOverviewCardsList()
                .map((card) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: card,
                    ))
                .toList(),
          );
        } else {
          // Horizontal layout for larger screens
          return Row(
            children: List.generate(cardCount, (index) {
              final cards = _buildOverviewCardsList();
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < cardCount - 1 ? 16 : 0,
                  ),
                  child: cards[index],
                ),
              );
            }),
          );
        }
      },
    );
  }

  List<Widget> _buildOverviewCardsList() {
    final activeDeployments =
        _recentDeployments.where((d) => d.status == 'in_progress').length;
    final successfulDeployments =
        _recentDeployments.where((d) => d.status == 'success').length;
    final activeMembers =
        _teamMembers.where((m) => m.status == 'active').length;
    final benchMembers = _teamMembers.where((m) => m.status == 'bench').length;
    final approvedSpecs =
        _recentSpecs.where((s) => s.status == 'approved').length;
    final pendingSpecs = _recentSpecs.where((s) => s.status == 'draft').length;

    return [
      _OverviewCard(
        title: 'Active Deployments',
        value: '${_recentDeployments.length}',
        subtitle:
            '$successfulDeployments successful, $activeDeployments active',
        color: Colors.blue,
        icon: Icons.rocket_launch_outlined,
        onTap: () => _navigateToScreen('deployments'),
      ),
      _OverviewCard(
        title: 'Security Alerts',
        value: '${_securityStatus?.activeAlerts ?? 0}',
        subtitle: _securityStatus?.criticalAlerts == 0
            ? 'All systems secure'
            : '${_securityStatus?.criticalAlerts} critical alerts',
        color: _securityStatus?.criticalAlerts == 0 ? Colors.green : Colors.red,
        icon: Icons.shield_outlined,
        onTap: () => _navigateToScreen('security'),
      ),
      _OverviewCard(
        title: 'Team Members',
        value: '${_teamMembers.length}',
        subtitle: '$activeMembers active, $benchMembers available',
        color: Colors.purple,
        icon: Icons.people_outlined,
        onTap: () => _navigateToScreen('team'),
      ),
      _OverviewCard(
        title: 'Active Tasks',
        value: '${_activeTasks.length}',
        subtitle: '$approvedSpecs specs approved, $pendingSpecs pending',
        color: Colors.orange,
        icon: Icons.task_outlined,
        onTap: () => _navigateToScreen('workflow'),
      ),
    ];
  }

  Widget _buildDashboardGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1200;

        if (isCompact) {
          // Single column layout for smaller screens
          return Column(
            children: [
              _buildRecentActivityCard(context),
              const SizedBox(height: 24),
              _buildSecurityStatusCard(context),
              const SizedBox(height: 24),
              _buildGitIntegrationCard(context),
              const SizedBox(height: 24),
              _buildActiveTasksCard(context),
            ],
          );
        } else {
          // Two-column grid for larger screens
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildRecentActivityCard(context),
                    const SizedBox(height: 24),
                    _buildActiveTasksCard(context),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Column
              Expanded(
                child: Column(
                  children: [
                    _buildSecurityStatusCard(context),
                    const SizedBox(height: 24),
                    _buildGitIntegrationCard(context),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildRecentActivityCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                TextButton(
                  onPressed: () => _navigateToScreen('audit'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _recentSpecs.isEmpty
                  ? _buildEmptyState('No recent activity', Icons.timeline)
                  : ListView.separated(
                      itemCount: _recentSpecs.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final spec = _recentSpecs[index];
                        return _buildActivityItem(
                          context,
                          spec.suggestedBranchName.replaceAll('feature/', ''),
                          spec.aiInterpretation,
                          _formatTime(spec.createdAt),
                          _getStatusColor(spec.status),
                          _getStatusIcon(spec.status),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityStatusCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Security Status',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Icon(
                  Icons.security,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_securityStatus != null) ...[
              _buildSecurityMetric(
                context,
                'Active Alerts',
                '${_securityStatus!.activeAlerts}',
                _securityStatus!.activeAlerts == 0
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildSecurityMetric(
                context,
                'Critical Alerts',
                '${_securityStatus!.criticalAlerts}',
                _securityStatus!.criticalAlerts == 0
                    ? Colors.green
                    : Colors.red,
              ),
              const SizedBox(height: 12),
              _buildSecurityMetric(
                context,
                'Honeytokens',
                '${_securityStatus!.honeytokensDeployed}',
                Colors.blue,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _securityStatus!.systemSecure
                        ? Icons.check_circle
                        : Icons.warning,
                    color: _securityStatus!.systemSecure
                        ? Colors.green
                        : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _securityStatus!.systemSecure
                          ? 'All systems secure'
                          : 'Security issues detected',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _securityStatus!.systemSecure
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ] else
              _buildEmptyState('Security status unavailable', Icons.security),
          ],
        ),
      ),
    );
  }

  Widget _buildGitIntegrationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Git Integration',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Icon(
                  Icons.source,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_gitStatus != null) ...[
              _buildGitStatusRow(
                context,
                'Repository',
                _gitStatus!.repository,
                Icons.folder_outlined,
              ),
              const SizedBox(height: 12),
              _buildGitStatusRow(
                context,
                'Current Branch',
                _gitStatus!.currentBranch,
                Icons.call_split,
              ),
              const SizedBox(height: 12),
              _buildGitStatusRow(
                context,
                'Active Branches',
                '${_gitStatus!.activeBranches}',
                Icons.account_tree,
              ),
              const SizedBox(height: 12),
              _buildGitStatusRow(
                context,
                'Last Sync',
                _formatTime(_gitStatus!.lastSync),
                Icons.sync,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _gitStatus!.connected ? Icons.check_circle : Icons.error,
                    color: _gitStatus!.connected ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _gitStatus!.connected ? 'Connected' : 'Disconnected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              _gitStatus!.connected ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ] else
              _buildEmptyState('Git status unavailable', Icons.source),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTasksCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Tasks',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                TextButton(
                  onPressed: () => _navigateToScreen('workflow'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _activeTasks.isEmpty
                  ? _buildEmptyState('No active tasks', Icons.task)
                  : ListView.separated(
                      itemCount: _activeTasks.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final task = _activeTasks[index];
                        return _buildTaskItem(context, task);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    String title,
    String subtitle,
    String time,
    Color color,
    IconData icon,
  ) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: 0.2),
        child: Icon(
          icon,
          size: 16,
          color: color,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        time,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, Task task) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: _getTaskTypeColor(task.type).withValues(alpha: 0.2),
        child: Icon(
          _getTaskTypeIcon(task.type),
          size: 16,
          color: _getTaskTypeColor(task.type),
        ),
      ),
      title: Text(
        task.title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${task.priority.toUpperCase()} • ${task.estimatedHours}h estimated',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor(task.status).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          task.status.replaceAll('_', ' '),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _getStatusColor(task.status),
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }

  Widget _buildSecurityMetric(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildGitStatusRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getSystemStatusColor() {
    if (_securityStatus?.criticalAlerts != null &&
        _securityStatus!.criticalAlerts > 0) {
      return Colors.red;
    }
    if (_securityStatus?.activeAlerts != null &&
        _securityStatus!.activeAlerts > 0) {
      return Colors.orange;
    }
    return Colors.green;
  }

  IconData _getSystemStatusIcon() {
    if (_securityStatus?.criticalAlerts != null &&
        _securityStatus!.criticalAlerts > 0) {
      return Icons.error;
    }
    if (_securityStatus?.activeAlerts != null &&
        _securityStatus!.activeAlerts > 0) {
      return Icons.warning;
    }
    return Icons.check_circle;
  }

  String _getSystemStatusText() {
    if (_securityStatus?.criticalAlerts != null &&
        _securityStatus!.criticalAlerts > 0) {
      return 'Critical Issues';
    }
    if (_securityStatus?.activeAlerts != null &&
        _securityStatus!.activeAlerts > 0) {
      return 'Warnings';
    }
    return 'All Systems Operational';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
      case 'success':
        return Colors.green;
      case 'draft':
      case 'pending':
        return Colors.orange;
      case 'in_progress':
      case 'review':
        return Colors.blue;
      case 'rejected':
      case 'failed':
      case 'blocked':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
      case 'success':
        return Icons.check_circle;
      case 'draft':
      case 'pending':
        return Icons.edit;
      case 'in_progress':
      case 'review':
        return Icons.hourglass_empty;
      case 'rejected':
      case 'failed':
      case 'blocked':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getTaskTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'feature':
        return Colors.blue;
      case 'bug':
        return Colors.red;
      case 'security':
        return Colors.purple;
      case 'deployment':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getTaskTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'feature':
        return Icons.new_releases;
      case 'bug':
        return Icons.bug_report;
      case 'security':
        return Icons.security;
      case 'deployment':
        return Icons.rocket_launch;
      default:
        return Icons.task;
    }
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

  void _navigateToScreen(String screen) {
    // This would typically use a navigation service or provider
    // For now, we'll just print the navigation intent
    print('Navigate to: $screen');
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                          .withValues(alpha: 0.6),
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
