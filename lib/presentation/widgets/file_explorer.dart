import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';

/// File explorer widget for repository navigation
class FileExplorer extends StatefulWidget {
  final Function(String) onFileSelected;
  final Function(String) onFileCreated;

  const FileExplorer({
    Key? key,
    required this.onFileSelected,
    required this.onFileCreated,
  }) : super(key: key);

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  final _authService = AuthService.instance;
  final Map<String, bool> _expandedFolders = {};
  String? _selectedFile;
  
  // Mock file system structure
  final Map<String, FileSystemItem> _fileSystem = {
    'lib': FileSystemItem(
      name: 'lib',
      type: FileSystemItemType.folder,
      path: 'lib',
      children: {
        'main.dart': FileSystemItem(
          name: 'main.dart',
          type: FileSystemItemType.file,
          path: 'lib/main.dart',
        ),
        'core': FileSystemItem(
          name: 'core',
          type: FileSystemItemType.folder,
          path: 'lib/core',
          children: {
            'auth': FileSystemItem(
              name: 'auth',
              type: FileSystemItemType.folder,
              path: 'lib/core/auth',
              children: {
                'auth_service.dart': FileSystemItem(
                  name: 'auth_service.dart',
                  type: FileSystemItemType.file,
                  path: 'lib/core/auth/auth_service.dart',
                ),
              },
            ),
            'database': FileSystemItem(
              name: 'database',
              type: FileSystemItemType.folder,
              path: 'lib/core/database',
              children: {
                'database_service.dart': FileSystemItem(
                  name: 'database_service.dart',
                  type: FileSystemItemType.file,
                  path: 'lib/core/database/database_service.dart',
                ),
              },
            ),
          },
        ),
        'presentation': FileSystemItem(
          name: 'presentation',
          type: FileSystemItemType.folder,
          path: 'lib/presentation',
          children: {
            'screens': FileSystemItem(
              name: 'screens',
              type: FileSystemItemType.folder,
              path: 'lib/presentation/screens',
              children: {
                'home_screen.dart': FileSystemItem(
                  name: 'home_screen.dart',
                  type: FileSystemItemType.file,
                  path: 'lib/presentation/screens/home_screen.dart',
                ),
                'code_editor_screen.dart': FileSystemItem(
                  name: 'code_editor_screen.dart',
                  type: FileSystemItemType.file,
                  path: 'lib/presentation/screens/code_editor_screen.dart',
                ),
              },
            ),
            'widgets': FileSystemItem(
              name: 'widgets',
              type: FileSystemItemType.folder,
              path: 'lib/presentation/widgets',
              children: {
                'terminal_panel.dart': FileSystemItem(
                  name: 'terminal_panel.dart',
                  type: FileSystemItemType.file,
                  path: 'lib/presentation/widgets/terminal_panel.dart',
                ),
                'file_explorer.dart': FileSystemItem(
                  name: 'file_explorer.dart',
                  type: FileSystemItemType.file,
                  path: 'lib/presentation/widgets/file_explorer.dart',
                ),
              },
            ),
          },
        ),
      },
    ),
    'test': FileSystemItem(
      name: 'test',
      type: FileSystemItemType.folder,
      path: 'test',
      children: {
        'widget_test.dart': FileSystemItem(
          name: 'widget_test.dart',
          type: FileSystemItemType.file,
          path: 'test/widget_test.dart',
        ),
      },
    ),
    'pubspec.yaml': FileSystemItem(
      name: 'pubspec.yaml',
      type: FileSystemItemType.file,
      path: 'pubspec.yaml',
    ),
    'README.md': FileSystemItem(
      name: 'README.md',
      type: FileSystemItemType.file,
      path: 'README.md',
    ),
    '.gitignore': FileSystemItem(
      name: '.gitignore',
      type: FileSystemItemType.file,
      path: '.gitignore',
    ),
  };

