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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deployments',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monitor and manage your deployment pipeline',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _showRollbackDialog,
                    icon: const Icon(Icons.undo),
                    label: const Text('Rollback'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loadDeployments,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Environment Status Cards
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildEnvironmentCards(),
          
          const SizedBox(height: 32),
          
          // Recent Deployments
          Text(
            'Recent Deployments',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _deployments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rocket_launch_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No deployments yet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Deployments will appear here once you start deploying',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _deployments.length,
                        itemBuilder: (context, index) {
                          final deployment = _deployments[index];
                          return _DeploymentCard(deployment: deployment);
                        },
                      ),
          ),
        ],
      ),
    );
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
      builder: (context) => _RollbackOptionsDialog(
        environment: environment,
        options: options,
        onConfirm: (option) async {
          try {
            final result = await _rollbackController.executeRollback(
              environment,
              option.snapshotId,
              'User-initiated rollback via UI',
            );
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.success 
                      ? 'Rollback initiated successfully' 
                      : 'Rollback failed: ${result.message}'),
                  backgroundColor: result.success ? Colors.green : Colors.red,
                ),
              );
              
              if (result.success) {
                _loadDeployments(); // Refresh the list
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error executing rollback: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusIcon(String status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case 'success':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'failed':
        icon = Icons.error;
        color = Colors.red;
        break;
      case 'in_progress':
        icon = Icons.hourglass_empty;
        color = Colors.blue;
        break;
      case 'rolled_back':
        icon = Icons.undo;
        color = Colors.orange;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }
    
    return Icon(icon, color: color, size: 20);
  }

  Widget _getStatusChip(BuildContext context, String status) {
    Color backgroundColor;
    Color textColor;
    
    switch (status) {
      case 'success':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        break;
      case 'failed':
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red;
        break;
      case 'in_progress':
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        break;
      case 'rolled_back':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        break;
      default:
        backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        textColor = Theme.of(context).colorScheme.onSurface;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
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
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  environment,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              status,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lastDeployment,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
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
      title: const Text('Rollback Deployment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select the environment to rollback:'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedEnvironment,
            decoration: const InputDecoration(
              labelText: 'Environment',
              border: OutlineInputBorder(),
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
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _RollbackOptionsDialog extends StatelessWidget {
  final String environment;
  final List<RollbackOption> options;
  final Function(RollbackOption) onConfirm;
  
  const _RollbackOptionsDialog({
    required this.environment,
    required this.options,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rollback Options - ${environment.toUpperCase()}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a snapshot to rollback to:'),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return Card(
                    child: ListTile(
                      title: Text('Version ${option.version}'),
                      subtitle: Text(
                        'Created: ${_formatTime(option.createdAt)}\n'
                        'Reason: ${option.aiReasoning}',
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onConfirm(option);
                        },
                        child: const Text('Rollback'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
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