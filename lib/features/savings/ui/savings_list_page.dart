import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/savings_repo.dart';
import '../../app_shell.dart';
import '../../../core/widgets/app_bottom_nav.dart';

class SavingsListPage extends ConsumerStatefulWidget {
  const SavingsListPage({super.key});
  @override
  ConsumerState<SavingsListPage> createState() => _SavingsListPageState();
}

class _SavingsListPageState extends ConsumerState<SavingsListPage> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _search;
  String? _type;

  @override
  void initState() {
    super.initState();
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
      final res = await ref.read(savingsRepoProvider).list(page: _page, search: _search, type: _type);
      final data = (res['data'] as List?) ?? const [];
      final pg = Map<String, dynamic>.from(res['pagination'] ?? {});
      setState(() {
        _items.addAll(data.map((e) => Map<String, dynamic>.from(e as Map)));
        _page += 1;
        _hasMore = _page <= (pg['totalPages'] ?? 1);
      });
    } catch (e) {
      showToast('Failed: $e', error: true);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(authProvider).hasPermission('savings.create');
    return Scaffold(
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Savings'),
        leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(onPressed: () => context.push('/savings/new'), icon: const Icon(Icons.add), label: const Text('New'))
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search...'),
                    onSubmitted: (v) { _search = v.trim().isEmpty ? null : v.trim(); _load(reset: true); },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String?>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (v) { _type = v; _load(reset: true); },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: null, child: Text('All types')),
                    PopupMenuItem(value: 'SAVINGS', child: Text('Savings')),
                    PopupMenuItem(value: 'PIGMI', child: Text('Pigmi')),
                    PopupMenuItem(value: 'RD', child: Text('RD')),
                    PopupMenuItem(value: 'FD', child: Text('FD')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _items.isEmpty && !_loading
                  ? const EmptyView(message: 'No savings accounts', icon: Icons.savings_outlined)
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _items.length + (_loading ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i >= _items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                        final s = _items[i];
                        final c = Map<String, dynamic>.from(s['customer'] ?? {});
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            onTap: () => context.push('/savings/${s['id']}'),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                              child: Text(s['accountType']?.toString().substring(0,1) ?? 'S', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(s['accountNumber']?.toString() ?? ''),
                            subtitle: Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''} • ${s['accountType'] ?? ''}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatCurrency(s['balance']), style: const TextStyle(fontWeight: FontWeight.w600)),
                                StatusChip(label: s['status']?.toString() ?? '', color: statusColor(s['status']?.toString())),
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
}
