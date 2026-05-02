import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/loan_repo.dart';

class OverdueListPage extends ConsumerStatefulWidget {
  const OverdueListPage({super.key});
  @override
  ConsumerState<OverdueListPage> createState() => _OverdueListPageState();
}

class _OverdueListPageState extends ConsumerState<OverdueListPage> {
  List<dynamic> _items = [];
  bool _loading = true;
  bool _grouped = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _grouped = prefs.getBool('overdueGroupByCustomer') ?? false;
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await ref.read(loanRepoProvider).overdue(groupByCustomer: _grouped);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleGrouped() async {
    final next = !_grouped;
    setState(() => _grouped = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('overdueGroupByCustomer', next);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _grouped
        ? _items.fold<double>(0, (s, e) => s + toNum(e['totalDue']))
        : _items.fold<double>(0, (s, e) => s + toNum(e['emiAmount']) + toNum(e['lateFee']) - toNum(e['paidAmount']));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overdue'),
        actions: [
          TextButton.icon(
            onPressed: _toggleGrouped,
            icon: Icon(_grouped ? Icons.check_box : Icons.check_box_outline_blank, size: 18),
            label: const Text('Group', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error.toString(), onRetry: _fetch)
              : _items.isEmpty
                  ? const EmptyView(message: 'No overdue', icon: Icons.check_circle_outline)
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Overdue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger)),
                                Text(formatCurrency(totalAmount), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.danger)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (ctx, i) => _grouped ? _groupedTile(_items[i]) : _detailTile(_items[i]),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _detailTile(dynamic item) {
    final l = Map<String, dynamic>.from(item as Map);
    final loan = Map<String, dynamic>.from(l['loan'] ?? {});
    final c = Map<String, dynamic>.from(loan['customer'] ?? {});
    final dueAmount = toNum(l['emiAmount']) + toNum(l['lateFee']) - toNum(l['paidAmount']);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.warning_amber, color: AppColors.danger),
        title: Text(loan['loanNumber']?.toString() ?? l['loanNumber']?.toString() ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim(), style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('Due: ${formatCurrency(dueAmount)} • ${l['daysOverdue'] ?? 0} days', style: const TextStyle(fontSize: 11, color: AppColors.danger)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/loans/${l['loanId'] ?? loan['id']}'),
      ),
    );
  }

  Widget _groupedTile(dynamic item) {
    final g = Map<String, dynamic>.from(item as Map);
    final c = Map<String, dynamic>.from(g['customer'] ?? {});
    final loans = (g['loans'] as List?) ?? [];
    final loanNumbers = (g['loanNumbers'] as List?)?.join(', ') ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.warning_amber, color: AppColors.danger),
        title: Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim(), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loanNumbers, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text('${g['overdueCount']} installments • ${g['daysOverdue']} days overdue',
                style: const TextStyle(fontSize: 11, color: AppColors.danger)),
          ],
        ),
        trailing: Text(formatCurrency(g['totalDue']),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
        onTap: loans.length == 1 ? () => context.push('/loans/${loans[0]['loanId']}') : null,
      ),
    );
  }
}
