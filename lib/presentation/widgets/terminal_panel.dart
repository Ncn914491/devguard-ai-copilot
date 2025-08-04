import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/database/services/audit_log_service.dart';

/// Embedded terminal panel for git operations and system commands
class TerminalPanel extends StatefulWidget {
  final Function(String) onCommand;

  const TerminalPanel({
    super.key,
    required this.onCommand,
  });

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;

  final List<TerminalEntry> _history = [];
  final List<String> _commandHistory = [];
  int _historyIndex = -1;
  String _currentDirectory = '/workspace';

  @override
  void initState() {
    super.initState();
    _initializeTerminal();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initializeTerminal() {
    final user = _authService.currentUser;
    _addEntry(TerminalEntry(
      type: TerminalEntryType.system,
      content: 'DevGuard AI Terminal v1.0.0',
      timestamp: DateTime.now(),
    ));
    _addEntry(TerminalEntry(
      type: TerminalEntryType.system,
      content:
          'Welcome ${user?.name ?? 'User'}! You are logged in as ${user?.role ?? 'unknown'}.',
      timestamp: DateTime.now(),
    ));
    _addEntry(TerminalEntry(
      type: TerminalEntryType.system,
      content: 'Type "help" for available commands.',
      timestamp: DateTime.now(),
    ));
    _addEntry(TerminalEntry(
      type: TerminalEntryType.system,
      content: '',
      timestamp: DateTime.now(),
    ));
  }

  void _addEntry(TerminalEntry entry) {
    setState(() {
      _history.add(entry);
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _executeCommand(String command) {
    if (command.trim().isEmpty) return;

    // Add command to history
    _commandHistory.add(command);
    _historyIndex = -1;

    // Add command entry
    _addEntry(TerminalEntry(
      type: TerminalEntryType.command,
      content: '$_currentDirectory\$ $command',
      timestamp: DateTime.now(),
    ));

    // Process command
    _processCommand(command.trim());

    // Clear input
    _inputController.clear();
  }

  void _processCommand(String command) {
    final parts = command.split(' ');
    final cmd = parts[0].toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];

    switch (cmd) {
      case 'help':
        _showHelp();
        break;
      case 'clear':
        _clearTerminal();
        break;
      case 'pwd':
        _showCurrentDirectory();
        break;
      case 'ls':
        _listFiles(args);
        break;
      case 'cd':
        _changeDirectory(args);
        break;
      case 'git':
        _handleGitCommand(args);
        break;
      case 'npm':
        _handleNpmCommand(args);
        break;
      case 'flutter':
        _handleFlutterCommand(args);
        break;
      case 'docker':
        _handleDockerCommand(args);
        break;
      case 'whoami':
        _showCurrentUser();
        break;
      case 'history':
        _showCommandHistory();
        break;
      case 'echo':
        _echo(args);
        break;
      default:
        _addEntry(TerminalEntry(
          type: TerminalEntryType.error,
          content: 'Command not found: $cmd',
          timestamp: DateTime.now(),
        ));
    }

    // Notify parent about command execution
    widget.onCommand(command);
  }

  void _showHelp() {
    const helpText = '''Available commands:

System Commands:
  help          - Show this help message
  clear         - Clear terminal screen
  pwd           - Show current directory
  ls [path]     - List directory contents
  cd <path>     - Change directory
  whoami        - Show current user
  history       - Show command history
  echo <text>   - Display text

Git Commands:
  git status    - Show repository status
  git add <file>- Add file to staging
  git commit    - Commit changes
  git push      - Push to remote repository
  git pull      - Pull from remote repository
  git branch    - List branches
  git checkout  - Switch branches

Development Commands:
  npm install   - Install npm packages
  npm run <cmd> - Run npm script
  flutter run   - Run Flutter app
  flutter build - Build Flutter app
  docker build  - Build Docker image
  docker run    - Run Docker container

Note: Some commands require appropriate permissions based on your role.''';

    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: helpText,
      timestamp: DateTime.now(),
    ));
  }

  void _clearTerminal() {
    setState(() {
      _history.clear();
    });
    _initializeTerminal();
  }

  void _showCurrentDirectory() {
    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: _currentDirectory,
      timestamp: DateTime.now(),
    ));
  }

  void _listFiles(List<String> args) {
    // Simulate file listing
    final files = [
      'lib/',
      'test/',
      'pubspec.yaml',
      'README.md',
      '.gitignore',
      'analysis_options.yaml',
    ];

    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: files.join('  '),
      timestamp: DateTime.now(),
    ));
  }

  void _changeDirectory(List<String> args) {
    if (args.isEmpty) {
      _currentDirectory = '/workspace';
    } else {
      final path = args[0];
      if (path == '..') {
        final parts = _currentDirectory.split('/');
        if (parts.length > 2) {
          parts.removeLast();
          _currentDirectory = parts.join('/');
        }
      } else if (path.startsWith('/')) {
        _currentDirectory = path;
      } else {
        _currentDirectory = '$_currentDirectory/$path';
      }
    }

    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: 'Changed directory to $_currentDirectory',
      timestamp: DateTime.now(),
    ));
  }

  void _handleGitCommand(List<String> args) {
    if (!_authService.hasPermission('commit_code')) {
      _addEntry(TerminalEntry(
        type: TerminalEntryType.error,
        content: 'Permission denied: You do not have git access',
        timestamp: DateTime.now(),
      ));
      return;
    }

    if (args.isEmpty) {
      _addEntry(TerminalEntry(
        type: TerminalEntryType.error,
        content: 'Usage: git <command>',
        timestamp: DateTime.now(),
      ));
      return;
    }

    final gitCmd = args[0];
    switch (gitCmd) {
      case 'status':
        _gitStatus();
        break;
      case 'add':
        _gitAdd(args.length > 1 ? args.sublist(1) : []);
        break;
      case 'commit':
        _gitCommit(args.length > 1 ? args.sublist(1) : []);
        break;
      case 'push':
        _gitPush();
        break;
      case 'pull':
        _gitPull();
        break;
      case 'branch':
        _gitBranch();
        break;
      case 'checkout':
        _gitCheckout(args.length > 1 ? args.sublist(1) : []);
        break;
      default:
        _addEntry(TerminalEntry(
          type: TerminalEntryType.error,
          content: 'Unknown git command: $gitCmd',
          timestamp: DateTime.now(),
        ));
    }
  }

  void _gitStatus() {
    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: '''On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

        modified:   lib/main.dart
        modified:   lib/presentation/screens/code_editor_screen.dart

Untracked files:
  (use "git add <file>..." to include in what will be committed)

        lib/core/auth/auth_service.dart

no changes added to commit (use "git add" and/or "git commit -a")''',
      timestamp: DateTime.now(),
    ));

    // Log git status command
    _auditService.logAction(
      actionType: 'git_status_executed',
      description: 'Git status command executed in terminal',
      contextData: {
        'command': 'git status',
        'directory': _currentDirectory,
      },
      userId: _authService.currentUser?.id,
    );
  }

  void _gitAdd(List<String> files) {
    if (files.isEmpty) {
      _addEntry(TerminalEntry(
        type: TerminalEntryType.error,
        content: 'Nothing specified, nothing added.',
        timestamp: DateTime.now(),
      ));
      return;
    }

    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: 'Added ${files.join(", ")} to staging area',
      timestamp: DateTime.now(),
    ));

    // Log git add command with audit trail
    _auditService.logAction(
      actionType: 'git_add_executed',
      description: 'Files added to git staging area',
      contextData: {
        'command': 'git add ${files.join(" ")}',
        'files': files,
        'directory': _currentDirectory,
      },
      userId: _authService.currentUser?.id,
    );
  }

  void _gitCommit(List<String> args) {
    String message = 'Update files';

    // Parse commit message
    for (int i = 0; i < args.length; i++) {
      if (args[i] == '-m' && i + 1 < args.length) {
        message = args[i + 1];
        break;
      }
    }

    final commitHash =
        'abc${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: '''[main $commitHash] $message
 2 files changed, 15 insertions(+), 3 deletions(-)
 create mode 100644 lib/core/auth/auth_service.dart''',
      timestamp: DateTime.now(),
    ));

    // Log git commit with comprehensive audit trail
    _auditService.logAction(
      actionType: 'git_commit_executed',
      description: 'Git commit created via terminal',
      contextData: {
        'command': 'git commit ${args.join(" ")}',
        'commit_message': message,
        'commit_hash': commitHash,
        'directory': _currentDirectory,
        'files_changed': 2,
        'insertions': 15,
        'deletions': 3,
      },
      userId: _authService.currentUser?.id,
    );
  }

  void _gitPush() {
    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: '''Enumerating objects: 8, done.
Counting objects: 100% (8/8), done.
Delta compression using up to 8 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (5/5), 1.23 KiB | 1.23 MiB/s, done.
Total 5 (delta 2), reused 0 (delta 0), pack-reused 0
To https://github.com/devguard/ai-copilot.git
   def5678..abc1234  main -> main''',
      timestamp: DateTime.now(),
    ));

    // Log git push with security audit trail
    _auditService.logAction(
      actionType: 'git_push_executed',
      description: 'Code pushed to remote repository',
      contextData: {
        'command': 'git push',
        'remote_url': 'https://github.com/devguard/ai-copilot.git',
        'branch': 'main',
        'objects_pushed': 8,
        'bytes_transferred': '1.23 KiB',
        'directory': _currentDirectory,
      },
      userId: _authService.currentUser?.id,
      requiresApproval: true, // Push operations may require approval
    );
  }

  void _gitPull() {
    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: '''remote: Enumerating objects: 3, done.
remote: Counting objects: 100% (3/3), done.
remote: Total 3 (delta 0), reused 0 (delta 0), pack-reused 0
Unpacking objects: 100% (3/3), 1.05 KiB | 1.05 MiB/s, done.
From https://github.com/devguard/ai-copilot
   abc1234..ghi9012  main       -> origin/main
Updating abc1234..ghi9012
Fast-forward
 README.md | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)''',
      timestamp: DateTime.now(),
    ));

    // Log git pull with audit trail
    _auditService.logAction(
      actionType: 'git_pull_executed',
      description: 'Code pulled from remote repository',
      contextData: {
        'command': 'git pull',
        'remote_url': 'https://github.com/devguard/ai-copilot',
        'branch': 'main',
        'objects_received': 3,
        'bytes_received': '1.05 KiB',
        'files_changed': 1,
        'directory': _currentDirectory,
      },
      userId: _authService.currentUser?.id,
    );
  }

  void _gitBranch() {
    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: '''  feature/auth-system
  feature/code-editor
