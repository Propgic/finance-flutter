import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../customers/data/customer_repo.dart';

class CustomerReportPage extends ConsumerStatefulWidget {
  final String? customerId;
  const CustomerReportPage({super.key, this.customerId});
  @override
  ConsumerState<CustomerReportPage> createState() => _CustomerReportPageState();
}

class _CustomerReportPageState extends ConsumerState<CustomerReportPage> {
  Map<String,dynamic>? _customer;
  Map<String,dynamic>? _report;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) _load(widget.customerId!);
  }

  Future<void> _load(String id) async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        ref.read(customerRepoProvider).get(id),
        api.get('/reports/customer/$id'),
      ]);
      setState(() {
        _customer = Map<String,dynamic>.from(results[0] as Map);
        _report = Map<String,dynamic>.from(results[1] as Map);
      });
    } catch (e) { setState(() => _error = e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pick() async {
    final picked = await showModalBottomSheet<Map<String,dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomerPicker(ref: ref),
    );
    if (picked != null) await _load(picked['id'].toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Report'),
        actions: [
          if (_customer != null)
            TextButton(onPressed: () { setState(() { _customer = null; _report = null; }); }, child: const Text('Change')),
          IconButton(icon: const Icon(Icons.search), onPressed: _pick),
        ],
      ),
      body: _loading ? const LoadingView()
        : _error != null ? ErrorView(message: _error.toString(), onRetry: _customer == null ? null : () => _load(_customer!['id'].toString()))
        : _customer == null ? _initialSearch()
        : _buildReport(),
    );
  }

  Widget _initialSearch() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_search, size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        const Text('Select a customer to view their financial report', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _pick, icon: const Icon(Icons.search), label: const Text('Search Customer')),
      ]),
    ),
  );

  Widget _buildReport() {
    final c = _customer!;
    final r = _report!;
    final loans = (r['loans'] as List?) ?? const [];
    final savings = (r['savings'] as List?) ?? const [];
    final totalBorrowed = loans.fold<num>(0, (s, l) => s + toNum(Map<String,dynamic>.from(l as Map)['principalAmount']));
    final totalSavings = savings.fold<num>(0, (s, a) => s + toNum(Map<String,dynamic>.from(a as Map)['balance']));

    return RefreshIndicator(
      onRefresh: () => _load(c['id'].toString()),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Avatar(url: c['photo']?.toString(), name: '${c['firstName'] ?? ''}', size: 54),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('${c['phone'] ?? '-'} • ${c['city'] ?? '-'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  StatusChip(label: c['isActive'] == true ? 'ACTIVE' : 'INACTIVE', color: c['isActive'] == true ? AppColors.accent : AppColors.textSecondary),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.8,
            children: [
              _sumTile('Total Borrowed', formatCurrency(totalBorrowed), AppColors.primary),
              _sumTile('Outstanding', formatCurrency(r['totalOutstanding']), AppColors.danger),
              _sumTile('Total Paid', formatCurrency(r['totalPaid']), AppColors.accent),
              _sumTile('Savings Balance', formatCurrency(totalSavings), AppColors.purple),
            ],
          ),
          const SizedBox(height: 16),
          Text('Loan History (${loans.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (loans.isEmpty) const EmptyView(message: 'No loan history', icon: Icons.request_quote_outlined)
          else ...loans.map((l) {
            final m = Map<String,dynamic>.from(l as Map);
            return Card(
              child: ListTile(
                dense: true,
                onTap: () => context.push('/loans/${m['id']}'),
                title: Text(m['loanNumber']?.toString() ?? ''),
                subtitle: Text('${m['loanType'] ?? ''} • Principal ${formatCurrency(m['principalAmount'])}', style: const TextStyle(fontSize: 11)),
                trailing: StatusChip(label: m['status']?.toString() ?? '', color: statusColor(m['status']?.toString())),
              ),
            );
          }),
          if (savings.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Savings Accounts (${savings.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...savings.map((s) {
              final m = Map<String,dynamic>.from(s as Map);
              return Card(
                child: ListTile(
                  dense: true,
                  title: Text(m['accountNumber']?.toString() ?? ''),
                  subtitle: Text(m['accountType']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
                  trailing: Text(formatCurrency(m['balance']), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sumTile(String label, String value, Color color) => Card(
    margin: EdgeInsets.zero,
    color: color.withValues(alpha: 0.08),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

class _CustomerPicker extends StatefulWidget {
  final WidgetRef ref;
  const _CustomerPicker({required this.ref});
  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  final _search = TextEditingController();
  List<Map<String,dynamic>> _items = const [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _load(''); }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final r = await widget.ref.read(customerRepoProvider).list(page: 1, search: q.isEmpty ? null : q);
      setState(() => _items = ((r['data'] as List?) ?? []).map((e) => Map<String,dynamic>.from(e as Map)).toList());
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Expanded(child: Text('Select Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: TextField(controller: _search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search)), onSubmitted: _load)),
        const SizedBox(height: 8),
        Expanded(child: _loading ? const LoadingView() : _items.isEmpty ? const EmptyView(message: 'No results') : ListView.builder(
          controller: ctrl,
          itemCount: _items.length,
          itemBuilder: (ctx, i) {
            final c = _items[i];
            return ListTile(
              leading: Avatar(url: c['photo']?.toString(), name: '${c['firstName'] ?? ''}'),
              title: Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim()),
              subtitle: Text('${c['customerId'] ?? ''} • ${c['phone'] ?? ''}'),
              onTap: () => Navigator.pop(context, c),
            );
          },
        )),
      ]),
    );
  }
}
