import 'package:flutter/material.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/models/join_request.dart';
import '../../core/auth/auth_service.dart';

/// Widget for managing join requests in admin dashboard
class JoinRequestManagement extends StatefulWidget {
  const JoinRequestManagement({super.key});

  @override
  State<JoinRequestManagement> createState() => _JoinRequestManagementState();
}

class _JoinRequestManagementState extends State<JoinRequestManagement> {
  final _onboardingService = OnboardingService.instance;
  final _authService = AuthService.instance;

  List<JoinRequest> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRequests();

    // Listen to real-time updates
    _onboardingService.requestsStream.listen((requests) {
      if (mounted) {
        setState(() {
          _requests = requests
              .where((r) => r.status == JoinRequestStatus.pending)
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
      }
    });
  }

  Future<void> _loadRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final requests = await _onboardingService.getPendingRequests();

      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveRequest(JoinRequest request) async {
    final adminNotes = await _showAdminNotesDialog(
      title: 'Approve Join Request',
      subtitle: 'Approving request from ${request.name}',
      hintText: 'Optional notes for the new member...',
    );

    if (adminNotes == null) return; // User cancelled

    try {
      final success = await _onboardingService.approveRequest(
        request.id,
        adminNotes: adminNotes.isEmpty ? null : adminNotes,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Approved ${request.name}\'s request'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadRequests();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve request'),
            backgroundColor: Colors.red,
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
    }
  }

  Future<void> _rejectRequest(JoinRequest request) async {
    final reason = await _showAdminNotesDialog(
      title: 'Reject Join Request',
      subtitle: 'Rejecting request from ${request.name}',
      hintText: 'Reason for rejection (required)...',
      required: true,
    );

    if (reason == null || reason.isEmpty) return;

    try {
      final success =
          await _onboardingService.rejectRequest(request.id, reason);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Rejected ${request.name}\'s request'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadRequests();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject request'),
            backgroundColor: Colors.red,
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
    }
  }

  Future<String?> _showAdminNotesDialog({
    required String title,
    required String subtitle,
    required String hintText,
    bool required = false,
  }) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: hintText,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This field is required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop(text);
            },
            child: Text(title.contains('Approve') ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check admin permissions
    if (!_authService.hasPermission('manage_users')) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Access Denied: You need admin permissions to manage join requests.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Join Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadRequests,
                  tooltip: 'Refresh requests',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading requests:\n$_errorMessage',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRequests,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_requests.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.inbox, color: Colors.grey, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'No pending join requests',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return _buildRequestCard(request);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(JoinRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    request.name.isNotEmpty
                        ? request.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        request.email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        _getRoleColor(request.requestedRole).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getRoleColor(request.requestedRole),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    request.requestedRole.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _getRoleColor(request.requestedRole),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.message!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Submitted ${_formatDateTime(request.createdAt)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _rejectRequest(request),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _approveRequest(request),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
