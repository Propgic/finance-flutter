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
  late DateTime _monthStart;
  late DateTime _monthEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthStart = DateTime(now.year, now.month, 1);
    _monthEnd = DateTime(now.year, now.month + 1, 0);
    _load();
  }

  void _load() {
    _future = ref.read(expenseRepoProvider).list(
      from: formatInputDate(_monthStart),
      to: formatInputDate(_monthEnd),
    );
    setState(() {});
  }

  void _changeMonth(int delta) {
    final m = DateTime(_monthStart.year, _monthStart.month + delta, 1);
    setState(() {
      _monthStart = m;
      _monthEnd = DateTime(m.year, m.month + 1, 0);
    });
    _load();
  }

  String get _monthLabel {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[_monthStart.month - 1]} ${_monthStart.year}';
  }

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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                Text(_monthLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _load);
                final items = extractList(snap.data?['data'] ?? snap.data);
                if (items.isEmpty) return const EmptyView(message: 'No expenses this month', icon: Icons.receipt_long_outlined);

                final totalAmount = items.fold<double>(0, (sum, e) => sum + (double.tryParse((e as Map)['amount']?.toString() ?? '0') ?? 0));

                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFBE123C)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Expenses', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(formatCurrency(totalAmount), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text('${items.length} entries', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      ...items.map((item) {
                        final e = Map<String, dynamic>.from(item as Map);
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
                                            ListTile(leading: const Icon(Icons.edit), title: const Text('Edit'), onTap: () => Navigator.pop(context, 'edit')),
                                            ListTile(leading: const Icon(Icons.delete, color: AppColors.danger), title: const Text('Delete'), onTap: () => Navigator.pop(context, 'delete')),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (action == 'edit') {
                                      if (mounted) context.push('/expenses/${e['id']}/edit');
                                    } else if (action == 'delete') {
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
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
