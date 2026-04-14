import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/investor_repo.dart';

final investmentDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(investmentRepoProvider).get(id);
});
final investmentTxnsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  return ref.read(investmentRepoProvider).transactions(id);
});

class InvestmentDetailPage extends ConsumerStatefulWidget {
  final String id;
  const InvestmentDetailPage({super.key, required this.id});
  @override
  ConsumerState<InvestmentDetailPage> createState() => _InvestmentDetailPageState();
}

class _InvestmentDetailPageState extends ConsumerState<InvestmentDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _withdrawInterest() async {
    final amountCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Interest'),
        content: TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw'))],
      ),
    );
    if (ok != true) return;
    final amt = double.tryParse(amountCtrl.text);
    if (amt == null || amt <= 0) return showToast('Enter valid amount', error: true);
    try {
      await ref.read(investmentRepoProvider).withdrawInterest(widget.id, amount: amt);
      ref.invalidate(investmentDetailProvider(widget.id));
      ref.invalidate(investmentTxnsProvider(widget.id));
      showToast('Interest withdrawn');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Future<void> _close() async {
    final ok = await confirmDialog(context, message: 'Close this investment?', destructive: true, confirmText: 'Close');
    if (!ok) return;
    try {
      await ref.read(investmentRepoProvider).close(widget.id);
      ref.invalidate(investmentDetailProvider(widget.id));
      showToast('Investment closed');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(investmentDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Info'), Tab(text: 'Transactions')]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'withdraw') _withdrawInterest();
              if (v == 'close') _close();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'withdraw', child: Text('Withdraw Interest')),
              PopupMenuItem(value: 'close', child: Text('Close Investment')),
            ],
          ),
        ],
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (inv) => TabBarView(
          controller: _tabs,
          children: [_info(inv), _txns()],
        ),
      ),
    );
  }

  Widget _info(Map<String, dynamic> inv) {
    final investor = Map<String, dynamic>.from(inv['investor'] ?? {});
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Text(formatCurrency(inv['amount']), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 8),
                StatusChip(label: inv['status']?.toString() ?? '', color: statusColor(inv['status']?.toString())),
              ],
            ),
          ),
        ),
        SectionCard(
          title: 'Investor',
          child: KeyValueRow(label: 'Name', value: investor['name']?.toString() ?? '-'),
        ),
        SectionCard(
          title: 'Details',
          child: Column(
            children: [
              KeyValueRow(label: 'Rate', value: '${inv['interestRate'] ?? 0}%'),
              KeyValueRow(label: 'Type', value: inv['interestType']?.toString() ?? '-'),
              KeyValueRow(label: 'Start', value: formatDate(inv['startDate'])),
              KeyValueRow(label: 'Maturity', value: formatDate(inv['maturityDate'])),
              KeyValueRow(label: 'Interest Earned', value: formatCurrency(inv['interestEarned'])),
              KeyValueRow(label: 'Interest Paid', value: formatCurrency(inv['interestPaid'])),
              KeyValueRow(label: 'Current Balance', value: formatCurrency(inv['currentBalance'])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _txns() {
    final txns = ref.watch(investmentTxnsProvider(widget.id));
    return txns.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No transactions');
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final t = Map<String, dynamic>.from(items[i] as Map);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                title: Text(t['type']?.toString() ?? ''),
                subtitle: Text(formatDateTime(t['createdAt'])),
                trailing: Text(formatCurrency(t['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            );
          },
        );
      },
    );
  }
}
