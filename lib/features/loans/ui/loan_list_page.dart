import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/loan_repo.dart';
import '../../app_shell.dart';
import '../../../core/widgets/app_bottom_nav.dart';

const _loanTypeFeatureMap = {
  'PERSONAL': 'enablePersonalLoan',
  'GOLD': 'enableGoldLoan',
  'GROUP': 'enableGroupLoan',
  'VEHICLE': 'enableVehicleLoan',
  'PROPERTY': 'enableMortgage',
  'BUSINESS': 'enableBusinessLoan',
  'AGRICULTURE': 'enableAgricultureLoan',
  'EDUCATION': 'enableEducationLoan',
  'DAILY': 'enableDailyLoan',
  'WEEKLY': 'enableWeeklyLoan',
};

const _loanTypeLabels = {
  'PERSONAL': 'Personal',
  'GOLD': 'Gold',
  'GROUP': 'Group',
  'VEHICLE': 'Vehicle',
  'PROPERTY': 'Property',
  'BUSINESS': 'Business',
  'AGRICULTURE': 'Agriculture',
  'EDUCATION': 'Education',
  'DAILY': 'Daily',
  'WEEKLY': 'Weekly',
};

const _statusDropdownOptions = [
  'DRAFT',
  'PENDING',
  'APPROVED',
  'DISBURSED',
  'ACTIVE',
  'CLOSED',
  'REJECTED',
  'WRITTEN_OFF',
];

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
  String? _typeTab;
  String _statusTab = 'ACTIVE';
  String? _statusFilter;
  String? _assigneeFilter;
  List<Map<String, dynamic>> _assignees = [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 && !_loading && _hasMore) {
        _load();
      }
    });
    Future.microtask(() async {
      await ref.read(authProvider.notifier).refreshMe();
      if (!mounted) return;
      _initDefaults();
      _loadAssignees();
      _load();
    });
  }

  void _initDefaults() {
    final features = ref.read(authProvider).org?.features ?? const {};
    final enabled = _loanTypeLabels.keys
        .where((k) => !_loanTypeFeatureMap.containsKey(k) || features[_loanTypeFeatureMap[k]] == true)
        .toList();
    if (_typeTab == null && enabled.isNotEmpty) _typeTab = enabled.first;
  }

  Future<void> _loadAssignees() async {
    final auth = ref.read(authProvider);
    if (!(auth.hasRole('ORG_ADMIN') || auth.hasRole('MANAGER'))) return;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.raw(() => api.dio.get('/team', queryParameters: {'limit': 500}));
      final body = res.data;
      final rawList = body is Map
          ? (body['data'] is List
              ? body['data']
              : body['data'] is Map && body['data']['data'] is List
                  ? body['data']['data']
                  : const [])
          : (body is List ? body : const []);
      if (!mounted) return;
      setState(() => _assignees = (rawList as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((u) => u['isActive'] == true)
          .toList());
    } catch (_) {}
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String? _resolvedStatus() {
    if (_statusTab == 'ACTIVE') return 'ACTIVE';
    if (_statusTab == 'CLOSED') return 'CLOSED';
    return _statusFilter;
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (_typeTab == null) return;
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
      final res = await ref.read(loanRepoProvider).list(
            page: _page,
            search: _search,
            status: _resolvedStatus(),
            type: _typeTab,
            assignedToId: _assigneeFilter,
          );
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

  void _openAdvancedFilters() {
    final auth = ref.read(authProvider);
    final canFilterAssignee = auth.hasRole('ORG_ADMIN') || auth.hasRole('MANAGER');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        String? tempStatus = _statusFilter;
        String? tempAssignee = _assigneeFilter;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 4,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (_statusTab == 'ALL')
                  DropdownButtonFormField<String?>(
                    initialValue: tempStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Statuses')),
                      ..._statusDropdownOptions.map(
                        (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
                      ),
                    ],
                    onChanged: (v) => setSheetState(() => tempStatus = v),
                  ),
                if (canFilterAssignee) ...[
                  if (_statusTab == 'ALL') const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: tempAssignee,
                    decoration: const InputDecoration(labelText: 'Assignee'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Assignees')),
                      ..._assignees.map((a) => DropdownMenuItem<String?>(
                            value: a['id']?.toString(),
                            child: Text(a['name']?.toString() ?? ''),
                          )),
                    ],
                    onChanged: (v) => setSheetState(() => tempAssignee = v),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setSheetState(() {
                            tempStatus = null;
                            tempAssignee = null;
                          });
                        },
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _statusFilter = tempStatus;
                            _assigneeFilter = tempAssignee;
                          });
                          _load(reset: true);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canCreate = auth.hasPermission('loans.create');
    final canFilterAssignee = auth.hasRole('ORG_ADMIN') || auth.hasRole('MANAGER');
    final features = auth.org?.features ?? const {};
    final typeTabs = _loanTypeLabels.entries
        .where((e) => !_loanTypeFeatureMap.containsKey(e.key) || features[_loanTypeFeatureMap[e.key]] == true)
        .toList();
    final activeFilterCount =
        (_statusTab == 'ALL' && _statusFilter != null ? 1 : 0) + (_assigneeFilter != null ? 1 : 0);
    final showFilterIcon = canFilterAssignee || _statusTab == 'ALL';

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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                if (showFilterIcon) ...[
                  const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.tune),
                        tooltip: 'Filters',
                        onPressed: _openAdvancedFilters,
                      ),
                      if (activeFilterCount > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$activeFilterCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (typeTabs.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: typeTabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final e = typeTabs[i];
                  final selected = _typeTab == e.key;
                  return ChoiceChip(
                    label: Text(
                      e.value,
                      style: TextStyle(
                        color: selected ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    selected: selected,
                    showCheckmark: false,
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.primary.withValues(alpha: 0.12),
                    side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                    onSelected: (_) {
                      if (selected) return;
                      setState(() => _typeTab = e.key);
                      _load(reset: true);
                    },
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                for (final pill in const [
                  ['ACTIVE', 'Active'],
                  ['CLOSED', 'Closed'],
                  ['ALL', 'All'],
                ]) ...[
                  Expanded(
                    child: _StatusPill(
                      label: pill[1],
                      selected: _statusTab == pill[0],
                      onTap: () {
                        if (_statusTab == pill[0]) return;
                        setState(() {
                          _statusTab = pill[0];
                          _statusFilter = null;
                        });
                        _load(reset: true);
                      },
                    ),
                  ),
                ],
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

class _StatusPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
