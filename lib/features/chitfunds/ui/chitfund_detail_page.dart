import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/chitfund_repo.dart';
import '../../customers/data/customer_repo.dart';

final chitfundDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(chitfundRepoProvider).get(id);
});
final chitfundMembersProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  return ref.read(chitfundRepoProvider).members(id);
});
final chitfundAuctionsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  return ref.read(chitfundRepoProvider).auctions(id);
});
final chitfundPaymentsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  return ref.read(chitfundRepoProvider).payments(id);
});
final chitfundPayoutsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  return ref.read(chitfundRepoProvider).payouts(id);
});

const _paymentModes = ['CASH', 'UPI', 'BANK_TRANSFER', 'CHEQUE', 'ONLINE'];

class ChitfundDetailPage extends ConsumerStatefulWidget {
  final String id;
  const ChitfundDetailPage({super.key, required this.id});
  @override
  ConsumerState<ChitfundDetailPage> createState() => _ChitfundDetailPageState();
}

class _ChitfundDetailPageState extends ConsumerState<ChitfundDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  bool get _canManage {
    final auth = ref.read(authProvider);
    return auth.hasPermission('chitfunds.create') || auth.hasRole('ORG_ADMIN') || auth.hasRole('MANAGER');
  }

  Map<String, Map<String, dynamic>> _memberById() {
    final map = <String, Map<String, dynamic>>{};
    ref.watch(chitfundMembersProvider(widget.id)).whenData((items) {
      for (final m in items) {
        final mm = Map<String, dynamic>.from(m as Map);
        map[mm['id'].toString()] = mm;
      }
    });
    return map;
  }

  void _refreshAll() {
    ref.invalidate(chitfundDetailProvider(widget.id));
    ref.invalidate(chitfundMembersProvider(widget.id));
    ref.invalidate(chitfundAuctionsProvider(widget.id));
    ref.invalidate(chitfundPaymentsProvider(widget.id));
    ref.invalidate(chitfundPayoutsProvider(widget.id));
  }

  Future<void> _addMember() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustPicker(ref: ref),
    );
    if (picked == null) return;
    try {
      await ref.read(chitfundRepoProvider).addMember(widget.id, picked['id'].toString());
      ref.invalidate(chitfundMembersProvider(widget.id));
      ref.invalidate(chitfundDetailProvider(widget.id));
      showToast('Member added');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Future<void> _doAction(Future<void> Function() fn, String msg) async {
    try {
      await fn();
      _refreshAll();
      showToast(msg);
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(chitfundDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chitfund'),
        bottom: TabBar(controller: _tabs, isScrollable: true, tabs: const [
          Tab(text: 'Info'), Tab(text: 'Members'), Tab(text: 'Auctions'), Tab(text: 'Payments'), Tab(text: 'Payouts'),
        ]),
        actions: [
          data.maybeWhen(
            data: (c) => _canManage ? _menu(c) : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (c) => TabBarView(
          controller: _tabs,
          children: [_infoTab(c), _membersTab(c), _auctionsTab(c), _paymentsTab(c), _payoutsTab(c)],
        ),
      ),
    );
  }

  Widget _menu(Map<String, dynamic> c) {
    final status = c['status']?.toString();
    final dividendType = c['dividendType']?.toString() ?? 'SPLIT';
    final surplusOverflow = dividendType == 'ACCUMULATED' &&
        toNum(c['surplusPool']) >= toNum(c['totalAmount']);
    return PopupMenuButton<String>(
      onSelected: (v) {
        switch (v) {
          case 'start':
            _doAction(() => ref.read(chitfundRepoProvider).start(widget.id), 'Started');
            break;
          case 'complete':
            _doAction(() => ref.read(chitfundRepoProvider).complete(widget.id), 'Completed');
            break;
          case 'add_member':
            _addMember();
            break;
          case 'edit':
            _editChitfund(c);
            break;
          case 'record_payment':
            _openPayment(c);
            break;
          case 'final_dues':
            _openFinalDues(c);
            break;
          case 'extra_auction':
            _openExtraAuction(c);
            break;
        }
      },
      itemBuilder: (_) => [
        if (status == 'UPCOMING') const PopupMenuItem(value: 'start', child: Text('Start')),
        if (status == 'UPCOMING') const PopupMenuItem(value: 'edit', child: Text('Edit chitfund')),
        if (status == 'UPCOMING') const PopupMenuItem(value: 'add_member', child: Text('Add Member')),
        if (status == 'ACTIVE') const PopupMenuItem(value: 'record_payment', child: Text('Record Payment')),
        if (status == 'ACTIVE') const PopupMenuItem(value: 'final_dues', child: Text('Final Dues')),
        if (status == 'ACTIVE' && surplusOverflow)
          const PopupMenuItem(value: 'extra_auction', child: Text('Extra Auction')),
        if (status == 'ACTIVE') const PopupMenuItem(value: 'complete', child: Text('Complete')),
      ],
    );
  }

  Widget _infoTab(Map<String, dynamic> c) {
    final dividendType = c['dividendType']?.toString() ?? 'SPLIT';
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusChip(label: c['status']?.toString() ?? '', color: statusColor(c['status']?.toString())),
                    StatusChip(label: dividendType, color: AppColors.info),
                    if (toNum(c['pendingPayoutCount']) > 0)
                      StatusChip(
                        label: '${c['pendingPayoutCount']} payout(s) pending · ${formatCurrency(c['pendingPayoutAmount'] ?? 0)}',
                        color: AppColors.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SectionCard(
          title: 'Details',
          child: Column(
            children: [
              KeyValueRow(label: 'Total Amount', value: formatCurrency(c['totalAmount'])),
              KeyValueRow(label: 'Monthly Installment', value: formatCurrency(c['monthlyInstallment'])),
              KeyValueRow(label: 'Members', value: '${c['totalMembers']}'),
              KeyValueRow(label: 'Duration', value: '${c['durationMonths']} months'),
              KeyValueRow(label: 'Commission', value: '${c['commission'] ?? 0}%'),
              KeyValueRow(label: 'Start Date', value: formatDate(c['startDate'])),
              KeyValueRow(label: 'Current Month', value: '${c['currentMonth'] ?? 0} / ${c['durationMonths']}'),
              KeyValueRow(label: 'Total Collected', value: formatCurrency(c['totalCollected'] ?? 0)),
              KeyValueRow(
                label: 'Dividend Type',
                value: dividendType +
                    (dividendType == 'SPLIT' ? ' (${c['splitAudience'] == 'NON_WINNERS' ? 'Non-winners' : 'All'})' : ''),
              ),
              if (dividendType == 'ACCUMULATED')
                KeyValueRow(label: 'Surplus Pool', value: formatCurrency(c['surplusPool'] ?? 0), valueColor: AppColors.warning),
            ],
          ),
        ),
      ],
    );
  }

  Widget _membersTab(Map<String, dynamic> c) {
    final m = ref.watch(chitfundMembersProvider(widget.id));
    final isUpcoming = c['status'] == 'UPCOMING';
    return m.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No members yet');
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final mem = Map<String, dynamic>.from(items[i] as Map);
            final cust = Map<String, dynamic>.from(mem['customer'] ?? {});
            final hasWon = mem['hasWonAuction'] == true;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Avatar(url: cust['photo']?.toString(), name: '${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'),
                title: Text('#${mem['ticketNumber'] ?? '-'} ${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim()),
                subtitle: Text(
                  '${cust['phone'] ?? ''}'
                  '${hasWon ? ' · Won month ${mem['wonMonth'] ?? '-'}' : ''}',
                ),
                trailing: (isUpcoming && _canManage)
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () async {
                          final ok = await confirmDialog(context, message: 'Remove ticket #${mem['ticketNumber']} from this chitfund?', destructive: true, confirmText: 'Remove');
                          if (!ok) return;
                          try {
                            await ref.read(chitfundRepoProvider).removeMember(widget.id, mem['id'].toString());
                            ref.invalidate(chitfundMembersProvider(widget.id));
                            ref.invalidate(chitfundDetailProvider(widget.id));
                          } on ApiException catch (e) { showToast(e.message, error: true); }
                        },
                      )
                    : (toNum(mem['totalPaid']) > 0
                        ? Text(formatCurrency(mem['totalPaid']), style: const TextStyle(fontWeight: FontWeight.w600))
                        : null),
              ),
            );
          },
        );
      },
    );
  }

  Widget _auctionsTab(Map<String, dynamic> c) {
    final a = ref.watch(chitfundAuctionsProvider(widget.id));
    final status = c['status']?.toString();
    final currentMonth = toNum(c['currentMonth']).toInt();
    return a.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No auctions');
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final au = Map<String, dynamic>.from(items[i] as Map);
            final isCompleted = au['status'] == 'COMPLETED';
            final isExtra = au['isExtra'] == true;
            final monthNumber = toNum(au['monthNumber']).toInt();
            // Latest completed auction (this month's, or any extra) can be reversed.
            final canReverse = _canManage && isCompleted && status == 'ACTIVE' &&
                (isExtra || monthNumber == currentMonth - 1);
            // The current month's pending auction can be conducted.
            final canConduct = _canManage && !isCompleted && status == 'ACTIVE' && monthNumber == currentMonth;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                title: Row(
                  children: [
                    Text('Month ${au['monthNumber']}'),
                    if (isExtra) ...[
                      const SizedBox(width: 8),
                      const StatusChip(label: 'Extra', color: AppColors.warning),
                    ],
                  ],
                ),
                subtitle: Text(
                  isCompleted ? formatDate(au['auctionDate']) : 'Not conducted',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      toNum(au['bidAmount']) > 0 ? formatCurrency(au['bidAmount']) : '-',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (canConduct)
                      IconButton(
                        tooltip: 'Conduct auction',
                        icon: const Icon(Icons.gavel, color: AppColors.primary),
                        onPressed: () => _recordAuction(au['id'].toString()),
                      ),
                    if (canReverse)
                      IconButton(
                        tooltip: 'Reverse auction',
                        icon: const Icon(Icons.undo, color: AppColors.danger),
                        onPressed: () => _reverseAuction(au),
                      ),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
                onTap: () => context.push('/chitfunds/${widget.id}/auctions/${au['id']}'),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reverseAuction(Map<String, dynamic> au) async {
    final isExtra = au['isExtra'] == true;
    final ok = await confirmDialog(
      context,
      title: 'Reverse Auction',
      message: 'Reverse ${isExtra ? 'extra auction' : 'month ${au['monthNumber']}'}? The winner will be cleared, '
          'dividends/pool updated, and the auto-created payout deleted. This will fail if any collections already '
          'exist for this month or the payout is already settled.',
      confirmText: 'Reverse',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(chitfundRepoProvider).reverseAuction(widget.id, au['id'].toString());
      _refreshAll();
      showToast('Auction reversed');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Future<void> _recordAuction(String auctionId) async {
    final members = await ref.read(chitfundRepoProvider).members(widget.id);
    // Only members who have not yet won are eligible.
    final eligible = members.where((m) => (m as Map)['hasWonAuction'] != true).toList();
    if (eligible.isEmpty || !mounted) {
      if (mounted) showToast('No eligible members', error: true);
      return;
    }
    Map<String, dynamic>? selected;
    final bidController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Record Auction'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Winner'),
                    items: eligible.map((m) {
                      final mm = Map<String, dynamic>.from(m as Map);
                      final cust = Map<String, dynamic>.from(mm['customer'] ?? {});
                      return DropdownMenuItem(value: mm, child: Text('#${mm['ticketNumber']} ${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim()));
                    }).toList(),
                    onChanged: (v) => setState(() => selected = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: bidController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bid Amount')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record')),
            ],
          ),
        );
      },
    );
    if (ok != true || selected == null) return;
    try {
      await ref.read(chitfundRepoProvider).recordAuction(
        widget.id,
        auctionId,
        winnerMemberId: selected!['id'].toString(),
        bidAmount: double.tryParse(bidController.text) ?? 0,
      );
      _refreshAll();
      showToast('Auction recorded');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Future<void> _openExtraAuction(Map<String, dynamic> c) async {
    final members = await ref.read(chitfundRepoProvider).members(widget.id);
    final eligible = members.where((m) => (m as Map)['hasWonAuction'] != true).toList();
    if (eligible.isEmpty || !mounted) {
      if (mounted) showToast('No eligible members', error: true);
      return;
    }
    Map<String, dynamic>? selected;
    final bidController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Extra Auction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Surplus pool ${formatCurrency(c['surplusPool'] ?? 0)} · Chit value ${formatCurrency(c['totalAmount'])}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Winner'),
                  items: eligible.map((m) {
                    final mm = Map<String, dynamic>.from(m as Map);
                    final cust = Map<String, dynamic>.from(mm['customer'] ?? {});
                    return DropdownMenuItem(value: mm, child: Text('#${mm['ticketNumber']} ${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim()));
                  }).toList(),
                  onChanged: (v) => setState(() => selected = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bidController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Bid Amount (optional)', hintText: 'Leave blank to pay full chit value'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record')),
          ],
        ),
      ),
    );
    if (ok != true || selected == null) return;
    try {
      await ref.read(chitfundRepoProvider).extraAuction(
        widget.id,
        winnerMemberId: selected!['id'].toString(),
        bidAmount: double.tryParse(bidController.text) ?? 0,
      );
      _refreshAll();
      showToast('Extra auction recorded');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Widget _paymentsTab(Map<String, dynamic> c) {
    final p = ref.watch(chitfundPaymentsProvider(widget.id));
    final canDelete = _canManage && c['status'] != 'COMPLETED';
    final memberById = _memberById();
    return p.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No payments yet');
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final pm = Map<String, dynamic>.from(items[i] as Map);
            final type = pm['type']?.toString() ?? 'COLLECTION';
            // listPayments returns raw rows (no relation) — resolve the name from the members list.
            final mem = memberById[pm['chitfundMemberId']?.toString()];
            final cust = mem != null && mem['customer'] != null ? Map<String, dynamic>.from(mem['customer'] as Map) : {};
            final ticket = mem != null ? '#${mem['ticketNumber']} ' : '';
            final name = '$ticket${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim();
            final isCollection = type == 'COLLECTION';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(child: Text('Month ${pm['monthNumber']}${name.isNotEmpty ? ' - $name' : ''}')),
                    StatusChip(label: type, color: type == 'PAYOUT' ? AppColors.info : AppColors.primary),
                  ],
                ),
                subtitle: Text(
                  '${pm['paymentMode'] ?? '-'} · ${formatDate(pm['paidDate'] ?? pm['paymentDate'])}'
                  '${pm['reference'] != null ? ' · ${pm['reference']}' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatCurrency(pm['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (canDelete && isCollection)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                        onPressed: () => _deletePayment(pm),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deletePayment(Map<String, dynamic> pm) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete Payment',
      message: "Delete this ${formatCurrency(pm['amount'])} payment for month ${pm['monthNumber']}? The member's total paid will be decreased.",
      confirmText: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(chitfundRepoProvider).deletePayment(widget.id, pm['id'].toString());
      _refreshAll();
      showToast('Payment deleted');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Widget _payoutsTab(Map<String, dynamic> c) {
    final p = ref.watch(chitfundPayoutsProvider(widget.id));
    final memberById = _memberById();
    return p.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No payouts yet');
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final po = Map<String, dynamic>.from(items[i] as Map);
            final isPaid = po['status'] == 'PAID';
            final mem = memberById[po['chitfundMemberId']?.toString()];
            final cust = mem != null && mem['customer'] != null ? Map<String, dynamic>.from(mem['customer'] as Map) : {};
            final winnerLabel = mem != null
                ? '#${mem['ticketNumber']} ${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim()
                : '-';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(child: Text('Month ${po['monthNumber']} · $winnerLabel')),
                    StatusChip(label: po['status']?.toString() ?? 'PENDING', color: statusColor(po['status']?.toString())),
                  ],
                ),
                subtitle: Text(
                  isPaid
                      ? '${po['paymentMode'] ?? '-'} · ${formatDate(po['paidDate'])}${po['reference'] != null ? ' · ${po['reference']}' : ''}'
                      : 'Pending settlement',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatCurrency(po['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (_canManage)
                      isPaid
                          ? IconButton(
                              tooltip: 'Unsettle',
                              icon: const Icon(Icons.restart_alt, color: AppColors.danger, size: 22),
                              onPressed: () => _unsettlePayout(po),
                            )
                          : IconButton(
                              tooltip: 'Pay winner',
                              icon: const Icon(Icons.payments, color: AppColors.primary, size: 22),
                              onPressed: () => _settlePayout(c, po),
                            ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _unsettlePayout(Map<String, dynamic> po) async {
    final ok = await confirmDialog(
      context,
      title: 'Unsettle Payout',
      message: 'Mark this payout of ${formatCurrency(po['amount'])} back to PENDING? The settlement details (mode, reference, date) will be cleared.',
      confirmText: 'Unsettle',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(chitfundRepoProvider).unsettlePayout(widget.id, po['id'].toString());
      _refreshAll();
      showToast('Payout unsettled');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Future<void> _settlePayout(Map<String, dynamic> c, Map<String, dynamic> po) async {
    final amountController = TextEditingController(text: po['amount'] != null ? po['amount'].toString() : '');
    final refController = TextEditingController();
    final shareController = TextEditingController();
    String mode = 'CASH';
    bool collectShare = false;
    DateTime paidDate = DateTime.now();

    // Look up the winner's expected share for the month + whether collection already exists.
    num shareExpected = toNum(c['monthlyInstallment']);
    bool shareAlreadyPaid = false;
    try {
      final dues = await ref.read(chitfundRepoProvider).monthlyDues(widget.id, toNum(po['monthNumber']).toInt());
      final list = (dues['dues'] as List?) ?? const [];
      final winnerDue = list.cast<Map?>().firstWhere(
            (d) => d?['memberId']?.toString() == po['chitfundMemberId']?.toString(),
            orElse: () => null,
          );
      if (winnerDue != null) shareExpected = toNum(winnerDue['expectedAmount']);
      final pays = await ref.read(chitfundRepoProvider).payments(
            widget.id,
            monthNumber: toNum(po['monthNumber']).toInt(),
            memberId: po['chitfundMemberId']?.toString(),
            type: 'COLLECTION',
          );
      shareAlreadyPaid = pays.isNotEmpty;
    } catch (_) {}
    shareController.text = (shareExpected).toStringAsFixed(2);

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Pay Winner — Month ${po['monthNumber']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount Paid')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(titleCase(m)))).toList(),
                  onChanged: (v) => setState(() => mode = v ?? 'CASH'),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: paidDate,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => paidDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Paid Date'),
                    child: Text(formatDate(paidDate)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(controller: refController, decoration: const InputDecoration(labelText: 'Reference', hintText: 'Txn ID / cheque #')),
                const SizedBox(height: 10),
                if (shareAlreadyPaid)
                  Text('Collection for month ${po['monthNumber']} is already recorded for this member.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                else ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: collectShare,
                    title: Text("Also collect winner's share for month ${po['monthNumber']}", style: const TextStyle(fontSize: 13)),
                    onChanged: (v) => setState(() => collectShare = v ?? false),
                  ),
                  if (collectShare)
                    TextField(controller: shareController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Share Amount')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(collectShare ? 'Settle & Collect' : 'Mark as Paid')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final amt = double.tryParse(amountController.text) ?? 0;
    if (amt <= 0) { showToast('Enter a positive amount', error: true); return; }
    final body = <String, dynamic>{
      'amount': amt,
      'paymentMode': mode,
      'reference': refController.text.isEmpty ? null : refController.text,
      'paidDate': formatInputDate(paidDate),
      'collectShare': collectShare,
    };
    if (collectShare) {
      final shareAmt = double.tryParse(shareController.text) ?? 0;
      if (shareAmt <= 0) { showToast('Enter a positive share amount', error: true); return; }
      body['shareAmount'] = shareAmt;
    }
    try {
      await ref.read(chitfundRepoProvider).settlePayout(widget.id, po['id'].toString(), body);
      _refreshAll();
      showToast(collectShare ? 'Payout settled & share collected' : 'Payout settled');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Future<void> _openPayment(Map<String, dynamic> c) async {
    final members = await ref.read(chitfundRepoProvider).members(widget.id);
    if (!mounted) return;
    final duration = toNum(c['durationMonths']).toInt();
    final maxMonth = duration < 1 ? 1 : duration;
    final current = toNum(c['currentMonth']).toInt();
    final initialMonth = current < 1 ? 1 : (current > maxMonth ? maxMonth : current);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSheet(
        chitfundId: widget.id,
        chitfund: c,
        members: members,
        initialMonth: initialMonth,
        onRecorded: _refreshAll,
      ),
    );
  }

  Future<void> _openFinalDues(Map<String, dynamic> c) async {
    Map<String, dynamic>? dues;
    String? error;
    try {
      dues = await ref.read(chitfundRepoProvider).finalDues(widget.id);
    } on ApiException catch (e) {
      error = e.message;
    }
    if (!mounted) return;
    if (error != null) { showToast(error, error: true); return; }
    final d = dues!;
    final dividendType = d['dividendType']?.toString() ?? 'SPLIT';
    final list = (d['dues'] as List?) ?? const [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Expanded(child: Text('Final Installment Dues', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  dividendType +
                      (dividendType == 'SPLIT' ? ' (${d['splitAudience'] == 'NON_WINNERS' ? 'Non-winners' : 'All'})' : '') +
                      (dividendType == 'ACCUMULATED' ? ' · Pool leftover ${formatCurrency(d['surplusPool'])}' : ''),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final due = Map<String, dynamic>.from(list[i] as Map);
                  return ListTile(
                    dense: true,
                    leading: Text('#${due['ticketNumber']}', style: const TextStyle(color: AppColors.textSecondary)),
                    title: Text(due['customerName']?.toString() ?? '-'),
                    subtitle: Text(
                      'Base ${formatCurrency(due['baseInstallment'])}'
                      '${dividendType == 'SPLIT' && toNum(due['dividendCredited']) > 0 ? ' · Credited ${formatCurrency(due['dividendCredited'])}' : ''}'
                      '${dividendType == 'ACCUMULATED' && toNum(due['poolShare']) > 0 ? ' · Pool share ${formatCurrency(due['poolShare'])}' : ''}',
                    ),
                    trailing: Text(formatCurrency(due['finalAmount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editChitfund(Map<String, dynamic> c) async {
    final nameC = TextEditingController(text: c['name']?.toString() ?? '');
    final totalC = TextEditingController(text: c['totalAmount']?.toString() ?? '');
    final instC = TextEditingController(text: c['monthlyInstallment']?.toString() ?? '');
    final commC = TextEditingController(text: c['commission']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Chitfund'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: totalC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Amount')),
              const SizedBox(height: 8),
              TextField(controller: instC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly Installment')),
              const SizedBox(height: 8),
              TextField(controller: commC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Commission (%)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final body = <String, dynamic>{
      'name': nameC.text.trim(),
      'totalAmount': num.tryParse(totalC.text) ?? c['totalAmount'],
      'monthlyInstallment': num.tryParse(instC.text) ?? c['monthlyInstallment'],
      'commission': num.tryParse(commC.text) ?? c['commission'],
    };
    try {
      await ref.read(chitfundRepoProvider).update(widget.id, body);
      ref.invalidate(chitfundDetailProvider(widget.id));
      showToast('Chitfund updated');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }
}

// Record-payment sheet with month picker + per-member monthly dues.
class _PaymentSheet extends ConsumerStatefulWidget {
  final String chitfundId;
  final Map<String, dynamic> chitfund;
  final List<dynamic> members;
  final int initialMonth;
  final VoidCallback onRecorded;
  const _PaymentSheet({
    required this.chitfundId,
    required this.chitfund,
    required this.members,
    required this.initialMonth,
    required this.onRecorded,
  });
  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  late int _month = widget.initialMonth;
  bool _loading = false;
  bool _saving = false;
  Map<String, dynamic>? _dues; // monthly-dues (or mapped final-dues) response
  List<dynamic> _monthPayments = const [];
  String? _selectedMemberId;
  final _amountC = TextEditingController();
  final _refC = TextEditingController();
  String _mode = 'CASH';

  int get _duration => toNum(widget.chitfund['durationMonths']).toInt();
  bool get _isFinalAccum => widget.chitfund['dividendType'] == 'ACCUMULATED' && _month == _duration;

  @override
  void initState() {
    super.initState();
    _load(_month);
  }

  Future<void> _load(int month) async {
    setState(() {
      _loading = true;
      _dues = null;
      _monthPayments = const [];
      _selectedMemberId = null;
      _amountC.text = '';
    });
    try {
      final repo = ref.read(chitfundRepoProvider);
      final isFinalAccum = widget.chitfund['dividendType'] == 'ACCUMULATED' && month == _duration;
      final duesRaw = isFinalAccum ? await repo.finalDues(widget.chitfundId) : await repo.monthlyDues(widget.chitfundId, month);
      final pays = await repo.payments(widget.chitfundId, monthNumber: month);
      Map<String, dynamic> dues;
      if (isFinalAccum) {
        // Map final-dues shape to the monthly-dues structure used by the form.
        final list = (duesRaw['dues'] as List?) ?? const [];
        dues = {
          'monthNumber': month,
          'dividendType': duesRaw['dividendType'],
          'splitAudience': duesRaw['splitAudience'],
          'auctionCompleted': true,
          'dividendPerMember': 0,
          'surplusPool': duesRaw['surplusPool'],
          'dues': list.map((raw) {
            final d = Map<String, dynamic>.from(raw as Map);
            return {...d, 'expectedAmount': d['finalAmount'], 'dividendCredit': 0, 'poolShare': d['poolShare']};
          }).toList(),
        };
      } else {
        dues = duesRaw;
      }
      if (!mounted) return;
      setState(() {
        _dues = dues;
        _monthPayments = pays;
      });
    } on ApiException catch (e) {
      if (mounted) showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSelectMember(String? memberId) {
    setState(() {
      _selectedMemberId = memberId;
      final list = (_dues?['dues'] as List?) ?? const [];
      final due = list.cast<Map?>().firstWhere((d) => d?['memberId']?.toString() == memberId, orElse: () => null);
      _amountC.text = due != null ? (toNum(due['expectedAmount'])).toStringAsFixed(2) : '';
    });
  }

  Future<void> _submit() async {
    if (_selectedMemberId == null) { showToast('Select a member', error: true); return; }
    final amt = double.tryParse(_amountC.text) ?? 0;
    if (amt <= 0) { showToast('Enter a positive amount', error: true); return; }
    setState(() => _saving = true);
    try {
      await ref.read(chitfundRepoProvider).recordPayment(widget.chitfundId, {
        'chitfundMemberId': _selectedMemberId,
        'monthNumber': _month,
        'amount': amt,
        'paymentMode': _mode,
        'reference': _refC.text.isEmpty ? null : _refC.text,
      });
      showToast('Payment recorded');
      widget.onRecorded();
      _refC.text = '';
      await _load(_month); // refresh so the paid member drops off the list
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chitfund;
    final paidIds = _monthPayments.map((p) => (p as Map)['chitfundMemberId']?.toString()).toSet();
    final allDues = (_dues?['dues'] as List?) ?? const [];
    final selectable = allDues.where((d) => !paidIds.contains((d as Map)['memberId']?.toString())).toList();
    final selectedDue = allDues.cast<Map?>().firstWhere(
          (d) => d?['memberId']?.toString() == _selectedMemberId,
          orElse: () => null,
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _month,
              decoration: const InputDecoration(labelText: 'Month'),
              items: List.generate(_duration, (i) {
                final m = i + 1;
                final tags = <String>[];
                if (m == toNum(c['currentMonth']).toInt()) tags.add('current');
                if (m == _duration) tags.add('final');
                return DropdownMenuItem(value: m, child: Text('Month $m${tags.isNotEmpty ? ' — ${tags.join(', ')}' : ''}'));
              }),
              onChanged: (v) { if (v != null) { setState(() => _month = v); _load(v); } },
            ),
            const SizedBox(height: 12),
            if (_dues != null && !_isFinalAccum)
              Text(
                (_dues!['auctionCompleted'] == true)
                    ? 'Auction done · dividend ${formatCurrency(_dues!['dividendPerMember'] ?? 0)}/eligible member'
                    : 'Auction for this month is not completed — expected = base installment',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            if (_isFinalAccum && _dues != null)
              Text('Final month · pool ${formatCurrency(_dues!['surplusPool'] ?? 0)} split across ${c['totalMembers']} members',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            if (_loading)
              const LoadingView()
            else if (_dues != null) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedMemberId,
                decoration: const InputDecoration(labelText: 'Member'),
                isExpanded: true,
                items: selectable.map((raw) {
                  final d = Map<String, dynamic>.from(raw as Map);
                  return DropdownMenuItem(
                    value: d['memberId'].toString(),
                    child: Text(
                      '#${d['ticketNumber']} ${d['customerName'] ?? 'Member'}${d['hasWonAuction'] == true ? ' (won)' : ''} — ${formatCurrency(d['expectedAmount'])}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: selectable.isEmpty ? null : _onSelectMember,
              ),
              if (selectable.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('All members have paid for this month', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              if (selectedDue != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      KeyValueRow(label: 'Base installment', value: formatCurrency(selectedDue['baseInstallment'])),
                      if (toNum(selectedDue['dividendCredit']) > 0)
                        KeyValueRow(label: 'Dividend credit', value: '− ${formatCurrency(selectedDue['dividendCredit'])}'),
                      if (toNum(selectedDue['poolShare']) > 0)
                        KeyValueRow(label: 'Pool share', value: '− ${formatCurrency(selectedDue['poolShare'])}'),
                      KeyValueRow(label: 'Expected', value: formatCurrency(selectedDue['expectedAmount'])),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(controller: _amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount Collected')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Payment Mode'),
                items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(titleCase(m)))).toList(),
                onChanged: (v) => setState(() => _mode = v ?? 'CASH'),
              ),
              const SizedBox(height: 12),
              TextField(controller: _refC, decoration: const InputDecoration(labelText: 'Reference', hintText: 'Txn ID / cheque #')),
              const SizedBox(height: 12),
              Text('${_monthPayments.length} of ${widget.members.length} members paid for month $_month',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_saving || _selectedMemberId == null) ? null : _submit,
                  child: Text(_saving ? 'Saving...' : 'Record Payment'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustPicker extends StatefulWidget {
  final WidgetRef ref;
  const _CustPicker({required this.ref});
  @override
  State<_CustPicker> createState() => _CustPickerState();
}

class _CustPickerState extends State<_CustPicker> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _load(''); }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final r = await widget.ref.read(customerRepoProvider).list(page: 1, search: q.isEmpty ? null : q);
      setState(() => _items = ((r['data'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      showToast('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Expanded(child: Text('Add Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: TextField(controller: _search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search)), onSubmitted: _load)),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const LoadingView()
                : ListView.builder(
                    controller: ctrl,
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final c = _items[i];
                      return ListTile(
                        title: Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim()),
                        subtitle: Text('${c['customerId']} • ${c['phone']}'),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
