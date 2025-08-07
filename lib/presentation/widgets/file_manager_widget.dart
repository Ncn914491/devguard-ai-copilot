import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/services/supabase_storage_service.dart';
import '../../core/auth/auth_service.dart';
import 'file_upload_widget.dart';
import 'file_download_widget.dart';

/// Comprehensive file manager widget for Supabase Storage
/// Requirements: 5.1, 5.2, 5.3, 5.4 - File management with proper access controls
class FileManagerWidget extends StatefulWidget {
  final String bucket;
  final String? pathPrefix;
  final bool allowUpload;
  final bool allowDownload;
  final bool allowDelete;
  final List<String>? allowedExtensions;
  final int? maxFileSizeMB;

  const FileManagerWidget({
    super.key,
    required this.bucket,
    this.pathPrefix,
    this.allowUpload = true,
    this.allowDownload = true,
    this.allowDelete = false,
    this.allowedExtensions,
    this.maxFileSizeMB = 50,
  });

  @override
  State<FileManagerWidget> createState() => _FileManagerWidgetState();
}

class _FileManagerWidgetState extends State<FileManagerWidget>
    with SingleTickerProviderStateMixin {
  final _storageService = SupabaseStorageService.instance;
  final _authService = AuthService.instance;

  late TabController _tabController;
  List<FileObject> _files = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.allowUpload ? 2 : 1,
      vsync: this,
    );
    _loadFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'File Manager - ${widget.bucket}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadFiles,
                  tooltip: 'Refresh files',
                ),
              ],
            ),
          ),
          if (widget.allowUpload)
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Files', icon: Icon(Icons.folder)),
                Tab(text: 'Upload', icon: Icon(Icons.cloud_upload)),
              ],
            ),
          Expanded(
            child: widget.allowUpload
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFilesTab(),
                      _buildUploadTab(),
                    ],
                  )
                : _buildFilesTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _error = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_files.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No files found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return _buildFileItem(file);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FileUploadWidget(
        bucket: widget.bucket,
        pathPrefix: widget.pathPrefix,
        allowedExtensions: widget.allowedExtensions,
        maxFileSizeMB: widget.maxFileSizeMB,
        onUploadComplete: (filePath) {
          // Refresh files list after upload
          _loadFiles();
          // Switch to files tab to show the uploaded file
          _tabController.animateTo(0);
        },
        onUploadError: (error) {
          setState(() {
            _error = error;
          });
        },
      ),
    );
  }

  Widget _buildFileItem(FileObject file) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _getFileIcon(file.name),
          color: Colors.blue,
        ),
        title: Text(
          file.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Size: ${_formatFileSize(file.metadata?['size'] ?? 0)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (file.updatedAt != null)
              Text(
                'Modified: ${_formatDate(file.updatedAt!)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.allowDownload)
              IconButton(
                icon: const Icon(Icons.download, color: Colors.green),
                onPressed: () => _showDownloadDialog(file),
                tooltip: 'Download',
              ),
            if (widget.allowDelete && _canDeleteFile(file))
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteConfirmation(file),
                tooltip: 'Delete',
              ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.grey),
              onPressed: () => _showFileInfo(file),
              tooltip: 'File Info',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = await _storageService.listFiles(
        widget.bucket,
        prefix: widget.pathPrefix,
      );

      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load files: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _showDownloadDialog(FileObject file) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(16),
          child: FileDownloadWidget(
            bucket: widget.bucket,
            filePath: file.name,
            displayName: file.name,
            onDownloadComplete: (data) {
              Navigator.of(context).pop();
            },
            onDownloadError: (error) {
              setState(() {
                _error = error;
              });
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(FileObject file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteFile(file);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFile(FileObject file) async {
    try {
      await _storageService.deleteFile(widget.bucket, file.name);

      // Refresh files list
      await _loadFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to delete file: ${e.toString()}';
      });
    }
  }

  void _showFileInfo(FileObject file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('File Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', file.name),
            _buildInfoRow('Size', _formatFileSize(file.metadata?['size'] ?? 0)),
            if (file.updatedAt != null)
              _buildInfoRow('Modified', _formatDate(file.updatedAt!)),
            _buildInfoRow('Bucket', widget.bucket),
            if (file.metadata?['mimetype'] != null)
              _buildInfoRow('Type', file.metadata!['mimetype']),
          ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  bool _canDeleteFile(FileObject file) {
    // Only allow deletion if user is admin or owns the file
    final currentUser = _authService.currentUser;
    if (currentUser == null) return false;

    // Admin can delete any file
    if (currentUser.role == 'admin') return true;

    // Check if file belongs to current user (based on path structure)
    if (widget.pathPrefix != null) {
      return file.name.startsWith('${currentUser.id}/');
    }

    return false;
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'txt':
      case 'md':
        return Icons.text_snippet;
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(dynamic date) {
    DateTime dateTime;
    if (date is String) {
      dateTime = DateTime.parse(date);
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'Unknown';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
