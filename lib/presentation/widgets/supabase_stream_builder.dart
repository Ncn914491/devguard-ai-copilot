import 'package:flutter/material.dart';
import 'data_loading_widget.dart';

/// Generic stream builder widget for Supabase data with proper error handling
class SupabaseStreamBuilder<T> extends StatelessWidget {
  final Stream<List<T>>? stream;
  final Widget Function(BuildContext context, List<T> data) builder;
  final String? loadingMessage;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final VoidCallback? onRetry;
  final VoidCallback? onEmptyAction;
  final String? emptyActionLabel;

  const SupabaseStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.loadingMessage,
    this.emptyMessage,
    this.emptyIcon,
    this.onRetry,
    this.onEmptyAction,
    this.emptyActionLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (stream == null) {
      return DataErrorWidget(
        message: 'Stream not initialized',
        onRetry: onRetry,
      );
    }

    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return DataLoadingWidget(
            message: loadingMessage ?? 'Loading data...',
          );
        }

        // Error state
        if (snapshot.hasError) {
          return DataErrorWidget(
            message: 'Failed to load data: ${snapshot.error}',
            onRetry: onRetry,
          );
        }

        // Empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return DataEmptyWidget(
            message: emptyMessage ?? 'No data available',
            icon: emptyIcon,
            onAction: onEmptyAction,
            actionLabel: emptyActionLabel,
          );
        }

        // Success state
        return builder(context, snapshot.data!);
      },
    );
  }
}

/// Stream builder specifically for real-time updates with connection status
class RealtimeStreamBuilder<T> extends StatelessWidget {
  final Stream<List<T>>? stream;
  final Widget Function(BuildContext context, List<T> data, bool isConnected)
      builder;
  final String? loadingMessage;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final VoidCallback? onRetry;

  const RealtimeStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.loadingMessage,
    this.emptyMessage,
    this.emptyIcon,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (stream == null) {
      return DataErrorWidget(
        message: 'Real-time stream not initialized',
        onRetry: onRetry,
      );
    }

    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        final isConnected = snapshot.connectionState == ConnectionState.active;

        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return DataLoadingWidget(
            message: loadingMessage ?? 'Connecting to real-time updates...',
          );
        }

        // Error state
        if (snapshot.hasError) {
          return DataErrorWidget(
            message: 'Real-time connection failed: ${snapshot.error}',
            onRetry: onRetry,
          );
        }

        // Empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Column(
            children: [
              if (!isConnected)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.orange.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Real-time updates disconnected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.orange,
                            ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: DataEmptyWidget(
                  message: emptyMessage ?? 'No data available',
                  icon: emptyIcon,
                ),
              ),
            ],
          );
        }

        // Success state with connection indicator
        return Column(
          children: [
            if (!isConnected)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.orange.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Real-time updates disconnected',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                          ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: builder(context, snapshot.data!, isConnected),
            ),
          ],
        );
      },
    );
  }
}
