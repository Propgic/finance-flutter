import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/loan_repo.dart';

final loanDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(loanRepoProvider).get(id);
});

final loanEmiProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  return ref.read(loanRepoProvider).emiSchedule(id);
});

class LoanDetailPage extends ConsumerStatefulWidget {
  final String id;
  const LoanDetailPage({super.key, required this.id});
  @override
  ConsumerState<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends ConsumerState<LoanDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _doAction(Future<void> Function() fn, String msg) async {
    try {
      await fn();
      ref.invalidate(loanDetailProvider(widget.id));
      showToast(msg);
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(loanDetailProvider(widget.id));
    final auth = ref.watch(authProvider);
    final isMgr = auth.hasRole('ORG_ADMIN') || auth.hasRole('MANAGER');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Details'), Tab(text: 'EMI Schedule')],
        ),
        actions: [
          data.maybeWhen(
            data: (l) => PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'disburse') {
                  final ok = await confirmDialog(context, message: 'Disburse this loan?');
                  if (ok) _doAction(() => ref.read(loanRepoProvider).disburse(widget.id), 'Loan disbursed');
                }
                if (v == 'reject') {
                  final ok = await confirmDialog(context, message: 'Reject this loan?', destructive: true, confirmText: 'Reject');
                  if (ok) _doAction(() => ref.read(loanRepoProvider).reject(widget.id), 'Loan rejected');
                }
                if (v == 'close') {
                  final ok = await confirmDialog(context, message: 'Close this loan?');
                  if (ok) _doAction(() => ref.read(loanRepoProvider).close(widget.id), 'Loan closed');
                }
              },
              itemBuilder: (_) => [
                if (isMgr && l['status'] == 'APPROVED') const PopupMenuItem(value: 'disburse', child: Text('Disburse')),
                if (isMgr && (l['status'] == 'PENDING' || l['status'] == 'APPROVED')) const PopupMenuItem(value: 'reject', child: Text('Reject')),
                if (isMgr && l['status'] == 'ACTIVE') const PopupMenuItem(value: 'close', child: Text('Close Loan')),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(loanDetailProvider(widget.id))),
        data: (l) => TabBarView(
          controller: _tabs,
          children: [_infoTab(l), _emiTab()],
        ),
      ),
    );
  }

  Widget _infoTab(Map<String, dynamic> l) {
    final c = Map<String, dynamic>.from(l['customer'] ?? {});
    final assignee = Map<String, dynamic>.from(l['assignedTo'] ?? {});
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l['loanNumber']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                    StatusChip(label: l['status']?.toString() ?? '', color: statusColor(l['status']?.toString())),
                  ],
                ),
                const SizedBox(height: 4),
                Text(l['loanType']?.toString() ?? '', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        SectionCard(
          title: 'Customer',
          actions: [
            TextButton(
              onPressed: () => context.push('/customers/${c['id']}'),
              child: const Text('View'),
            ),
          ],
          child: Column(
            children: [
              KeyValueRow(label: 'Name', value: '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim()),
              KeyValueRow(label: 'Phone', value: c['phone']?.toString() ?? '-'),
            ],
          ),
        ),
        SectionCard(
          title: 'Loan Terms',
          child: Column(
            children: [
              KeyValueRow(label: 'Principal', value: formatCurrency(l['principalAmount'])),
              KeyValueRow(label: 'Interest Rate', value: '${l['interestRate'] ?? '-'}%'),
              KeyValueRow(label: 'Tenure', value: '${l['tenure'] ?? ''} ${l['tenureType'] ?? ''}'),
              KeyValueRow(label: 'EMI', value: formatCurrency(l['emiAmount'])),
              KeyValueRow(label: 'Total Payable', value: formatCurrency(l['totalPayable'])),
              KeyValueRow(label: 'Processing Fee', value: formatCurrency(l['processingFee'])),
              KeyValueRow(label: 'Start Date', value: formatDate(l['startDate'])),
              KeyValueRow(label: 'Disbursed', value: formatDate(l['disbursedDate'])),
              KeyValueRow(label: 'Maturity', value: formatDate(l['maturityDate'])),
            ],
          ),
        ),
        SectionCard(
          title: 'Payment Status',
          child: Column(
            children: [
              KeyValueRow(label: 'Paid', value: formatCurrency(l['totalPaid'])),
              KeyValueRow(label: 'Outstanding', value: formatCurrency(l['outstandingAmount'])),
              KeyValueRow(label: 'Overdue', value: formatCurrency(l['overdueAmount'])),
            ],
          ),
        ),
        if (assignee.isNotEmpty)
          SectionCard(
            title: 'Assigned To',
            child: KeyValueRow(label: assignee['name']?.toString() ?? '-', value: assignee['role']?.toString() ?? '-'),
          ),
        if (l['notes'] != null && l['notes'].toString().isNotEmpty)
          SectionCard(title: 'Notes', child: Text(l['notes'].toString())),
      ],
    );
  }

  Widget _emiTab() {
    final emis = ref.watch(loanEmiProvider(widget.id));
    return emis.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No EMI schedule');
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final e = Map<String, dynamic>.from(items[i] as Map);
            final status = e['status']?.toString() ?? '';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor(status).withValues(alpha: 0.15),
                  child: Text('${e['emiNumber']}', style: TextStyle(color: statusColor(status), fontWeight: FontWeight.bold)),
                ),
                title: Text(formatDate(e['dueDate'])),
                subtitle: Text('EMI: ${formatCurrency(e['emiAmount'])}${toNum(e['lateFee']) > 0 ? ' • Late: ${formatCurrency(e['lateFee'])}' : ''}'),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatusChip(label: status, color: statusColor(status)),
                    if (toNum(e['paidAmount']) > 0)
                      Text(formatCurrency(e['paidAmount']), style: const TextStyle(fontSize: 11, color: AppColors.accent)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
