import 'package:flutter/material.dart';
import '../../core/services/merge_conflict_service.dart';
import '../../core/auth/auth_service.dart';

/// Visual merge conflict resolution widget
/// Satisfies Requirements: 8.2 (Visual merge conflict resolution tools)
class MergeConflictResolver extends StatefulWidget {
  final String repositoryId;
  final String filePath;
  final int conflictIndex;
  final Function(bool) onResolved;
  final VoidCallback onCancel;

  const MergeConflictResolver({
    super.key,
    required this.repositoryId,
    required this.filePath,
    required this.conflictIndex,
    required this.onResolved,
    required this.onCancel,
  });

  @override
  State<MergeConflictResolver> createState() => _MergeConflictResolverState();
}

class _MergeConflictResolverState extends State<MergeConflictResolver> {
  final _conflictService = MergeConflictService.instance;
  final _authService = AuthService.instance;
  final _customContentController = TextEditingController();

  late ThreeWayMergeView _mergeView;
  ConflictResolutionType _selectedResolution =
      ConflictResolutionType.acceptCurrent;
  bool _showCustomEditor = false;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _loadMergeView();
  }

  @override
  void dispose() {
    _customContentController.dispose();
    super.dispose();
  }

  void _loadMergeView() {
    try {
      _mergeView = _conflictService.getThreeWayMergeView(
        repositoryId: widget.repositoryId,
        filePath: widget.filePath,
        conflictIndex: widget.conflictIndex,
      );
      _customContentController.text = _mergeView.currentContent;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading conflict: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resolveConflict() async {
    if (!_authService.hasPermission('commit_code')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to resolve conflicts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isResolving = true;
    });

    try {
      ConflictResolution resolution;

      if (_selectedResolution == ConflictResolutionType.custom) {
        resolution = ConflictResolution(
          type: ConflictResolutionType.custom,
          customContent: _customContentController.text,
        );
      } else {
        resolution = ConflictResolution(type: _selectedResolution);
      }

      final success = await _conflictService.resolveConflict(
        repositoryId: widget.repositoryId,
        filePath: widget.filePath,
        conflictIndex: widget.conflictIndex,
        resolution: resolution,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conflict resolved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onResolved(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resolve conflict'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resolving conflict: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isResolving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.merge_type, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Resolve Merge Conflict',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'File: ${widget.filePath}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),

            // Resolution options
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resolution Options',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildResolutionOption(
                      ConflictResolutionType.acceptCurrent,
                      'Accept Current (HEAD)',
                      'Keep the changes from the current branch',
                      Icons.arrow_downward,
                      Colors.blue,
                    ),
                    _buildResolutionOption(
                      ConflictResolutionType.acceptIncoming,
                      'Accept Incoming',
                      'Keep the changes from the incoming branch',
                      Icons.arrow_upward,
                      Colors.green,
                    ),
                    _buildResolutionOption(
                      ConflictResolutionType.acceptBoth,
                      'Accept Both',
                      'Keep changes from both branches',
                      Icons.merge,
                      Colors.purple,
                    ),
                    _buildResolutionOption(
                      ConflictResolutionType.custom,
                      'Custom Resolution',
                      'Manually edit the resolution',
                      Icons.edit,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Three-way merge view or custom editor
            Expanded(
              child: _showCustomEditor
                  ? _buildCustomEditor()
                  : _buildThreeWayView(),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isResolving ? null : _resolveConflict,
                  child: _isResolving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Resolve Conflict'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionOption(
    ConflictResolutionType type,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedResolution == type;

    return RadioListTile<ConflictResolutionType>(
      value: type,
      groupValue: _selectedResolution,
      onChanged: (value) {
        setState(() {
          _selectedResolution = value!;
          _showCustomEditor = value == ConflictResolutionType.custom;
        });
      },
      title: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      subtitle: Text(description),
      dense: true,
    );
  }

  Widget _buildThreeWayView() {
    return Card(
      child: Column(
        children: [
          // Headers
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.grey)),
                    ),
                    child: const Text(
                      'Current (HEAD)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.grey)),
                    ),
                    child: const Text(
                      'Base',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Incoming',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.grey)),
                    ),
                    child: _buildCodeView(
                      _mergeView.currentContent,
                      Colors.blue.withOpacity(0.1),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.grey)),
                    ),
                    child: _buildCodeView(
                      _mergeView.baseContent,
                      Colors.grey.withOpacity(0.1),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildCodeView(
                    _mergeView.incomingContent,
                    Colors.green.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeView(String content, Color backgroundColor) {
    return Container(
      color: backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: SelectableText(
          content,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomEditor() {
    return Card(
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Custom Resolution',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _customContentController.text = _mergeView.currentContent;
                  },
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  label: const Text('Use Current'),
                ),
                TextButton.icon(
                  onPressed: () {
                    _customContentController.text = _mergeView.incomingContent;
                  },
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: const Text('Use Incoming'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _customContentController,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Edit the resolved content here...',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
