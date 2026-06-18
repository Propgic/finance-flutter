import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'update_service.dart';

/// Wraps the whole app (via [MaterialApp.router]'s `builder`) and enforces the
/// version policy returned by the backend:
///   * [UpdateLevel.forced]   → replaces everything with a blocking update screen.
///   * [UpdateLevel.optional] → overlays a dismissible "update available" banner.
///   * [UpdateLevel.none]     → renders the app untouched.
/// Re-checks whenever the app is resumed so a force-update published while the
/// app was backgrounded is caught without a relaunch.
class UpdateGate extends ConsumerStatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> with WidgetsBindingObserver {
  bool _optionalDismissed = false;

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
      ref.invalidate(updateCheckProvider);
    }
  }

  Future<void> _openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(updateCheckProvider).value ?? UpdateCheck.none;

    if (check.level == UpdateLevel.forced) {
      return _ForceUpdateScreen(
        check: check,
        onUpdate: () => _openStore(check.storeUrl),
      );
    }

    return Stack(
      children: [
        widget.child,
        if (check.level == UpdateLevel.optional && !_optionalDismissed)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _UpdateBanner(
              check: check,
              onUpdate: () => _openStore(check.storeUrl),
              onLater: () => setState(() => _optionalDismissed = true),
            ),
          ),
      ],
    );
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  final UpdateCheck check;
  final VoidCallback onUpdate;
  const _ForceUpdateScreen({required this.check, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = check.releaseNotes.trim();
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
                  Icon(Icons.system_update, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  Text(
                    'Update required',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A new version of the app is available and is required to continue. '
                    'Please update to the latest version to keep using the app.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text("What's new\n$notes", style: theme.textTheme.bodySmall),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onUpdate,
                      icon: const Icon(Icons.download),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Update now'),
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

class _UpdateBanner extends StatelessWidget {
  final UpdateCheck check;
  final VoidCallback onUpdate;
  final VoidCallback onLater;
  const _UpdateBanner({required this.check, required this.onUpdate, required this.onLater});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Icon(Icons.system_update, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Update available',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        check.latest.isNotEmpty
                            ? 'Version ${check.latest} is now available.'
                            : 'A newer version is available.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: onLater, child: const Text('Later')),
                FilledButton(onPressed: onUpdate, child: const Text('Update')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
