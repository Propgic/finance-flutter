import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/savings_repo.dart';

final savingsDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(savingsRepoProvider).get(id);
});
final savingsTxnsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  return ref.read(savingsRepoProvider).transactions(id);
});

class SavingsDetailPage extends ConsumerStatefulWidget {
  final String id;
  const SavingsDetailPage({super.key, required this.id});
  @override
  ConsumerState<SavingsDetailPage> createState() => _SavingsDetailPageState();
}

class _SavingsDetailPageState extends ConsumerState<SavingsDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _deposit() async {
    final res = await _showTxnSheet(context, 'Deposit');
    if (res == null) return;
    try {
      await ref.read(savingsRepoProvider).deposit(widget.id, res);
      ref.invalidate(savingsDetailProvider(widget.id));
      ref.invalidate(savingsTxnsProvider(widget.id));
      showToast('Deposit recorded');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Future<void> _withdraw() async {
    final res = await _showTxnSheet(context, 'Withdraw');
    if (res == null) return;
    try {
      await ref.read(savingsRepoProvider).withdraw(widget.id, res);
      ref.invalidate(savingsDetailProvider(widget.id));
      ref.invalidate(savingsTxnsProvider(widget.id));
      showToast('Withdrawal recorded');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Future<void> _close() async {
    final ok = await confirmDialog(context, message: 'Close this account?', destructive: true, confirmText: 'Close');
    if (!ok) return;
    try {
      await ref.read(savingsRepoProvider).close(widget.id);
      ref.invalidate(savingsDetailProvider(widget.id));
      showToast('Account closed');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(savingsDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Account'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Info'), Tab(text: 'Transactions')]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'deposit') _deposit();
              if (v == 'withdraw') _withdraw();
              if (v == 'close') _close();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'deposit', child: Text('Deposit')),
              PopupMenuItem(value: 'withdraw', child: Text('Withdraw')),
              PopupMenuItem(value: 'close', child: Text('Close Account')),
            ],
          ),
        ],
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (s) => TabBarView(
          controller: _tabs,
          children: [_infoTab(s), _txnTab()],
        ),
      ),
    );
  }

  Widget _infoTab(Map<String, dynamic> s) {
    final c = Map<String, dynamic>.from(s['customer'] ?? {});
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['accountNumber']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(s['accountType']?.toString() ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                const Text('Current Balance', style: TextStyle(color: AppColors.textSecondary)),
                Text(formatCurrency(s['balance']), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary)),
                const SizedBox(height: 8),
                StatusChip(label: s['status']?.toString() ?? '', color: statusColor(s['status']?.toString())),
              ],
            ),
          ),
        ),
        SectionCard(
          title: 'Customer',
          child: KeyValueRow(label: 'Name', value: '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim()),
        ),
        SectionCard(
          title: 'Details',
          child: Column(
            children: [
              KeyValueRow(label: 'Type', value: s['accountType']?.toString() ?? ''),
              KeyValueRow(label: 'Interest Rate', value: '${s['interestRate'] ?? 0}%'),
              KeyValueRow(label: 'Opened', value: formatDate(s['openedDate'])),
              if (s['pigmiAmount'] != null) KeyValueRow(label: 'Pigmi Amount', value: formatCurrency(s['pigmiAmount'])),
              if (s['pigmiFrequency'] != null) KeyValueRow(label: 'Pigmi Frequency', value: s['pigmiFrequency'].toString()),
              if (s['rdAmount'] != null) KeyValueRow(label: 'RD Monthly', value: formatCurrency(s['rdAmount'])),
              if (s['rdTenure'] != null) KeyValueRow(label: 'RD Tenure', value: '${s['rdTenure']} months'),
              if (s['fdAmount'] != null) KeyValueRow(label: 'FD Amount', value: formatCurrency(s['fdAmount'])),
              if (s['fdTenure'] != null) KeyValueRow(label: 'FD Tenure', value: '${s['fdTenure']} months'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _txnTab() {
    final txns = ref.watch(savingsTxnsProvider(widget.id));
    return txns.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No transactions');
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final t = Map<String, dynamic>.from(items[i] as Map);
            final isCredit = t['type'] == 'DEPOSIT' || t['type'] == 'INTEREST';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isCredit ? AppColors.accent : AppColors.danger,
                ),
                title: Text(t['type']?.toString() ?? ''),
                subtitle: Text(formatDateTime(t['createdAt'])),
                trailing: Text(
                  '${isCredit ? "+" : "-"}${formatCurrency(t['amount'])}',
                  style: TextStyle(color: isCredit ? AppColors.accent : AppColors.danger, fontWeight: FontWeight.w600),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Future<Map<String, dynamic>?> _showTxnSheet(BuildContext context, String title) {
  final amount = TextEditingController();
  final ref = TextEditingController();
  final notes = TextEditingController();
  String mode = 'CASH';
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setState) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                    DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                  ],
                  onChanged: (v) => setState(() => mode = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: ref, decoration: const InputDecoration(labelText: 'Reference')),
                const SizedBox(height: 10),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(amount.text);
                    if (amt == null || amt <= 0) return showToast('Enter valid amount', error: true);
                    Navigator.pop(ctx, {
                      'amount': amt,
                      'paymentMode': mode,
                      if (ref.text.trim().isNotEmpty) 'reference': ref.text.trim(),
                      if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
                    });
                  },
                  child: Text(title),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
