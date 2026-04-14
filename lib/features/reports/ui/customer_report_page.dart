import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/report_repo.dart';
import '../../customers/data/customer_repo.dart';

class CustomerReportPage extends ConsumerStatefulWidget {
  final String? customerId;
  const CustomerReportPage({super.key, this.customerId});
  @override
  ConsumerState<CustomerReportPage> createState() => _CustomerReportPageState();
}

class _CustomerReportPageState extends ConsumerState<CustomerReportPage> {
  Map<String, dynamic>? _customer;
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) {
      _loadFor(widget.customerId!);
    }
  }

  Future<void> _pick() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustPicker(ref: ref),
    );
    if (picked != null) {
      setState(() => _customer = picked);
      _loadFor(picked['id'].toString());
    }
  }

  Future<void> _loadFor(String id) async {
    setState(() => _future = ref.read(reportRepoProvider).fetch('customer/$id'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Report'),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: _pick)],
      ),
      body: _future == null
          ? const EmptyView(message: 'Select a customer', icon: Icons.person_search)
          : FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                if (snap.hasError) return ErrorView(message: snap.error.toString());
                final r = snap.data ?? {};
                final c = Map<String, dynamic>.from(r['customer'] ?? _customer ?? {});
                final loans = (r['loans'] as List?) ?? [];
                final savings = (r['savings'] as List?) ?? [];
                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Avatar(url: c['photo']?.toString(), name: '${c['firstName'] ?? ''}', size: 56),
                            const SizedBox(height: 6),
                            Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            Text(c['phone']?.toString() ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    SectionCard(
                      title: 'Loans (${loans.length})',
                      child: loans.isEmpty
                          ? const EmptyView(message: 'No loans')
                          : Column(
                              children: loans.map((l) {
                                final m = Map<String, dynamic>.from(l as Map);
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(m['loanNumber']?.toString() ?? ''),
                                  subtitle: Text('${m['status'] ?? ''} • ${formatCurrency(m['principalAmount'])}'),
                                  trailing: Text(formatCurrency(m['outstandingAmount'])),
                                );
                              }).toList(),
                            ),
                    ),
                    SectionCard(
                      title: 'Savings (${savings.length})',
                      child: savings.isEmpty
                          ? const EmptyView(message: 'No savings')
                          : Column(
                              children: savings.map((s) {
                                final m = Map<String, dynamic>.from(s as Map);
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(m['accountNumber']?.toString() ?? ''),
                                  subtitle: Text(m['accountType']?.toString() ?? ''),
                                  trailing: Text(formatCurrency(m['balance'])),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                );
              },
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
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Expanded(child: Text('Select Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))])),
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
                      return ListTile(title: Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim()), subtitle: Text('${c['customerId']} • ${c['phone']}'), onTap: () => Navigator.pop(context, c));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
