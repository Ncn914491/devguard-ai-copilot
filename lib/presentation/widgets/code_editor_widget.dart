import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

/// Code editor widget with syntax highlighting and AI assistance
class CodeEditorWidget extends StatefulWidget {
  final String content;
  final String language;
  final Function(String) onChanged;
  final bool readOnly;

  const CodeEditorWidget({
    Key? key,
    required this.content,
    required this.language,
    required this.onChanged,
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends State<CodeEditorWidget> {
  late TextEditingController _controller;
  late ScrollController _scrollController;
  late ScrollController _lineNumberScrollController;
  
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _textFieldKey = GlobalKey();
  
  List<String> _lines = [];
  int _currentLine = 1;
  int _currentColumn = 1;
  bool _showSuggestions = false;
  List<CodeSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    _scrollController = ScrollController();
    _lineNumberScrollController = ScrollController();
    _updateLines();
    
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_syncScrolling);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _lineNumberScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _updateLines();
    _updateCursorPosition();
    widget.onChanged(_controller.text);
    
    // Check for AI assistance trigger
    if (_controller.text.endsWith('//AI:')) {
      _showAISuggestions();
    }
  }

  void _updateLines() {
    setState(() {
      _lines = _controller.text.split('\n');
    });
  }

  void _updateCursorPosition() {
    final selection = _controller.selection;
    if (selection.isValid) {
      final textBeforeCursor = _controller.text.substring(0, selection.baseOffset);
      final lines = textBeforeCursor.split('\n');
      setState(() {
        _currentLine = lines.length;
        _currentColumn = lines.last.length + 1;
      });
    }
  }

  void _syncScrolling() {
    if (_lineNumberScrollController.hasClients) {
      _lineNumberScrollController.jumpTo(_scrollController.offset);
    }
  }

  void _showAISuggestions() {
    setState(() {
      _suggestions = _generateAISuggestions();
      _showSuggestions = true;
    });
  }

  List<CodeSuggestion> _generateAISuggestions() {
    // Generate AI-powered code suggestions based on context
    switch (widget.language) {
      case 'dart':
        return [
          CodeSuggestion(
            title: 'Create Flutter Widget',
            description: 'Generate a new StatelessWidget',
            code: '''class MyWidget extends StatelessWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}''',
          ),
          CodeSuggestion(
            title: 'Add Error Handling',
            description: 'Wrap code in try-catch block',
            code: '''try {
  // Your code here
} catch (e) {
  print('Error: \$e');
}''',
          ),
        ];
      case 'javascript':
        return [
          CodeSuggestion(
            title: 'Create Async Function',
            description: 'Generate async/await function',
            code: '''async function fetchData() {
  try {
    const response = await fetch('/api/data');
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error:', error);
  }
}''',
          ),
          CodeSuggestion(
            title: 'Add Event Listener',
            description: 'Add DOM event listener',
            code: '''document.addEventListener('DOMContentLoaded', function() {
  // Your code here
});''',
          ),
        ];
      case 'python':
        return [
          CodeSuggestion(
            title: 'Create Class',
            description: 'Generate Python class with constructor',
            code: '''class MyClass:
    def __init__(self, name):
        self.name = name
    
    def __str__(self):
        return f"MyClass({self.name})"''',
          ),
          CodeSuggestion(
            title: 'Add Logging',
            description: 'Add logging configuration',
            code: '''import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

logger.info("Your message here")''',
          ),
        ];
      default:
        return [
          CodeSuggestion(
            title: 'Add Comment',
            description: 'Add descriptive comment',
            code: '// TODO: Add implementation',
          ),
        ];
    }
  }

  void _applySuggestion(CodeSuggestion suggestion) {
    final currentText = _controller.text;
    final cursorPosition = _controller.selection.baseOffset;
    
    // Remove the //AI: trigger
    final beforeCursor = currentText.substring(0, cursorPosition - 5);
    final afterCursor = currentText.substring(cursorPosition);
    
    final newText = beforeCursor + suggestion.code + afterCursor;
    
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: beforeCursor.length + suggestion.code.length,
    );
    
    setState(() {
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: [
          Row(
            children: [
              // Line numbers
              Container(
                width: 60,
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: ListView.builder(
                  controller: _lineNumberScrollController,
                  itemCount: _lines.length,
                  itemBuilder: (context, index) {
                    return Container(
                      height: 20,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Code editor
              Expanded(
                child: TextField(
                  key: _textFieldKey,
                  controller: _controller,
                  focusNode: _focusNode,
                  readOnly: widget.readOnly,
                  maxLines: null,
                  expands: true,
                  scrollController: _scrollController,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(8),
                  ),
                  inputFormatters: [
                    _SyntaxHighlightingFormatter(widget.language),
                  ],
                  onChanged: (text) => _onTextChanged(),
                ),
              ),
            ],
          ),
          
          // Status bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 24,
              color: Theme.of(context).colorScheme.surfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    'Line $_currentLine, Column $_currentColumn',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.language.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'UTF-8',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // AI Suggestions overlay
          if (_showSuggestions)
            Positioned(
              top: 100,
              right: 20,
              child: _buildSuggestionsPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsPanel() {
    return Container(
      width: 300,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Code Suggestions',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showSuggestions = false),
                  child: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  title: Text(suggestion.title),
                  subtitle: Text(suggestion.description),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                  onTap: () => _applySuggestion(suggestion),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Syntax highlighting formatter
class _SyntaxHighlightingFormatter extends TextInputFormatter {
  final String language;
  
  _SyntaxHighlightingFormatter(this.language);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Basic syntax highlighting would be implemented here
    // For now, return the value as-is
    return newValue;
  }
}

/// Code suggestion model
class CodeSuggestion {
  final String title;
  final String description;
  final String code;

  CodeSuggestion({
    required this.title,
    required this.description,
    required this.code,
  });
}