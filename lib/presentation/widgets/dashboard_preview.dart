import 'package:flutter/material.dart';

/// Dashboard preview widget showing different role-based interfaces
class DashboardPreview extends StatefulWidget {
  const DashboardPreview({super.key});

  @override
  State<DashboardPreview> createState() => _DashboardPreviewState();
}

class _DashboardPreviewState extends State<DashboardPreview>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _rolePreviews = [
    {
      'role': 'Admin',
      'icon': Icons.admin_panel_settings,
      'color': Colors.red,
      'features': [
        'User Management',
        'Repository Control',
        'System Settings',
        'Join Request Approvals',
        'Deployment Management',
      ],
    },
    {
      'role': 'Lead Developer',
      'icon': Icons.engineering,
      'color': Colors.orange,
      'features': [
        'Team Task Management',
        'Code Review Queues',
        'Branch Management',
        'Deployment Oversight',
        'Developer Assignments',
      ],
    },
    {
      'role': 'Developer',
      'icon': Icons.code,
      'color': Colors.blue,
      'features': [
        'Code Editor',
        'Git Operations',
        'Assigned Tasks',
        'Terminal Access',
        'AI Assistance',
      ],
    },
    {
      'role': 'Viewer',
      'icon': Icons.visibility,
      'color': Colors.green,
      'features': [
        'Project Overview',
        'Read-only Dashboards',
        'Public Repositories',
        'Progress Tracking',
        'Documentation Access',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _rolePreviews.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });

    // Auto-cycle through previews
    _startAutoCycle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startAutoCycle() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        final nextIndex = (_currentIndex + 1) % _rolePreviews.length;
        _tabController.animateTo(nextIndex);
        _startAutoCycle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Role-Based Dashboards',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Each role gets a customized interface with appropriate tools and permissions',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Role tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            indicator: BoxDecoration(
              color: _rolePreviews[_currentIndex]['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: _rolePreviews[_currentIndex]['color'],
            unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
            tabs: _rolePreviews.map((role) {
              return Tab(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(role['icon'], size: 20),
                    const SizedBox(height: 4),
                    Text(
                      role['role'],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        // Preview content
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(24),
            child: TabBarView(
              controller: _tabController,
              children: _rolePreviews.map((role) => _buildRolePreview(role)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRolePreview(Map<String, dynamic> role) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: role['color'].withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: role['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  role['icon'],
                  color: role['color'],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${role['role']} Dashboard',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: role['color'],
                      ),
                    ),
                    Text(
                      'Customized interface for ${role['role'].toLowerCase()} role',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Features list
          Text(
            'Key Features:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              itemCount: role['features'].length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: role['color'].withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: role['color'].withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: role['color'].withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.check,
                          color: role['color'],
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          role['features'][index],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Mock dashboard elements
          const SizedBox(height: 16),
          _buildMockDashboardElements(role),
        ],
      ),
    );
  }

  Widget _buildMockDashboardElements(Map<String, dynamic> role) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: role['color'].withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: role['color'].withOpacity(0.1),
        ),
      ),
      child: Stack(
        children: [
          // Mock interface elements
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                color: role['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 8,
            width: 100,
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: role['color'].withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 8,
            width: 60,
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: role['color'].withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: role['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: role['color'].withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: role['color'].withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Overlay text
          Center(
            child: Text(
              'Interactive ${role['role']} Interface',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: role['color'].withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}