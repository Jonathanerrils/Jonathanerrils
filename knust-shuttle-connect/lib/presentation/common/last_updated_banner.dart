import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Offline honesty: when we're showing cached data, say so with a timestamp
/// instead of pretending it's live (requirement: no blank screens offline).
class LastUpdatedBanner extends StatelessWidget {
  final bool fromCacheOnly;
  final DateTime? updatedAt;

  const LastUpdatedBanner({
    super.key,
    required this.fromCacheOnly,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    if (!fromCacheOnly) return const SizedBox.shrink();
    final when = updatedAt == null
        ? 'earlier'
        : DateFormat('EEE h:mm a').format(updatedAt!);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Showing saved data (last updated $when). Counts may be stale.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
