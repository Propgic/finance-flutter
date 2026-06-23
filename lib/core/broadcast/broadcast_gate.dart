import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'broadcast_controller.dart';

/// Wraps the app (via [MaterialApp.router]'s `builder`, below the maintenance
/// and update gates) and floats a dismissible super-admin broadcast banner at
/// the top of the screen. Shows one broadcast at a time (newest first); the
/// next surfaces after the current one is dismissed. Re-checks on app resume so
/// a broadcast published while backgrounded appears without a relaunch.
class BroadcastGate extends ConsumerStatefulWidget {
  final Widget child;
  const BroadcastGate({super.key, required this.child});

  @override
  ConsumerState<BroadcastGate> createState() => _BroadcastGateState();
}

class _BroadcastGateState extends ConsumerState<BroadcastGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(broadcastProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(broadcastProvider);
    final current = items.isNotEmpty ? items.first : null;

    return Stack(
      children: [
        widget.child,
        if (current != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _BroadcastBanner(
              item: current,
              remaining: items.length,
              onDismiss: () => ref.read(broadcastProvider.notifier).dismiss(current.id),
            ),
          ),
      ],
    );
  }
}

class _BroadcastBanner extends StatelessWidget {
  final Broadcast item;
  final int remaining;
  final VoidCallback onDismiss;
  const _BroadcastBanner({required this.item, required this.remaining, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.campaign_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (remaining > 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '1 of $remaining',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(item.message, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
