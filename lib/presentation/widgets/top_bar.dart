import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/providers/app_state_provider.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Menu button to toggle left sidebar
            Consumer<AppStateProvider>(
              builder: (context, appState, _) {
                return IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => appState.toggleLeftSidebar(),
                  tooltip: 'Toggle sidebar',
                );
              },
            ),
            
            const SizedBox(width: 8),
            
            // App Name
            Text(
              'DevGuard AI Copilot',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            
            const Spacer(),
            
            // Project Selector (placeholder)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Current Project',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Status Indicators
            Row(
              children: [
                _StatusIndicator(
                  icon: Icons.security,
                  color: Colors.green,
                  tooltip: 'Security: Normal',
                ),
                const SizedBox(width: 8),
                _StatusIndicator(
                  icon: Icons.cloud_done,
                  color: Colors.blue,
                  tooltip: 'Deployment: Ready',
                ),
              ],
            ),
            
            const SizedBox(width: 16),
            
            // Theme Toggle
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return IconButton(
                  icon: Icon(
                    themeProvider.isDarkMode 
                        ? Icons.light_mode 
                        : Icons.dark_mode,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                  tooltip: 'Toggle theme',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  
  const _StatusIndicator({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}