* main
  develop''',
      timestamp: DateTime.now(),
    ));
  }

  void _gitCheckout(List<String> args) {
    if (args.isEmpty) {
      _addEntry(TerminalEntry(
        type: TerminalEntryType.error,
        content: 'Usage: git checkout <branch>',
        timestamp: DateTime.now(),
      ));
      return;
    }

    final branch = args[0];
    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: 'Switched to branch \'$branch\'',
      timestamp: DateTime.now(),
    ));

    // Log git checkout with audit trail
    _auditService.logAction(
      actionType: 'git_checkout_executed',
      description: 'Switched to git branch: $branch',
      contextData: {
        'command': 'git checkout $branch',
        'target_branch': branch,
        'directory': _currentDirectory,
      },
      userId: _authService.currentUser?.id,
    );
  }

  void _handleNpmCommand(List<String> args) {
    if (args.isEmpty) {
      _addEntry(TerminalEntry(
        type: TerminalEntryType.error,
        content: 'Usage: npm <command>',
        timestamp: DateTime.now(),
      ));
      return;
    }

    final npmCmd = args[0];
    switch (npmCmd) {
      case 'install':
        _addEntry(TerminalEntry(
          type: TerminalEntryType.output,
          content:
              '''npm WARN deprecated package@1.0.0: This package is deprecated
