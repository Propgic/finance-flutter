import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
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

class ChitfundDetailPage extends ConsumerStatefulWidget {
  final String id;
  const ChitfundDetailPage({super.key, required this.id});
  @override
  ConsumerState<ChitfundDetailPage> createState() => _ChitfundDetailPageState();
}

class _ChitfundDetailPageState extends ConsumerState<ChitfundDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

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
      showToast('Member added');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Future<void> _doAction(Future<void> Function() fn, String msg) async {
    try {
      await fn();
      ref.invalidate(chitfundDetailProvider(widget.id));
      showToast(msg);
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(chitfundDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chitfund'),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Info'), Tab(text: 'Members'), Tab(text: 'Auctions'), Tab(text: 'Payments'),
        ]),
        actions: [
          data.maybeWhen(
            data: (c) => PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'start') _doAction(() => ref.read(chitfundRepoProvider).start(widget.id), 'Started');
                if (v == 'complete') _doAction(() => ref.read(chitfundRepoProvider).complete(widget.id), 'Completed');
                if (v == 'add_member') _addMember();
              },
              itemBuilder: (_) => [
                if (c['status'] == 'UPCOMING') const PopupMenuItem(value: 'start', child: Text('Start')),
                if (c['status'] == 'ACTIVE') const PopupMenuItem(value: 'complete', child: Text('Complete')),
                const PopupMenuItem(value: 'add_member', child: Text('Add Member')),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (c) => TabBarView(
          controller: _tabs,
          children: [_infoTab(c), _membersTab(), _auctionsTab(c), _paymentsTab()],
        ),
      ),
    );
  }

  Widget _infoTab(Map<String, dynamic> c) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              StatusChip(label: c['status']?.toString() ?? '', color: statusColor(c['status']?.toString())),
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
            KeyValueRow(label: 'Current Month', value: '${c['currentMonth'] ?? 0}'),
          ],
        ),
      ),
    ],
  );

  Widget _membersTab() {
    final m = ref.watch(chitfundMembersProvider(widget.id));
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
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Avatar(url: cust['photo']?.toString(), name: '${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'),
                title: Text('${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim()),
                subtitle: Text(cust['phone']?.toString() ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () async {
                    final ok = await confirmDialog(context, message: 'Remove member?', destructive: true, confirmText: 'Remove');
                    if (!ok) return;
                    try {
                      await ref.read(chitfundRepoProvider).removeMember(widget.id, mem['id'].toString());
                      ref.invalidate(chitfundMembersProvider(widget.id));
                    } on ApiException catch (e) { showToast(e.message, error: true); }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _auctionsTab(Map<String, dynamic> c) {
    final a = ref.watch(chitfundAuctionsProvider(widget.id));
    return a.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No auctions');
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final au = Map<String, dynamic>.from(items[i] as Map);
            final winner = au['winner'] != null ? Map<String, dynamic>.from(au['winner'] as Map) : null;
            final wCust = winner != null && winner['customer'] != null ? Map<String, dynamic>.from(winner['customer'] as Map) : null;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                title: Text('Month ${au['monthNumber']}'),
                subtitle: Text(wCust != null ? 'Winner: ${wCust['firstName'] ?? ''} ${wCust['lastName'] ?? ''}' : 'Not conducted'),
                trailing: Text(formatCurrency(au['bidAmount']), style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: wCust == null ? () => _recordAuction(au['id'].toString()) : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _recordAuction(String auctionId) async {
    final members = await ref.read(chitfundRepoProvider).members(widget.id);
    if (members.isEmpty || !mounted) return;
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
                    items: members.map((m) {
                      final mm = Map<String, dynamic>.from(m as Map);
                      final cust = Map<String, dynamic>.from(mm['customer'] ?? {});
                      return DropdownMenuItem(value: mm, child: Text('${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim()));
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
      ref.invalidate(chitfundAuctionsProvider(widget.id));
      showToast('Auction recorded');
    } on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Widget _paymentsTab() {
    final p = ref.watch(chitfundPaymentsProvider(widget.id));
    return p.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No payments yet');
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final pm = Map<String, dynamic>.from(items[i] as Map);
            final mem = pm['chitfundMember'] != null ? Map<String, dynamic>.from(pm['chitfundMember'] as Map) : {};
            final cust = mem['customer'] != null ? Map<String, dynamic>.from(mem['customer'] as Map) : {};
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                title: Text('Month ${pm['monthNumber']} - ${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'),
                subtitle: Text(formatDateTime(pm['paymentDate'])),
                trailing: Text(formatCurrency(pm['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            );
          },
        );
      },
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
