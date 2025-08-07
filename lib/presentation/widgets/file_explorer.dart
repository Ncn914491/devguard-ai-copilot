import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/file_system_service.dart';
import '../../core/services/supabase_file_system_service.dart';
import '../../core/api/repository_api.dart';
import '../../core/api/supabase_repository_api.dart';
import 'merge_conflict_resolver.dart';
import 'file_upload_widget.dart';
import 'file_manager_widget.dart';

/// File explorer widget for repository navigation
class FileExplorer extends StatefulWidget {
  final Function(String) onFileSelected;
  final Function(String) onFileCreated;

  const FileExplorer({
    super.key,
    required this.onFileSelected,
    required this.onFileCreated,
  });

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  final _authService = AuthService.instance;
  final _repositoryAPI = RepositoryAPI.instance;
  final _supabaseRepositoryAPI = SupabaseRepositoryAPI.instance;
  final _fileSystemService = FileSystemService.instance;
  final _supabaseFileSystemService = SupabaseFileSystemService.instance;

  final Map<String, bool> _expandedFolders = {};
  String? _selectedFile;
  bool _useSupabaseStorage = true; // Toggle for using Supabase Storage
  bool _showFileManager = false;

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
          gitStatus: GitFileStatus.modified,
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

  Color _getGitStatusColor(GitFileStatus status) {
    switch (status) {
      case GitFileStatus.modified:
        return Colors.orange;
      case GitFileStatus.added:
        return Colors.green;
      case GitFileStatus.deleted:
        return Colors.red;
      case GitFileStatus.untracked:
        return Colors.blue;
      case GitFileStatus.conflicted:
        return Colors.purple;
      case GitFileStatus.clean:
        return Colors.transparent;
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

  void _showContextMenu(
      BuildContext context, String path, FileSystemItem item) {
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
    ).then((value) {
      if (value != null) {
        _handleContextMenuAction(value, path, item);
      }
    });
  }

  List<PopupMenuEntry<String>> _buildContextMenuItems(
      String path, FileSystemItem item) {
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

      // Add git operations if user has permissions
      if (_authService.hasPermission('commit_code')) {
        items.addAll([
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'git_add',
            child: Row(
              children: [
                Icon(Icons.add_circle, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Text('Git Add'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'git_diff',
            child: Row(
              children: [
                Icon(Icons.compare_arrows, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                Text('Show Diff'),
              ],
            ),
          ),
          if (item.gitStatus == GitFileStatus.modified)
            const PopupMenuItem<String>(
              value: 'git_restore',
              child: Row(
                children: [
                  Icon(Icons.restore, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Restore File'),
                ],
              ),
            ),
        ]);
      }
    }

    return items;
  }

  void _handleContextMenuAction(
      String action, String path, FileSystemItem item) {
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
      case 'git_add':
        _gitAddFile(path);
        break;
      case 'git_diff':
        _showGitDiff(path);
        break;
      case 'git_restore':
        _gitRestoreFile(path);
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

  void _gitAddFile(String filePath) {
    if (!_authService.hasPermission('commit_code')) {
      _showPermissionError();
      return;
    }

    // Simulate git add operation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $filePath to staging area')),
    );

    // In a real implementation, this would update the git status
    setState(() {
      // Update file status to added
    });
  }

  void _showGitDiff(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Git Diff - $filePath'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              '''@@ -1,5 +1,7 @@
 import 'package:flutter/material.dart';
+import 'package:flutter/services.dart';
 
 void main() {
   runApp(MyApp());
 }
+
+// Added new comment''',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _gitRestoreFile(String filePath) {
    if (!_authService.hasPermission('commit_code')) {
      _showPermissionError();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore File'),
        content: Text(
            'Are you sure you want to restore "$filePath" to its last committed state? This will discard all changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Restored $filePath')),
              );
              // In a real implementation, this would restore the file
              setState(() {
                // Update file status to clean
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                // Storage toggle
                Tooltip(
                  message: _useSupabaseStorage
                      ? 'Using Supabase Storage'
                      : 'Using Local Storage',
                  child: IconButton(
                    icon: Icon(
                      _useSupabaseStorage ? Icons.cloud : Icons.folder,
                      size: 16,
                      color: _useSupabaseStorage ? Colors.blue : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _useSupabaseStorage = !_useSupabaseStorage;
                      });
                    },
                  ),
                ),
                // File manager toggle
                Tooltip(
                  message: 'File Manager',
                  child: IconButton(
                    icon: const Icon(Icons.upload_file, size: 16),
                    onPressed: () {
                      setState(() {
                        _showFileManager = !_showFileManager;
                      });
                    },
                  ),
                ),
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

          // File manager (when enabled)
          if (_showFileManager) ...[
            Container(
              height: 300,
              padding: const EdgeInsets.all(8),
              child: FileManagerWidget(
                bucket: _useSupabaseStorage
                    ? SupabaseFileSystemService.projectFilesBucket
                    : 'local-files',
                pathPrefix: 'explorer',
                allowUpload: _authService.hasPermission('commit_code'),
                allowDownload: true,
                allowDelete: _authService.hasPermission('commit_code'),
                allowedExtensions: const [
                  'dart',
                  'js',
                  'ts',
                  'html',
                  'css',
                  'json',
                  'yaml',
                  'yml',
                  'md',
                  'txt',
                  'py',
                  'java',
                  'cpp',
                  'c',
                  'h'
                ],
                maxFileSizeMB: 10,
              ),
            ),
            const Divider(height: 1),
          ],

          // File tree
          Expanded(
            child: _useSupabaseStorage
                ? _buildSupabaseFileTree()
                : ListView(
                    children: _buildFileTree(_fileSystem, 0),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupabaseFileTree() {
    return FutureBuilder<List<CloudFileSystemNode>>(
      future: _loadSupabaseFiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading files',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final files = snapshot.data ?? [];
        if (files.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, color: Colors.grey, size: 48),
                SizedBox(height: 16),
                Text(
                  'No files found',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return _buildSupabaseFileItem(file);
          },
        );
      },
    );
  }

  Future<List<CloudFileSystemNode>> _loadSupabaseFiles() async {
    try {
      // For demo purposes, use a mock repository ID
      const repositoryId = 'demo-repo';

      final response =
          await _supabaseRepositoryAPI.getRepositoryFiles(repositoryId);
      if (response.success && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      throw Exception('Failed to load files: $e');
    }
  }

  Widget _buildSupabaseFileItem(CloudFileSystemNode file) {
    final isSelected = _selectedFile == file.path;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color:
            isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Icon(
          _getFileIcon(file.name),
          size: 16,
          color: Colors.blue,
        ),
        title: Text(
          file.name,
          style: TextStyle(
            fontSize: 13,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : null,
          ),
        ),
        subtitle: Text(
          '${_formatFileSize(file.size)} • ${_formatDate(file.modifiedAt)}',
          style: TextStyle(
            fontSize: 11,
            color: isSelected
                ? Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer
                    .withOpacity(0.7)
                : Colors.grey,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedFile = file.path;
          });
          widget.onFileSelected(file.path);
        },
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 14),
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'download',
              child: Row(
                children: [
                  Icon(Icons.download, size: 16),
                  SizedBox(width: 8),
                  Text('Download'),
                ],
              ),
            ),
            if (_authService.hasPermission('commit_code'))
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
          ],
          onSelected: (action) => _handleSupabaseFileAction(action, file),
        ),
      ),
    );
  }

  void _handleSupabaseFileAction(String action, CloudFileSystemNode file) {
    switch (action) {
      case 'download':
        _downloadSupabaseFile(file);
        break;
      case 'delete':
        _deleteSupabaseFile(file);
        break;
    }
  }

  Future<void> _downloadSupabaseFile(CloudFileSystemNode file) async {
    try {
      const repositoryId = 'demo-repo';
      final data = await _supabaseFileSystemService.downloadRepositoryFile(
        repositoryId: repositoryId,
        filePath: file.path,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${file.name} (${data.length} bytes)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download ${file.name}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSupabaseFile(CloudFileSystemNode file) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        const repositoryId = 'demo-repo';
        await _supabaseFileSystemService.deleteRepositoryFile(
          repositoryId: repositoryId,
          filePath: file.path,
        );

        // Refresh the file list
        setState(() {});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${file.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete ${file.name}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'dart':
        return Icons.code;
      case 'js':
      case 'ts':
        return Icons.javascript;
      case 'html':
        return Icons.web;
      case 'css':
        return Icons.style;
      case 'json':
      case 'yaml':
      case 'yml':
        return Icons.data_object;
      case 'md':
        return Icons.text_snippet;
      case 'txt':
        return Icons.description;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
                Stack(
                  children: [
                    Icon(
                      item.type == FileSystemItemType.folder
                          ? (isExpanded ? Icons.folder_open : Icons.folder)
                          : _getFileIcon(item.name),
                      size: 16,
                      color: item.type == FileSystemItemType.folder
                          ? Theme.of(context).colorScheme.primary
                          : _getFileColor(item.name),
                    ),
                    if (item.gitStatus != GitFileStatus.clean)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getGitStatusColor(item.gitStatus),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
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
  final GitFileStatus gitStatus;

  FileSystemItem({
    required this.name,
    required this.type,
    required this.path,
    this.children,
    this.gitStatus = GitFileStatus.clean,
  });
}

/// File system item types
enum FileSystemItemType {
  file,
  folder,
}

/// Git file status
enum GitFileStatus {
  clean,
  modified,
  added,
  deleted,
  untracked,
  conflicted,
}
