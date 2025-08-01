import 'package:flutter/material.dart';
import '../../core/deployment/deployment_pipeline.dart';
import '../../core/deployment/rollback_controller.dart';
import '../../core/database/models/models.dart';

class DeploymentsScreen extends StatefulWidget {
  const DeploymentsScreen({super.key});

  @override
  State<DeploymentsScreen> createState() => _DeploymentsScreenState();
}

class _DeploymentsScreenState extends State<DeploymentsScreen> {
  final _deploymentPipeline = DeploymentPipeline.instance;
  final _rollbackController = RollbackController.instance;
  
  List<Deployment> _deployments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeployments();
  }

  Future<void> _loadDeployments() async {
    setState(() => _isLoading = true);
    
    try {
      final deployments = await _deploymentPipeline.getRecentDeployments();
      setState(() {
        _deployments = deployments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading deployments: $e')),
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
            'Deployments',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage CI/CD pipelines, deployments, and rollback operations',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Environment Status
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildEnvironmentCards(),
          
          const SizedBox(height: 32),
          
          // Actions
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement create pipeline
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Pipeline'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement deploy
                },
                icon: const Icon(Icons.rocket_launch, size: 16),
                label: const Text('Deploy'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showRollbackDialog,
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Rollback'),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _loadDeployments,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Deployment History
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deployment History',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _deployments.isEmpty
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
                                    'No deployment history',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create your first pipeline to start deploying',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _deployments.length,
                              itemBuilder: (context, index) {
                                return _DeploymentCard(deployment: _deployments[index]);
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

class _EnvironmentCard extends StatelessWidget {
  final String environment;
  final String status;
  final String lastDeployment;
  final Color color;
  
  const _EnvironmentCard({
    required this.environment,
    required this.status,
    required this.lastDeployment,
    required this.color,
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
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  environment,
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
              'Last deployment:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              lastDeployment,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
 Widget _buildEnvironmentCards() {
    final environments = ['development', 'staging', 'production'];
    final colors = [Colors.blue, Colors.orange, Colors.green];
    
    return Row(
      children: environments.asMap().entries.map((entry) {
        final index = entry.key;
        final env = entry.value;
        final color = colors[index];
        
        final envDeployments = _deployments.where((d) => d.environment == env).toList();
        final latestDeployment = envDeployments.isNotEmpty ? envDeployments.first : null;
        
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < environments.length - 1 ? 16 : 0),
            child: _EnvironmentCard(
              environment: env.toUpperCase(),
              status: latestDeployment?.status ?? 'Ready',
              lastDeployment: latestDeployment != null 
                  ? '${latestDeployment.version} - ${_formatTime(latestDeployment.deployedAt)}'
                  : 'No deployments yet',
              color: _getStatusColor(latestDeployment?.status, color),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor(String? status, Color defaultColor) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      case 'rolled_back':
        return Colors.orange;
      default:
        return defaultColor;
    }
  }

  void _showRollbackDialog() {
    showDialog(
      context: context,
      builder: (context) => _RollbackDialog(
        onRollback: (environment) async {
          try {
            final options = await _rollbackController.getRollbackOptions(environment);
            if (options.isNotEmpty && mounted) {
              _showRollbackOptionsDialog(environment, options);
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No rollback options available for $environment')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error loading rollback options: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showRollbackOptionsDialog(String environment, List<RollbackOption> options) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rollback Options for $environment'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              return ListTile(
                title: Text(option.version),
                subtitle: Text(option.description),
                trailing: option.verified 
                    ? const Icon(Icons.verified, color: Colors.green, size: 16)
                    : const Icon(Icons.warning, color: Colors.orange, size: 16),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmRollback(option);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmRollback(RollbackOption option) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Rollback'),
        content: Text('Are you sure you want to rollback to ${option.version}?\n\n${option.description}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final request = await _rollbackController.initiateRollback(
                  environment: option.environment,
                  snapshotId: option.snapshotId,
                  reason: 'Manual rollback requested by user',
                  requestedBy: 'current_user',
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rollback request created: ${request.id}')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating rollback request: $e')),
                  );
                }
              }
            },
            child: const Text('Confirm Rollback'),
          ),
        ],
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

class _DeploymentCard extends StatelessWidget {
  final Deployment deployment;
  
  const _DeploymentCard({required this.deployment});

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
                _getStatusIcon(deployment.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${deployment.version} - ${deployment.environment}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _getStatusChip(context, deployment.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Deployed by: ${deployment.deployedBy}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Deployed: ${_formatTime(deployment.deployedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (deployment.rollbackAvailable) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Rollback Available',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'success':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'failed':
        return const Icon(Icons.error, color: Colors.red, size: 20);
      case 'in_progress':
        return const Icon(Icons.hourglass_empty, color: Colors.blue, size: 20);
      case 'rolled_back':
        return const Icon(Icons.undo, color: Colors.orange, size: 20);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey, size: 20);
    }
  }

  Widget _getStatusChip(BuildContext context, String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'success':
        backgroundColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green.shade700;
        break;
      case 'failed':
        backgroundColor = Colors.red.withOpacity(0.2);
        textColor = Colors.red.shade700;
        break;
      case 'in_progress':
        backgroundColor = Colors.blue.withOpacity(0.2);
        textColor = Colors.blue.shade700;
        break;
      case 'rolled_back':
        backgroundColor = Colors.orange.withOpacity(0.2);
        textColor = Colors.orange.shade700;
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

class _RollbackDialog extends StatefulWidget {
  final Function(String) onRollback;
  
  const _RollbackDialog({required this.onRollback});

  @override
  State<_RollbackDialog> createState() => _RollbackDialogState();
}

class _RollbackDialogState extends State<_RollbackDialog> {
  String _selectedEnvironment = 'production';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Initiate Rollback'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select environment for rollback:'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedEnvironment,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Environment',
            ),
            items: ['development', 'staging', 'production']
                .map((env) => DropdownMenuItem(
                      value: env,
                      child: Text(env.toUpperCase()),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedEnvironment = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onRollback(_selectedEnvironment);
          },
          child: const Text('Show Options'),
        ),
      ],
    );
  }
}