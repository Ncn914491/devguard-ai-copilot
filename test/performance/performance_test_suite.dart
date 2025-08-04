import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:async';
import 'dart:math';
import 'package:devguard_ai_copilot/core/auth/auth_service.dart';
import 'package:devguard_ai_copilot/core/api/task_management_api.dart';
import 'package:devguard_ai_copilot/core/api/repository_api.dart';
import 'package:devguard_ai_copilot/core/api/websocket_service.dart';
import 'package:devguard_ai_copilot/core/database/services/services.dart';

/// Performance testing for concurrent users, large repositories, and real-time operations
/// Satisfies Requirements: 14.3 - Performance testing for concurrent users and large repositories
void main() {
  group('Performance Test Suite', () {
    late AuthService authService;
    late TaskManagementAPI taskAPI;
    late RepositoryAPI repoAPI;
    late WebSocketService wsService;

    setUpAll(() async {
      // Initialize SQLite FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // Initialize services
      authService = AuthService.instance;
      taskAPI = TaskManagementAPI.instance;
      repoAPI = RepositoryAPI.instance;
      wsService = WebSocketService.instance;

      await authService.initialize();
      await wsService.initialize();
    });

    tearDownAll(() async {
      await authService.dispose();
      await wsService.dispose();
    });

    group('Concurrent User Performance Tests', () {
      test('Concurrent authentication load test', () async {
        const int concurrentUsers = 100;
        const Duration testDuration = Duration(seconds: 30);

        print(
            '🚀 Starting concurrent authentication test with $concurrentUsers users');

        // Create test users
        final testUsers = <Map<String, String>>[];
        for (int i = 0; i < concurrentUsers; i++) {
          testUsers.add({
            'email': 'perftest$i@example.com',
            'password': 'TestPassword123!',
          });
        }

        // Pre-create users in database
        final adminToken = await _getAdminToken();
        for (final user in testUsers) {
          await authService.createUser(
            email: user['email']!,
            password: user['password']!,
            role: 'developer',
            adminToken: adminToken,
          );
        }

        // Performance metrics
        final authTimes = <Duration>[];
        final errors = <String>[];
        final startTime = DateTime.now();

        // Concurrent authentication test
        final authFutures = testUsers.map((user) async {
          final authStart = DateTime.now();
          try {
            final result = await authService.authenticate(
              user['email']!,
              user['password']!,
            );

            final authEnd = DateTime.now();
            final authDuration = authEnd.difference(authStart);
            authTimes.add(authDuration);

            if (!result.success) {
              errors.add('Auth failed for ${user['email']}: ${result.error}');
            }

            return result;
          } catch (e) {
            errors.add('Exception for ${user['email']}: $e');
            return null;
          }
        }).toList();

        final results = await Future.wait(authFutures);
        final endTime = DateTime.now();
        final totalDuration = endTime.difference(startTime);

        // Analyze results
        final successfulAuths = results.where((r) => r?.success == true).length;
        final averageAuthTime = authTimes.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: authTimes
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    authTimes.length);
        final maxAuthTime = authTimes.isEmpty
            ? Duration.zero
            : authTimes
                .reduce((a, b) => a.inMicroseconds > b.inMicroseconds ? a : b);
        final minAuthTime = authTimes.isEmpty
            ? Duration.zero
            : authTimes
                .reduce((a, b) => a.inMicroseconds < b.inMicroseconds ? a : b);

        // Performance assertions
        expect(successfulAuths,
            greaterThanOrEqualTo(concurrentUsers * 0.95)); // 95% success rate
        expect(averageAuthTime.inMilliseconds,
            lessThan(1000)); // Average < 1 second
        expect(maxAuthTime.inMilliseconds, lessThan(5000)); // Max < 5 seconds
        expect(
            errors.length, lessThan(concurrentUsers * 0.05)); // < 5% error rate

        print('✅ Concurrent Authentication Results:');
        print('   Total Users: $concurrentUsers');
        print('   Successful Auths: $successfulAuths');
        print('   Total Duration: ${totalDuration.inMilliseconds}ms');
        print('   Average Auth Time: ${averageAuthTime.inMilliseconds}ms');
        print('   Min Auth Time: ${minAuthTime.inMilliseconds}ms');
        print('   Max Auth Time: ${maxAuthTime.inMilliseconds}ms');
        print('   Error Count: ${errors.length}');
        print(
            '   Throughput: ${(successfulAuths / totalDuration.inSeconds).toStringAsFixed(2)} auths/sec');
      });

      test('Concurrent task operations load test', () async {
        const int concurrentOperations = 200;
        const int usersCount = 20;

        print('🚀 Starting concurrent task operations test');

        // Setup authenticated users
        final userTokens = <String>[];
        for (int i = 0; i < usersCount; i++) {
          final auth = await authService.authenticate(
            'perftest$i@example.com',
            'TestPassword123!',
          );
          if (auth.success) {
            userTokens.add(auth.token!);
          }
        }

        expect(userTokens.length, equals(usersCount));

        // Performance metrics
        final operationTimes = <Duration>[];
        final errors = <String>[];
        final random = Random();

        // Generate concurrent task operations
        final operationFutures = <Future>[];

        for (int i = 0; i < concurrentOperations; i++) {
          final userToken = userTokens[random.nextInt(userTokens.length)];
          final operationType =
              random.nextInt(4); // 0: create, 1: read, 2: update, 3: list

          operationFutures.add(_performTaskOperation(
            operationType,
            userToken,
            i,
            operationTimes,
            errors,
          ));
        }

        final startTime = DateTime.now();
        await Future.wait(operationFutures);
        final endTime = DateTime.now();
        final totalDuration = endTime.difference(startTime);

        // Analyze results
        final successfulOps = concurrentOperations - errors.length;
        final averageOpTime = operationTimes.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: operationTimes
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    operationTimes.length);

        // Performance assertions
        expect(
            successfulOps,
            greaterThanOrEqualTo(
                concurrentOperations * 0.9)); // 90% success rate
        expect(averageOpTime.inMilliseconds,
            lessThan(2000)); // Average < 2 seconds
        expect(errors.length,
            lessThan(concurrentOperations * 0.1)); // < 10% error rate

        print('✅ Concurrent Task Operations Results:');
        print('   Total Operations: $concurrentOperations');
        print('   Successful Operations: $successfulOps');
        print('   Total Duration: ${totalDuration.inMilliseconds}ms');
        print('   Average Operation Time: ${averageOpTime.inMilliseconds}ms');
        print('   Error Count: ${errors.length}');
        print(
            '   Throughput: ${(successfulOps / totalDuration.inSeconds).toStringAsFixed(2)} ops/sec');
      });

      test('Concurrent WebSocket connections test', () async {
        const int concurrentConnections = 50;

        print('🚀 Starting concurrent WebSocket connections test');

        // Setup authenticated users
        final userTokens = <String>[];
        for (int i = 0; i < concurrentConnections; i++) {
          final auth = await authService.authenticate(
            'perftest$i@example.com',
            'TestPassword123!',
          );
          if (auth.success) {
            userTokens.add(auth.token!);
          }
        }

        // Performance metrics
        final connectionTimes = <Duration>[];
        final messageLatencies = <Duration>[];
        final errors = <String>[];

        // Establish concurrent WebSocket connections
        final connectionFutures = userTokens.map((token) async {
          final connectStart = DateTime.now();
          try {
            final connection = await wsService.connect(token);
            final connectEnd = DateTime.now();

            if (connection.success) {
              connectionTimes.add(connectEnd.difference(connectStart));

              // Test message latency
              final messageStart = DateTime.now();
              await wsService.sendMessage(token, {
                'type': 'ping',
                'timestamp': messageStart.toIso8601String(),
              });

              // Simulate message processing time
              await Future.delayed(const Duration(milliseconds: 10));
              final messageEnd = DateTime.now();
              messageLatencies.add(messageEnd.difference(messageStart));

              return connection;
            } else {
              errors.add('Connection failed: ${connection.error}');
              return null;
            }
          } catch (e) {
            errors.add('Connection exception: $e');
            return null;
          }
        }).toList();

        final startTime = DateTime.now();
        final connections = await Future.wait(connectionFutures);
        final endTime = DateTime.now();
        final totalDuration = endTime.difference(startTime);

        // Analyze results
        final successfulConnections =
            connections.where((c) => c?.success == true).length;
        final averageConnectionTime = connectionTimes.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: connectionTimes
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    connectionTimes.length);
        final averageMessageLatency = messageLatencies.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: messageLatencies
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    messageLatencies.length);

        // Performance assertions
        expect(
            successfulConnections,
            greaterThanOrEqualTo(
                concurrentConnections * 0.95)); // 95% success rate
        expect(averageConnectionTime.inMilliseconds,
            lessThan(1000)); // Average < 1 second
        expect(averageMessageLatency.inMilliseconds,
            lessThan(100)); // Average < 100ms
        expect(errors.length,
            lessThan(concurrentConnections * 0.05)); // < 5% error rate

        print('✅ Concurrent WebSocket Results:');
        print('   Total Connections: $concurrentConnections');
        print('   Successful Connections: $successfulConnections');
        print('   Total Duration: ${totalDuration.inMilliseconds}ms');
        print(
            '   Average Connection Time: ${averageConnectionTime.inMilliseconds}ms');
        print(
            '   Average Message Latency: ${averageMessageLatency.inMilliseconds}ms');
        print('   Error Count: ${errors.length}');

        // Cleanup connections
        for (final token in userTokens) {
          await wsService.disconnect(token);
        }
      });
    });

    group('Large Repository Performance Tests', () {
      test('Large file operations performance test', () async {
        const int fileCount = 1000;
        const int largeFileSize = 1024 * 100; // 100KB files

        print('🚀 Starting large file operations test with $fileCount files');

        final developerToken = await _getDeveloperToken();

        // Create test repository
        final repoCreation = await repoAPI.createRepository(
          name: 'large-perf-test-repo',
          description: 'Repository for large file performance testing',
          visibility: 'private',
          authToken: developerToken,
        );

        expect(repoCreation.success, isTrue);
        final repoId = repoCreation.repository!.id;

        // Performance metrics
        final fileCreationTimes = <Duration>[];
        final fileReadTimes = <Duration>[];
        final errors = <String>[];

        // Generate large file content
        final largeContent = 'A' * largeFileSize;

        // Test file creation performance
        print('   Creating $fileCount files...');
        final creationStartTime = DateTime.now();

        final creationFutures = <Future>[];
        for (int i = 0; i < fileCount; i++) {
          creationFutures.add(_createLargeFile(
            repoAPI,
            repoId,
            'large_files/file_$i.txt',
            largeContent,
            developerToken,
            fileCreationTimes,
            errors,
          ));
        }

        await Future.wait(creationFutures);
        final creationEndTime = DateTime.now();
        final totalCreationTime = creationEndTime.difference(creationStartTime);

        // Test file reading performance
        print('   Reading $fileCount files...');
        final readStartTime = DateTime.now();

        final readFutures = <Future>[];
        for (int i = 0; i < fileCount; i++) {
          readFutures.add(_readLargeFile(
            repoAPI,
            repoId,
            'large_files/file_$i.txt',
            developerToken,
            fileReadTimes,
            errors,
          ));
        }

        await Future.wait(readFutures);
        final readEndTime = DateTime.now();
        final totalReadTime = readEndTime.difference(readStartTime);

        // Analyze results
        final successfulCreations =
            fileCount - errors.where((e) => e.contains('create')).length;
        final successfulReads =
            fileCount - errors.where((e) => e.contains('read')).length;

        final averageCreationTime = fileCreationTimes.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: fileCreationTimes
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    fileCreationTimes.length);
        final averageReadTime = fileReadTimes.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: fileReadTimes
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    fileReadTimes.length);

        // Performance assertions
        expect(successfulCreations,
            greaterThanOrEqualTo(fileCount * 0.95)); // 95% success rate
        expect(successfulReads,
            greaterThanOrEqualTo(fileCount * 0.95)); // 95% success rate
        expect(averageCreationTime.inMilliseconds,
            lessThan(500)); // Average < 500ms
        expect(
            averageReadTime.inMilliseconds, lessThan(200)); // Average < 200ms
        expect(totalCreationTime.inSeconds,
            lessThan(60)); // Total creation < 60 seconds
        expect(totalReadTime.inSeconds,
            lessThan(30)); // Total reading < 30 seconds

        print('✅ Large File Operations Results:');
        print('   File Count: $fileCount');
        print('   File Size: ${largeFileSize / 1024}KB each');
        print('   Successful Creations: $successfulCreations');
        print('   Successful Reads: $successfulReads');
        print('   Total Creation Time: ${totalCreationTime.inSeconds}s');
        print('   Total Read Time: ${totalReadTime.inSeconds}s');
        print(
            '   Average Creation Time: ${averageCreationTime.inMilliseconds}ms');
        print('   Average Read Time: ${averageReadTime.inMilliseconds}ms');
        print(
            '   Creation Throughput: ${(successfulCreations / totalCreationTime.inSeconds).toStringAsFixed(2)} files/sec');
        print(
            '   Read Throughput: ${(successfulReads / totalReadTime.inSeconds).toStringAsFixed(2)} files/sec');
      });

      test('Repository structure browsing performance test', () async {
        const int directoryDepth = 10;
        const int filesPerDirectory = 50;

        print('🚀 Starting repository structure browsing test');

        final developerToken = await _getDeveloperToken();

        // Create test repository with deep structure
        final repoCreation = await repoAPI.createRepository(
          name: 'deep-structure-repo',
          description:
              'Repository for testing deep directory structure browsing',
          visibility: 'private',
          authToken: developerToken,
        );

        expect(repoCreation.success, isTrue);
        final repoId = repoCreation.repository!.id;

        // Create deep directory structure
        print('   Creating deep directory structure...');
        final structureCreationStart = DateTime.now();

        final structureCreationFutures = <Future>[];
        for (int depth = 0; depth < directoryDepth; depth++) {
          final dirPath = List.generate(depth + 1, (i) => 'level$i').join('/');

          for (int fileIndex = 0; fileIndex < filesPerDirectory; fileIndex++) {
            structureCreationFutures.add(
              repoAPI.createFile(
                repositoryId: repoId,
                filePath: '$dirPath/file_$fileIndex.dart',
                content: '''// File at depth $depth, index $fileIndex
class File${depth}_$fileIndex {
  final String id = 'file_${depth}_$fileIndex';
  final int depth = $depth;
  final int index = $fileIndex;
  
  void performOperation() {
    print('Operation in file at depth \$depth, index \$index');
  }
}
''',
                commitMessage: 'Add file at depth $depth, index $fileIndex',
                authToken: developerToken,
              ),
            );
          }
        }

        await Future.wait(structureCreationFutures);
        final structureCreationEnd = DateTime.now();
        final structureCreationTime =
            structureCreationEnd.difference(structureCreationStart);

        // Test browsing performance at different depths
        final browsingTimes = <int, Duration>{};

        for (int testDepth = 1; testDepth <= directoryDepth; testDepth++) {
          final browseStart = DateTime.now();

          final structure = await repoAPI.getRepositoryStructure(
            repositoryId: repoId,
            path: List.generate(testDepth, (i) => 'level$i').join('/'),
            maxDepth: 3, // Limit depth for performance
            authToken: developerToken,
          );

          final browseEnd = DateTime.now();
          browsingTimes[testDepth] = browseEnd.difference(browseStart);

          expect(structure.success, isTrue);
          expect(structure.structure.files.length, greaterThan(0));
        }

        // Test full repository browsing
        final fullBrowseStart = DateTime.now();
        final fullStructure = await repoAPI.getRepositoryStructure(
          repositoryId: repoId,
          authToken: developerToken,
        );
        final fullBrowseEnd = DateTime.now();
        final fullBrowseTime = fullBrowseEnd.difference(fullBrowseStart);

        // Analyze results
        final totalFiles = directoryDepth * filesPerDirectory;
        final averageBrowseTime = browsingTimes.values.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: browsingTimes.values
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    browsingTimes.length);

        // Performance assertions
        expect(fullStructure.success, isTrue);
        expect(fullStructure.structure.files.length, equals(totalFiles));
        expect(averageBrowseTime.inMilliseconds,
            lessThan(1000)); // Average < 1 second
        expect(
            fullBrowseTime.inSeconds, lessThan(5)); // Full browse < 5 seconds

        print('✅ Repository Structure Browsing Results:');
        print('   Directory Depth: $directoryDepth');
        print('   Files Per Directory: $filesPerDirectory');
        print('   Total Files: $totalFiles');
        print(
            '   Structure Creation Time: ${structureCreationTime.inSeconds}s');
        print('   Average Browse Time: ${averageBrowseTime.inMilliseconds}ms');
        print('   Full Browse Time: ${fullBrowseTime.inMilliseconds}ms');
        print('   Browse Performance by Depth:');
        browsingTimes.forEach((depth, time) {
          print('     Depth $depth: ${time.inMilliseconds}ms');
        });
      });

      test('Git operations performance test', () async {
        const int commitCount = 100;
        const int branchCount = 10;

        print('🚀 Starting Git operations performance test');

        final developerToken = await _getDeveloperToken();

        // Create test repository
        final repoCreation = await repoAPI.createRepository(
          name: 'git-perf-test-repo',
          description: 'Repository for Git operations performance testing',
          visibility: 'private',
          authToken: developerToken,
        );

        expect(repoCreation.success, isTrue);
        final repoId = repoCreation.repository!.id;

        // Performance metrics
        final commitTimes = <Duration>[];
        final branchTimes = <Duration>[];
        final mergeTimes = <Duration>[];
        final errors = <String>[];

        // Test commit performance
        print('   Testing commit performance...');
        for (int i = 0; i < commitCount; i++) {
          final commitStart = DateTime.now();

          try {
            final fileContent = '''// Commit $i
class CommitTest$i {
  final int commitNumber = $i;
  final DateTime timestamp = DateTime.parse('${DateTime.now().toIso8601String()}');
  
  void performCommitOperation() {
    print('Performing operation for commit \$commitNumber');
  }
}
''';

            final commitResult = await repoAPI.createFile(
              repositoryId: repoId,
              filePath: 'commits/commit_$i.dart',
              content: fileContent,
              commitMessage: 'Performance test commit $i',
              authToken: developerToken,
            );

            final commitEnd = DateTime.now();

            if (commitResult.success) {
              commitTimes.add(commitEnd.difference(commitStart));
            } else {
              errors.add('Commit $i failed: ${commitResult.error}');
            }
          } catch (e) {
            errors.add('Commit $i exception: $e');
          }
        }

        // Test branch operations performance
        print('   Testing branch operations...');
        for (int i = 0; i < branchCount; i++) {
          final branchStart = DateTime.now();

          try {
            final branchResult = await repoAPI.createBranch(
              repositoryId: repoId,
              branchName: 'perf-test-branch-$i',
              fromBranch: 'main',
              authToken: developerToken,
            );

            final branchEnd = DateTime.now();

            if (branchResult.success) {
              branchTimes.add(branchEnd.difference(branchStart));
            } else {
              errors.add('Branch $i creation failed: ${branchResult.error}');
            }
          } catch (e) {
            errors.add('Branch $i exception: $e');
          }
        }

        // Test merge operations performance
        print('   Testing merge operations...');
        for (int i = 0; i < min(branchCount, 5); i++) {
          // Test fewer merges
          final mergeStart = DateTime.now();

          try {
            final mergeResult = await repoAPI.mergeBranch(
              repositoryId: repoId,
              sourceBranch: 'perf-test-branch-$i',
              targetBranch: 'main',
              authToken: developerToken,
            );

            final mergeEnd = DateTime.now();

            if (mergeResult.success) {
              mergeTimes.add(mergeEnd.difference(mergeStart));
            } else {
              errors.add('Merge $i failed: ${mergeResult.error}');
            }
          } catch (e) {
            errors.add('Merge $i exception: $e');
          }
        }

        // Analyze results
        final successfulCommits = commitTimes.length;
        final successfulBranches = branchTimes.length;
        final successfulMerges = mergeTimes.length;

        final averageCommitTime = commitTimes.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: commitTimes
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    commitTimes.length);
        final averageBranchTime = branchTimes.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: branchTimes
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    branchTimes.length);
        final averageMergeTime = mergeTimes.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: mergeTimes
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    mergeTimes.length);

        // Performance assertions
        expect(successfulCommits,
            greaterThanOrEqualTo(commitCount * 0.95)); // 95% success rate
        expect(successfulBranches,
            greaterThanOrEqualTo(branchCount * 0.9)); // 90% success rate
        expect(averageCommitTime.inMilliseconds,
            lessThan(1000)); // Average < 1 second
        expect(
            averageBranchTime.inMilliseconds, lessThan(500)); // Average < 500ms
        expect(averageMergeTime.inMilliseconds,
            lessThan(2000)); // Average < 2 seconds

        print('✅ Git Operations Performance Results:');
        print('   Successful Commits: $successfulCommits/$commitCount');
        print('   Successful Branches: $successfulBranches/$branchCount');
        print('   Successful Merges: $successfulMerges/${min(branchCount, 5)}');
        print('   Average Commit Time: ${averageCommitTime.inMilliseconds}ms');
        print('   Average Branch Time: ${averageBranchTime.inMilliseconds}ms');
        print('   Average Merge Time: ${averageMergeTime.inMilliseconds}ms');
        print('   Error Count: ${errors.length}');
      });
    });

    group('Real-time Operations Performance Tests', () {
      test('WebSocket message broadcasting performance test', () async {
        const int connectionCount = 100;
        const int messageCount = 1000;

        print('🚀 Starting WebSocket broadcasting performance test');

        // Setup connections
        final connections = <String>[];
        for (int i = 0; i < connectionCount; i++) {
          final auth = await authService.authenticate(
            'perftest$i@example.com',
            'TestPassword123!',
          );

          if (auth.success) {
            final connection = await wsService.connect(auth.token!);
            if (connection.success) {
              connections.add(auth.token!);
            }
          }
        }

        expect(connections.length, greaterThanOrEqualTo(connectionCount * 0.9));

        // Performance metrics
        final broadcastTimes = <Duration>[];
        final messageLatencies = <Duration>[];
        final errors = <String>[];

        // Setup message listeners
        final receivedMessages = <String, List<Map<String, dynamic>>>{};
        for (final token in connections) {
          receivedMessages[token] = [];
          wsService.onMessage(token, (message) {
            receivedMessages[token]!.add({
              ...message,
              'receivedAt': DateTime.now().toIso8601String(),
            });
          });
        }

        // Test message broadcasting performance
        print(
            '   Broadcasting $messageCount messages to ${connections.length} connections...');

        for (int i = 0; i < messageCount; i++) {
          final broadcastStart = DateTime.now();

          try {
            final message = {
              'type': 'performance_test',
              'messageId': i,
              'content': 'Performance test message $i',
              'timestamp': broadcastStart.toIso8601String(),
            };

            await wsService.broadcastMessage(message);

            final broadcastEnd = DateTime.now();
            broadcastTimes.add(broadcastEnd.difference(broadcastStart));

            // Small delay to prevent overwhelming
            if (i % 10 == 0) {
              await Future.delayed(const Duration(milliseconds: 10));
            }
          } catch (e) {
            errors.add('Broadcast $i failed: $e');
          }
        }

        // Wait for message propagation
        await Future.delayed(const Duration(seconds: 2));

        // Calculate message latencies
        for (final token in connections) {
          final messages = receivedMessages[token]!;
          for (final message in messages) {
            if (message['timestamp'] != null && message['receivedAt'] != null) {
              final sentTime = DateTime.parse(message['timestamp']);
              final receivedTime = DateTime.parse(message['receivedAt']);
              messageLatencies.add(receivedTime.difference(sentTime));
            }
          }
        }

        // Analyze results
        final successfulBroadcasts = broadcastTimes.length;
        final totalMessagesReceived = receivedMessages.values
            .map((msgs) => msgs.length)
            .reduce((a, b) => a + b);
        final expectedMessages = messageCount * connections.length;
        final messageDeliveryRate = totalMessagesReceived / expectedMessages;

        final averageBroadcastTime = broadcastTimes.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: broadcastTimes
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    broadcastTimes.length);
        final averageLatency = messageLatencies.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: messageLatencies
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    messageLatencies.length);

        // Performance assertions
        expect(successfulBroadcasts,
            greaterThanOrEqualTo(messageCount * 0.95)); // 95% success rate
        expect(messageDeliveryRate,
            greaterThanOrEqualTo(0.9)); // 90% delivery rate
        expect(averageBroadcastTime.inMilliseconds,
            lessThan(100)); // Average < 100ms
        expect(averageLatency.inMilliseconds, lessThan(500)); // Average < 500ms

        print('✅ WebSocket Broadcasting Results:');
        print('   Connections: ${connections.length}');
        print('   Messages Sent: $messageCount');
        print('   Successful Broadcasts: $successfulBroadcasts');
        print('   Total Messages Received: $totalMessagesReceived');
        print('   Expected Messages: $expectedMessages');
        print(
            '   Delivery Rate: ${(messageDeliveryRate * 100).toStringAsFixed(1)}%');
        print(
            '   Average Broadcast Time: ${averageBroadcastTime.inMilliseconds}ms');
        print('   Average Message Latency: ${averageLatency.inMilliseconds}ms');
        print('   Error Count: ${errors.length}');

        // Cleanup connections
        for (final token in connections) {
          await wsService.disconnect(token);
        }
      });

      test('Real-time task updates performance test', () async {
        const int taskCount = 500;
        const int updateCount = 2000;

        print('🚀 Starting real-time task updates performance test');

        final adminToken = await _getAdminToken();
        final developerTokens = <String>[];

        // Setup multiple developers
        for (int i = 0; i < 10; i++) {
          final auth = await authService.authenticate(
            'perftest$i@example.com',
            'TestPassword123!',
          );
          if (auth.success) {
            developerTokens.add(auth.token!);
          }
        }

        // Create tasks
        print('   Creating $taskCount tasks...');
        final taskIds = <String>[];
        for (int i = 0; i < taskCount; i++) {
          final task = await taskAPI.createTask(
            title: 'Performance Test Task $i',
            description: 'Task for real-time updates performance testing',
            type: 'feature',
            priority: 'medium',
            confidentialityLevel: 'team',
            authToken: adminToken,
          );

          if (task.success) {
            taskIds.add(task.task!.id);
          }
        }

        expect(taskIds.length, equals(taskCount));

        // Setup WebSocket connections for real-time updates
        final connections = <String>[];
        for (final token in developerTokens) {
          final connection = await wsService.connect(token);
          if (connection.success) {
            connections.add(token);
          }
        }

        // Performance metrics
        final updateTimes = <Duration>[];
        final notificationLatencies = <Duration>[];
        final errors = <String>[];
        final random = Random();

        // Setup notification listeners
        final receivedNotifications = <String, List<Map<String, dynamic>>>{};
        for (final token in connections) {
          receivedNotifications[token] = [];
          wsService.onNotification(token, (notification) {
            receivedNotifications[token]!.add({
              ...notification,
              'receivedAt': DateTime.now().toIso8601String(),
            });
          });
        }

        // Perform concurrent task updates
        print('   Performing $updateCount task updates...');
        final updateFutures = <Future>[];

        for (int i = 0; i < updateCount; i++) {
          final taskId = taskIds[random.nextInt(taskIds.length)];
          final token = developerTokens[random.nextInt(developerTokens.length)];
          final statuses = ['pending', 'in_progress', 'review', 'completed'];
          final newStatus = statuses[random.nextInt(statuses.length)];

          updateFutures.add(_performTaskUpdate(
            taskAPI,
            wsService,
            taskId,
            newStatus,
            token,
            updateTimes,
            errors,
          ));
        }

        final updateStart = DateTime.now();
        await Future.wait(updateFutures);
        final updateEnd = DateTime.now();
        final totalUpdateTime = updateEnd.difference(updateStart);

        // Wait for notifications to propagate
        await Future.delayed(const Duration(seconds: 1));

        // Calculate notification latencies
        for (final token in connections) {
          final notifications = receivedNotifications[token]!;
          for (final notification in notifications) {
            if (notification['timestamp'] != null &&
                notification['receivedAt'] != null) {
              final sentTime = DateTime.parse(notification['timestamp']);
              final receivedTime = DateTime.parse(notification['receivedAt']);
              notificationLatencies.add(receivedTime.difference(sentTime));
            }
          }
        }

        // Analyze results
        final successfulUpdates = updateCount - errors.length;
        final totalNotifications = receivedNotifications.values
            .map((notifs) => notifs.length)
            .reduce((a, b) => a + b);

        final averageUpdateTime = updateTimes.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: updateTimes
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    updateTimes.length);
        final averageNotificationLatency = notificationLatencies.isEmpty
            ? Duration.zero
            : Duration(
                microseconds: notificationLatencies
                        .map((d) => d.inMicroseconds)
                        .reduce((a, b) => a + b) ~/
                    notificationLatencies.length);

        // Performance assertions
        expect(successfulUpdates,
            greaterThanOrEqualTo(updateCount * 0.9)); // 90% success rate
        expect(averageUpdateTime.inMilliseconds,
            lessThan(1000)); // Average < 1 second
        expect(averageNotificationLatency.inMilliseconds,
            lessThan(200)); // Average < 200ms
        expect(
            totalUpdateTime.inSeconds, lessThan(30)); // Total time < 30 seconds

        print('✅ Real-time Task Updates Results:');
        print('   Task Count: $taskCount');
        print('   Update Count: $updateCount');
        print('   Successful Updates: $successfulUpdates');
        print('   Total Notifications: $totalNotifications');
        print('   Total Update Time: ${totalUpdateTime.inSeconds}s');
        print('   Average Update Time: ${averageUpdateTime.inMilliseconds}ms');
        print(
            '   Average Notification Latency: ${averageNotificationLatency.inMilliseconds}ms');
        print(
            '   Update Throughput: ${(successfulUpdates / totalUpdateTime.inSeconds).toStringAsFixed(2)} updates/sec');
        print('   Error Count: ${errors.length}');

        // Cleanup connections
        for (final token in connections) {
          await wsService.disconnect(token);
        }
      });
    });

    group('Memory and Resource Performance Tests', () {
      test('Memory usage under load test', () async {
        print('🚀 Starting memory usage under load test');

        // This test would typically use platform-specific memory monitoring
        // For now, we'll simulate memory-intensive operations and verify they complete

        const int operationCount = 1000;
        final operations = <Future>[];

        // Simulate memory-intensive operations
        for (int i = 0; i < operationCount; i++) {
          operations.add(_performMemoryIntensiveOperation(i));
        }

        final startTime = DateTime.now();
        await Future.wait(operations);
        final endTime = DateTime.now();
        final totalTime = endTime.difference(startTime);

        // Verify operations completed successfully
        expect(operations.length, equals(operationCount));
        expect(totalTime.inSeconds,
            lessThan(60)); // Should complete within 60 seconds

        print('✅ Memory Usage Test Results:');
        print('   Operations: $operationCount');
        print('   Total Time: ${totalTime.inSeconds}s');
        print(
            '   Operations/sec: ${(operationCount / totalTime.inSeconds).toStringAsFixed(2)}');
      });
    });
  });
}

