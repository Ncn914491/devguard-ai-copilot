import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/utils/responsive_utils.dart';
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
import 'file_management_screen.dart';

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
    return ResponsiveWidget(
      mobile: _buildMobileLayout(context),
      tablet: _buildTabletLayout(context),
      desktop: _buildDesktopLayout(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      key: const Key('main_scaffold_mobile'),
      appBar: AppBar(
        title: const Text('DevGuard AI Copilot'),
        actions: [
          IconButton(
            icon: Icon(_isCopilotExpanded ? Icons.close : Icons.assistant),
            onPressed: () {
              setState(() {
                _isCopilotExpanded = !_isCopilotExpanded;
              });
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: LeftSidebar(
          isCollapsed: false,
          onNavigate: (screen) {
            context.read<AppStateProvider>().setCurrentScreen(screen);
            Navigator.of(context).pop(); // Close drawer
          },
        ),
      ),
      body: Stack(
        children: [
          Consumer<AppStateProvider>(
            builder: (context, appState, child) {
              return _buildMainContent(appState.currentScreen);
            },
          ),
          if (_isCopilotExpanded)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.85,
              child: CopilotSidebar(
                isExpanded: true,
                onToggle: () {
                  setState(() {
                    _isCopilotExpanded = false;
                  });
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      key: const Key('main_scaffold_tablet'),
      body: Column(
        children: [
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
          Expanded(
            child: Row(
              children: [
                LeftSidebar(
                  isCollapsed: _isLeftSidebarCollapsed,
                  onNavigate: (screen) {
                    context.read<AppStateProvider>().setCurrentScreen(screen);
                  },
                ),
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
                if (_isCopilotExpanded)
                  SizedBox(
                    width: 350,
                    child: CopilotSidebar(
                      isExpanded: true,
                      onToggle: () {
                        setState(() {
                          _isCopilotExpanded = false;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      key: const Key('main_scaffold_desktop'),
      body: Column(
        children: [
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
          Expanded(
            child: Row(
              children: [
                LeftSidebar(
                  isCollapsed: _isLeftSidebarCollapsed,
                  onNavigate: (screen) {
                    context.read<AppStateProvider>().setCurrentScreen(screen);
                  },
                ),
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

  Widget _buildBottomNavigation(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _getBottomNavIndex(appState.currentScreen),
          onTap: (index) {
            final screens = [
              'home',
              'workflow',
              'security',
              'team',
              'deployments'
            ];
            if (index < screens.length) {
              appState.setCurrentScreen(screens[index]);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.work),
              label: 'Workflow',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.security),
              label: 'Security',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group),
              label: 'Team',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.rocket_launch),
              label: 'Deploy',
            ),
          ],
        );
      },
    );
  }

  int _getBottomNavIndex(String currentScreen) {
    switch (currentScreen) {
      case 'home':
        return 0;
      case 'workflow':
        return 1;
      case 'security':
        return 2;
      case 'team':
        return 3;
      case 'deployments':
        return 4;
      case 'files':
        return 5;
      default:
        return 0;
    }
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
      case 'files':
        return const FileManagementScreen();
      case 'audit':
        return const AuditScreen();
      case 'settings':
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }
}
