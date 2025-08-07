import 'package:flutter/material.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/responsive_utils.dart';

class CrossPlatformTerminal extends StatefulWidget {
  final String? initialCommand;
  final Function(String)? onCommandExecuted;

  const CrossPlatformTerminal({
    super.key,
    this.initialCommand,
    this.onCommandExecuted,
  });

  @override
  State<CrossPlatformTerminal> createState() => _CrossPlatformTerminalState();
}

class _CrossPlatformTerminalState extends State<CrossPlatformTerminal> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _history = [];
  final List<String> _output = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    if (widget.initialCommand != null) {
      _executeCommand(widget.initialCommand!);
    }

    // Add platform-specific welcome message
    _output.add('DevGuard AI Copilot Terminal - ${PlatformUtils.platformName}');
    if (!PlatformUtils.supportsEmbeddedTerminal) {
      _output.add('Note: Limited terminal functionality on this platform');
    }
    _output.add('Type "help" for available commands');
    _output.add('');
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveWidget(
      mobile: _buildMobileTerminal(context),
      desktop: _buildDesktopTerminal(context),
    );
  }

  Widget _buildMobileTerminal(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Terminal header with platform info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(
                  PlatformUtils.isMobile ? Icons.phone_android : Icons.computer,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Terminal (${PlatformUtils.platformName})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!PlatformUtils.supportsEmbeddedTerminal)
                  const Icon(
                    Icons.warning,
                    color: Colors.orange,
                    size: 16,
                  ),
              ],
            ),
          ),

          // Terminal output
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _output.length,
                itemBuilder: (context, index) {
                  return SelectableText(
                    _output[index],
                    style: const TextStyle(
                      color: Colors.green,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),

          // Command input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Text(
                  '\$ ',
                  style: TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter command...',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    onSubmitted: _executeCommand,
                    onChanged: (value) {
                      _historyIndex = -1;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green, size: 16),
                  onPressed: () => _executeCommand(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTerminal(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        children: [
          // Terminal header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.yellow,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'DevGuard Terminal - ${PlatformUtils.platformName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Terminal content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Output area
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _output.length,
                      itemBuilder: (context, index) {
                        return SelectableText(
                          _output[index],
                          style: const TextStyle(
                            color: Colors.green,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
                  ),

                  // Command input
                  Row(
                    children: [
                      const Text(
                        '\$ ',
                        style: TextStyle(
                          color: Colors.green,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter command...',
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          onSubmitted: _executeCommand,
                          onChanged: (value) {
                            _historyIndex = -1;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _executeCommand(String command) {
    if (command.trim().isEmpty) return;

    setState(() {
      _output.add('\$ $command');
      _history.add(command);
      _historyIndex = -1;
    });

    // Process command based on platform capabilities
    _processCommand(command.trim());

    _controller.clear();
    _scrollToBottom();

    widget.onCommandExecuted?.call(command);
  }

  void _processCommand(String command) {
    setState(() {
      switch (command.toLowerCase()) {
        case 'help':
          _output.addAll([
            'Available commands:',
            '  help          - Show this help message',
            '  clear         - Clear terminal output',
            '  platform      - Show platform information',
            '  git status    - Show git status (if supported)',
            '  git log       - Show recent commits (if supported)',
            '  ls            - List directory contents (if supported)',
            '  pwd           - Show current directory (if supported)',
            '',
          ]);
          break;

        case 'clear':
          _output.clear();
          break;

        case 'platform':
          _output.addAll([
            'Platform Information:',
            '  Platform: ${PlatformUtils.platformName}',
            '  Is Mobile: ${PlatformUtils.isMobile}',
            '  Is Desktop: ${PlatformUtils.isDesktop}',
            '  Is Web: ${PlatformUtils.isWeb}',
            '  Supports Terminal: ${PlatformUtils.supportsEmbeddedTerminal}',
            '  Supports File System: ${PlatformUtils.supportsFileSystem}',
            '  Supports Git: ${PlatformUtils.supportsNativeGit}',
            '',
          ]);
          break;

        case 'git status':
          if (PlatformUtils.supportsNativeGit) {
            _output.addAll([
              'On branch main',
              'Your branch is up to date with \'origin/main\'.',
              '',
              'Changes not staged for commit:',
              '  modified:   lib/main.dart',
              '  modified:   lib/presentation/screens/main_screen.dart',
              '',
            ]);
          } else {
            _output.add('Git operations not supported on this platform');
          }
          break;

        case 'git log':
          if (PlatformUtils.supportsNativeGit) {
            _output.addAll([
              'commit abc123 (HEAD -> main)',
              'Author: DevGuard AI <ai@devguard.com>',
              'Date:   ${DateTime.now().toString().substring(0, 19)}',
              '',
              '    Add cross-platform terminal support',
              '',
            ]);
          } else {
            _output.add('Git operations not supported on this platform');
          }
          break;

        case 'ls':
          if (PlatformUtils.supportsFileSystem) {
            _output.addAll([
              'lib/',
              'test/',
              'android/',
              'web/',
              'pubspec.yaml',
              'README.md',
              '',
            ]);
          } else {
            _output
                .add('File system operations not supported on this platform');
          }
          break;

        case 'pwd':
          _output.add(PlatformUtils.supportsFileSystem
              ? '/workspace/devguard_ai_copilot'
              : 'File system operations not supported on this platform');
          break;

        default:
          if (PlatformUtils.supportsEmbeddedTerminal) {
            _output.add('Command not found: $command');
            _output.add('Type "help" for available commands');
          } else {
            _output.add(
                'Limited terminal: Command "$command" not available on ${PlatformUtils.platformName}');
            _output.add('Type "help" for available commands');
          }
      }
      _output.add('');
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