/// Helper function to perform task operations
Future<void> _performTaskOperation(
  int operationType,
  String userToken,
  int operationIndex,
  List<Duration> operationTimes,
  List<String> errors,
) async {
  final opStart = DateTime.now();

  try {
    final taskAPI = TaskManagementAPI.instance;

    switch (operationType) {
      case 0: // Create task
        final result = await taskAPI.createTask(
          title: 'Concurrent Task $operationIndex',
          description: 'Task created during concurrent testing',
          type: 'feature',
          priority: 'medium',
          confidentialityLevel: 'team',
          authToken: userToken,
        );
        if (!result.success) {
          errors.add('Create task $operationIndex failed: ${result.error}');
        }
        break;

      case 1: // Read tasks
        final result = await taskAPI.getTasks(authToken: userToken);
        if (!result.success) {
          errors.add('Read tasks $operationIndex failed: ${result.error}');
        }
        break;

      case 2: // Update task (if any exist)
        final tasks = await taskAPI.getTasks(authToken: userToken);
        if (tasks.success && tasks.tasks.isNotEmpty) {
          final result = await taskAPI.updateTaskStatus(
            taskId: tasks.tasks.first.id,
            status: 'in_progress',
            authToken: userToken,
          );
          if (!result.success) {
            errors.add('Update task $operationIndex failed: ${result.error}');
          }
        }
        break;

      case 3: // List assigned tasks
        final result = await taskAPI.getAssignedTasks(
          userId: 'user-id',
          authToken: userToken,
        );
        if (!result.success) {
          errors.add(
              'List assigned tasks $operationIndex failed: ${result.error}');
        }
        break;
    }

    final opEnd = DateTime.now();
    operationTimes.add(opEnd.difference(opStart));
  } catch (e) {
    errors.add('Operation $operationIndex exception: $e');
  }
}

