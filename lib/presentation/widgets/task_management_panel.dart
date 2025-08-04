import 'package:flutter/material.dart';
import '../../core/database/models/task.dart';
import '../../core/database/services/enhanced_task_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/api/websocket_service.dart';

/// Task Management Panel with confidentiality controls
/// Satisfies Requirements: 5.1, 5.2, 5.3, 5.4, 5.5 (Task management with confidentiality)
class TaskManagementPanel extends StatefulWidget {
  final String userRole;
  final String userId;
  final bool showCreateButton;
  final bool showAllTasks;
  final String? filterAssigneeId;
  final String? filterStatus;

  const TaskManagementPanel({
    super.key,
    required this.userRole,
    required this.userId,
    this.showCreateButton = true,
    this.showAllTasks = false,
    this.filterAssigneeId,
    this.filterStatus,
  });

  @override
  State<TaskManagementPanel> createState() => _TaskManagementPanelState();
}

class _TaskManagementPanelState extends State<TaskManagementPanel> {
  final _taskService = EnhancedTaskService.instance;
  final _authService = AuthService.instance;
  final _websocketService = WebSocketService.instance;

  List<Task> _tasks = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _selectedPriority = 'all';
  String _selectedConfidentiality = 'all';

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _setupWebSocketListeners();
  }

  void _setupWebSocketListeners() {
    _websocketService.onTaskUpdate.listen((update) {
      if (mounted) {
        _loadTasks(); // Refresh tasks when updates are received
      }
    });
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tasks = await _taskService.getAuthorizedTasks(
        userId: widget.userId,
        userRole: widget.userRole,
        assigneeId: widget.showAllTasks
            ? null
            : widget.filterAssigneeId ?? widget.userId,
        status: widget.filterStatus,
        priority: _selectedPriority == 'all' ? null : _selectedPriority,
        confidentialityLevel:
            _selectedConfidentiality == 'all' ? null : _selectedConfidentiality,
      );

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tasks: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 16),
            _buildTaskList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.showAllTasks ? 'All Tasks' : 'My Tasks',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (widget.showCreateButton && _canCreateTasks())
          ElevatedButton.icon(
            onPressed: _showCreateTaskDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Task'),
          ),
      ],
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 16,
      children: [
        _buildFilterDropdown(
          'Status',
          _selectedFilter,
          [
            'all',
            'pending',
            'in_progress',
            'review',
            'testing',
            'completed',
            'blocked'
          ],
          (value) => setState(() {
            _selectedFilter = value!;
            _loadTasks();
          }),
        ),
        _buildFilterDropdown(
          'Priority',
          _selectedPriority,
          ['all', 'low', 'medium', 'high', 'critical'],
          (value) => setState(() {
            _selectedPriority = value!;
            _loadTasks();
          }),
        ),
        if (_canViewConfidentialityFilter())
          _buildFilterDropdown(
            'Confidentiality',
            _selectedConfidentiality,
            ['all', 'public', 'team', 'restricted', 'confidential'],
            (value) => setState(() {
              _selectedConfidentiality = value!;
              _loadTasks();
            }),
          ),
      ],
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        value: value,
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option.replaceAll('_', ' ').toUpperCase()),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTaskList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildTaskStatusIcon(task.status),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.description),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildTaskChip(task.type, _getTypeColor(task.type)),
                const SizedBox(width: 8),
                _buildTaskChip(task.priority, _getPriorityColor(task.priority)),
                const SizedBox(width: 8),
                _buildConfidentialityChip(task.confidentialityLevel),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleTaskAction(action, task),
          itemBuilder: (context) => _buildTaskActions(task),
        ),
        onTap: () => _showTaskDetails(task),
      ),
    );
  }

  Widget _buildTaskStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status.toLowerCase()) {
      case 'pending':
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case 'in_progress':
        icon = Icons.play_circle;
        color = Colors.blue;
        break;
      case 'review':
        icon = Icons.rate_review;
        color = Colors.purple;
        break;
      case 'testing':
        icon = Icons.bug_report;
        color = Colors.amber;
        break;
      case 'completed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'blocked':
        icon = Icons.block;
        color = Colors.red;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Icon(icon, color: color);
  }

  Widget _buildTaskChip(String label, Color color) {
    return Chip(
      label: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildConfidentialityChip(String level) {
    Color color;
    IconData icon;

    switch (level.toLowerCase()) {
      case 'public':
        color = Colors.green;
        icon = Icons.public;
        break;
      case 'team':
        color = Colors.blue;
        icon = Icons.group;
        break;
      case 'restricted':
        color = Colors.orange;
        icon = Icons.lock_outline;
        break;
      case 'confidential':
        color = Colors.red;
        icon = Icons.lock;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        level.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'feature':
        return Colors.blue;
      case 'bug':
        return Colors.red;
      case 'security':
        return Colors.purple;
      case 'deployment':
        return Colors.green;
      case 'research':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  List<PopupMenuEntry<String>> _buildTaskActions(Task task) {
    final actions = <PopupMenuEntry<String>>[];

    if (_canEditTask(task)) {
      actions.add(const PopupMenuItem(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit),
          title: Text('Edit'),
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    if (_canChangeTaskStatus(task)) {
      actions.add(const PopupMenuItem(
        value: 'status',
        child: ListTile(
          leading: Icon(Icons.update),
          title: Text('Update Status'),
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    if (_canAssignTask(task)) {
      actions.add(const PopupMenuItem(
        value: 'assign',
        child: ListTile(
          leading: Icon(Icons.person_add),
          title: Text('Reassign'),
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    if (_canDeleteTask(task)) {
      actions.add(const PopupMenuItem(
        value: 'delete',
        child: ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('Delete', style: TextStyle(color: Colors.red)),
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    return actions;
  }

  void _handleTaskAction(String action, Task task) {
    switch (action) {
      case 'edit':
        _showEditTaskDialog(task);
        break;
      case 'status':
        _showStatusUpdateDialog(task);
        break;
      case 'assign':
        _showAssignTaskDialog(task);
        break;
      case 'delete':
        _showDeleteConfirmation(task);
        break;
    }
  }

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailsDialog(task: task),
    );
  }

  void _showCreateTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateTaskDialog(
        onTaskCreated: _loadTasks,
        userRole: widget.userRole,
        userId: widget.userId,
      ),
    );
  }

  void _showEditTaskDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => EditTaskDialog(
        task: task,
        onTaskUpdated: _loadTasks,
        userRole: widget.userRole,
        userId: widget.userId,
      ),
    );
  }

  void _showStatusUpdateDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => StatusUpdateDialog(
        task: task,
        onStatusUpdated: _loadTasks,
        userRole: widget.userRole,
        userId: widget.userId,
      ),
    );
  }

  void _showAssignTaskDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => AssignTaskDialog(
        task: task,
        onTaskAssigned: _loadTasks,
        userRole: widget.userRole,
        userId: widget.userId,
      ),
    );
  }

  void _showDeleteConfirmation(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteTask(task);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await _taskService.deleteTaskWithConfidentiality(
        taskId: task.id,
        userId: widget.userId,
        userRole: widget.userRole,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting task: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Permission check methods
  bool _canCreateTasks() {
    return widget.userRole != 'viewer';
  }

  bool _canEditTask(Task task) {
    return widget.userRole == 'admin' ||
        widget.userRole == 'lead_developer' ||
        task.assigneeId == widget.userId;
  }

  bool _canChangeTaskStatus(Task task) {
    return widget.userRole == 'admin' ||
        widget.userRole == 'lead_developer' ||
        task.assigneeId == widget.userId;
  }

  bool _canAssignTask(Task task) {
    return widget.userRole == 'admin' || widget.userRole == 'lead_developer';
  }

  bool _canDeleteTask(Task task) {
    return widget.userRole == 'admin' || widget.userRole == 'lead_developer';
  }

  bool _canViewConfidentialityFilter() {
    return widget.userRole == 'admin' || widget.userRole == 'lead_developer';
  }
}

// Placeholder dialog classes - these would be implemented separately
class TaskDetailsDialog extends StatelessWidget {
  final Task task;

  const TaskDetailsDialog({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(task.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Description: ${task.description}'),
            const SizedBox(height: 8),
            Text('Type: ${task.type}'),
            Text('Priority: ${task.priority}'),
            Text('Status: ${task.status}'),
            Text('Confidentiality: ${task.confidentialityLevel}'),
            Text('Created: ${task.createdAt.toString()}'),
            Text('Due: ${task.dueDate.toString()}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class CreateTaskDialog extends StatelessWidget {
  final VoidCallback onTaskCreated;
  final String userRole;
  final String userId;

  const CreateTaskDialog({
    super.key,
    required this.onTaskCreated,
    required this.userRole,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Task'),
      content: const Text('Task creation dialog would be implemented here'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onTaskCreated();
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class EditTaskDialog extends StatelessWidget {
  final Task task;
  final VoidCallback onTaskUpdated;
  final String userRole;
  final String userId;

  const EditTaskDialog({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    required this.userRole,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Task'),
      content: const Text('Task editing dialog would be implemented here'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onTaskUpdated();
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class StatusUpdateDialog extends StatelessWidget {
  final Task task;
  final VoidCallback onStatusUpdated;
  final String userRole;
  final String userId;

  const StatusUpdateDialog({
    super.key,
    required this.task,
    required this.onStatusUpdated,
    required this.userRole,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Status'),
      content: const Text('Status update dialog would be implemented here'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onStatusUpdated();
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class AssignTaskDialog extends StatelessWidget {
  final Task task;
  final VoidCallback onTaskAssigned;
  final String userRole;
  final String userId;

  const AssignTaskDialog({
    super.key,
    required this.task,
    required this.onTaskAssigned,
    required this.userRole,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Task'),
      content: const Text('Task assignment dialog would be implemented here'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onTaskAssigned();
          },
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
