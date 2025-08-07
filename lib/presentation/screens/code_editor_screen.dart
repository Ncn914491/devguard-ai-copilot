import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/terminal_panel.dart';
import '../widgets/file_explorer.dart';
import '../widgets/code_editor_widget.dart';
import '../screens/file_management_screen.dart';
import '../../core/auth/auth_service.dart';
import '../../core/gitops/git_integration.dart';
import '../../core/services/supabase_file_system_service.dart';

/// Code editor screen with integrated terminal and file explorer
/// Provides syntax highlighting and AI-assisted code suggestions
class CodeEditorScreen extends StatefulWidget {
  const CodeEditorScreen({super.key});

  @override
  State<CodeEditorScreen> createState() => _CodeEditorScreenState();
}

class _CodeEditorScreenState extends State<CodeEditorScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _bottomTabController;

  final List<EditorTab> _openTabs = [];
  final _authService = AuthService.instance;
  final _gitIntegration = GitIntegration.instance;

  bool _isTerminalVisible = true;
  bool _isFileExplorerVisible = true;
  double _terminalHeight = 200.0;
  double _fileExplorerWidth = 250.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _bottomTabController = TabController(length: 3, vsync: this);
    _initializeEditor();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bottomTabController.dispose();
    super.dispose();
  }

  Future<void> _initializeEditor() async {
    // Check permissions
    if (!_authService.hasPermission('commit_code')) {
      _showPermissionError();
      return;
    }

    // Load recent files or create welcome tab
    if (_openTabs.isEmpty) {
      _openWelcomeTab();
    }
  }

  void _showPermissionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You do not have permission to access the code editor'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _openWelcomeTab() {
    final welcomeTab = EditorTab(
      id: 'welcome',
      title: 'Welcome',
      filePath: null,
      content: _getWelcomeContent(),
      language: 'markdown',
      isModified: false,
    );

    setState(() {
      _openTabs.add(welcomeTab);
      _tabController = TabController(length: _openTabs.length, vsync: this);
    });
  }

  String _getWelcomeContent() {
    final user = _authService.currentUser;
    return '''# Welcome to DevGuard AI Code Editor

Hello ${user?.name ?? 'Developer'}!

## Your Role: ${user?.role ?? 'Unknown'}

### Available Features:
${_authService.hasPermission('commit_code') ? '✅ Code editing and commits' : '❌ Code editing (no permission)'}
${_authService.hasPermission('create_pull_requests') ? '✅ Create pull requests' : '❌ Create pull requests (no permission)'}
${_authService.hasPermission('review_code') ? '✅ Code review' : '❌ Code review (no permission)'}
${_authService.hasPermission('manage_repositories') ? '✅ Repository management' : '❌ Repository management (no permission)'}

### Quick Start:
1. Use Ctrl+O to open a file
2. Use Ctrl+N to create a new file
3. Use Ctrl+S to save changes
4. Use Ctrl+` to toggle terminal
5. Use F1 for command palette

### AI Assistant:
- Type `//AI:` followed by your request for AI suggestions
- Use Ctrl+Space for code completion
- Use Ctrl+Shift+P for AI-powered refactoring

Happy coding! 🚀
''';
  }

  void _openFile(String filePath) {
    // Check if file is already open
    final existingTabIndex =
        _openTabs.indexWhere((tab) => tab.filePath == filePath);
    if (existingTabIndex != -1) {
      _tabController.animateTo(existingTabIndex);
      return;
    }

    // Create new tab
    final newTab = EditorTab(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: filePath.split('/').last,
      filePath: filePath,
      content: _loadFileContent(filePath),
      language: _detectLanguage(filePath),
      isModified: false,
    );

    setState(() {
      _openTabs.add(newTab);
      _tabController = TabController(
        length: _openTabs.length,
        vsync: this,
        initialIndex: _openTabs.length - 1,
      );
    });
  }

  String _loadFileContent(String filePath) {
    // In a real implementation, this would load file from filesystem
    // For demo purposes, return sample content based on file type
    final extension = filePath.split('.').last.toLowerCase();

    switch (extension) {
      case 'dart':
        return '''import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text('Hello, World!'),
    );
  }
}''';
      case 'js':
        return '''function greet(name) {
  return `Hello, \${name}!`;
}

const message = greet('World');
console.log(message);''';
      case 'py':
        return '''def greet(name):
    return f"Hello, {name}!"

if __name__ == "__main__":
    message = greet("World")
    print(message)''';
      case 'json':
        return '''{
  "name": "DevGuard AI Copilot",
  "version": "1.0.0",
  "description": "AI-powered development security and productivity copilot"
}''';
      default:
        return '// File content would be loaded here\n// File: $filePath';
    }
  }

  String _detectLanguage(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();

    switch (extension) {
      case 'dart':
        return 'dart';
      case 'js':
      case 'jsx':
        return 'javascript';
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'py':
        return 'python';
      case 'java':
        return 'java';
      case 'cpp':
      case 'cc':
      case 'cxx':
        return 'cpp';
      case 'c':
        return 'c';
      case 'cs':
        return 'csharp';
      case 'go':
        return 'go';
      case 'rs':
        return 'rust';
      case 'php':
        return 'php';
      case 'rb':
        return 'ruby';
      case 'swift':
        return 'swift';
      case 'kt':
        return 'kotlin';
      case 'html':
        return 'html';
      case 'css':
        return 'css';
      case 'scss':
        return 'scss';
      case 'json':
        return 'json';
      case 'xml':
        return 'xml';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'md':
        return 'markdown';
      case 'sql':
        return 'sql';
      case 'sh':
        return 'bash';
      default:
        return 'text';
    }
  }

  void _closeTab(int index) {
    if (_openTabs[index].isModified) {
      _showUnsavedChangesDialog(index);
      return;
    }

    setState(() {
      _openTabs.removeAt(index);
      if (_openTabs.isEmpty) {
        _openWelcomeTab();
      } else {
        _tabController = TabController(
          length: _openTabs.length,
          vsync: this,
          initialIndex: index > 0 ? index - 1 : 0,
        );
      }
    });
  }

  void _showUnsavedChangesDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content:
            Text('Do you want to save changes to ${_openTabs[index].title}?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _openTabs.removeAt(index);
                if (_openTabs.isEmpty) {
                  _openWelcomeTab();
                } else {
                  _tabController = TabController(
                    length: _openTabs.length,
                    vsync: this,
                    initialIndex: index > 0 ? index - 1 : 0,
                  );
                }
              });
            },
            child: const Text('Don\'t Save'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveFile(index);
              setState(() {
                _openTabs.removeAt(index);
                if (_openTabs.isEmpty) {
                  _openWelcomeTab();
                } else {
                  _tabController = TabController(
                    length: _openTabs.length,
                    vsync: this,
                    initialIndex: index > 0 ? index - 1 : 0,
                  );
                }
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _saveFile(int index) {
    // In a real implementation, this would save to filesystem
    setState(() {
      _openTabs[index] = _openTabs[index].copyWith(isModified: false);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${_openTabs[index].title}')),
    );
  }

  void _onContentChanged(int index, String content) {
    setState(() {
      _openTabs[index] = _openTabs[index].copyWith(
        content: content,
        isModified: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Menu bar
          _buildMenuBar(),

          // Main editor area
          Expanded(
            child: Row(
              children: [
                // File explorer
                if (_isFileExplorerVisible)
                  SizedBox(
                    width: _fileExplorerWidth,
                    child: FileExplorer(
                      onFileSelected: _openFile,
                      onFileCreated: (path) => _openFile(path),
                    ),
                  ),

                // Resize handle for file explorer
                if (_isFileExplorerVisible)
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _fileExplorerWidth += details.delta.dx;
                        _fileExplorerWidth =
                            _fileExplorerWidth.clamp(200.0, 400.0);
                      });
                    },
                    child: Container(
                      width: 4,
                      color: Theme.of(context).dividerColor,
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),

                // Editor tabs and content
                Expanded(
                  child: Column(
                    children: [
                      // Tab bar
                      if (_openTabs.isNotEmpty)
                        Container(
                          height: 40,
                          color: Theme.of(context).cardColor,
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabs: _openTabs.asMap().entries.map((entry) {
                              final index = entry.key;
                              final tab = entry.value;
                              return Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (tab.isModified)
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Text(tab.title),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => _closeTab(index),
                                      child: const Icon(Icons.close, size: 16),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // Editor content
                      Expanded(
                        child: _openTabs.isEmpty
                            ? const Center(child: Text('No files open'))
                            : TabBarView(
                                controller: _tabController,
                                children:
                                    _openTabs.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final tab = entry.value;
                                  return CodeEditorWidget(
                                    content: tab.content,
                                    language: tab.language,
                                    onChanged: (content) =>
                                        _onContentChanged(index, content),
                                    readOnly: !_authService
                                        .hasPermission('commit_code'),
                                  );
                                }).toList(),
                              ),
                      ),

                      // Bottom panel (terminal, problems, etc.)
                      if (_isTerminalVisible)
                        GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _terminalHeight -= details.delta.dy;
                              _terminalHeight =
                                  _terminalHeight.clamp(100.0, 400.0);
                            });
                          },
                          child: Container(
                            height: 4,
                            color: Theme.of(context).dividerColor,
                            child: const MouseRegion(
                              cursor: SystemMouseCursors.resizeRow,
                              child: SizedBox.expand(),
                            ),
                          ),
                        ),

                      if (_isTerminalVisible)
                        SizedBox(
                          height: _terminalHeight,
                          child: Column(
                            children: [
                              // Bottom tab bar
                              Container(
                                height: 30,
                                color: Theme.of(context).cardColor,
                                child: TabBar(
                                  controller: _bottomTabController,
                                  tabs: const [
                                    Tab(text: 'Terminal'),
                                    Tab(text: 'Problems'),
                                    Tab(text: 'Output'),
                                  ],
                                ),
                              ),

                              // Bottom tab content
                              Expanded(
                                child: TabBarView(
                                  controller: _bottomTabController,
                                  children: [
                                    TerminalPanel(
                                      onCommand: _handleTerminalCommand,
                                    ),
                                    _buildProblemsPanel(),
                                    _buildOutputPanel(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuBar() {
    return Container(
      height: 30,
      color: Theme.of(context).primaryColor,
      child: Row(
        children: [
          _buildMenuButton('File', [
            MenuAction('New File', Icons.add, () => _createNewFile()),
            MenuAction('Open File', Icons.folder_open, () => _openFileDialog()),
            MenuAction('File Manager', Icons.cloud, () => _openFileManager()),
            MenuAction('Save', Icons.save, () => _saveCurrentFile()),
            MenuAction('Save All', Icons.save_alt, () => _saveAllFiles()),
          ]),
          _buildMenuButton('Edit', [
            MenuAction('Undo', Icons.undo, () => _undo()),
            MenuAction('Redo', Icons.redo, () => _redo()),
            MenuAction('Find', Icons.search, () => _showFindDialog()),
            MenuAction(
                'Replace', Icons.find_replace, () => _showReplaceDialog()),
          ]),
          _buildMenuButton('View', [
            MenuAction(
              _isFileExplorerVisible ? 'Hide Explorer' : 'Show Explorer',
              Icons.folder,
              () => setState(
                  () => _isFileExplorerVisible = !_isFileExplorerVisible),
            ),
            MenuAction(
              _isTerminalVisible ? 'Hide Terminal' : 'Show Terminal',
              Icons.terminal,
              () => setState(() => _isTerminalVisible = !_isTerminalVisible),
            ),
          ]),
          _buildMenuButton('Git', [
            MenuAction('Commit', Icons.commit, () => _showCommitDialog()),
            MenuAction('Push', Icons.cloud_upload, () => _gitPush()),
            MenuAction('Pull', Icons.cloud_download, () => _gitPull()),
            MenuAction('Branch', Icons.account_tree, () => _showBranchDialog()),
          ]),
          const Spacer(),
          Text(
            'DevGuard Code Editor - ${_authService.currentUser?.name ?? 'Unknown User'}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildMenuButton(String title, List<MenuAction> actions) {
    return PopupMenuButton<MenuAction>(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      itemBuilder: (context) => actions.map((action) {
        return PopupMenuItem<MenuAction>(
          value: action,
          child: Row(
            children: [
              Icon(action.icon, size: 16),
              const SizedBox(width: 8),
              Text(action.title),
            ],
          ),
        );
      }).toList(),
      onSelected: (action) => action.onTap(),
    );
  }

  Widget _buildProblemsPanel() {
    return Container(
      color: Theme.of(context).cardColor,
      child: const Center(
        child: Text('No problems detected'),
      ),
    );
  }

  Widget _buildOutputPanel() {
    return Container(
      color: Theme.of(context).cardColor,
      child: const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
            'Output panel - compilation results and logs will appear here'),
      ),
    );
  }

  void _createNewFile() {
    // Implementation for creating new file
  }

  void _openFileManager() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FileManagementScreen(),
      ),
    );
  }

  void _openFileDialog() {
    // Implementation for opening file dialog
  }

  void _saveCurrentFile() {
    if (_tabController.index < _openTabs.length) {
      _saveFile(_tabController.index);
    }
  }

  void _saveAllFiles() {
    for (int i = 0; i < _openTabs.length; i++) {
      if (_openTabs[i].isModified) {
        _saveFile(i);
      }
    }
  }

  void _undo() {
    // Implementation for undo
  }

  void _redo() {
    // Implementation for redo
  }

  void _showFindDialog() {
    // Implementation for find dialog
  }

  void _showReplaceDialog() {
    // Implementation for replace dialog
  }

  void _showCommitDialog() {
    // Implementation for commit dialog
  }

  void _gitPush() {
    // Implementation for git push
  }

  void _gitPull() {
    // Implementation for git pull
  }

  void _showBranchDialog() {
    // Implementation for branch dialog
  }

  Future<void> _handleTerminalCommand(String command) async {
    // Handle terminal commands with git integration
    if (command.startsWith('git ')) {
      await _handleGitCommand(command);
    }
  }

  Future<void> _handleGitCommand(String command) async {
    // Integration with git service
    try {
      // This would execute actual git commands
      print('Executing git command: $command');
    } catch (e) {
      print('Git command failed: $e');
    }
  }
}

/// Editor tab model
class EditorTab {
  final String id;
  final String title;
  final String? filePath;
  final String content;
  final String language;
  final bool isModified;

  EditorTab({
    required this.id,
    required this.title,
    required this.filePath,
    required this.content,
    required this.language,
    required this.isModified,
  });

  EditorTab copyWith({
    String? title,
    String? filePath,
    String? content,
    String? language,
    bool? isModified,
  }) {
    return EditorTab(
      id: id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      content: content ?? this.content,
      language: language ?? this.language,
      isModified: isModified ?? this.isModified,
    );
  }
}

/// Menu action model
class MenuAction {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  MenuAction(this.title, this.icon, this.onTap);
}