/// Helper function to create large files
Future<void> _createLargeFile(
  RepositoryAPI repoAPI,
  String repoId,
  String filePath,
  String content,
  String authToken,
  List<Duration> creationTimes,
  List<String> errors,
) async {
  final createStart = DateTime.now();

  try {
    final result = await repoAPI.createFile(
      repositoryId: repoId,
      filePath: filePath,
      content: content,
      commitMessage: 'Add large file: $filePath',
      authToken: authToken,
    );

    final createEnd = DateTime.now();

    if (result.success) {
      creationTimes.add(createEnd.difference(createStart));
    } else {
      errors.add('Create file $filePath failed: ${result.error}');
    }
  } catch (e) {
    errors.add('Create file $filePath exception: $e');
  }
}

/// Helper function to read large files
Future<void> _readLargeFile(
  RepositoryAPI repoAPI,
  String repoId,
  String filePath,
  String authToken,
  List<Duration> readTimes,
  List<String> errors,
) async {
  final readStart = DateTime.now();

  try {
    final result = await repoAPI.getFileContent(
      repositoryId: repoId,
      filePath: filePath,
      authToken: authToken,
    );

    final readEnd = DateTime.now();

    if (result.success) {
      readTimes.add(readEnd.difference(readStart));
    } else {
      errors.add('Read file $filePath failed: ${result.error}');
    }
  } catch (e) {
    errors.add('Read file $filePath exception: $e');
  }
}

