import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/onboarding_service.dart';

/// Widget for manually adding team members (admin only)
class ManualMemberAddition extends StatefulWidget {
  const ManualMemberAddition({super.key});

  @override
  State<ManualMemberAddition> createState() => _ManualMemberAdditionState();
}

class _ManualMemberAdditionState extends State<ManualMemberAddition> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService.instance;

  String _selectedRole = 'developer';
  bool _isLoading = false;
  bool _generatePassword = true;

  final List<String> _availableRoles = [
    'admin',
    'lead_developer',
    'developer',
    'viewer',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate password if needed
      final password = _generatePassword
          ? _generateSecurePassword()
          : _passwordController.text;

      // Create user account
      final newUser = await _authService.createUser(
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        password: password,
        role: _selectedRole,
      );

      if (mounted) {
        // Show success message with credentials
        await _showSuccessDialog(newUser.email, password);

        // Clear form
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        setState(() {
          _selectedRole = 'developer';
          _generatePassword = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Successfully added ${newUser.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog(String email, String password) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Member Added Successfully'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'The new team member has been added with the following credentials:'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email: $email',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Password: $password',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Role: ${_selectedRole.replaceAll('_', ' ').toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ Make sure to securely share these credentials with the new member. They should change their password after first login.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  String _generateSecurePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    var password = '';

    for (int i = 0; i < 12; i++) {
      password += chars[(random + i) % chars.length];
    }

    return password;
  }

  @override
  Widget build(BuildContext context) {
    // Check admin permissions
    if (!_authService.hasPermission('manage_users')) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Access Denied: You need admin permissions to add team members.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Add Team Member Manually',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'Enter member\'s full name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  hintText: 'Enter member\'s email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Role selection
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security),
                ),
                items: _availableRoles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Row(
                      children: [
                        Icon(
                          _getRoleIcon(role),
                          color: _getRoleColor(role),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(role.replaceAll('_', ' ').toUpperCase()),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Password options
              Row(
                children: [
                  Checkbox(
                    value: _generatePassword,
                    onChanged: (value) {
                      setState(() {
                        _generatePassword = value!;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text('Generate secure password automatically'),
                  ),
                ],
              ),

              if (!_generatePassword) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    hintText: 'Enter temporary password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (!_generatePassword &&
                        (value == null || value.length < 6)) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addMember,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),
                  label:
                      Text(_isLoading ? 'Adding Member...' : 'Add Team Member'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Help text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Important Notes:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• The new member will receive their credentials and should change their password after first login\n'
                      '• Make sure to securely share the login credentials\n'
                      '• All actions are logged for security and audit purposes',
                      style: TextStyle(fontSize: 12),
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

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'lead_developer':
        return Icons.engineering;
      case 'developer':
        return Icons.code;
      case 'viewer':
        return Icons.visibility;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'lead_developer':
        return Colors.purple;
      case 'developer':
        return Colors.blue;
      case 'viewer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
