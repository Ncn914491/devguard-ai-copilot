import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/repository_api.dart';
import '../auth/auth_service.dart';
import '../database/services/audit_log_service.dart';
import '../api/websocket_service.dart';

/// Merge conflict resolution service with visual tools
/// Satisfies Requirements: 8.2 (Visual merge conflict resolution tools)
class MergeConflictService extends ChangeNotifier {
  static final MergeConflictService _instance =
      MergeConflictService._internal();
  static MergeConflictService get instance => _instance;
  MergeConflictService._internal();

  final _repositoryAPI = RepositoryAPI.instance;
  final _authService = AuthService.instance;
  final _auditService = AuditLogService.instance;
  final _websocketService = WebSocketService.instance;

  // Active conflicts
  final Map<String, List<MergeConflict>> _activeConflicts = {};

  /// Detect merge conflicts in repository
  Future<List<MergeConflict>> detectConflicts(String repositoryId) async {
    try {
      final repoResponse = await _repositoryAPI.getRepository(repositoryId);
      if (!repoResponse.success || repoResponse.data == null) {
        return [];
      }

      final repository = repoResponse.data!;
      final conflicts = <MergeConflict>[];

      // Get files with conflicts (mock implementation)
      final conflictFiles = await _getConflictFiles(repository.localPath);

      for (final filePath in conflictFiles) {
        final contentResponse = await _repositoryAPI.getFileContent(
          repoId: repositoryId,
          filePath: filePath,
        );

        if (contentResponse.success && contentResponse.data != null) {
          final conflict = await _parseConflictFile(
            repositoryId: repositoryId,
            filePath: filePath,
            content: contentResponse.data!,
          );

          if (conflict != null) {
            conflicts.add(conflict);
          }
        }
      }

      _activeConflicts[repositoryId] = conflicts;

      await _auditService.logAction(
        actionType: 'merge_conflicts_detected',
        description: 'Detected ${conflicts.length} merge conflicts',
        contextData: {
          'repository_id': repositoryId,
          'conflict_count': conflicts.length,
          'conflict_files': conflicts.map((c) => c.filePath).toList(),
        },
        userId: _authService.currentUser?.id,
      );

      return conflicts;
    } catch (e) {
      debugPrint('Error detecting conflicts: $e');
      return [];
    }
  }

  /// Get conflicts for a repository
  List<MergeConflict> getConflicts(String repositoryId) {
    return _activeConflicts[repositoryId] ?? [];
  }

  /// Resolve conflict with user's choice
  Future<bool> resolveConflict({
    required String repositoryId,
    required String filePath,
    required int conflictIndex,
    required ConflictResolution resolution,
  }) async {
    try {
      final conflicts = _activeConflicts[repositoryId];
      if (conflicts == null || conflictIndex >= conflicts.length) {
        return false;
      }

      final conflict = conflicts[conflictIndex];
      if (conflict.filePath != filePath) {
        return false;
      }

      // Get current file content
      final contentResponse = await _repositoryAPI.getFileContent(
        repoId: repositoryId,
        filePath: filePath,
      );

      if (!contentResponse.success || contentResponse.data == null) {
        return false;
      }

      // Apply resolution
      final resolvedContent = _applyResolution(
        content: contentResponse.data!,
        conflict: conflict,
        resolution: resolution,
      );

      // Update file with resolved content
      final updateResponse = await _repositoryAPI.updateFileContent(
        repoId: repositoryId,
        filePath: filePath,
        content: resolvedContent,
      );

      if (!updateResponse.success) {
        return false;
      }

      // Remove resolved conflict
      conflicts.removeAt(conflictIndex);
      if (conflicts.isEmpty) {
        _activeConflicts.remove(repositoryId);
      }

      // Broadcast resolution via WebSocket
      await _websocketService.broadcastConflictResolution(
        repositoryId: repositoryId,
        filePath: filePath,
        resolution: {
          'action': 'resolved',
          'conflict_index': conflictIndex,
          'resolution_type': resolution.type.name,
          'resolved_by': _authService.currentUser?.id,
          'resolved_at': DateTime.now().toIso8601String(),
        },
        targetUsers: await _getRepositoryCollaborators(repositoryId),
      );

      await _auditService.logAction(
        actionType: 'merge_conflict_resolved',
        description: 'Resolved merge conflict in $filePath',
        contextData: {
          'repository_id': repositoryId,
          'file_path': filePath,
          'conflict_index': conflictIndex,
          'resolution_type': resolution.type.name,
        },
        userId: _authService.currentUser?.id,
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error resolving conflict: $e');
      return false;
    }
  }

  /// Create custom resolution by editing conflict manually
  Future<bool> createCustomResolution({
    required String repositoryId,
    required String filePath,
    required int conflictIndex,
    required String customContent,
  }) async {
    try {
      final resolution = ConflictResolution(
        type: ConflictResolutionType.custom,
        customContent: customContent,
      );

      return await resolveConflict(
        repositoryId: repositoryId,
        filePath: filePath,
        conflictIndex: conflictIndex,
        resolution: resolution,
      );
    } catch (e) {
      debugPrint('Error creating custom resolution: $e');
      return false;
    }
  }

  /// Get three-way merge view for conflict
  ThreeWayMergeView getThreeWayMergeView({
    required String repositoryId,
    required String filePath,
    required int conflictIndex,
  }) {
    final conflicts = _activeConflicts[repositoryId];
    if (conflicts == null || conflictIndex >= conflicts.length) {
      throw ArgumentError('Conflict not found');
    }

    final conflict = conflicts[conflictIndex];

    return ThreeWayMergeView(
      baseContent: conflict.baseContent ?? '',
      currentContent: conflict.currentContent,
      incomingContent: conflict.incomingContent,
      conflictMarkers: conflict.markers,
    );
  }

  /// Helper methods

  Future<List<String>> _getConflictFiles(String repositoryPath) async {
    // Mock implementation - in production, this would use git status
    // to find files with conflict markers
    return ['lib/main.dart', 'README.md'];
  }

  Future<MergeConflict?> _parseConflictFile({
    required String repositoryId,
    required String filePath,
    required String content,
  }) async {
    final lines = content.split('\n');
    final conflicts = <ConflictSection>[];

    int? currentStart;
    int? separatorLine;
    String? currentBranch;
    String? incomingBranch;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('<<<<<<<')) {
        currentStart = i;
        currentBranch = line.substring(7).trim();
      } else if (line.startsWith('=======') && currentStart != null) {
        separatorLine = i;
      } else if (line.startsWith('>>>>>>>') &&
          currentStart != null &&
          separatorLine != null) {
        incomingBranch = line.substring(7).trim();

        final currentContent =
            lines.sublist(currentStart + 1, separatorLine).join('\n');
        final incomingContent = lines.sublist(separatorLine + 1, i).join('\n');

        conflicts.add(ConflictSection(
          startLine: currentStart,
          endLine: i,
          currentContent: currentContent,
          incomingContent: incomingContent,
          currentBranch: currentBranch,
          incomingBranch: incomingBranch,
        ));

        currentStart = null;
        separatorLine = null;
      }
    }

