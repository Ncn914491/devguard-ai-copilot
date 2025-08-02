import 'package:flutter/material.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/models/join_request.dart';

/// Form widget for submitting join requests
class JoinRequestForm extends StatefulWidget {
  const JoinRequestForm({super.key});

  @override
  State<JoinRequestForm> createState() => _JoinRequestFormState();
}

class _JoinRequestFormState extends State<JoinRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _selectedRole = 'developer';
  bool _isSubmitting = false;
  RequestResult? _submissionResult;

  final List<Map<String, String>> _availableRoles = [
    {
      'value': 'developer',
      'label': 'Developer',
      'description': 'Code editing, git operations, assigned tasks',
    },
    {
      'value': 'lead_developer',
      'label': 'Lead Developer',
      'description': 'Team management, code review, task assignment',
    },
    {
      'value': 'viewer',
      'label': 'Viewer',
      'description': 'Read-only access to project overviews',
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Show result message if available
          if (_submissionResult != null) ...[
            _buildResultMessage(),
            const SizedBox(height: 24),
          ],

          // Name field
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter your full name',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
            enabled: !_isSubmitting,
          ),

          const SizedBox(height: 16),

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter your email address',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
            enabled: !_isSubmitting,
          ),

          const SizedBox(height: 16),

          // Role selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Requested Role',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ..._availableRoles.map((role) => _buildRoleOption(role)),
            ],
          ),

          const SizedBox(height: 16),

          // Message field (optional)
          TextFormField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Message (Optional)',
              hintText: 'Tell us about your experience or why you want to join...',
              prefixIcon: const Icon(Icons.message),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            enabled: !_isSubmitting,
          ),

          const SizedBox(height: 24),

          // Submit button
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitRequest,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Submitting Request...'),
                    ],
                  )
                : const Text(
                    'Submit Join Request',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),

          const SizedBox(height: 16),

          // Info text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your request will be reviewed by an admin. You\'ll receive an email with login credentials if approved.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption(Map<String, String> role) {
    final isSelected = _selectedRole == role['value'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _isSubmitting ? null : () {
          setState(() {
            _selectedRole = role['value']!;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: role['value']!,
                groupValue: _selectedRole,
                onChanged: _isSubmitting ? null : (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role['label']!,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Theme.of(context).primaryColor : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role['description']!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultMessage() {
    final isSuccess = _submissionResult!.success;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess 
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess 
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _submissionResult!.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionResult = null;
    });

    try {
      final result = await OnboardingService.instance.submitJoinRequest(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        requestedRole: _selectedRole,
        message: _messageController.text.trim().isEmpty 
            ? null 
            : _messageController.text.trim(),
      );

      setState(() {
        _submissionResult = result;
      });

      if (result.success) {
        // Clear form on success
        _nameController.clear();
        _emailController.clear();
        _messageController.clear();
        _selectedRole = 'developer';
      }

    } catch (e) {
      setState(() {
        _submissionResult = RequestResult(
          success: false,
          message: 'An unexpected error occurred. Please try again.',
        );
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}