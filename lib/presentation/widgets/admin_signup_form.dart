import 'package:flutter/material.dart';
import '../../core/services/project_service.dart';
import '../../core/models/project.dart';

/// Admin signup form for creating new projects
class AdminSignupForm extends StatefulWidget {
  const AdminSignupForm({super.key});

  @override
  State<AdminSignupForm> createState() => _AdminSignupFormState();
}

class _AdminSignupFormState extends State<AdminSignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _projectDescriptionController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _projectNameController.dispose();
    _projectDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Stepper(
        currentStep: _currentStep,
        onStepTapped: (step) {
          if (step <= _currentStep) {
            setState(() {
              _currentStep = step;
            });
          }
        },
        controlsBuilder: (context, details) {
          return Row(
            children: [
              if (details.stepIndex > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : () {
                  if (details.stepIndex == 2) {
                    _createProject();
                  } else {
                    details.onStepContinue?.call();
                  }
                },
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(details.stepIndex == 2 ? 'Create Project' : 'Next'),
              ),
            ],
          );
        },
        onStepContinue: () {
          if (_validateCurrentStep()) {
            setState(() {
              _currentStep++;
            });
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep--;
            });
          }
        },
        steps: [
          Step(
            title: const Text('Admin Account'),
            content: _buildAdminAccountStep(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Project Details'),
            content: _buildProjectDetailsStep(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : 
                   _currentStep == 1 ? StepState.indexed : StepState.disabled,
          ),
          Step(
            title: const Text('Configuration'),
            content: _buildConfigurationStep(),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.indexed : StepState.disabled,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Admin Account',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You will become the initial administrator of this project.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            hintText: 'Enter your full name',
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'Enter your email address',
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email address';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter a secure password',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          obscureText: _obscurePassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters long';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Confirm your password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
          obscureText: _obscureConfirmPassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildProjectDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Project Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Configure your new development project.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        
        TextFormField(
          controller: _projectNameController,
          decoration: const InputDecoration(
            labelText: 'Project Name',
            hintText: 'Enter project name',
            prefixIcon: Icon(Icons.folder),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a project name';
            }
            if (value.length < 3) {
              return 'Project name must be at least 3 characters long';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _projectDescriptionController,
          decoration: const InputDecoration(
            labelText: 'Project Description',
            hintText: 'Describe your project',
            prefixIcon: Icon(Icons.description),
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a project description';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildConfigurationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Project Configuration',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Review your project settings before creation.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        
        _buildSummaryCard('Admin Account', [
          'Name: ${_nameController.text}',
          'Email: ${_emailController.text}',
          'Role: Project Administrator',
        ]),
        const SizedBox(height: 16),
        
        _buildSummaryCard('Project Details', [
          'Name: ${_projectNameController.text}',
          'Description: ${_projectDescriptionController.text}',
        ]),
        const SizedBox(height: 16),
        
        _buildSummaryCard('Default Settings', [
          '✓ Security monitoring enabled',
          '✓ Git repository initialized',
          '✓ Audit logging enabled',
          '✓ Join requests require approval',
        ]),
      ],
    );
  }

  Widget _buildSummaryCard(String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )),
          ],
        ),
      ),
    );
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _formKey.currentState?.validate() ?? false;
      case 1:
        return _formKey.currentState?.validate() ?? false;
      case 2:
        return true;
      default:
        return false;
    }
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ProjectService.instance.createProjectWithAdmin(
        adminName: _nameController.text.trim(),
        adminEmail: _emailController.text.trim(),
        adminPassword: _passwordController.text,
        projectName: _projectNameController.text.trim(),
        projectDescription: _projectDescriptionController.text.trim(),
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to main application
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating project: $e'),
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
}