    if (conflicts.isEmpty) {
      return null;
    }

    return MergeConflict(
      repositoryId: repositoryId,
      filePath: filePath,
      conflicts: conflicts,
      currentContent: content,
      incomingContent: content, // Simplified
      baseContent: null,
      markers: ConflictMarkers(
        currentStart: '<<<<<<<',
        separator: '=======',
        incomingEnd: '>>>>>>>',
      ),
      detectedAt: DateTime.now(),
    );
  }

  String _applyResolution({
    required String content,
    required MergeConflict conflict,
    required ConflictResolution resolution,
  }) {
    final lines = content.split('\n');
    final result = <String>[];

    int lineIndex = 0;

    for (final conflictSection in conflict.conflicts) {
      // Add lines before conflict
      while (lineIndex < conflictSection.startLine) {
        result.add(lines[lineIndex]);
        lineIndex++;
      }

      // Apply resolution
      switch (resolution.type) {
        case ConflictResolutionType.acceptCurrent:
          result.add(conflictSection.currentContent);
          break;
        case ConflictResolutionType.acceptIncoming:
          result.add(conflictSection.incomingContent);
          break;
        case ConflictResolutionType.acceptBoth:
          result.add(conflictSection.currentContent);
          result.add(conflictSection.incomingContent);
          break;
        case ConflictResolutionType.custom:
          if (resolution.customContent != null) {
            result.add(resolution.customContent!);
          }
          break;
      }

      // Skip conflict lines
      lineIndex = conflictSection.endLine + 1;
    }

    // Add remaining lines
    while (lineIndex < lines.length) {
      result.add(lines[lineIndex]);
      lineIndex++;
    }

    return result.join('\n');
  }

  Future<List<String>> _getRepositoryCollaborators(String repositoryId) async {
    final repoResponse = await _repositoryAPI.getRepository(repositoryId);
    if (!repoResponse.success || repoResponse.data == null) {
      return [];
    }

    final repository = repoResponse.data!;
    final collaborators = [repository.ownerId];
    collaborators.addAll(repository.collaborators.map((c) => c.userId));
    return collaborators;
  }
}

/// Merge conflict models
class MergeConflict {
  final String repositoryId;
  final String filePath;
  final List<ConflictSection> conflicts;
  final String currentContent;
  final String incomingContent;
  final String? baseContent;
  final ConflictMarkers markers;
  final DateTime detectedAt;

  MergeConflict({
    required this.repositoryId,
    required this.filePath,
    required this.conflicts,
    required this.currentContent,
    required this.incomingContent,
    this.baseContent,
    required this.markers,
    required this.detectedAt,
  });
}

class ConflictSection {
  final int startLine;
  final int endLine;
  final String currentContent;
  final String incomingContent;
  final String currentBranch;
  final String incomingBranch;

  ConflictSection({
    required this.startLine,
    required this.endLine,
    required this.currentContent,
    required this.incomingContent,
    required this.currentBranch,
    required this.incomingBranch,
  });
}

class ConflictMarkers {
  final String currentStart;
  final String separator;
  final String incomingEnd;

  ConflictMarkers({
    required this.currentStart,
    required this.separator,
    required this.incomingEnd,
  });
}

class ConflictResolution {
  final ConflictResolutionType type;
  final String? customContent;

  ConflictResolution({
    required this.type,
    this.customContent,
  });
}

enum ConflictResolutionType {
  acceptCurrent,
  acceptIncoming,
  acceptBoth,
  custom,
}

class ThreeWayMergeView {
  final String baseContent;
  final String currentContent;
  final String incomingContent;
  final ConflictMarkers conflictMarkers;

  ThreeWayMergeView({
    required this.baseContent,
    required this.currentContent,
    required this.incomingContent,
    required this.conflictMarkers,
  });
}
