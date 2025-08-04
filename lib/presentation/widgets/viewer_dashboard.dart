import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';

/// Viewer dashboard widget with read-only project information
class ViewerDashboard extends StatefulWidget {
  const ViewerDashboard({super.key});

  @override
  State<ViewerDashboard> createState() => _ViewerDashboardState();
}

class _ViewerDashboardState extends State<ViewerDashboard>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.visibility, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Project Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Read-only access to project information and public resources',
                style: TextStyle(
                  color: Colors.teal.shade600,
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
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.teal.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.teal.shade700,
            tabs: const [
              Tab(icon: Icon(Icons.info), text: 'Project Info'),
              Tab(icon: Icon(Icons.public), text: 'Public Repos'),
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
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                // Project Info tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildProjectInfoTab(),
                ),

                // Public Repositories tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildPublicReposTab(),
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

  Widget _buildProjectInfoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_open, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'DevGuard AI Copilot',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A cross-platform productivity and security copilot application designed specifically for developers. The application automates git-based workflows, manages deployments with rollback safety, and detects suspicious activities.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip('Flutter', Colors.blue),
                      const SizedBox(width: 8),
                      _buildInfoChip('Dart', Colors.blue.shade700),
                      const SizedBox(width: 8),
                      _buildInfoChip('SQLite', Colors.green),
                      const SizedBox(width: 8),
                      _buildInfoChip('AI/ML', Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Project Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Project Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                            'Team Members', '12', Icons.people, Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                            'Repositories', '5', Icons.folder, Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard('Total Commits', '1,247',
                            Icons.commit, Colors.orange),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Project Timeline
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Project Timeline',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineItem('Project Initiated', 'January 2024',
                      Icons.flag, Colors.green),
                  _buildTimelineItem('Alpha Release', 'March 2024',
                      Icons.rocket_launch, Colors.blue),
                  _buildTimelineItem('Beta Testing', 'May 2024',
                      Icons.bug_report, Colors.orange),
                  _buildTimelineItem('Production Ready', 'July 2024',
                      Icons.check_circle, Colors.purple),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicReposTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Public Repositories
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Public Repositories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPublicRepoItem(
                    'devguard-docs',
                    'Project documentation and user guides',
                    'Markdown',
                    '45 commits',
                    '3 contributors',
                    true,
                  ),
                  _buildPublicRepoItem(
                    'devguard-examples',
                    'Example configurations and use cases',
                    'YAML • JSON',
                    '23 commits',
                    '2 contributors',
                    true,
                  ),
                  _buildPublicRepoItem(
                    'devguard-plugins',
                    'Community plugins and extensions',
                    'Dart • Flutter',
                    '67 commits',
                    '5 contributors',
                    true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Repository Guidelines
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contribution Guidelines',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildGuidelineItem(
                    'Code of Conduct',
                    'Please read our code of conduct before contributing',
                    Icons.gavel,
                  ),
                  _buildGuidelineItem(
                    'Issue Templates',
                    'Use provided templates when reporting bugs or requesting features',
                    Icons.bug_report,
                  ),
                  _buildGuidelineItem(
                    'Pull Request Process',
                    'Follow our PR guidelines for faster review and approval',
                    Icons.merge_type,
                  ),
                  _buildGuidelineItem(
                    'Documentation',
                    'All new features must include appropriate documentation',
                    Icons.description,
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
          // Recent Public Activity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Public Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActivityItem(
                    Icons.description,
                    'Updated installation guide in documentation',
                    '2 hours ago',
                    'devguard-docs',
                    Colors.blue,
                  ),
                  _buildActivityItem(
                    Icons.add_circle,
                    'Added new plugin example for custom integrations',
                    '1 day ago',
                    'devguard-plugins',
                    Colors.green,
                  ),
                  _buildActivityItem(
                    Icons.bug_report,
                    'Fixed typo in configuration example',
                    '2 days ago',
                    'devguard-examples',
                    Colors.orange,
                  ),
                  _buildActivityItem(
                    Icons.update,
                    'Updated README with latest features',
                    '3 days ago',
                    'devguard-docs',
                    Colors.purple,
                  ),
                  _buildActivityItem(
                    Icons.star,
                    'Released v1.2.0 with new security features',
                    '1 week ago',
                    'devguard-ai-copilot',
                    Colors.amber,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Community Stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCommunityStatCard(
                            'Stars', '1.2k', Icons.star, Colors.amber),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCommunityStatCard(
                            'Forks', '234', Icons.fork_right, Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCommunityStatCard(
                            'Issues', '12', Icons.bug_report, Colors.red),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCommunityStatCard(
                            'PRs', '8', Icons.merge_type, Colors.green),
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

  // Helper methods for building UI components
  Widget _buildInfoChip(String label, Color color) {
    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontSize: 12),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
      String title, String date, IconData icon, Color color) {
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
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicRepoItem(String name, String description, String tech,
      String commits, String contributors, bool isPublic) {
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
            isPublic ? Icons.public : Icons.lock,
            color: isPublic ? Colors.green : Colors.grey,
            size: 24,
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
                      '• $commits',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $contributors',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isPublic)
            ElevatedButton(
              onPressed: () {
                // View repository
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 30),
              ),
              child: const Text('View', style: TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String description, String time,
      String repo, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                ),
                Row(
                  children: [
                    Text(
                      repo,
                      style:
                          TextStyle(fontSize: 11, color: Colors.teal.shade700),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $time',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
