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
  final _gitIntegration = GitIntegration.instance;
  
  SecurityStatus? _securityStatus;
  List<Deployment> _recentDeployments = [];
  List<Specification> _recentSpecs = [];
  List<TeamMember> _teamMembers = [];
  GitIntegrationStatus? _gitStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _securityMonitor.getSecurityStatus(),
        _deploymentPipeline.getRecentDeployments(limit: 5),
        _specService.getAllSpecifications(),
        _teamMemberService.getAllTeamMembers(),
        _gitIntegration.getIntegrationStatus(),
      ]);
      
      setState(() {
        _securityStatus = results[0] as SecurityStatus;
        _recentDeployments = results[1] as List<Deployment>;
        _recentSpecs = (results[2] as List<Specification>).take(5).toList();
        _teamMembers = results[3] as List<TeamMember>;
        _gitStatus = results[4] as GitIntegrationStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Real-time overview of your development workflow and security status',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              if (!_isLoading)
                IconButton(
                  onPressed: _loadDashboardData,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Dashboard',
                ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Overview Cards
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildOverviewCards(),
          
          const SizedBox(height: 32),
          
          // Recent Activity and Git Status
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Activity
                Expanded(
                  flex: 2,
                  child: _buildRecentActivity(),
                ),
                const SizedBox(width: 16),
                // Git Integration Status
                Expanded(
                  child: _buildGitStatus(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    final activeDeployments = _recentDeployments.where((d) => d.status == 'in_progress').length;
    final successfulDeployments = _recentDeployments.where((d) => d.status == 'success').length;
    final activeMembers = _teamMembers.where((m) => m.status == 'active').length;
    final benchMembers = _teamMembers.where((m) => m.status == 'bench').length;
    final approvedSpecs = _recentSpecs.where((s) => s.status == 'approved').length;
    final pendingSpecs = _recentSpecs.where((s) => s.status == 'draft').length;
    
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Deployments',
            value: '${_recentDeployments.length}',
            subtitle: '$successfulDeployments successful, $activeDeployments active',
            color: Colors.blue,
            icon: Icons.rocket_launch_outlined,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Security Alerts',
            value: '${_securityStatus?.activeAlerts ?? 0}',
            subtitle: _securityStatus?.criticalAlerts == 0 ? 'All systems secure' : '${_securityStatus?.criticalAlerts} critical',
            color: _securityStatus?.criticalAlerts == 0 ? Colors.green : Colors.red,
            icon: Icons.shield_outlined,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Team Members',
            value: '${_teamMembers.length}',
            subtitle: '$activeMembers active, $benchMembers available',
            color: Colors.purple,
            icon: Icons.people_outlined,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Specifications',
            value: '${_recentSpecs.length}',
            subtitle: '$approvedSpecs approved, $pendingSpecs pending',
            color: Colors.orange,
            icon: Icons.description_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _recentSpecs.isEmpty && _recentDeployments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recent activity',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start by creating a specification or monitoring your security',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        ..._recentSpecs.map((spec) => _ActivityItem(
                          icon: Icons.description,
                          title: 'Specification: ${spec.suggestedBranchName}',
                          subtitle: 'Status: ${spec.status}',
                          time: _formatTime(spec.createdAt),
                          color: spec.status == 'approved' ? Colors.green : Colors.orange,
                        )),
                        ..._recentDeployments.map((deployment) => _ActivityItem(
                          icon: Icons.rocket_launch,
                          title: 'Deployment: ${deployment.environment}',
                          subtitle: 'Status: ${deployment.status}',
                          time: _formatTime(deployment.createdAt),
                          color: deployment.status == 'success' ? Colors.green : Colors.blue,
                        )),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGitStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Git Integration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (_gitStatus != null) ...[
              _GitStatusItem(
                label: 'Repository',
                value: _gitStatus!.repository,
                icon: Icons.folder_outlined,
              ),
              const SizedBox(height: 12),
              _GitStatusItem(
                label: 'Current Branch',
                value: _gitStatus!.currentBranch,
                icon: Icons.account_tree_outlined,
              ),
              const SizedBox(height: 12),
              _GitStatusItem(
                label: 'Active Branches',
                value: '${_gitStatus!.activeBranches}',
                icon: Icons.merge_type_outlined,
              ),
              const SizedBox(height: 12),
              _GitStatusItem(
                label: 'Last Sync',
                value: _formatTime(_gitStatus!.lastSync),
                icon: Icons.sync_outlined,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _gitStatus!.connected ? Icons.check_circle : Icons.error,
                    color: _gitStatus!.connected ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _gitStatus!.connected ? 'Connected' : 'Disconnected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _gitStatus!.connected ? Colors.green : Colors.red,
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
                Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _GitStatusItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _GitStatusItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}