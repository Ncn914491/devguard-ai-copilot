import 'package:flutter/material.dart';
import '../../core/supabase/services/supabase_realtime_service.dart';
import 'dart:async';

/// Real-time connection status indicator widget
/// Shows the current status of real-time subscriptions
class RealtimeStatusIndicator extends StatefulWidget {
  const RealtimeStatusIndicator({super.key});

  @override
  State<RealtimeStatusIndicator> createState() =>
      _RealtimeStatusIndicatorState();
}

class _RealtimeStatusIndicatorState extends State<RealtimeStatusIndicator> {
  final _realtimeService = SupabaseRealtimeService.instance;
  Timer? _statusCheckTimer;
  bool _isConnected = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _startStatusChecking();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _startStatusChecking() {
    // Check status immediately
    _checkStatus();

    // Set up periodic status checking
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkStatus(),
    );
  }

  void _checkStatus() {
    if (mounted) {
      setState(() {
        _isConnected = _realtimeService.isConnected;
        _lastError = _realtimeService.lastError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getTooltipMessage(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStatusColor().withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getStatusColor(),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _getStatusColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (_isConnected) {
      return Colors.green;
    } else if (_lastError != null) {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }

  String _getStatusText() {
    if (_isConnected) {
      return 'Live';
    } else if (_lastError != null) {
      return 'Error';
    } else {
      return 'Connecting';
    }
  }

  String _getTooltipMessage() {
    if (_isConnected) {
      final status = _realtimeService.getSubscriptionStatus();
      final activeSubscriptions = status['activeSubscriptions'] ?? 0;
      return 'Real-time connected\n$activeSubscriptions active subscriptions';
    } else if (_lastError != null) {
      return 'Real-time connection error:\n$_lastError';
    } else {
      return 'Connecting to real-time services...';
    }
  }
}