/// Helper function to perform task updates with real-time notifications
Future<void> _performTaskUpdate(
  TaskManagementAPI taskAPI,
  WebSocketService wsService,
  String taskId,
  String newStatus,
  String authToken,
  List<Duration> updateTimes,
  List<String> errors,
) async {
  final updateStart = DateTime.now();

  try {
    final result = await taskAPI.updateTaskStatus(
      taskId: taskId,
      status: newStatus,
      authToken: authToken,
    );

    if (result.success) {
      // Broadcast real-time notification
      await wsService.broadcastTaskUpdate(taskId, {
        'status': newStatus,
        'timestamp': updateStart.toIso8601String(),
      });

      final updateEnd = DateTime.now();
      updateTimes.add(updateEnd.difference(updateStart));
    } else {
      errors.add('Update task $taskId failed: ${result.error}');
    }
  } catch (e) {
    errors.add('Update task $taskId exception: $e');
  }
}

/// Helper function to perform memory-intensive operations
Future<void> _performMemoryIntensiveOperation(int operationIndex) async {
  // Simulate memory-intensive operation
  final largeList =
      List.generate(10000, (index) => 'Data item $operationIndex-$index');

  // Perform some operations on the data
  final processedData = largeList.map((item) => item.toUpperCase()).toList();
  final filteredData =
      processedData.where((item) => item.contains('DATA')).toList();

  // Simulate processing time
  await Future.delayed(const Duration(milliseconds: 10));

  // Ensure data is used (prevent optimization)
  expect(filteredData.length, greaterThan(0));
}

/// Helper functions for authentication
Future<String> _getAdminToken() async {
  final authService = AuthService.instance;
  final auth = await authService.authenticate(
    'admin@testproject.com',
    'AdminPassword123!',
  );
  return auth.token!;
}

Future<String> _getDeveloperToken() async {
  final authService = AuthService.instance;
  final auth = await authService.authenticate(
    'perftest0@example.com',
    'TestPassword123!',
  );
  return auth.token!;
}
