import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/expense_repo.dart';
import '../../app_shell.dart';
import '../../../core/widgets/app_bottom_nav.dart';

class ExpenseListPage extends ConsumerStatefulWidget {
  const ExpenseListPage({super.key});
  @override
  ConsumerState<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends ConsumerState<ExpenseListPage> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() { super.initState(); _load(); }
  void _load() { _future = ref.read(expenseRepoProvider).list(); setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final isMgr = ref.watch(authProvider).hasRole('ORG_ADMIN') || ref.watch(authProvider).hasRole('MANAGER');
    return Scaffold(
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Expenses'),
        leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
      ),
      floatingActionButton: isMgr
          ? FloatingActionButton.extended(onPressed: () => context.push('/expenses/new'), icon: const Icon(Icons.add), label: const Text('New'))
          : null,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
          if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _load);
          final items = extractList(snap.data?['data'] ?? snap.data);
          if (items.isEmpty) return const EmptyView(message: 'No expenses', icon: Icons.receipt_long_outlined);
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final e = Map<String, dynamic>.from(items[i] as Map);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                      child: const Icon(Icons.receipt_long, color: AppColors.danger, size: 18),
                    ),
                    title: Text(e['category']?.toString() ?? ''),
                    subtitle: Text('${formatDate(e['expenseDate'])} • ${e['paymentMode'] ?? ''}'),
                    trailing: Text(formatCurrency(e['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: isMgr
                        ? () async {
                            final action = await showModalBottomSheet<String>(
                              context: context,
                              builder: (_) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(leading: const Icon(Icons.delete, color: AppColors.danger), title: const Text('Delete'), onTap: () => Navigator.pop(context, 'delete')),
                                  ],
                                ),
                              ),
                            );
                            if (action == 'delete') {
                              final ok = await confirmDialog(context, message: 'Delete expense?', destructive: true, confirmText: 'Delete');
                              if (!ok) return;
                              try {
                                await ref.read(expenseRepoProvider).delete(e['id'].toString());
                                showToast('Deleted');
                                _load();
                              } on ApiException catch (ex) { showToast(ex.message, error: true); }
                            }
                          }
                        : null,
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
