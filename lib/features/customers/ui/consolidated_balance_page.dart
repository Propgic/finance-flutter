import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/customer_repo.dart';
import '../../app_shell.dart';
import '../../../core/widgets/app_bottom_nav.dart';

/// Top-level page: org-wide consolidated loan + chit balances per customer.
/// Backend: GET /customers/consolidated-balances ({ data, pagination, summary }).
class ConsolidatedBalanceSheetPage extends ConsumerStatefulWidget {
  const ConsolidatedBalanceSheetPage({super.key});
  @override
  ConsumerState<ConsolidatedBalanceSheetPage> createState() => _ConsolidatedBalanceSheetPageState();
}

class _ConsolidatedBalanceSheetPageState extends ConsumerState<ConsolidatedBalanceSheetPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _summary = const {};
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  bool _hasMore = true;
  String? _search;
  Object? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 && !_loading && _hasMore) {
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) {
        _items.clear();
        _page = 1;
        _hasMore = true;
        _error = null;
      }
    });
    try {
      final res = await ref.read(customerRepoProvider).consolidatedBalances(params: {
        'page': _page,
        'limit': 20,
        if (_search != null && _search!.isNotEmpty) 'search': _search,
      });
      final data = (res['data'] as List?) ?? const [];
      final pagination = Map<String, dynamic>.from(res['pagination'] ?? {});
      setState(() {
        _items.addAll(data.map((e) => Map<String, dynamic>.from(e as Map)));
        _summary = (res['summary'] is Map) ? Map<String, dynamic>.from(res['summary'] as Map) : const {};
        _total = (pagination['total'] as num?)?.toInt() ?? _items.length;
        _page += 1;
        final totalPages = (pagination['totalPages'] as num?)?.toInt() ?? 1;
        _hasMore = _page <= totalPages;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search = v.trim().isEmpty ? null : v.trim();
      _load(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Balance Sheet'),
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by customer name or ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search = null;
                          _load(reset: true);
                        },
                      ),
              ),
              onChanged: (v) {
                setState(() {});
                _onSearchChanged(v);
              },
            ),
          ),
          if (_items.isNotEmpty) _summaryBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _error != null && _items.isEmpty
                  ? ErrorView(message: _error.toString(), onRetry: () => _load(reset: true))
                  : _items.isEmpty && !_loading
                      ? const EmptyView(message: 'No customers found', icon: Icons.account_balance_outlined)
                      : ListView.builder(
                          controller: _scroll,
                          itemCount: _items.length + (_loading ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }
                            return _row(_items[i]);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _summaryItem('Customers', _total.toString()),
          _summaryItem('Loan Balance', formatCurrency(_summary['totalBalance'])),
          _summaryItem('Chit Balance', formatCurrency(_summary['chitBalance'])),
          _summaryItem('Outstanding', formatCurrency(_summary['totalOutstanding']), color: AppColors.danger),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> c) {
    final name = c['customerName']?.toString() ?? '';
    final loansCount = toNum(c['activeLoansCount']).toInt();
    final chitsCount = toNum(c['activeChitsCount']).toInt();
    final parts = <String>[
      '#${c['customerId'] ?? ''}',
      if (loansCount > 0) '$loansCount loan${loansCount == 1 ? '' : 's'}',
      if (chitsCount > 0) '$chitsCount chit${chitsCount == 1 ? '' : 's'}',
    ];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () => context.push('/customers/${c['id']}'),
        leading: Avatar(name: name, size: 40),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(parts.join(' • '), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(c['totalOutstanding']),
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
            ),
            const Text('Outstanding', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
