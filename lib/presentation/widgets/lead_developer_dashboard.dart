import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/database/services/services.dart';
import '../screens/code_editor_screen.dart';
import 'task_management_panel.dart';

/// Lead Developer dashboard widget with team management features
class LeadDeveloperDashboard extends StatefulWidget {
  const LeadDeveloperDashboard({super.key});

  @override
  State<LeadDeveloperDashboard> createState() => _LeadDeveloperDashboardState();
}

class _LeadDeveloperDashboardState extends State<LeadDeveloperDashboard>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService.instance;
  final _taskService = TaskService.instance;
  final _teamMemberService = TeamMemberService.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check lead developer permissions
    if (!_authService.hasPermission('assign_developer_tasks')) {
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
                'You need lead developer permissions to access the team management dashboard.',
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
            color: Colors.green.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.engineering, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Lead Developer Dashboard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Manage team tasks, code reviews, and deployment oversight',
                style: TextStyle(
                  color: Colors.green.shade600,
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
            border: Border.all(color: Colors.green.shade200),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.green.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.green.shade700,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.task_alt), text: 'Team Tasks'),
              Tab(icon: Icon(Icons.assignment), text: 'All Tasks'),
              Tab(icon: Icon(Icons.code), text: 'Code Review'),
              Tab(icon: Icon(Icons.rocket_launch), text: 'Deployments'),
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
              border: Border.all(color: Colors.green.shade200),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                // Overview tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildOverviewTab(),
                ),

                // Team Tasks tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TaskManagementPanel(
                    userRole: 'lead_developer',
                    userId: _authService.currentUser?.id ?? '',
                    showCreateButton: true,
                    showAllTasks: false,
                    filterAssigneeId: null, // Show tasks for all team members
                  ),
                ),

                // All Tasks tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TaskManagementPanel(
                    userRole: 'lead_developer',
                    userId: _authService.currentUser?.id ?? '',
                    showCreateButton: true,
                    showAllTasks: true,
                  ),
                ),

                // Code Review tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildCodeReviewTab(),
                ),

                // Deployments tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildDeploymentsTab(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team Status Cards
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  'Team Members',
                  '8',
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusCard(
                  'Active Tasks',
                  '15',
                  Icons.task_alt,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusCard(
                  'Pending Reviews',
                  '4',
                  Icons.rate_review,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Team Performance
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Team Performance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPerformanceMetric('Tasks Completed This Week', '12'),
                  _buildPerformanceMetric(
                      'Average Task Completion Time', '2.3 days'),
                  _buildPerformanceMetric(
                      'Code Review Turnaround', '4.2 hours'),
                  _buildPerformanceMetric('Deployment Success Rate', '95%'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTasksTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Assignment Section
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
                        'Task Assignment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      ElevatedButton.icon(
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
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showCreateTaskDialog();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Task'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTaskItem(
                    'Implement user authentication',
                    'John Doe',
                    'In Progress',
                    Colors.orange,
                    'High',
                  ),
                  _buildTaskItem(
                    'Fix database connection issue',
                    'Jane Smith',
                    'Review',
                    Colors.purple,
                    'Critical',
                  ),
                  _buildTaskItem(
                    'Update API documentation',
                    'Unassigned',
                    'To Do',
                    Colors.grey,
                    'Medium',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Team Workload
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Team Workload',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildWorkloadItem('John Doe', 3, 5, Colors.orange),
                  _buildWorkloadItem('Jane Smith', 2, 5, Colors.green),
                  _buildWorkloadItem('Mike Johnson', 4, 5, Colors.red),
                  _buildWorkloadItem('Sarah Wilson', 1, 5, Colors.blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeReviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pending Reviews
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Code Reviews',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildReviewItem(
                    'PR #123: Add user profile feature',
                    'John Doe',
                    '2 hours ago',
                    '+245 -67',
                  ),
                  _buildReviewItem(
                    'PR #124: Fix memory leak in data service',
                    'Jane Smith',
                    '4 hours ago',
                    '+12 -8',
                  ),
                  _buildReviewItem(
                    'PR #125: Update dependencies',
                    'Mike Johnson',
                    '1 day ago',
                    '+156 -203',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Review Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReviewStat(
                            'Reviews This Week', '8', Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildReviewStat(
                            'Avg Review Time', '2.1h', Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildReviewStat(
                            'Approval Rate', '92%', Colors.purple),
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

  Widget _buildDeploymentsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Deployment Controls
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
                        'Deployment Controls',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showDeploymentDialog();
                        },
                        icon: const Icon(Icons.rocket_launch),
                        label: const Text('Deploy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDeploymentEnv(
                            'Development', 'v1.2.3', 'Healthy', Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDeploymentEnv(
                            'Staging', 'v1.2.2', 'Deploying', Colors.orange),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDeploymentEnv(
                            'Production', 'v1.2.1', 'Healthy', Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recent Deployments
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Deployments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDeploymentItem('v1.2.3', 'Development', 'Success',
                      '2 hours ago', Colors.green),
                  _buildDeploymentItem('v1.2.2', 'Staging', 'In Progress',
                      '4 hours ago', Colors.orange),
                  _buildDeploymentItem('v1.2.1', 'Production', 'Success',
                      '1 day ago', Colors.green),
                  _buildDeploymentItem('v1.2.0', 'Production', 'Failed',
                      '2 days ago', Colors.red),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for building UI components
  Widget _buildStatusCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
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

  Widget _buildPerformanceMetric(String metric, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(metric, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  color: Colors.green.shade700, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String title, String assignee, String status,
      Color statusColor, String priority) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Assigned to: $assignee',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Chip(
            label: Text(priority),
            backgroundColor: priority == 'Critical'
                ? Colors.red.shade100
                : priority == 'High'
                    ? Colors.orange.shade100
                    : Colors.blue.shade100,
            labelStyle: TextStyle(
              color: priority == 'Critical'
                  ? Colors.red
                  : priority == 'High'
                      ? Colors.orange
                      : Colors.blue,
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
    );
  }

  Widget _buildWorkloadItem(
      String name, int currentTasks, int maxTasks, Color color) {
    final percentage = currentTasks / maxTasks;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('$currentTasks/$maxTasks tasks'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(
      String title, String author, String time, String changes) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('by $author • $time',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text(changes,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              // Open code review
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(60, 30),
            ),
            child: const Text('Review', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStat(String title, String value, Color color) {
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

  Widget _buildDeploymentEnv(
      String env, String version, String status, Color color) {
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
            env,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(version, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeploymentItem(
      String version, String env, String status, String time, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$version → $env',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(time,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Chip(
            label: Text(status),
            backgroundColor: color.withOpacity(0.2),
            labelStyle: TextStyle(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _showCreateTaskDialog() {
    // Show create task dialog
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

  void _showDeploymentDialog() {
    // Show deployment dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deploy Application'),
        content: const Text(
            'Deployment configuration dialog would be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Deploy'),
          ),
        ],
      ),
    );
  }
}