  @override
  void initState() {
    super.initState();
    // Expand lib folder by default
    _expandedFolders['lib'] = true;
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'dart':
        return Icons.code;
      case 'yaml':
      case 'yml':
        return Icons.settings;
      case 'md':
        return Icons.description;
      case 'json':
        return Icons.data_object;
      case 'js':
      case 'ts':
        return Icons.javascript;
      case 'html':
        return Icons.web;
      case 'css':
        return Icons.style;
      case 'py':
        return Icons.code;
      case 'java':
        return Icons.code;
      case 'cpp':
      case 'c':
        return Icons.code;
      case 'gitignore':
        return Icons.visibility_off;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'dart':
        return Colors.blue;
      case 'yaml':
      case 'yml':
        return Colors.orange;
      case 'md':
        return Colors.green;
      case 'json':
        return Colors.yellow;
      case 'js':
      case 'ts':
        return Colors.yellow[700]!;
      case 'html':
        return Colors.red;
      case 'css':
        return Colors.blue[300]!;
      case 'py':
        return Colors.green[700]!;
      case 'java':
        return Colors.red[700]!;
      case 'cpp':
      case 'c':
        return Colors.blue[700]!;
      default:
        return Colors.grey;
    }
  }

  void _toggleFolder(String path) {
    setState(() {
      _expandedFolders[path] = !(_expandedFolders[path] ?? false);
    });
  }

  void _selectFile(String path) {
    setState(() {
      _selectedFile = path;
    });
    widget.onFileSelected(path);
  }

  void _showContextMenu(BuildContext context, String path, FileSystemItem item) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + renderBox.size.width,
        position.dy + renderBox.size.height,
      ),
      items: _buildContextMenuItems(path, item),
    );
  }

  List<PopupMenuEntry<String>> _buildContextMenuItems(String path, FileSystemItem item) {
    final List<PopupMenuEntry<String>> items = [];
    
    if (item.type == FileSystemItemType.folder) {
      items.addAll([
        const PopupMenuItem<String>(
          value: 'new_file',
          child: Row(
            children: [
              Icon(Icons.add, size: 16),
              SizedBox(width: 8),
              Text('New File'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'new_folder',
          child: Row(
            children: [
              Icon(Icons.create_new_folder, size: 16),
              SizedBox(width: 8),
              Text('New Folder'),
            ],
          ),
        ),
        const PopupMenuDivider(),
      ]);
    }
    
    items.addAll([
      const PopupMenuItem<String>(
        value: 'rename',
        child: Row(
          children: [
            Icon(Icons.edit, size: 16),
            SizedBox(width: 8),
            Text('Rename'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 16, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ]);
    
    if (item.type == FileSystemItemType.file) {
      items.addAll([
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'copy_path',
          child: Row(
            children: [
              Icon(Icons.copy, size: 16),
              SizedBox(width: 8),
              Text('Copy Path'),
            ],
          ),
        ),
      ]);
    }
    
    return items;
  }

  void _handleContextMenuAction(String action, String path, FileSystemItem item) {
    switch (action) {
      case 'new_file':
        _showNewFileDialog(path);
        break;
      case 'new_folder':
        _showNewFolderDialog(path);
        break;
      case 'rename':
        _showRenameDialog(path, item);
        break;
      case 'delete':
        _showDeleteConfirmation(path, item);
        break;
      case 'copy_path':
        _copyPathToClipboard(path);
        break;
    }
  }

  void _showNewFileDialog(String parentPath) {
    if (!_authService.hasPermission('commit_code')) {
      _showPermissionError();
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => _NewItemDialog(
        title: 'New File',
        parentPath: parentPath,
        onConfirm: (name) {
          final newPath = '$parentPath/$name';
          widget.onFileCreated(newPath);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showNewFolderDialog(String parentPath) {
    if (!_authService.hasPermission('commit_code')) {
      _showPermissionError();
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => _NewItemDialog(
        title: 'New Folder',
        parentPath: parentPath,
        onConfirm: (name) {
          // Create new folder logic would go here
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showRenameDialog(String path, FileSystemItem item) {
    if (!_authService.hasPermission('commit_code')) {
      _showPermissionError();
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => _RenameDialog(
        currentName: item.name,
        onConfirm: (newName) {
          // Rename logic would go here
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showDeleteConfirmation(String path, FileSystemItem item) {
    if (!_authService.hasPermission('commit_code')) {
      _showPermissionError();
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Delete logic would go here
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _copyPathToClipboard(String path) {
    // Copy path to clipboard logic would go here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied path: $path')),
    );
  }

  void _showPermissionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You do not have permission to modify files'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Header
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Explorer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_authService.hasPermission('commit_code'))
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 16),
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'new_file',
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 16),
                            SizedBox(width: 8),
                            Text('New File'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'new_folder',
                        child: Row(
                          children: [
                            Icon(Icons.create_new_folder, size: 16),
                            SizedBox(width: 8),
                            Text('New Folder'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 16),
                            SizedBox(width: 8),
                            Text('Refresh'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'new_file':
                          _showNewFileDialog('');
                          break;
                        case 'new_folder':
                          _showNewFolderDialog('');
                          break;
                        case 'refresh':
                          setState(() {});
                          break;
                      }
                    },
                  ),
              ],
            ),
          ),
          
          // File tree
          Expanded(
            child: ListView(
              children: _buildFileTree(_fileSystem, 0),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFileTree(Map<String, FileSystemItem> items, int depth) {
    final List<Widget> widgets = [];
    
    final sortedItems = items.entries.toList()
      ..sort((a, b) {
        // Folders first, then files
        if (a.value.type != b.value.type) {
          return a.value.type == FileSystemItemType.folder ? -1 : 1;
        }
        return a.key.compareTo(b.key);
      });
    
    for (final entry in sortedItems) {
      final item = entry.value;
      final isExpanded = _expandedFolders[item.path] ?? false;
      final isSelected = _selectedFile == item.path;
      
      widgets.add(
        GestureDetector(
          onTap: () {
            if (item.type == FileSystemItemType.folder) {
              _toggleFolder(item.path);
            } else {
              _selectFile(item.path);
            }
          },
          onSecondaryTap: () {
            _showContextMenu(context, item.path, item);
          },
          child: Container(
            height: 24,
            padding: EdgeInsets.only(left: depth * 16.0 + 8),
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: Row(
              children: [
                if (item.type == FileSystemItemType.folder)
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 4),
                Icon(
                  item.type == FileSystemItemType.folder
                      ? (isExpanded ? Icons.folder_open : Icons.folder)
                      : _getFileIcon(item.name),
                  size: 16,
                  color: item.type == FileSystemItemType.folder
                      ? Theme.of(context).colorScheme.primary
                      : _getFileColor(item.name),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      // Add children if folder is expanded
      if (item.type == FileSystemItemType.folder &&
          isExpanded &&
          item.children != null) {
        widgets.addAll(_buildFileTree(item.children!, depth + 1));
      }
    }
    
    return widgets;
  }
}

/// New item dialog
class _NewItemDialog extends StatefulWidget {
  final String title;
  final String parentPath;
  final Function(String) onConfirm;

  const _NewItemDialog({
    required this.title,
    required this.parentPath,
    required this.onConfirm,
  });

  @override
  State<_NewItemDialog> createState() => _NewItemDialogState();
}

class _NewItemDialogState extends State<_NewItemDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            widget.onConfirm(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              widget.onConfirm(name);
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Rename dialog
class _RenameDialog extends StatefulWidget {
  final String currentName;
  final Function(String) onConfirm;

  const _RenameDialog({
    required this.currentName,
    required this.onConfirm,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'New name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            widget.onConfirm(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              widget.onConfirm(name);
            }
          },
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

/// File system item model
class FileSystemItem {
  final String name;
  final FileSystemItemType type;
  final String path;
  final Map<String, FileSystemItem>? children;

  FileSystemItem({
    required this.name,
    required this.type,
    required this.path,
    this.children,
  });
}

/// File system item types
enum FileSystemItemType {
  file,
  folder,
}