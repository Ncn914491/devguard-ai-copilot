import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_state_provider.dart';
import '../widgets/top_bar.dart';
import '../widgets/left_sidebar.dart';
import '../widgets/copilot_sidebar.dart';
import 'home_screen.dart';
import 'workflow_screen.dart';
// import 'security_screen.dart';
import 'team_screen.dart';
import 'deployments_screen.dart';
import 'audit_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isLeftSidebarCollapsed = false;
  bool _isCopilotExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('main_scaffold'),
      body: Column(
        children: [
          // Top Bar
          TopBar(
            onMenuPressed: () {
              setState(() {
                _isLeftSidebarCollapsed = !_isLeftSidebarCollapsed;
              });
            },
            onCopilotPressed: () {
              setState(() {
                _isCopilotExpanded = !_isCopilotExpanded;
              });
            },
            isCopilotExpanded: _isCopilotExpanded,
          ),
          
          // Main Content Area
          Expanded(
            child: Row(
              children: [
                // Left Sidebar
                LeftSidebar(
                  isCollapsed: _isLeftSidebarCollapsed,
                  onNavigate: (screen) {
                    context.read<AppStateProvider>().setCurrentScreen(screen);
                  },
                ),
                
                // Main Canvas
                Expanded(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: Consumer<AppStateProvider>(
                      builder: (context, appState, child) {
                        return _buildMainContent(appState.currentScreen);
                      },
                    ),
                  ),
                ),
                
                // Right Sidebar (Copilot)
                CopilotSidebar(
                  isExpanded: _isCopilotExpanded,
                  onToggle: () {
                    setState(() {
                      _isCopilotExpanded = !_isCopilotExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(String currentScreen) {
    switch (currentScreen) {
      case 'home':
        return const HomeScreen();
      case 'workflow':
        return const WorkflowScreen();
      case 'security':
        return const Center(child: Text('Security Screen - Coming Soon'));
      case 'team':
        return const TeamScreen();
      case 'deployments':
        return const DeploymentsScreen();
      case 'audit':
        return const AuditScreen();
      case 'settings':
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }
}