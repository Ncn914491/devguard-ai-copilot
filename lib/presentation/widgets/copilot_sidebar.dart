import 'package:flutter/material.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/ai/copilot_service.dart';

class CopilotSidebar extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;

  const CopilotSidebar({
    super.key,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<CopilotSidebar> createState() => _CopilotSidebarState();
}

class _CopilotSidebarState extends State<CopilotSidebar> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        text: 'Hello! I\'m your DevGuard AI Copilot. I can help you with:\n\n'
              '• Explaining security alerts\n'
              '• Summarizing recent activity\n'
              '• Managing deployments and rollbacks\n'
              '• Team assignments\n\n'
              'Try commands like /rollback, /assign, or /summarize, or just ask me anything!',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.isExpanded ? 400 : 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: widget.isExpanded ? _buildExpandedView() : _buildCollapsedView(),
    );
  }

  Widget _buildCollapsedView() {
    return Column(
      children: [
        const SizedBox(height: 16),
        IconButton(
          onPressed: widget.onToggle,
          icon: const Icon(Icons.smart_toy),
          tooltip: 'Expand AI Copilot',
        ),
        const SizedBox(height: 16),
        // Quick action buttons
        _buildQuickActionButton(
          icon: Icons.help_outline,
          tooltip: 'Get Help',
          onPressed: () {
            widget.onToggle();
            _sendMessage('Help me understand the current system status');
          },
        ),
        const SizedBox(height: 8),
        _buildQuickActionButton(
          icon: Icons.summarize,
          tooltip: 'Summarize',
          onPressed: () {
            widget.onToggle();
            _sendMessage('/summarize');
          },
        ),
        const SizedBox(height: 8),
        _buildQuickActionButton(
          icon: Icons.security,
          tooltip: 'Security Status',
          onPressed: () {
            widget.onToggle();
            _sendMessage('What is the current security status?');
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
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
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Copilot',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Online',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onToggle,
                icon: const Icon(Icons.close),
                tooltip: 'Collapse Copilot',
              ),
            ],
          ),
        ),

        // Quick Commands
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Commands',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCommandChip('/rollback', 'Rollback deployment'),
                  _buildCommandChip('/assign', 'Assign task'),
                  _buildCommandChip('/summarize', 'Summarize activity'),
                  _buildCommandChip('/security', 'Security status'),
                ],
              ),
            ],
          ),
        ),

        // Chat Messages
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
        ),

        // Loading Indicator
        if (_isLoading)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'AI is thinking...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

        // Input Area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask me anything or use /commands...',
                    hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _handleSendMessage,
                icon: const Icon(Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommandChip(String command, String description) {
    return ActionChip(
      label: Text(
        command,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
        ),
      ),
      onPressed: () => _sendMessage(command),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      tooltip: description,
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: message.isUser
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: message.isUser
                          ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  // Show approval buttons if required
                  if (message.requiresApproval && !message.isUser) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _handleApproval(message, true),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _handleApproval(message, false),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Deny'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 12,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.person,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleSendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      _sendMessage(message);
      _messageController.clear();
    }
  }

  void _sendMessage(String message) {
    setState(() {
      _messages.add(
        ChatMessage(
          text: message,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });

    _scrollToBottom();
    _processMessage(message);
  }

  Future<void> _processMessage(String message) async {
    try {
      // Use CopilotService for all message processing
      final response = await CopilotService.instance.processCommand(
        message,
        userId: 'current_user', // TODO: Get actual user ID from auth
      );

      setState(() {
        _messages.add(
          ChatMessage(
            text: response.message,
            isUser: false,
            timestamp: DateTime.now(),
            requiresApproval: response.requiresApproval,
            actionData: response.actionData,
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Sorry, I encountered an error: $e\n\n'
                  'I\'m running in fallback mode. I can still help with basic commands '
                  'like /rollback, /assign, and /summarize.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }



  void _handleApproval(ChatMessage message, bool approved) async {
    if (message.actionData == null) return;

    try {
      if (approved) {
        // Execute the approved action
        await CopilotService.instance.executeApprovedAction(
          'action_${DateTime.now().millisecondsSinceEpoch}',
          message.actionData!,
          'current_user', // TODO: Get actual user ID
        );

        setState(() {
          _messages.add(
            ChatMessage(
              text: '✅ Action approved and executed successfully.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      } else {
        setState(() {
          _messages.add(
            ChatMessage(
              text: '❌ Action denied by user.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: '⚠️ Error processing approval: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    }

    _scrollToBottom();
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool requiresApproval;
  final Map<String, dynamic>? actionData;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.requiresApproval = false,
    this.actionData,
  });
}