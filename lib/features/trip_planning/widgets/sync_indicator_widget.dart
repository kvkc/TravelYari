import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/sync/trip_sync_service.dart';
import '../../../core/theme/app_theme.dart';

class SyncIndicatorWidget extends ConsumerWidget {
  final String tripId;
  final VoidCallback onRefresh;

  const SyncIndicatorWidget({
    super.key,
    required this.tripId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasRemoteChanges = ref.watch(tripHasRemoteChangesProvider(tripId));

    if (!hasRemoteChanges) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(8),
      child: Material(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          onTap: onRefresh,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.sync,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Changes available',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      Text(
                        'Someone updated this trip',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Refresh',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner version that shows at the top of a screen
class SyncBanner extends ConsumerWidget {
  final String tripId;
  final VoidCallback onRefresh;

  const SyncBanner({
    super.key,
    required this.tripId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasRemoteChanges = ref.watch(tripHasRemoteChangesProvider(tripId));
    final syncState = ref.watch(tripSyncServiceProvider);

    if (!hasRemoteChanges) {
      return const SizedBox.shrink();
    }

    return MaterialBanner(
      content: const Text(
        'This trip has been updated by another participant.',
      ),
      leading: const Icon(Icons.sync, color: Colors.blue),
      backgroundColor: Colors.blue.shade50,
      actions: [
        TextButton(
          onPressed: () {
            ref.read(tripSyncServiceProvider.notifier).clearRemoteChanges(tripId);
          },
          child: const Text('Dismiss'),
        ),
        TextButton(
          onPressed: onRefresh,
          child: const Text('Refresh'),
        ),
      ],
    );
  }
}

/// Small sync status indicator for app bar
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(tripSyncServiceProvider);

    IconData icon;
    Color color;
    String tooltip;

    switch (syncState.status) {
      case SyncStatus.syncing:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white70),
            ),
          ),
        );
      case SyncStatus.synced:
        icon = Icons.cloud_done;
        color = Colors.white70;
        tooltip = 'Synced';
        break;
      case SyncStatus.error:
        icon = Icons.cloud_off;
        color = Colors.red.shade200;
        tooltip = 'Sync error';
        break;
      case SyncStatus.offline:
        icon = Icons.cloud_off;
        color = Colors.grey;
        tooltip = 'Offline';
        break;
      case SyncStatus.idle:
      default:
        icon = Icons.cloud_outlined;
        color = Colors.white70;
        tooltip = 'Ready to sync';
    }

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
