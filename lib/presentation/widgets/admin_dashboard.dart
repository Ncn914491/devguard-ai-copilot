import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/database/services/services.dart';
import '../screens/code_editor_screen.dart';
import 'join_request_management.dart';
import 'manual_member_addition.dart';
import 'task_management_panel.dart';

/// Admin dashboard widget with member onboarding features
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService.instance;
  // Services are accessed directly when needed
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Status Cards
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  'Active Users',
                  '12',
                  Icons.people,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusCard(
                  'Pending Requests',
                  '3',
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusCard(
                  'Security Alerts',
                  '1',
                  Icons.security,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Activity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildActivityItem(
                      'User john.doe@company.com joined the project',
                      '2 hours ago'),
                  _buildActivityItem(
                      'Security alert: Unusual login pattern detected',
                      '4 hours ago'),
                  _buildActivityItem(
                      'Deployment completed successfully', '6 hours ago'),
                  _buildActivityItem(
                      'New join request from jane.smith@company.com',
                      '1 day ago'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security Overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Security Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSecurityMetric(
                            'Active Alerts', '1', Colors.red),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSecurityMetric(
                            'Failed Logins', '5', Colors.orange),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSecurityMetric(
                            'Blocked IPs', '2', Colors.yellow.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Active Security Alerts
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Security Alerts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSecurityAlert(
                    'Unusual Login Pattern',
                    'Multiple failed login attempts detected from IP 192.168.1.100',
                    'High',
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

  Widget _buildSystemTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'System Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSystemSetting('Project Name', 'DevGuard AI Copilot'),
                  _buildSystemSetting('Max Team Members', '50'),
                  _buildSystemSetting('Session Timeout', '24 hours'),
                  _buildSystemSetting('Security Level', 'High'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // System Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
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
                      ElevatedButton.icon(
                        onPressed: () {
                          // Export audit logs
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Export Audit Logs'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Backup system
                        },
                        icon: const Icon(Icons.backup),
                        label: const Text('Backup System'),
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
          ),
        ],
      ),
    );
  }

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

  Widget _buildActivityItem(String activity, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.blue.shade300,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(activity),
          ),
          Text(
            time,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityMetric(String title, String value, Color color) {
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
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityAlert(
      String title, String description, String severity, Color color) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Chip(
            label: Text(severity),
            backgroundColor: color.withOpacity(0.2),
            labelStyle: TextStyle(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSetting(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check admin permissions
    if (!_authService.hasPermission('manage_users')) {
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
                'You need admin permissions to access the member management dashboard.',
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
            color: Colors.blue.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Member Management Dashboard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Manage join requests and add team members to the project',
                style: TextStyle(
                  color: Colors.blue.shade600,
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
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.blue.shade700,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.pending_actions), text: 'Join Requests'),
              Tab(icon: Icon(Icons.person_add_alt_1), text: 'Add Member'),
              Tab(icon: Icon(Icons.task_alt), text: 'Tasks'),
              Tab(icon: Icon(Icons.security), text: 'Security'),
              Tab(icon: Icon(Icons.settings), text: 'System'),
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
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                // Overview tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildOverviewTab(),
                ),

                // Join Requests tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: const JoinRequestManagement(),
                ),

                // Add Member tab
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: ManualMemberAddition(),
                ),

                // Tasks tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TaskManagementPanel(
                    userRole: 'admin',
                    userId: _authService.currentUser?.id ?? '',
                    showCreateButton: true,
                    showAllTasks: true,
                  ),
                ),

                // Security tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildSecurityTab(),
                ),

                // System Settings tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildSystemTab(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
