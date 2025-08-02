import 'package:flutter/material.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevGuard AI Copilot Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TestHomeScreen(),
    );
  }
}

class TestHomeScreen extends StatelessWidget {
  const TestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DevGuard AI Copilot'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 800;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(isCompact ? 16.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Overview Cards - responsive grid
                if (isCompact)
                  Column(
                    children: [
                      _buildOverviewCard(context, 'Deployments', '3', 'Active deployments', Colors.blue, Icons.rocket_launch),
                      const SizedBox(height: 16),
                      _buildOverviewCard(context, 'Security', '0', 'Active alerts', Colors.green, Icons.shield),
                      const SizedBox(height: 16),
                      _buildOverviewCard(context, 'Team', '5', 'Active members', Colors.purple, Icons.people),
                      const SizedBox(height: 16),
                      _buildOverviewCard(context, 'Specs', '12', 'Total specifications', Colors.orange, Icons.description),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: _buildOverviewCard(context, 'Deployments', '3', 'Active deployments', Colors.blue, Icons.rocket_launch)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildOverviewCard(context, 'Security', '0', 'Active alerts', Colors.green, Icons.shield)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildOverviewCard(context, 'Team', '5', 'Active members', Colors.purple, Icons.people)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildOverviewCard(context, 'Specs', '12', 'Total specifications', Colors.orange, Icons.description)),
                    ],
                  ),
                
                const SizedBox(height: 32),
                
                // Activity Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Activity',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.code, color: Colors.white),
                          ),
                          title: Text('New specification created'),
                          subtitle: Text('User authentication feature'),
                          trailing: Text('2 hours ago'),
                        ),
                        const Divider(),
                        const ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.check, color: Colors.white),
                          ),
                          title: Text('Deployment successful'),
                          subtitle: Text('Production environment'),
                          trailing: Text('4 hours ago'),
                        ),
                        const Divider(),
                        const ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.security, color: Colors.white),
                          ),
                          title: Text('Security scan completed'),
                          subtitle: Text('No vulnerabilities found'),
                          trailing: Text('6 hours ago'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, String title, String value, String subtitle, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}