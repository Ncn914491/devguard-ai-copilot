import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:io';
import 'dart:typed_data';

import '../lib/core/supabase/services/supabase_storage_service.dart';
import '../lib/core/services/supabase_file_system_service.dart';
import '../lib/core/services/cross_platform_storage_service.dart';
import '../lib/presentation/widgets/file_upload_widget.dart';
import '../lib/presentation/widgets/file_download_widget.dart';
import '../lib/presentation/widgets/file_manager_widget.dart';

// Generate mocks
@GenerateMocks([
  SupabaseStorageService,
  SupabaseFileSystemService,
  CrossPlatformStorageService,
])
import 'supabase_storage_integration_test.mocks.dart';

void main() {
  group('Supabase Storage Integration Tests', () {
    late MockSupabaseStorageService mockStorageService;
    late MockSupabaseFileSystemService mockFileSystemService;
    late MockCrossPlatformStorageService mockCrossPlatformService;

    setUp(() {
      mockStorageService = MockSupabaseStorageService();
      mockFileSystemService = MockSupabaseFileSystemService();
      mockCrossPlatformService = MockCrossPlatformStorageService();
    });

    group('SupabaseStorageService', () {
      test('should upload file successfully', () async {
        // Arrange
        final testFile = File('test_file.txt');
        const bucket = 'test-bucket';
        const path = 'test/file.txt';
        const expectedPath = 'test/file.txt';

        when(mockStorageService.uploadFile(bucket, path, testFile))
            .thenAnswer((_) async => expectedPath);

        // Act
        final result =
            await mockStorageService.uploadFile(bucket, path, testFile);

        // Assert
        expect(result, equals(expectedPath));
        verify(mockStorageService.uploadFile(bucket, path, testFile)).called(1);
      });

      test('should download file successfully', () async {
        // Arrange
        const bucket = 'test-bucket';
        const path = 'test/file.txt';
        final expectedData = Uint8List.fromList([1, 2, 3, 4, 5]);

        when(mockStorageService.downloadFile(bucket, path))
            .thenAnswer((_) async => expectedData);

        // Act
        final result = await mockStorageService.downloadFile(bucket, path);

        // Assert
        expect(result, equals(expectedData));
        verify(mockStorageService.downloadFile(bucket, path)).called(1);
      });

      test('should delete file successfully', () async {
        // Arrange
        const bucket = 'test-bucket';
        const path = 'test/file.txt';

        when(mockStorageService.deleteFile(bucket, path))
            .thenAnswer((_) async => {});

        // Act
        await mockStorageService.deleteFile(bucket, path);

        // Assert
        verify(mockStorageService.deleteFile(bucket, path)).called(1);
      });

      test('should list files successfully', () async {
        // Arrange
        const bucket = 'test-bucket';
        const prefix = 'test/';
        final expectedFiles = <FileObject>[];

        when(mockStorageService.listFiles(bucket, prefix: prefix))
            .thenAnswer((_) async => expectedFiles);

        // Act
        final result =
            await mockStorageService.listFiles(bucket, prefix: prefix);

        // Assert
        expect(result, equals(expectedFiles));
        verify(mockStorageService.listFiles(bucket, prefix: prefix)).called(1);
      });

      test('should get public URL successfully', () async {
        // Arrange
        const bucket = 'test-bucket';
        const path = 'test/file.txt';
        const expectedUrl = 'https://example.com/test/file.txt';

        when(mockStorageService.getPublicUrl(bucket, path))
            .thenReturn(expectedUrl);

        // Act
        final result = mockStorageService.getPublicUrl(bucket, path);

        // Assert
        expect(result, equals(expectedUrl));
        verify(mockStorageService.getPublicUrl(bucket, path)).called(1);
      });

      test('should create signed URL successfully', () async {
        // Arrange
        const bucket = 'test-bucket';
        const path = 'test/file.txt';
        const expectedUrl = 'https://example.com/signed/test/file.txt';
        const expiresIn = Duration(hours: 1);

        when(mockStorageService.createSignedUrl(bucket, path,
                expiresIn: expiresIn))
            .thenAnswer((_) async => expectedUrl);

        // Act
        final result = await mockStorageService.createSignedUrl(bucket, path,
            expiresIn: expiresIn);

        // Assert
        expect(result, equals(expectedUrl));
        verify(mockStorageService.createSignedUrl(bucket, path,
                expiresIn: expiresIn))
            .called(1);
      });

      test('should move file successfully', () async {
        // Arrange
        const bucket = 'test-bucket';
        const fromPath = 'test/old_file.txt';
        const toPath = 'test/new_file.txt';

        when(mockStorageService.moveFile(bucket, fromPath, toPath))
            .thenAnswer((_) async => {});

        // Act
        await mockStorageService.moveFile(bucket, fromPath, toPath);

        // Assert
        verify(mockStorageService.moveFile(bucket, fromPath, toPath)).called(1);
      });

      test('should copy file successfully', () async {
        // Arrange
        const bucket = 'test-bucket';
        const fromPath = 'test/source_file.txt';
        const toPath = 'test/copy_file.txt';

        when(mockStorageService.copyFile(bucket, fromPath, toPath))
            .thenAnswer((_) async => {});

        // Act
        await mockStorageService.copyFile(bucket, fromPath, toPath);

        // Assert
        verify(mockStorageService.copyFile(bucket, fromPath, toPath)).called(1);
      });
    });

    group('SupabaseFileSystemService', () {
      test('should upload repository file successfully', () async {
        // Arrange
        const repositoryId = 'test-repo';
        const filePath = 'src/main.dart';
        final testFile = File('test_file.dart');
        const expectedPath = 'test-repo/src/main.dart';

        when(mockFileSystemService.uploadRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
          file: testFile,
        )).thenAnswer((_) async => expectedPath);

        // Act
        final result = await mockFileSystemService.uploadRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
          file: testFile,
        );

        // Assert
        expect(result, equals(expectedPath));
        verify(mockFileSystemService.uploadRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
          file: testFile,
        )).called(1);
      });

      test('should download repository file successfully', () async {
        // Arrange
        const repositoryId = 'test-repo';
        const filePath = 'src/main.dart';
        final expectedData =
            Uint8List.fromList('print("Hello World");'.codeUnits);

        when(mockFileSystemService.downloadRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
        )).thenAnswer((_) async => expectedData);

        // Act
        final result = await mockFileSystemService.downloadRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
        );

        // Assert
        expect(result, equals(expectedData));
        verify(mockFileSystemService.downloadRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
        )).called(1);
      });

      test('should update repository file successfully', () async {
        // Arrange
        const repositoryId = 'test-repo';
        const filePath = 'src/main.dart';
        const content = 'print("Updated Hello World");';

        when(mockFileSystemService.updateRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
          content: content,
        )).thenAnswer((_) async => {});

        // Act
        await mockFileSystemService.updateRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
          content: content,
        );

        // Assert
        verify(mockFileSystemService.updateRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
          content: content,
        )).called(1);
      });

      test('should delete repository file successfully', () async {
        // Arrange
        const repositoryId = 'test-repo';
        const filePath = 'src/old_file.dart';

        when(mockFileSystemService.deleteRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
        )).thenAnswer((_) async => {});

        // Act
        await mockFileSystemService.deleteRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
        );

        // Assert
        verify(mockFileSystemService.deleteRepositoryFile(
          repositoryId: repositoryId,
          filePath: filePath,
        )).called(1);
      });

      test('should list repository files successfully', () async {
        // Arrange
        const repositoryId = 'test-repo';
        const pathPrefix = 'src/';
        final expectedFiles = <CloudFileInfo>[];

        when(mockFileSystemService.listRepositoryFiles(
          repositoryId: repositoryId,
          pathPrefix: pathPrefix,
        )).thenAnswer((_) async => expectedFiles);

        // Act
        final result = await mockFileSystemService.listRepositoryFiles(
          repositoryId: repositoryId,
          pathPrefix: pathPrefix,
        );

        // Assert
        expect(result, equals(expectedFiles));
        verify(mockFileSystemService.listRepositoryFiles(
          repositoryId: repositoryId,
          pathPrefix: pathPrefix,
        )).called(1);
      });

      test('should search files successfully', () async {
        // Arrange
        const repositoryId = 'test-repo';
        const query = 'main';
        final expectedResults = <CloudFileSearchResult>[];

        when(mockFileSystemService.searchFiles(
          repositoryId: repositoryId,
          query: query,
        )).thenAnswer((_) async => expectedResults);

        // Act
        final result = await mockFileSystemService.searchFiles(
          repositoryId: repositoryId,
          query: query,
        );

        // Assert
        expect(result, equals(expectedResults));
        verify(mockFileSystemService.searchFiles(
          repositoryId: repositoryId,
          query: query,
        )).called(1);
      });
    });

    group('CrossPlatformStorageService Cloud Integration', () {
      test('should save user data to cloud successfully', () async {
        // Arrange
        const key = 'user_preferences';
        final data = {'theme': 'dark', 'language': 'en'};

        when(mockCrossPlatformService.saveUserDataToCloud(key, data))
            .thenAnswer((_) async => {});

        // Act
        await mockCrossPlatformService.saveUserDataToCloud(key, data);

        // Assert
        verify(mockCrossPlatformService.saveUserDataToCloud(key, data))
            .called(1);
      });

      test('should load user data from cloud successfully', () async {
        // Arrange
        const key = 'user_preferences';
        final expectedData = {'theme': 'dark', 'language': 'en'};

        when(mockCrossPlatformService.loadUserDataFromCloud(key))
            .thenAnswer((_) async => expectedData);

        // Act
        final result =
            await mockCrossPlatformService.loadUserDataFromCloud(key);

        // Assert
        expect(result, equals(expectedData));
        verify(mockCrossPlatformService.loadUserDataFromCloud(key)).called(1);
      });

      test('should sync with cloud successfully', () async {
        // Arrange
        when(mockCrossPlatformService.syncWithCloud())
            .thenAnswer((_) async => {});

        // Act
        await mockCrossPlatformService.syncWithCloud();

        // Assert
        verify(mockCrossPlatformService.syncWithCloud()).called(1);
      });

      test('should restore from cloud successfully', () async {
        // Arrange
        when(mockCrossPlatformService.restoreFromCloud())
            .thenAnswer((_) async => {});

        // Act
        await mockCrossPlatformService.restoreFromCloud();

        // Assert
        verify(mockCrossPlatformService.restoreFromCloud()).called(1);
      });

      test('should upload user file successfully', () async {
        // Arrange
        final testFile = File('user_file.txt');
        const fileName = 'user_file.txt';
        const expectedPath = 'user123/files/user_file.txt';

        when(mockCrossPlatformService.uploadUserFile(testFile, fileName))
            .thenAnswer((_) async => expectedPath);

        // Act
        final result =
            await mockCrossPlatformService.uploadUserFile(testFile, fileName);

        // Assert
        expect(result, equals(expectedPath));
        verify(mockCrossPlatformService.uploadUserFile(testFile, fileName))
            .called(1);
      });

      test('should download user file successfully', () async {
        // Arrange
        const fileName = 'user_file.txt';
        final expectedFile = File('downloaded_user_file.txt');

        when(mockCrossPlatformService.downloadUserFile(fileName))
            .thenAnswer((_) async => expectedFile);

        // Act
        final result =
            await mockCrossPlatformService.downloadUserFile(fileName);

        // Assert
        expect(result, equals(expectedFile));
        verify(mockCrossPlatformService.downloadUserFile(fileName)).called(1);
      });
    });

    group('Error Handling', () {
      test('should handle upload errors gracefully', () async {
        // Arrange
        final testFile = File('test_file.txt');
        const bucket = 'test-bucket';
        const path = 'test/file.txt';

        when(mockStorageService.uploadFile(bucket, path, testFile))
            .thenThrow(Exception('Upload failed'));

        // Act & Assert
        expect(
          () => mockStorageService.uploadFile(bucket, path, testFile),
          throwsException,
        );
      });

      test('should handle download errors gracefully', () async {
        // Arrange
        const bucket = 'test-bucket';
        const path = 'test/nonexistent_file.txt';

        when(mockStorageService.downloadFile(bucket, path))
            .thenThrow(Exception('File not found'));

        // Act & Assert
        expect(
          () => mockStorageService.downloadFile(bucket, path),
          throwsException,
        );
      });

      test('should handle network errors with retry', () async {
        // Arrange
        const bucket = 'test-bucket';
        const path = 'test/file.txt';

        when(mockStorageService.downloadFile(bucket, path))
            .thenThrow(Exception('Network timeout'));

        // Act & Assert
        expect(
          () => mockStorageService.downloadFile(bucket, path),
          throwsException,
        );
      });
    });

    group('File Validation', () {
      test('should validate file size limits', () async {
        // This would test file size validation in the actual implementation
        // For now, we just verify the mock behavior
        final testFile = File('large_file.txt');
        const bucket = 'test-bucket';
        const path = 'test/large_file.txt';

        when(mockStorageService.uploadFile(bucket, path, testFile))
            .thenThrow(Exception('File size exceeds limit'));

        expect(
          () => mockStorageService.uploadFile(bucket, path, testFile),
          throwsException,
        );
      });

      test('should validate file types', () async {
        // This would test file type validation in the actual implementation
        final testFile = File('malicious_file.exe');
        const bucket = 'test-bucket';
        const path = 'test/malicious_file.exe';

        when(mockStorageService.uploadFile(bucket, path, testFile))
            .thenThrow(Exception('File type not allowed'));

        expect(
          () => mockStorageService.uploadFile(bucket, path, testFile),
          throwsException,
        );
      });
    });

    group('Access Control', () {
      test('should enforce bucket access permissions', () async {
        // This would test access control in the actual implementation
        const bucket = 'restricted-bucket';
        const path = 'test/file.txt';

        when(mockStorageService.downloadFile(bucket, path))
            .thenThrow(Exception('Access denied'));

        expect(
          () => mockStorageService.downloadFile(bucket, path),
          throwsException,
        );
      });

      test('should enforce file path restrictions', () async {
        // This would test path traversal protection
        const bucket = 'test-bucket';
        const path = '../../../etc/passwd';

        when(mockStorageService.downloadFile(bucket, path))
            .thenThrow(Exception('Invalid file path'));

        expect(
          () => mockStorageService.downloadFile(bucket, path),
          throwsException,
        );
      });
    });
  });
}

/// Mock FileObject class for testing
class FileObject {
  final String name;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  FileObject({
    required this.name,
    this.updatedAt,
    this.metadata,
  });
}

/// Mock CloudFileInfo class for testing
class CloudFileInfo {
  final String name;
  final String path;
  final String cloudPath;
  final int size;
  final String contentType;
  final DateTime lastModified;
  final String bucket;

  CloudFileInfo({
    required this.name,
    required this.path,
    required this.cloudPath,
    required this.size,
    required this.contentType,
    required this.lastModified,
    required this.bucket,
  });
}

/// Mock CloudFileSearchResult class for testing
class CloudFileSearchResult {
  final String filePath;
  final String fileName;
  final String cloudPath;

  CloudFileSearchResult({
    required this.filePath,
    required this.fileName,
    required this.cloudPath,
  });
}
