import 'package:flutter/material.dart';
import '../../core/database/services/services.dart';
import '../../core/database/models/models.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/models/join_request.dart';
import '../../core/auth/auth_service.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> with TickerProviderStateMixin {
  final _teamMemberService = TeamMemberService.instance;
  final _taskService = TaskService.instance;
  final _specService = SpecService.instance;
  final _onboardingService = OnboardingService.instance;
  final _authService = AuthService.instance;
  
  List<TeamMember> _teamMembers = [];
  List<Task> _tasks = [];
  List<Specification> _specifications = [];
  List<JoinRequest> _pendingRequests = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    setState(() => _isLoading = true);
    
    try {
      final members = await _teamMemberService.getAllTeamMembers();
      final tasks = await _taskService.getAllTasks();
      final specs = await _specService.getAllSpecifications();
      
      // Load pending join requests if user has admin permissions
      List<JoinRequest> pendingRequests = [];
      if (_authService.hasPermission('manage_users')) {
        pendingRequests = await _onboardingService.getPendingRequests();
      }
      
      setState(() {
        _teamMembers = members;
        _tasks = tasks;
        _specifications = specs;
        _pendingRequests = pendingRequests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading team data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAdminPermissions = _authService.hasPermission('manage_users');
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Team Dashboard',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (hasAdminPermissions) ...[
                ElevatedButton.icon(
                  onPressed: _showAddMemberDialog,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Add Member'),
                ),
                const SizedBox(width: 12),
              ],
              TextButton.icon(
                onPressed: _loadTeamData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasAdminPermissions 
                ? 'Manage team members, review join requests, and track progress'
                : 'View team members and track progress',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Team Overview Cards
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildTeamOverview(),
          
          const SizedBox(height: 32),
          
          // Tab Bar (only show if admin)
          if (hasAdminPermissions) ...[
            TabBar(
              controller: TabController(length: 2, vsync: this),
              onTap: (index) => setState(() => _selectedTabIndex = index),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, size: 16),
                      const SizedBox(width: 8),
                      Text('Team Members (${_teamMembers.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_add_alt, size: 16),
                      const SizedBox(width: 8),
                      Text('Join Requests (${_pendingRequests.length})'),
                      if (_pendingRequests.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '${_pendingRequests.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          // Content based on selected tab
          Expanded(
            child: hasAdminPermissions 
                ? (_selectedTabIndex == 0 ? _buildTeamMembersTab() : _buildJoinRequestsTab())
                : _buildTeamMembersTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamOverview() {
    final activeMembers = _teamMembers.where((m) => m.status == 'active').length;
    final benchMembers = _teamMembers.where((m) => m.status == 'bench').length;
    final totalTasks = _tasks.length;
    final completedTasks = _tasks.where((t) => t.status == 'completed').length;
    
    return Row(
      children: [
        Expanded(
          child: _OverviewCard(
            title: 'Active Members',
            value: '$activeMembers',
            subtitle: '${_teamMembers.length} total members',
            color: Colors.green,
            icon: Icons.people,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _OverviewCard(
            title: 'Available',
            value: '$benchMembers',
            subtitle: 'Members on bench',
            color: Colors.blue,
            icon: Icons.person_outline,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _OverviewCard(
            title: 'Tasks',
            value: '$totalTasks',
            subtitle: '$completedTasks completed',
            color: Colors.orange,
            icon: Icons.task_alt,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _OverviewCard(
            title: _authService.hasPermission('manage_users') ? 'Join Requests' : 'Specifications',
            value: _authService.hasPermission('manage_users') ? '${_pendingRequests.length}' : '${_specifications.length}',
            subtitle: _authService.hasPermission('manage_users') 
                ? 'Pending approval' 
                : '${_specifications.where((s) => s.status == 'approved').length} approved',
            color: _authService.hasPermission('manage_users') 
                ? (_pendingRequests.isNotEmpty ? Colors.red : Colors.purple)
                : Colors.purple,
            icon: _authService.hasPermission('manage_users') ? Icons.person_add_alt : Icons.description,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamMembersTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team Members',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _teamMembers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No team members',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add team members to start managing assignments',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _teamMembers.length,
                      itemBuilder: (context, index) {
                        return _TeamMemberCard(
                          member: _teamMembers[index],
                          tasks: _tasks.where((t) => t.assigneeId == _teamMembers[index].id).toList(),
                          specifications: _specifications.where((s) => s.assignedTo == _teamMembers[index].id).toList(),
                          onAssignSpec: _showAssignSpecDialog,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinRequestsTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Join Requests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_pendingRequests.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pending_actions,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_pendingRequests.length} pending',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _pendingRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_alt_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No pending join requests',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'New join requests will appear here for review',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _pendingRequests.length,
                      itemBuilder: (context, index) {
                        return _JoinRequestCard(
                          request: _pendingRequests[index],
                          onApprove: _approveJoinRequest,
                          onReject: _rejectJoinRequest,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddMemberDialog(
        onMemberAdded: (member) async {
          try {
            await _teamMemberService.createTeamMember(member);
            _loadTeamData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Team member ${member.name} added successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error adding team member: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showAssignSpecDialog(TeamMember member) {
    final availableSpecs = _specifications.where((s) => s.assignedTo == null && s.status == 'approved').toList();
    
    if (availableSpecs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available specifications to assign')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Specification to ${member.name}'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: availableSpecs.length,
            itemBuilder: (context, index) {
              final spec = availableSpecs[index];
              return ListTile(
                title: Text(spec.suggestedBranchName),
                subtitle: Text(spec.aiInterpretation),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    final updatedSpec = spec.copyWith(assignedTo: member.id);
                    await _specService.updateSpecificationStatus(spec.id, 'in_progress');
                    _loadTeamData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Specification assigned to ${member.name}')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error assigning specification: $e')),
                      );
                    }
                  }
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

  Future<void> _approveJoinRequest(JoinRequest request, String? adminNotes) async {
    try {
      final success = await _onboardingService.approveRequest(request.id, adminNotes: adminNotes);
      
      if (success) {
        await _loadTeamData(); // Refresh data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Join request approved for ${request.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to approve join request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectJoinRequest(JoinRequest request, String reason) async {
    try {
      final success = await _onboardingService.rejectRequest(request.id, reason);
      
      if (success) {
        await _loadTeamData(); // Refresh data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Join request rejected for ${request.name}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to reject join request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  
  const _OverviewCard({
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

class _TeamMemberCard extends StatelessWidget {
  final TeamMember member;
  final List<Task> tasks;
  final List<Specification> specifications;
  final Function(TeamMember) onAssignSpec;
  
  const _TeamMemberCard({
    required this.member,
    required this.tasks,
    required this.specifications,
    required this.onAssignSpec,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    member.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${member.role} • ${member.email}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                _getStatusChip(context, member.status),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'assign') {
                      onAssignSpec(member);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'assign',
                      child: Row(
                        children: [
                          Icon(Icons.assignment, size: 16),
                          SizedBox(width: 8),
                          Text('Assign Specification'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Expertise
            if (member.expertise.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: member.expertise.map((skill) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    skill,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            
            // Workload and assignments
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workload: ${member.workload}/10',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: member.workload / 10,
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          member.workload > 8 ? Colors.red : 
                          member.workload > 6 ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${tasks.length} tasks',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${specifications.length} specs',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusChip(BuildContext context, String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'active':
        backgroundColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green.shade700;
        break;
      case 'bench':
        backgroundColor = Colors.blue.withOpacity(0.2);
        textColor = Colors.blue.shade700;
        break;
      case 'offline':
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
}

class _AddMemberDialog extends StatefulWidget {
  final Function(TeamMember) onMemberAdded;
  
  const _AddMemberDialog({required this.onMemberAdded});

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'developer';
  String _selectedStatus = 'active';
  final List<String> _expertise = [];
  final _expertiseController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _expertiseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Team Member'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: ['developer', 'admin', 'security_reviewer']
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(role.replaceAll('_', ' ').toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedRole = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: ['active', 'bench', 'offline']
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedStatus = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expertiseController,
                      decoration: const InputDecoration(
                        labelText: 'Add Expertise',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Flutter, Security, Backend',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final skill = _expertiseController.text.trim();
                      if (skill.isNotEmpty && !_expertise.contains(skill)) {
                        setState(() {
                          _expertise.add(skill);
                          _expertiseController.clear();
                        });
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
              if (_expertise.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _expertise.map((skill) => Chip(
                    label: Text(skill),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => _expertise.remove(skill));
                    },
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final member = TeamMember(
                id: '',
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                role: _selectedRole,
                status: _selectedStatus,
                assignments: [],
                expertise: _expertise,
                workload: 0,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              
              Navigator.of(context).pop();
              widget.onMemberAdded(member);
            }
          },
          child: const Text('Add Member'),
        ),
      ],
    );
  }
}
class _JoinRequestCard extends StatelessWidget {
  final JoinRequest request;
  final Function(JoinRequest, String?) onApprove;
  final Function(JoinRequest, String) onReject;
  
  const _JoinRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    request.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        request.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(request.requestedRole).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.requestedRole.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(request.requestedRole),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Request details
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  'Requested ${_formatTime(request.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.message!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showRejectDialog(context),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showApproveDialog(context),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'developer':
        return Colors.blue;
      case 'lead_developer':
        return Colors.purple;
      case 'viewer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showApproveDialog(BuildContext context) {
    final notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve ${request.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to approve this join request?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'User Details:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text('• Name: ${request.name}'),
              Text('• Email: ${request.email}'),
              Text('• Requested Role: ${request.requestedRole.replaceAll('_', ' ')}'),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Admin Notes (Optional)',
                  hintText: 'Add any notes for the new user...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A user account will be created and credentials will be sent via email.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
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
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onApprove(request, notesController.text.trim().isEmpty ? null : notesController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject ${request.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please provide a reason for rejecting this join request:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason *',
                  hintText: 'e.g., Position not available, insufficient experience...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The user will be notified of the rejection via email.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
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
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for rejection'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop();
              onReject(request, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}