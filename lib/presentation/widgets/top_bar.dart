import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/auth/auth_service.dart';
import 'realtime_notification_widget.dart';
import 'realtime_status_indicator.dart';

class TopBar extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onCopilotPressed;
  final bool isCopilotExpanded;

  const TopBar({
    super.key,
    required this.onMenuPressed,
    required this.onCopilotPressed,
    required this.isCopilotExpanded,
  });

  final _authService = AuthService.instance;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Menu Button
            IconButton(
              onPressed: onMenuPressed,
              icon: const Icon(Icons.menu),
              tooltip: 'Toggle Navigation',
            ),

            const SizedBox(width: 16),

            // App Title and Status
            Expanded(
              child: Row(
                children: [
                  // App Icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.security,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Title
                  Text(
                    'DevGuard AI Copilot',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),

                  const SizedBox(width: 16),

                  // Real-time Status Indicator
                  const RealtimeStatusIndicator(),
                ],
              ),
            ),

            // Search Bar
            Container(
              width: 300,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search specifications, tasks, alerts...',
                  hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

            const SizedBox(width: 16),

            // Action Buttons
            Row(
              children: [
                // Real-time Notifications
                RealtimeNotificationWidget(
                  userId: _authService.currentUser?.id ?? '',
                  userRole: _authService.currentUser?.role ?? 'viewer',
                ),

                const SizedBox(width: 8),

                // Theme Toggle
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return IconButton(
                      onPressed: themeProvider.toggleTheme,
                      icon: Icon(
                        themeProvider.isDarkMode
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                      tooltip: themeProvider.isDarkMode
                          ? 'Switch to Light Mode'
                          : 'Switch to Dark Mode',
                    );
                  },
                ),

                const SizedBox(width: 8),

                // Settings
                IconButton(
                  onPressed: () => _showSettings(context),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                ),

                const SizedBox(width: 16),

                // Copilot Toggle
                Container(
                  decoration: BoxDecoration(
                    color: isCopilotExpanded
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: onCopilotPressed,
                    icon: Icon(
                      Icons.smart_toy_outlined,
                      color: isCopilotExpanded
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    tooltip: isCopilotExpanded
                        ? 'Collapse AI Copilot'
                        : 'Expand AI Copilot',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Online',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: const SizedBox(
          width: 400,
          height: 300,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.security, color: Colors.red),
                title: Text('Security Alert'),
                subtitle: Text('Honeytoken accessed in database'),
                trailing: Text('2m ago'),
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Deployment Complete'),
                subtitle: Text('Production deployment successful'),
                trailing: Text('5m ago'),
              ),
              ListTile(
                leading: Icon(Icons.person_add, color: Colors.blue),
                title: Text('Team Member Added'),
                subtitle: Text('John Doe joined the team'),
                trailing: Text('1h ago'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to notifications screen
            },
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Settings'),
        content: const SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.api),
                title: Text('API Configuration'),
                subtitle: Text('Configure Gemini API key'),
              ),
              ListTile(
                leading: Icon(Icons.security),
                title: Text('Security Settings'),
                subtitle: Text('Manage security monitoring'),
              ),
              ListTile(
                leading: Icon(Icons.source),
                title: Text('Git Integration'),
                subtitle: Text('Configure repository settings'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to settings screen
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
