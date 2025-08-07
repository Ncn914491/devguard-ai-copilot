import 'package:flutter/material.dart';
import '../../core/supabase/supabase_auth_service.dart';
import '../../core/supabase/services/supabase_task_service.dart';
import '../screens/code_editor_screen.dart';
import 'task_management_panel.dart';
import 'realtime_status_indicator.dart';

/// Developer dashboard widget with task and repository access
class DeveloperDashboard extends StatefulWidget {
  const DeveloperDashboard({super.key});

  @override
  State<DeveloperDashboard> createState() => _DeveloperDashboardState();
}

class _DeveloperDashboardState extends State<DeveloperDashboard>
    with SingleTickerProviderStateMixin {
  final _authService = SupabaseAuthService.instance;
  final _taskService = SupabaseTaskService.instance;
  late TabController _tabController;

  // Real-time data streams
  Stream<List<dynamic>>? _tasksStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeRealTimeStreams();
  }

  void _initializeRealTimeStreams() {
    // Initialize real-time data streams
    _tasksStream = _taskService.watchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check developer permissions
    if (!_authService.hasPermission('create_tasks')) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.lock, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You need developer permissions to access this dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.code, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Developer Dashboard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your assigned tasks and access development tools',
                style: TextStyle(
                  color: Colors.purple.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.purple.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.purple.shade700,
            tabs: const [
              Tab(icon: Icon(Icons.task_alt), text: 'My Tasks'),
              Tab(icon: Icon(Icons.assignment), text: 'All Tasks'),
              Tab(icon: Icon(Icons.folder), text: 'Repositories'),
              Tab(icon: Icon(Icons.timeline), text: 'Activity'),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                // My Tasks tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TaskManagementPanel(
                    userRole: 'developer',
                    userId: _authService.currentUser?.id ?? '',
                    showCreateButton: false,
                    showAllTasks: false,
                  ),
                ),

                // All Tasks tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TaskManagementPanel(
                    userRole: 'developer',
                    userId: _authService.currentUser?.id ?? '',
                    showCreateButton: true,
                    showAllTasks: true,
                  ),
                ),

                // Repositories tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildRepositoriesTab(),
                ),

                // Activity tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildActivityTab(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyTasksTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Summary
          Row(
            children: [
              Expanded(
                child: _buildTaskSummaryCard(
                  'To Do',
                  '3',
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTaskSummaryCard(
                  'In Progress',
                  '2',
                  Icons.play_circle,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTaskSummaryCard(
                  'Completed',
                  '8',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Active Tasks
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Tasks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showCreateTaskDialog();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('New Task'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTaskItem(
                    'Implement user profile API',
                    'In Progress',
                    Colors.blue,
                    'High',
                    '2 days left',
                    0.6,
                  ),
                  _buildTaskItem(
                    'Fix authentication bug',
                    'In Progress',
                    Colors.blue,
                    'Critical',
                    '1 day left',
                    0.8,
                  ),
                  _buildTaskItem(
                    'Update documentation',
                    'To Do',
                    Colors.orange,
                    'Medium',
                    '5 days left',
                    0.0,
                  ),
                  _buildTaskItem(
                    'Code review for PR #123',
                    'To Do',
                    Colors.orange,
                    'Low',
                    '3 days left',
                    0.0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepositoriesTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repository Access
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accessible Repositories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRepositoryItem(
                    'devguard-ai-copilot',
                    'Main application repository',
                    'Flutter • Dart',
                    'main',
                    '2 hours ago',
                    true,
                  ),
                  _buildRepositoryItem(
                    'devguard-backend',
                    'Backend API services',
                    'Node.js • TypeScript',
                    'develop',
                    '1 day ago',
                    true,
                  ),
                  _buildRepositoryItem(
                    'devguard-docs',
                    'Documentation and guides',
                    'Markdown',
                    'main',
                    '3 days ago',
                    false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const CodeEditorScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.code),
                          label: const Text('Code Editor'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Open terminal
                          },
                          icon: const Icon(Icons.terminal),
                          label: const Text('Terminal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Create pull request
                          },
                          icon: const Icon(Icons.merge_type),
                          label: const Text('New PR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This Week\'s Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child:
                            _buildActivityStat('Commits', '12', Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child:
                            _buildActivityStat('PRs Created', '3', Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActivityStat(
                            'Tasks Completed', '5', Colors.orange),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recent Activity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActivityItem(
                    Icons.commit,
                    'Committed changes to user-auth branch',
                    '2 hours ago',
                    Colors.green,
                  ),
                  _buildActivityItem(
                    Icons.task_alt,
                    'Completed task: Fix login validation',
                    '4 hours ago',
                    Colors.blue,
                  ),
                  _buildActivityItem(
                    Icons.merge_type,
                    'Created PR #125: Add password reset feature',
                    '1 day ago',
                    Colors.orange,
                  ),
                  _buildActivityItem(
                    Icons.comment,
                    'Commented on PR #123: User profile implementation',
                    '1 day ago',
                    Colors.purple,
                  ),
                  _buildActivityItem(
                    Icons.bug_report,
                    'Reported bug: Memory leak in data service',
                    '2 days ago',
                    Colors.red,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for building UI components
  Widget _buildTaskSummaryCard(
      String title, String count, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(String title, String status, Color statusColor,
      String priority, String deadline, double progress) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Chip(
                label: Text(priority),
                backgroundColor: priority == 'Critical'
                    ? Colors.red.shade100
                    : priority == 'High'
                        ? Colors.orange.shade100
                        : priority == 'Medium'
                            ? Colors.blue.shade100
                            : Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: priority == 'Critical'
                      ? Colors.red
                      : priority == 'High'
                          ? Colors.orange
                          : priority == 'Medium'
                              ? Colors.blue
                              : Colors.grey,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(status),
                backgroundColor: statusColor.withOpacity(0.2),
                labelStyle: TextStyle(color: statusColor, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress: ${(progress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                deadline,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepositoryItem(String name, String description, String tech,
      String branch, String lastUpdate, bool hasAccess) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder,
            color: hasAccess ? Colors.blue : Colors.grey,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      tech,
                      style: const TextStyle(fontSize: 10, color: Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $branch',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $lastUpdate',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasAccess)
            ElevatedButton(
              onPressed: () {
                // Open repository
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 30),
              ),
              child: const Text('Open', style: TextStyle(fontSize: 10)),
            )
          else
            const Icon(Icons.lock, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildActivityStat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
      IconData icon, String description, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  time,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Task'),
        content: const Text('Task creation dialog would be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
