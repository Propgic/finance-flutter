import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'maintenance_controller.dart';

/// Wraps the whole app (via [MaterialApp.router]'s `builder`) and shows a
/// full-screen blocker whenever the backend reports maintenance (HTTP 503 —
/// platform-wide or for this org). "Try again" re-pings the API; if it's still
/// down the interceptor re-triggers the blocker, otherwise the app resumes.
class MaintenanceGate extends ConsumerStatefulWidget {
  final Widget child;
  const MaintenanceGate({super.key, required this.child});

  @override
  ConsumerState<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends ConsumerState<MaintenanceGate> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    ref.read(maintenanceProvider.notifier).clear();
    try {
      // Re-hit a gated endpoint. A 503 re-triggers the blocker via the API
      // client; any other outcome leaves the app to continue normally.
      await ref.read(apiClientProvider).get('dashboard');
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceProvider);
    if (!state.active) return widget.child;
    return _MaintenanceScreen(message: state.message, checking: _checking, onRetry: _retry);
  }
}

class _MaintenanceScreen extends StatelessWidget {
  final String message;
  final bool checking;
  final VoidCallback onRetry;
  const _MaintenanceScreen({
    required this.message,
    required this.checking,
    required this.onRetry,
  });

  static const _fallback =
      "We're performing scheduled maintenance and will be back shortly. Thanks for your patience.";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // canPop:false blocks the Android back button — there's no dismissing this.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.engineering, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  Text(
                    'Down for maintenance',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message.trim().isNotEmpty ? message : _fallback,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: checking ? null : onRetry,
                      icon: checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(checking ? 'Checking…' : 'Try again'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
