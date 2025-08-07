import 'package:flutter/material.dart';

class LeftSidebar extends StatefulWidget {
  final bool isCollapsed;
  final Function(String) onNavigate;

  const LeftSidebar({
    super.key,
    required this.isCollapsed,
    required this.onNavigate,
  });

  @override
  State<LeftSidebar> createState() => _LeftSidebarState();
}

class _LeftSidebarState extends State<LeftSidebar> {
  String _selectedItem = 'home';

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      id: 'home',
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    NavigationItem(
      id: 'workflow',
      label: 'Workflow',
      icon: Icons.alt_route_outlined,
      selectedIcon: Icons.alt_route,
    ),
    NavigationItem(
      id: 'security',
      label: 'Security',
      icon: Icons.security_outlined,
      selectedIcon: Icons.security,
    ),
    NavigationItem(
      id: 'team',
      label: 'Team',
      icon: Icons.people_outlined,
      selectedIcon: Icons.people,
    ),
    NavigationItem(
      id: 'deployments',
      label: 'Deployments',
      icon: Icons.rocket_launch_outlined,
      selectedIcon: Icons.rocket_launch,
    ),
    NavigationItem(
      id: 'files',
      label: 'Files',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
    ),
    NavigationItem(
      id: 'audit',
      label: 'Audit Log',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
    ),
  ];

  final List<NavigationItem> _bottomItems = [
    NavigationItem(
      id: 'settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: widget.isCollapsed ? 72 : 240,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ..._navigationItems.map((item) => _buildNavigationItem(item)),
              ],
            ),
          ),

          // Bottom Items
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                ..._bottomItems.map((item) => _buildNavigationItem(item)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(NavigationItem item) {
    final isSelected = _selectedItem == item.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNavigation(item.id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  size: 20,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                ),
                if (!widget.isCollapsed) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.8),
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                    ),
                  ),
                ],
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNavigation(String itemId) {
    setState(() {
      _selectedItem = itemId;
    });
    widget.onNavigate(itemId);
  }
}

class NavigationItem {
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  NavigationItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