added 234 packages from 567 contributors and audited 890 packages in 12.345s
found 0 vulnerabilities''',
          timestamp: DateTime.now(),
        ));
        break;
      case 'run':
        if (args.length > 1) {
          _addEntry(TerminalEntry(
            type: TerminalEntryType.output,
            content: 'Running script: ${args[1]}',
            timestamp: DateTime.now(),
          ));
        }
        break;
      default:
        _addEntry(TerminalEntry(
          type: TerminalEntryType.error,
          content: 'Unknown npm command: $npmCmd',
          timestamp: DateTime.now(),
        ));
    }
  }

  void _handleFlutterCommand(List<String> args) {
    if (args.isEmpty) {
      _addEntry(TerminalEntry(
        type: TerminalEntryType.error,
        content: 'Usage: flutter <command>',
        timestamp: DateTime.now(),
      ));
      return;
    }

    final flutterCmd = args[0];
    switch (flutterCmd) {
      case 'run':
        _addEntry(TerminalEntry(
          type: TerminalEntryType.output,
          content: '''Launching lib/main.dart on Chrome in debug mode...
Building application for the web...                                
lib/main.dart:1
Syncing files to device Chrome...                                  
🔥  To hot restart changes while running, press "r" or "R".
For a more detailed help message, press "h". To quit, press "q".

