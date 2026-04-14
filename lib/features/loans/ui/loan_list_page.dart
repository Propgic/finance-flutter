import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/loan_repo.dart';
import '../../app_shell.dart';
import '../../../core/widgets/app_bottom_nav.dart';

class LoanListPage extends ConsumerStatefulWidget {
  const LoanListPage({super.key});
  @override
  ConsumerState<LoanListPage> createState() => _LoanListPageState();
}

class _LoanListPageState extends ConsumerState<LoanListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _search;
  String? _status;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 && !_loading && _hasMore) {
        _load();
      }
    });
    _load();
    // Refresh user permissions so the FAB visibility tracks role changes.
    Future.microtask(() => ref.read(authProvider.notifier).refreshMe());
  }

  @override
  void dispose() {
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
      final res = await ref.read(loanRepoProvider).list(page: _page, search: _search, status: _status);
      final data = (res['data'] as List?) ?? const [];
      final pg = Map<String, dynamic>.from(res['pagination'] ?? {});
      setState(() {
        _items.addAll(data.map((e) => Map<String, dynamic>.from(e as Map)));
        _page += 1;
        _hasMore = _page <= (pg['totalPages'] ?? 1);
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(authProvider).hasPermission('loans.create');
    return Scaffold(
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Loans'),
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.warning_amber), tooltip: 'Overdue', onPressed: () => context.push('/loans/overdue')),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(onPressed: () => context.push('/loans/new'), icon: const Icon(Icons.add), label: const Text('New'))
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(hintText: 'Search loan number, customer...', prefixIcon: Icon(Icons.search)),
                    onSubmitted: (v) {
                      _search = v.trim().isEmpty ? null : v.trim();
                      _load(reset: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String?>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (v) {
                    _status = v;
                    _load(reset: true);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: null, child: Text('All')),
                    PopupMenuItem(value: 'PENDING', child: Text('Pending')),
                    PopupMenuItem(value: 'APPROVED', child: Text('Approved')),
                    PopupMenuItem(value: 'ACTIVE', child: Text('Active')),
                    PopupMenuItem(value: 'CLOSED', child: Text('Closed')),
                    PopupMenuItem(value: 'REJECTED', child: Text('Rejected')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _error != null && _items.isEmpty
                  ? ErrorView(message: _error.toString(), onRetry: () => _load(reset: true))
                  : _items.isEmpty && !_loading
                      ? const EmptyView(message: 'No loans', icon: Icons.request_quote_outlined)
                      : ListView.builder(
                          controller: _scroll,
                          itemCount: _items.length + (_loading ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i >= _items.length) {
                              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                            }
                            final l = _items[i];
                            final c = Map<String, dynamic>.from(l['customer'] ?? {});
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: ListTile(
                                onTap: () => context.push('/loans/${l['id']}'),
                                title: Text(l['loanNumber']?.toString() ?? ''),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim(),
                                        style: const TextStyle(fontWeight: FontWeight.w500)),
                                    Text('${l['loanType'] ?? ''} • ${formatCurrency(l['principalAmount'])}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                                trailing: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    StatusChip(label: l['status']?.toString() ?? '', color: statusColor(l['status']?.toString())),
                                    const SizedBox(height: 4),
                                    Text(formatDate(l['startDate']), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
