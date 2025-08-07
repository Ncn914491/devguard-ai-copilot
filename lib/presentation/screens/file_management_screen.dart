import 'package:flutter/material.dart';
import '../widgets/file_manager_widget.dart';
import '../widgets/file_upload_widget.dart';
import '../widgets/file_download_widget.dart';
import '../../core/supabase/services/supabase_storage_service.dart';
import '../../core/auth/auth_service.dart';

/// Screen for managing files using Supabase Storage
/// Requirements: 5.1, 5.2, 5.3, 5.4 - File management with proper access controls
class FileManagementScreen extends StatefulWidget {
  const FileManagementScreen({super.key});

  @override
  State<FileManagementScreen> createState() => _FileManagementScreenState();
}

class _FileManagementScreenState extends State<FileManagementScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Management'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Project Files', icon: Icon(Icons.folder)),
            Tab(text: 'User Files', icon: Icon(Icons.person)),
            Tab(text: 'Documents', icon: Icon(Icons.description)),
            Tab(text: 'Temp Files', icon: Icon(Icons.access_time)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProjectFilesTab(),
          _buildUserFilesTab(),
          _buildDocumentsTab(),
          _buildTempFilesTab(),
        ],
      ),
    );
  }

  Widget _buildProjectFilesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Project Files',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage project-related files such as documentation, assets, and configuration files.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FileManagerWidget(
              bucket: SupabaseStorageService.projectFilesBucket,
              pathPrefix: 'projects',
              allowUpload: _authService.hasPermission('commit_code'),
              allowDownload: true,
              allowDelete: _authService.hasPermission('commit_code'),
              allowedExtensions: [
                'md',
                'txt',
                'json',
                'yaml',
                'yml',
                'xml',
                'pdf',
                'doc',
                'docx',
                'png',
                'jpg',
                'jpeg',
                'gif'
              ],
              maxFileSizeMB: 25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserFilesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Personal Files',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your personal files and user-specific data. Only you can access these files.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FileManagerWidget(
              bucket: SupabaseStorageService.userAvatarsBucket,
              pathPrefix: _authService.currentUser?.id,
              allowUpload: true,
              allowDownload: true,
              allowDelete: true,
              maxFileSizeMB: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Documents',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Shared documents and team resources. Access depends on your role and permissions.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FileManagerWidget(
              bucket: SupabaseStorageService.documentsBucket,
              pathPrefix: 'shared',
              allowUpload: _authService.hasPermission('manage_team'),
              allowDownload: true,
              allowDelete: _authService.currentUser?.role == 'admin',
              allowedExtensions: [
                'pdf',
                'doc',
                'docx',
                'xls',
                'xlsx',
                'ppt',
                'pptx',
                'txt',
                'md',
                'rtf'
              ],
              maxFileSizeMB: 50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTempFilesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Temporary Files',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Temporary files and uploads. These files may be automatically deleted after a period of time.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FileManagerWidget(
              bucket: SupabaseStorageService.tempFilesBucket,
              pathPrefix: _authService.currentUser?.id,
              allowUpload: true,
              allowDownload: true,
              allowDelete: true,
              maxFileSizeMB: 100,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone file upload demo widget
class FileUploadDemo extends StatelessWidget {
  const FileUploadDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Upload Demo'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload to Project Files',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload files to the project files bucket with proper access controls.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FileUploadWidget(
              bucket: SupabaseStorageService.projectFilesBucket,
              pathPrefix: 'demo',
              allowedExtensions: [
                'pdf',
                'doc',
                'docx',
                'txt',
                'md',
                'png',
                'jpg'
              ],
              maxFileSizeMB: 25,
              onUploadComplete: (filePath) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('File uploaded successfully: $filePath'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              onUploadError: (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Upload failed: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone file download demo widget
class FileDownloadDemo extends StatefulWidget {
  const FileDownloadDemo({super.key});

  @override
  State<FileDownloadDemo> createState() => _FileDownloadDemoState();
}

class _FileDownloadDemoState extends State<FileDownloadDemo> {
  final _bucketController = TextEditingController(
    text: SupabaseStorageService.projectFilesBucket,
  );
  final _pathController = TextEditingController();

  @override
  void dispose() {
    _bucketController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Download Demo'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download File',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the bucket and file path to download a file from Supabase Storage.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _bucketController,
                      decoration: const InputDecoration(
                        labelText: 'Bucket Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pathController,
                      decoration: const InputDecoration(
                        labelText: 'File Path',
                        hintText: 'e.g., demo/example.pdf',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_pathController.text.isNotEmpty)
              FileDownloadWidget(
                bucket: _bucketController.text,
                filePath: _pathController.text,
                onDownloadComplete: (data) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('File downloaded: ${data.length} bytes'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                onDownloadError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Download failed: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {}); // Refresh to show download widget
              },
              child: const Text('Update Download Widget'),
            ),
          ],
        ),
      ),
    );
  }
}
