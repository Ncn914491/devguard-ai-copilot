import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure your DevGuard AI Copilot preferences',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),

          const SizedBox(height: 32),

          // Settings Sections
          Expanded(
            child: ListView(
              children: [
                // Appearance Section
                _SettingsSection(
                  title: 'Appearance',
                  children: [
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return _SettingsTile(
                          title: 'Theme',
                          subtitle:
                              _getThemeDescription(themeProvider.themeMode),
                          trailing: DropdownButton<ThemeMode>(
                            value: themeProvider.themeMode,
                            onChanged: (ThemeMode? mode) {
                              if (mode != null) {
                                themeProvider.setThemeMode(mode);
                              }
                            },
                            items: const [
                              DropdownMenuItem(
                                value: ThemeMode.system,
                                child: Text('System'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.light,
                                child: Text('Light'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.dark,
                                child: Text('Dark'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Security Section
                _SettingsSection(
                  title: 'Security',
                  children: [
                    _SettingsTile(
                      title: 'Database Monitoring',
                      subtitle: 'Enable honeytoken deployment and monitoring',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {
                          // TODO: Implement toggle
                        },
                      ),
                    ),
                    _SettingsTile(
                      title: 'Configuration Monitoring',
                      subtitle: 'Monitor configuration file changes',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {
                          // TODO: Implement toggle
                        },
                      ),
                    ),
                    _SettingsTile(
                      title: 'Authentication Monitoring',
                      subtitle: 'Monitor login attempts and anomalies',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {
                          // TODO: Implement toggle
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // AI Copilot Section
                _SettingsSection(
                  title: 'AI Copilot',
                  children: [
                    _SettingsTile(
                      title: 'Auto-expand on alerts',
                      subtitle:
                          'Automatically expand copilot when security alerts occur',
                      trailing: Switch(
                        value: false,
                        onChanged: (value) {
                          // TODO: Implement toggle
                        },
                      ),
                    ),
                    _SettingsTile(
                      title: 'Quick commands',
                      subtitle:
                          'Enable /rollback, /summarize, and other quick commands',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {
                          // TODO: Implement toggle
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // About Section
                const _SettingsSection(
                  title: 'About',
                  children: [
                    _SettingsTile(
                      title: 'Version',
                      subtitle: '1.0.0',
                      trailing: SizedBox.shrink(),
                    ),
                    _SettingsTile(
                      title: 'Database Location',
                      subtitle: 'Local SQLite database',
                      trailing: SizedBox.shrink(),
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

  String _getThemeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow system theme';
      case ThemeMode.light:
        return 'Light theme';
      case ThemeMode.dark:
        return 'Dark theme';
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
