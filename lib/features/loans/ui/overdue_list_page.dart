import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/loan_repo.dart';

final overdueProvider = FutureProvider.autoDispose<List<dynamic>>((ref) => ref.read(loanRepoProvider).overdue());

class OverdueListPage extends ConsumerWidget {
  const OverdueListPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(overdueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Overdue Loans')),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(overdueProvider)),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No overdue loans', icon: Icons.check_circle_outline);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(overdueProvider),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final l = Map<String, dynamic>.from(items[i] as Map);
                final c = Map<String, dynamic>.from(l['customer'] ?? {});
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber, color: AppColors.danger),
                    title: Text(l['loanNumber']?.toString() ?? ''),
                    subtitle: Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''} • Overdue: ${formatCurrency(l['overdueAmount'])}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/loans/${l['id']}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
