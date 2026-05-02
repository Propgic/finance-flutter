import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/collection_repo.dart';
import '../../app_shell.dart';
import '../../../core/widgets/app_bottom_nav.dart';

class CollectionListPage extends ConsumerStatefulWidget {
  const CollectionListPage({super.key});
  @override
  ConsumerState<CollectionListPage> createState() => _CollectionListPageState();
}

class _CollectionListPageState extends ConsumerState<CollectionListPage> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _verification;
  late String _dateFrom;
  late String _dateTo;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    final today = formatInputDate(DateTime.now());
    _dateFrom = today;
    _dateTo = today;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 && !_loading && _hasMore) _load();
    });
    _load();
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() { _loading = true; if (reset) { _items.clear(); _page = 1; _hasMore = true; } });
    try {
      final res = await ref.read(collectionRepoProvider).list(
        page: _page, fromDate: _dateFrom, toDate: _dateTo, verificationStatus: _verification,
      );
      final rawData = res['data'];
      final data = rawData is List
          ? rawData
          : (rawData is Map && rawData['collections'] is List ? rawData['collections'] as List : const []);
      final pg = Map<String, dynamic>.from(res['pagination'] ?? {});
      if (res['summary'] != null) _summary = Map<String, dynamic>.from(res['summary'] as Map);
      var mapped = data.map((e) => Map<String, dynamic>.from(e as Map));
      if (_verification != null) {
        mapped = mapped.where((c) => c['verificationStatus']?.toString() == _verification);
      }
      setState(() {
        _items.addAll(mapped);
        _page += 1;
        _hasMore = _page <= (pg['totalPages'] ?? 1);
      });
    } catch (e) { showToast('Failed: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pickDate(bool isFrom) async {
    final init = DateTime.tryParse(isFrom ? _dateFrom : _dateTo) ?? DateTime.now();
    final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: init);
    if (d != null) {
      setState(() {
        if (isFrom) _dateFrom = formatInputDate(d); else _dateTo = formatInputDate(d);
      });
      _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(authProvider).hasPermission('collections.create');
    return Scaffold(
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Collections'),
        leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
        actions: [
          IconButton(icon: const Icon(Icons.summarize_outlined), tooltip: 'Daily Summary', onPressed: () => context.push('/collections/summary')),
          IconButton(icon: const Icon(Icons.verified_outlined), tooltip: 'Verify', onPressed: () => context.push('/collections/verify')),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(onPressed: () => context.push('/collections/new'), icon: const Icon(Icons.add), label: const Text('New'))
          : null,
      body: Column(
        children: [
          if (_summary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                _metricCard('Total', formatCurrency(_summary!['totalCollected']), AppColors.textPrimary),
                const SizedBox(width: 8),
                _metricCard('Pending', formatCurrency(_summary!['pending']), AppColors.warning),
                const SizedBox(width: 8),
                _metricCard('Verified', formatCurrency(_summary!['verified']), AppColors.accent),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(_dateFrom, style: const TextStyle(fontSize: 12)),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('to', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(_dateTo, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('All', null),
                  _chip('Pending', 'PENDING'),
                  _chip('Verified', 'VERIFIED'),
                  _chip('Rejected', 'REJECTED'),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _items.isEmpty && !_loading
                  ? const EmptyView(message: 'No collections', icon: Icons.payments_outlined)
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _items.length + (_loading ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i >= _items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                        final c = _items[i];
                        final cust = Map<String, dynamic>.from(c['customer'] ?? {});
                        final loan = Map<String, dynamic>.from(c['loan'] ?? {});
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            onTap: () => context.push('/collections/${c['id']}/receipt'),
                            leading: const Icon(Icons.receipt_long_outlined, color: AppColors.accent),
                            title: Text('${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim()),
                            subtitle: Text('${loan['loanNumber'] ?? ''} • ${formatDateTime(c['collectedAt'])}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatCurrency(c['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
                                StatusChip(label: c['verificationStatus']?.toString() ?? '', color: statusColor(c['verificationStatus']?.toString())),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ]),
    ),
  );

  Widget _chip(String label, String? value) {
    final sel = _verification == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: sel ? AppColors.primary : AppColors.textPrimary, fontWeight: sel ? FontWeight.w600 : FontWeight.w500)),
        selected: sel,
        onSelected: (_) { _verification = value; _load(reset: true); },
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        side: BorderSide(color: sel ? AppColors.primary : AppColors.border),
      ),
    );
  }
}
