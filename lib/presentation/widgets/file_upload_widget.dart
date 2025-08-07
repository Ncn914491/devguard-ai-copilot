import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/supabase/services/supabase_storage_service.dart';
import '../../core/auth/auth_service.dart';

/// Widget for uploading files to Supabase Storage with progress tracking
/// Requirements: 5.1, 5.2, 5.3, 5.4 - File upload with proper access controls
class FileUploadWidget extends StatefulWidget {
  final String bucket;
  final String? pathPrefix;
  final List<String>? allowedExtensions;
  final int? maxFileSizeMB;
  final Function(String filePath)? onUploadComplete;
  final Function(String error)? onUploadError;
  final bool showProgress;

  const FileUploadWidget({
    super.key,
    required this.bucket,
    this.pathPrefix,
    this.allowedExtensions,
    this.maxFileSizeMB = 50,
    this.onUploadComplete,
    this.onUploadError,
    this.showProgress = true,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  final _storageService = SupabaseStorageService.instance;
  final _authService = AuthService.instance;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _selectedFileName;
  String? _uploadError;

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
                const Icon(Icons.cloud_upload, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Upload File',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedFileName != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedFileName!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_isUploading)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setState(() {
                            _selectedFileName = null;
                            _uploadError = null;
                          });
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isUploading && widget.showProgress) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_uploadProgress * 100).toInt()}% uploaded',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            if (_uploadError != null) ...[
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
                        _uploadError!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _selectFile,
                    icon: const Icon(Icons.folder_open),
                    label: Text(_selectedFileName == null
                        ? 'Select File'
                        : 'Change File'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_selectedFileName == null || _isUploading)
                        ? null
                        : _uploadFile,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.allowedExtensions != null ||
                widget.maxFileSizeMB != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.allowedExtensions != null)
                      Text(
                        'Allowed types: ${widget.allowedExtensions!.join(', ')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    if (widget.maxFileSizeMB != null)
                      Text(
                        'Max size: ${widget.maxFileSizeMB}MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectFile() async {
    try {
      setState(() {
        _uploadError = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: widget.allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: widget.allowedExtensions,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check file size
        if (widget.maxFileSizeMB != null &&
            file.size > (widget.maxFileSizeMB! * 1024 * 1024)) {
          setState(() {
            _uploadError = 'File size exceeds ${widget.maxFileSizeMB}MB limit';
          });
          return;
        }

        setState(() {
          _selectedFileName = file.name;
        });
      }
    } catch (e) {
      setState(() {
        _uploadError = 'Error selecting file: ${e.toString()}';
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFileName == null) return;

    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _uploadError = null;
      });

      // Get the file path from the selected file
      final result = await FilePicker.platform.pickFiles(
        type: widget.allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: widget.allowedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isUploading = false;
          _uploadError = 'No file selected';
        });
        return;
      }

      final platformFile = result.files.first;
      if (platformFile.path == null) {
        setState(() {
          _isUploading = false;
          _uploadError = 'Cannot access file path';
        });
        return;
      }

      final file = File(platformFile.path!);

      // Generate file path with user ID and timestamp for uniqueness
      final userId = _authService.currentUser?.id ?? 'anonymous';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFileName!.split('.').last;
      final fileName = '${timestamp}_${_selectedFileName!}';

      String filePath = fileName;
      if (widget.pathPrefix != null) {
        filePath = '${widget.pathPrefix}/$userId/$fileName';
      } else {
        filePath = '$userId/$fileName';
      }

      if (widget.showProgress) {
        // Upload with progress tracking
        await for (final progress in _storageService.uploadWithProgress(
          widget.bucket,
          filePath,
          file,
        )) {
          setState(() {
            _uploadProgress = progress;
          });
        }
      } else {
        // Upload without progress tracking
        await _storageService.uploadFile(
          widget.bucket,
          filePath,
          file,
        );
      }

      setState(() {
        _isUploading = false;
        _selectedFileName = null;
        _uploadProgress = 0.0;
      });

      // Notify parent widget
      widget.onUploadComplete?.call(filePath);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = 'Upload failed: ${e.toString()}';
      });

      widget.onUploadError?.call(e.toString());
    }
  }
}
