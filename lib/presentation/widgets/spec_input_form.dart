import 'package:flutter/material.dart';
import '../../core/database/services/services.dart';
import '../../core/database/models/models.dart';

class SpecInputForm extends StatefulWidget {
  final Function(Specification) onSpecificationCreated;

  const SpecInputForm({
    super.key,
    required this.onSpecificationCreated,
  });

  @override
  State<SpecInputForm> createState() => _SpecInputFormState();
}

class _SpecInputFormState extends State<SpecInputForm> {
  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController();
  final _specService = SpecService.instance;

  bool _isProcessing = false;
  Specification? _processedSpec;
  ValidationResult? _validationResult;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _validateInput() async {
    if (_inputController.text.trim().isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final validation = await _specService
          .validateSpecification(_inputController.text.trim());
      setState(() => _validationResult = validation);

      if (validation.isValid) {
        await _processSpecification();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Validation error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processSpecification() async {
    setState(() => _isProcessing = true);

    try {
      final spec = await _specService.processSpecification(
        _inputController.text.trim(),
        userId: 'current_user', // TODO: Get from auth context
      );

      setState(() => _processedSpec = spec);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _approveAndSave() async {
    if (_processedSpec == null) return;

    try {
      await _specService.approveSpecification(
        _processedSpec!.id,
        'current_user', // TODO: Get from auth context
      );

      widget.onSpecificationCreated(_processedSpec!);

      // Reset form
      _inputController.clear();
      setState(() {
        _processedSpec = null;
        _validationResult = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Specification approved and saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving specification: $e')),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _processedSpec = null;
      _validationResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Natural Language Specification',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Describe what you want to implement in natural language. The AI will convert it into structured git actions.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _inputController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText:
                          'Example: "Add user authentication with email and password, including login and registration forms with validation"',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a specification';
                      }
                      if (value.trim().length < 10) {
                        return 'Specification should be at least 10 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _validateInput,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(_isProcessing
                            ? 'Processing...'
                            : 'Process with AI'),
                      ),
                      if (_processedSpec != null) ...[
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Validation Results
          if (_validationResult != null && !_validationResult!.isValid) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Validation Issues',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...(_validationResult!.issues.map((issue) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $issue',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                          ),
                        ))),
                    if (_validationResult!.suggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Suggestions:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      ...(_validationResult!.suggestions
                          .map((suggestion) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• $suggestion',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                ),
                              ))),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // AI Processing Results
          if (_processedSpec != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Processing Results',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // AI Interpretation
                    _buildResultSection(
                      'AI Interpretation',
                      _processedSpec!.aiInterpretation,
                      Icons.psychology,
                    ),

                    const SizedBox(height: 16),

                    // Git Actions
                    Row(
                      children: [
                        Expanded(
                          child: _buildResultSection(
                            'Suggested Branch Name',
                            _processedSpec!.suggestedBranchName,
                            Icons.account_tree,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildResultSection(
                            'Commit Message',
                            _processedSpec!.suggestedCommitMessage,
                            Icons.commit,
                          ),
                        ),
                      ],
                    ),

                    if (_processedSpec!.placeholderDiff != null) ...[
                      const SizedBox(height: 16),
                      _buildResultSection(
                        'Expected Changes',
                        _processedSpec!.placeholderDiff!,
                        Icons.difference,
                      ),
                    ],

                    if (_processedSpec!.assignedTo != null) ...[
                      const SizedBox(height: 16),
                      _buildResultSection(
                        'Suggested Assignee',
                        _processedSpec!.assignedTo!,
                        Icons.person,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _approveAndSave,
                          icon: const Icon(Icons.check),
                          label: const Text('Approve & Save'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.edit),
                          label: const Text('Modify Input'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily:
                      title.contains('Branch') || title.contains('Commit')
                          ? 'monospace'
                          : null,
                ),
          ),
        ),
      ],
    );
  }
}
