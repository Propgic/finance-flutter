import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/update/update_gate.dart';
import 'core/maintenance/maintenance_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  runApp(const ProviderScope(child: FinanceApp()));
}

class FinanceApp extends ConsumerWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Rupit Financer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      // Maintenance blocker sits above the version gate and every route.
      builder: (context, child) => MaintenanceGate(
        child: UpdateGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
