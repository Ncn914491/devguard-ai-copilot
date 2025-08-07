import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../../core/supabase/services/supabase_storage_service.dart';
import '../../core/utils/platform_utils.dart';

/// Widget for downloading files from Supabase Storage
/// Requirements: 5.1, 5.2, 5.3, 5.4 - File download with proper access controls
class FileDownloadWidget extends StatefulWidget {
  final String bucket;
  final String filePath;
  final String? displayName;
  final bool showFileInfo;
  final Function(Uint8List data)? onDownloadComplete;
  final Function(String error)? onDownloadError;

  const FileDownloadWidget({
    super.key,
    required this.bucket,
    required this.filePath,
    this.displayName,
    this.showFileInfo = true,
    this.onDownloadComplete,
    this.onDownloadError,
  });

  @override
  State<FileDownloadWidget> createState() => _FileDownloadWidgetState();
}

class _FileDownloadWidgetState extends State<FileDownloadWidget> {
  final _storageService = SupabaseStorageService.instance;

  bool _isDownloading = false;
  bool _isLoadingInfo = false;
  Map<String, dynamic>? _fileInfo;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    if (widget.showFileInfo) {
      _loadFileInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _getFileIcon(),
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.displayName ?? path.basename(widget.filePath),
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (widget.showFileInfo) ...[
              const SizedBox(height: 12),
              if (_isLoadingInfo)
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_fileInfo != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                          'Size', _formatFileSize(_fileInfo!['size'] ?? 0)),
                      if (_fileInfo!['lastModified'] != null)
                        _buildInfoRow('Modified',
                            _formatDate(_fileInfo!['lastModified'])),
                      _buildInfoRow(
                          'Type', _fileInfo!['contentType'] ?? 'Unknown'),
                    ],
                  ),
                ),
              ],
            ],
            if (_downloadError != null) ...[
              const SizedBox(height: 12),
              Container(
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
                        _downloadError!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : _downloadFile,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isDownloading ? 'Downloading...' : 'Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _copyPublicUrl,
                  icon: const Icon(Icons.link),
                  label: const Text('Copy Link'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadFileInfo() async {
    if (_isLoadingInfo) return;

    setState(() {
      _isLoadingInfo = true;
      _downloadError = null;
    });

    try {
      final info =
          await _storageService.getFileInfo(widget.bucket, widget.filePath);
      setState(() {
        _fileInfo = info;
        _isLoadingInfo = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingInfo = false;
        _downloadError = 'Failed to load file info: ${e.toString()}';
      });
    }
  }

  Future<void> _downloadFile() async {
    setState(() {
      _isDownloading = true;
      _downloadError = null;
    });

    try {
      final data =
          await _storageService.downloadFile(widget.bucket, widget.filePath);

      setState(() {
        _isDownloading = false;
      });

      // Notify parent widget
      widget.onDownloadComplete?.call(data);

      // Save file to downloads directory if on desktop/mobile
      if (PlatformUtils.isDesktop || PlatformUtils.isMobile) {
        await _saveFileToDownloads(data);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadError = 'Download failed: ${e.toString()}';
      });

      widget.onDownloadError?.call(e.toString());
    }
  }

  Future<void> _saveFileToDownloads(Uint8List data) async {
    try {
      // Get downloads directory path
      final downloadsPath = PlatformUtils.getDownloadsPath();
      final fileName = widget.displayName ?? path.basename(widget.filePath);
      final filePath = path.join(downloadsPath, fileName);

      // Create file and write data
      final file = File(filePath);
      await file.writeAsBytes(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved to: $filePath'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to save file to downloads: $e');
    }
  }

  void _copyPublicUrl() {
    try {
      final url = _storageService.getPublicUrl(widget.bucket, widget.filePath);

      // Copy to clipboard (would need clipboard package for full implementation)
      // For now, just show the URL
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Public URL'),
          content: SelectableText(url),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _downloadError = 'Failed to get public URL: ${e.toString()}';
      });
    }
  }

  IconData _getFileIcon() {
    final extension = path.extension(widget.filePath).toLowerCase();

    switch (extension) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
        return Icons.image;
      case '.mp4':
      case '.avi':
      case '.mov':
        return Icons.video_file;
      case '.mp3':
      case '.wav':
      case '.flac':
        return Icons.audio_file;
      case '.zip':
      case '.rar':
      case '.7z':
        return Icons.archive;
      case '.txt':
      case '.md':
        return Icons.text_snippet;
      case '.json':
      case '.xml':
      case '.yaml':
      case '.yml':
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
    if (date == null) return 'Unknown';

    DateTime dateTime;
    if (date is String) {
      dateTime = DateTime.tryParse(date) ?? DateTime.now();
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'Unknown';
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
