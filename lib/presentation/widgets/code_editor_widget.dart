import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/database/services/services.dart';
import '../../core/gitops/git_integration.dart';

/// Code editor widget with syntax highlighting and AI assistance
class CodeEditorWidget extends StatefulWidget {
  final String content;
  final String language;
  final Function(String) onChanged;
  final bool readOnly;

  const CodeEditorWidget({
    super.key,
    required this.content,
    required this.language,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends State<CodeEditorWidget> {
  late TextEditingController _controller;
  late ScrollController _scrollController;
  late ScrollController _lineNumberScrollController;

  final FocusNode _focusNode = FocusNode();
  final GlobalKey _textFieldKey = GlobalKey();
  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;
  final _gitService = GitIntegration.instance;

  List<String> _lines = [];
  int _currentLine = 1;
  int _currentColumn = 1;
  bool _showSuggestions = false;
  List<CodeSuggestion> _suggestions = [];
  bool _hasUnsavedChanges = false;
  String? _currentFilePath;

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

    // Mark as having unsaved changes
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }

    widget.onChanged(_controller.text);

    // Log code editing activity
    _auditService.logAction(
      actionType: 'code_edited',
      description: 'Code content modified in editor',
      contextData: {
        'file_path': _currentFilePath ?? 'untitled',
        'language': widget.language,
        'line_count': _lines.length,
        'character_count': _controller.text.length,
      },
      userId: _authService.currentUser?.id,
    );

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
      final textBeforeCursor =
          _controller.text.substring(0, selection.baseOffset);
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
    final currentText = _controller.text;
    final cursorPosition = _controller.selection.baseOffset;
    final contextBefore = cursorPosition > 50
        ? currentText.substring(cursorPosition - 50, cursorPosition)
        : currentText.substring(0, cursorPosition);

    switch (widget.language) {
      case 'dart':
        return _generateDartSuggestions(contextBefore);
      case 'javascript':
        return _generateJavaScriptSuggestions(contextBefore);
      case 'python':
        return _generatePythonSuggestions(contextBefore);
      default:
        return _generateGenericSuggestions(contextBefore);
    }
  }

  List<CodeSuggestion> _generateDartSuggestions(String context) {
    final suggestions = <CodeSuggestion>[];

    // Context-aware suggestions
    if (context.contains('class ') && !context.contains('extends')) {
      suggestions.add(CodeSuggestion(
        title: 'Extend StatelessWidget',
        description: 'Make this class a Flutter widget',
        code:
            ' extends StatelessWidget {\n  const ${_extractClassName(context)}({Key? key}) : super(key: key);\n\n  @override\n  Widget build(BuildContext context) {\n    return Container();\n  }\n}',
      ));
    }

    if (context.contains('Future') || context.contains('async')) {
      suggestions.add(CodeSuggestion(
        title: 'Add Error Handling',
        description: 'Wrap async code in try-catch',
        code: '''try {
  // Your async code here
} catch (e) {
  print('Error: \$e');
  rethrow;
}''',
      ));
    }

    // Common Flutter patterns
    suggestions.addAll([
      CodeSuggestion(
        title: 'Create StatefulWidget',
        description: 'Generate a new StatefulWidget with state',
        code: '''class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}''',
      ),
      CodeSuggestion(
        title: 'Add HTTP Request',
        description: 'Create HTTP GET request with error handling',
        code: '''Future<Map<String, dynamic>> fetchData() async {
  try {
    final response = await http.get(Uri.parse('https://api.example.com/data'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  } catch (e) {
    print('Error fetching data: \$e');
    rethrow;
  }
}''',
      ),
      CodeSuggestion(
        title: 'Add Form Validation',
        description: 'Create form with validation',
        code: '''final _formKey = GlobalKey<FormState>();

Form(
  key: _formKey,
  child: Column(
    children: [
      TextFormField(
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter some text';
          }
          return null;
        },
      ),
      ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            // Process data
          }
        },
        child: Text('Submit'),
      ),
    ],
  ),
)''',
      ),
    ]);

    return suggestions;
    return suggestions;
  }

  List<CodeSuggestion> _generateJavaScriptSuggestions(String context) {
    final suggestions = <CodeSuggestion>[];

    if (context.contains('fetch') || context.contains('async')) {
      suggestions.add(CodeSuggestion(
        title: 'Add Error Handling',
        description: 'Wrap async code in try-catch',
        code: '''try {
  // Your async code here
} catch (error) {
  console.error('Error:', error);
  throw error;
}''',
      ));
    }

    suggestions.addAll([
      CodeSuggestion(
        title: 'Create Async Function',
        description: 'Generate async/await function with error handling',
        code: '''async function fetchData(url) {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! status: \${response.status}`);
    }
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Fetch error:', error);
    throw error;
  }
}''',
      ),
      CodeSuggestion(
        title: 'Add Event Listener',
        description: 'Add DOM event listener with cleanup',
        code: '''const handleClick = (event) => {
  // Handle click event
};

element.addEventListener('click', handleClick);

// Cleanup
return () => {
  element.removeEventListener('click', handleClick);
};''',
      ),
      CodeSuggestion(
        title: 'Create React Component',
        description: 'Generate React functional component',
        code: '''import React, { useState, useEffect } from 'react';

const MyComponent = ({ prop1, prop2 }) => {
  const [state, setState] = useState(null);

  useEffect(() => {
    // Effect logic here
  }, []);

  return (
    <div>
      {/* Component JSX */}
    </div>
  );
};

export default MyComponent;''',
      ),
    ]);

    return suggestions;
  }

  List<CodeSuggestion> _generatePythonSuggestions(String context) {
    final suggestions = <CodeSuggestion>[];

    if (context.contains('def ') && context.contains('async')) {
      suggestions.add(CodeSuggestion(
        title: 'Add Async Error Handling',
        description: 'Wrap async function in try-except',
        code: '''try:
    # Your async code here
    pass
except Exception as e:
    logger.error(f"Error: {e}")
    raise''',
      ));
    }

    suggestions.addAll([
      CodeSuggestion(
        title: 'Create Class with Properties',
        description: 'Generate Python class with properties and methods',
        code: '''class MyClass:
    def __init__(self, name: str, value: int = 0):
        self._name = name
        self._value = value
    
    @property
    def name(self) -> str:
        return self._name
    
    @property
    def value(self) -> int:
        return self._value
    
    @value.setter
    def value(self, new_value: int):
        if new_value < 0:
            raise ValueError("Value must be non-negative")
        self._value = new_value
    
    def __str__(self) -> str:
        return f"MyClass(name='{self._name}', value={self._value})"''',
      ),
      CodeSuggestion(
        title: 'Add Logging Setup',
        description: 'Configure logging with proper formatting',
        code: '''import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('app.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)
logger.info("Application started")''',
      ),
      CodeSuggestion(
        title: 'Create API Endpoint',
        description: 'Generate FastAPI endpoint with validation',
        code: '''from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional

app = FastAPI()

class ItemModel(BaseModel):
    name: str
    description: Optional[str] = None
    price: float

@app.post("/items/")
async def create_item(item: ItemModel):
    try:
        # Process item
        return {"message": "Item created successfully", "item": item}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))''',
      ),
    ]);

    return suggestions;
  }

  List<CodeSuggestion> _generateGenericSuggestions(String context) {
    return [
      CodeSuggestion(
        title: 'Add TODO Comment',
        description: 'Add a TODO comment for future implementation',
        code: '// TODO: Implement this functionality',
      ),
      CodeSuggestion(
        title: 'Add Debug Log',
        description: 'Add debug logging statement',
        code: 'console.log("Debug:", /* your variable here */);',
      ),
      CodeSuggestion(
        title: 'Add Function Documentation',
        description: 'Add comprehensive function documentation',
        code: '''/**
 * Brief description of the function
 * @param {type} param1 - Description of param1
 * @param {type} param2 - Description of param2
 * @returns {type} Description of return value
 */''',
      ),
    ];
  }

  String _extractClassName(String context) {
    final classMatch = RegExp(r'class\s+(\w+)').firstMatch(context);
    return classMatch?.group(1) ?? 'MyClass';
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

    // Log AI suggestion usage
    _auditService.logAction(
      actionType: 'ai_suggestion_applied',
      description: 'Applied AI code suggestion: ${suggestion.title}',
      aiReasoning:
          'User accepted AI-generated code suggestion to improve productivity',
      contextData: {
        'suggestion_title': suggestion.title,
        'suggestion_description': suggestion.description,
        'file_path': _currentFilePath ?? 'untitled',
        'language': widget.language,
      },
      userId: _authService.currentUser?.id,
    );
  }

  // File operations
  Future<void> saveFile() async {
    if (!_authService.hasPermission('commit_code')) {
      _showPermissionDenied('save files');
      return;
    }

    if (_currentFilePath == null) {
      await _showSaveAsDialog();
      return;
    }

    try {
      // Save file content (in real implementation, this would write to file system)
      await _saveFileContent(_currentFilePath!, _controller.text);

      setState(() {
        _hasUnsavedChanges = false;
      });

      await _auditService.logAction(
        actionType: 'file_saved',
        description: 'File saved successfully',
        contextData: {
          'file_path': _currentFilePath!,
          'language': widget.language,
          'size_bytes': _controller.text.length,
        },
        userId: _authService.currentUser?.id,
      );

      _showSnackBar('File saved successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to save file: $e', Colors.red);
    }
  }

  Future<void> _showSaveAsDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save As'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'File name',
            hintText: 'example.dart',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, 'untitled.${_getFileExtension()}'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _currentFilePath = result;
      await saveFile();
    }
  }

  String _getFileExtension() {
    switch (widget.language) {
      case 'dart':
        return 'dart';
      case 'javascript':
        return 'js';
      case 'typescript':
        return 'ts';
      case 'python':
        return 'py';
      case 'java':
        return 'java';
      case 'cpp':
        return 'cpp';
      case 'html':
        return 'html';
      case 'css':
        return 'css';
      default:
        return 'txt';
    }
  }

  Future<void> _saveFileContent(String filePath, String content) async {
    // In a real implementation, this would write to the file system
    // For demo purposes, we'll simulate the operation
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // Git operations
  Future<void> commitChanges() async {
    if (!_authService.hasPermission('commit_code')) {
      _showPermissionDenied('commit changes');
      return;
    }

    if (_currentFilePath == null) {
      _showSnackBar('Please save the file first', Colors.orange);
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commit Changes'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Commit message',
            hintText: 'Describe your changes...',
          ),
          maxLines: 3,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, 'Update ${_currentFilePath!}'),
            child: const Text('Commit'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        // Create a simple commit simulation
        await _gitService.createCommitFromSpec(
          'editor-commit-${DateTime.now().millisecondsSinceEpoch}',
          'main',
          _controller.text,
        );

        await _auditService.logAction(
          actionType: 'git_commit',
          description: 'File committed to git repository',
          contextData: {
            'file_path': _currentFilePath!,
            'commit_message': result,
            'language': widget.language,
          },
          userId: _authService.currentUser?.id,
        );

        _showSnackBar('Changes committed successfully', Colors.green);
      } catch (e) {
        _showSnackBar('Failed to commit changes: $e', Colors.red);
      }
    }
  }

  void _showPermissionDenied(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: Text(
            'You do not have permission to $action. Contact your administrator for access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ctrl+S to save
      if (event.logicalKey == LogicalKeyboardKey.keyS &&
          (HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed)) {
        saveFile();
      }
      // Ctrl+Shift+C to commit
      else if (event.logicalKey == LogicalKeyboardKey.keyC &&
          HardwareKeyboard.instance.isControlPressed &&
          HardwareKeyboard.instance.isShiftPressed) {
        commitChanges();
      }
      // Ctrl+Space for AI suggestions
      else if (event.logicalKey == LogicalKeyboardKey.space &&
          HardwareKeyboard.instance.isControlPressed) {
        _showAISuggestions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: [
          Column(
            children: [
              // Toolbar
              Container(
                height: 40,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(
                      _hasUnsavedChanges ? Icons.circle : Icons.check_circle,
                      size: 12,
                      color: _hasUnsavedChanges ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currentFilePath ?? 'Untitled',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    if (_hasUnsavedChanges)
                      const Text(' •', style: TextStyle(fontSize: 12)),
                    const Spacer(),
                    if (_authService.hasPermission('commit_code')) ...[
                      IconButton(
                        onPressed: saveFile,
                        icon: const Icon(Icons.save, size: 16),
                        tooltip: 'Save (Ctrl+S)',
                        padding: const EdgeInsets.all(4),
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        onPressed: commitChanges,
                        icon: const Icon(Icons.commit, size: 16),
                        tooltip: 'Commit Changes',
                        padding: const EdgeInsets.all(4),
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                    IconButton(
                      onPressed: () => _showAISuggestions(),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      tooltip: 'AI Suggestions',
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),

              // Editor content
              Expanded(
                child: Row(
                  children: [
                    // Line numbers
                    Container(
                      width: 60,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Code editor
                    Expanded(
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: _handleKeyEvent,
                        child: TextField(
                          key: _textFieldKey,
                          controller: _controller,
                          focusNode: _focusNode,
                          readOnly: widget.readOnly ||
                              !_authService.hasPermission('commit_code'),
                          maxLines: null,
                          expands: true,
                          scrollController: _scrollController,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(8),
                            hintText: widget.readOnly ||
                                    !_authService.hasPermission('commit_code')
                                ? 'Read-only mode - no edit permissions'
                                : 'Start typing or use //AI: for suggestions...',
                            hintStyle: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          inputFormatters: [
                            _SyntaxHighlightingFormatter(widget.language),
                          ],
                          onChanged: (text) => _onTextChanged(),
                        ),
                      ),
                    ),
                  ],
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
            color: Colors.black.withValues(alpha: 0.1),
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