An Observatory debugger and profiler on Chrome is available at: http://127.0.0.1:9100/
The Flutter DevTools debugger and profiler on Chrome is available at: http://127.0.0.1:9101/''',
          timestamp: DateTime.now(),
        ));
        break;
      case 'build':
        _addEntry(TerminalEntry(
          type: TerminalEntryType.output,
          content: '''Building without sound null safety
Building application for release...                                 
✓ Built build/web''',
          timestamp: DateTime.now(),
        ));
        break;
      default:
        _addEntry(TerminalEntry(
          type: TerminalEntryType.error,
          content: 'Unknown flutter command: $flutterCmd',
          timestamp: DateTime.now(),
        ));
    }
  }

  void _handleDockerCommand(List<String> args) {
    if (args.isEmpty) {
      _addEntry(TerminalEntry(
        type: TerminalEntryType.error,
        content: 'Usage: docker <command>',
        timestamp: DateTime.now(),
      ));
      return;
    }

    final dockerCmd = args[0];
    switch (dockerCmd) {
      case 'build':
        _addEntry(TerminalEntry(
          type: TerminalEntryType.output,
          content: '''Sending build context to Docker daemon  2.048kB
Step 1/5 : FROM node:16-alpine
 ---> 1234567890ab
Step 2/5 : WORKDIR /app
 ---> Using cache
 ---> abcdef123456
Successfully built abcdef123456
Successfully tagged myapp:latest''',
          timestamp: DateTime.now(),
        ));
        break;
      case 'run':
        _addEntry(TerminalEntry(
          type: TerminalEntryType.output,
          content: 'Container started with ID: abcdef123456789',
          timestamp: DateTime.now(),
        ));
        break;
      default:
        _addEntry(TerminalEntry(
          type: TerminalEntryType.error,
          content: 'Unknown docker command: $dockerCmd',
          timestamp: DateTime.now(),
        ));
    }
  }

  void _showCurrentUser() {
    final user = _authService.currentUser;
    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: '${user?.name ?? 'Unknown'} (${user?.role ?? 'unknown'})',
      timestamp: DateTime.now(),
    ));
  }

  void _showCommandHistory() {
    if (_commandHistory.isEmpty) {
      _addEntry(TerminalEntry(
        type: TerminalEntryType.output,
        content: 'No command history',
        timestamp: DateTime.now(),
      ));
      return;
    }

    final historyText = _commandHistory
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}  ${entry.value}')
        .join('\n');

    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: historyText,
      timestamp: DateTime.now(),
    ));
  }

  void _echo(List<String> args) {
    _addEntry(TerminalEntry(
      type: TerminalEntryType.output,
      content: args.join(' '),
      timestamp: DateTime.now(),
    ));
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _navigateHistory(-1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _navigateHistory(1);
      }
    }
  }

  void _navigateHistory(int direction) {
    if (_commandHistory.isEmpty) return;

    _historyIndex += direction;
    _historyIndex = _historyIndex.clamp(-1, _commandHistory.length - 1);

    if (_historyIndex == -1) {
      _inputController.clear();
    } else {
      _inputController.text = _commandHistory[_historyIndex];
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Terminal output
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final entry = _history[index];
                return _buildTerminalEntry(entry);
              },
            ),
          ),

          // Input line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Text(
                  '$_currentDirectory\$ ',
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: _handleKeyEvent,
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: _executeCommand,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalEntry(TerminalEntry entry) {
    Color textColor;
    switch (entry.type) {
      case TerminalEntryType.command:
        textColor = Colors.white;
        break;
      case TerminalEntryType.output:
        textColor = Colors.grey[300]!;
        break;
      case TerminalEntryType.error:
        textColor = Colors.red[300]!;
        break;
      case TerminalEntryType.system:
        textColor = Colors.blue[300]!;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: SelectableText(
        entry.content,
        style: TextStyle(
          color: textColor,
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Terminal entry model
class TerminalEntry {
  final TerminalEntryType type;
  final String content;
  final DateTime timestamp;

  TerminalEntry({
    required this.type,
    required this.content,
    required this.timestamp,
  });
}

/// Terminal entry types
enum TerminalEntryType {
  command,
  output,
  error,
  system,
}
