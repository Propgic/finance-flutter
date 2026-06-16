import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/search_repo.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _query = '';
  bool _loading = false;
  Object? _error;
  Map<String, dynamic>? _results;

  // Monotonic token so a slow in-flight request can't overwrite newer results.
  int _reqId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() => _query = q);
    if (q.length < 2) {
      // Below threshold: clear any prior results and skip the network call.
      setState(() {
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  Future<void> _run(String q) async {
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(searchRepoProvider).search(q);
      if (!mounted || id != _reqId) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
      showToast(e.message, error: true);
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _group(String key) {
    final list = _results?[key];
    if (list is List) {
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  String _customerName(Map<String, dynamic>? c) {
    if (c == null) return '';
    return '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search customers, loans, team, savings...',
            border: InputBorder.none,
            filled: false,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onChanged('');
                    },
                  ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_query.length < 2) {
      return const EmptyView(
        message: 'Type at least 2 characters to search',
        icon: Icons.search,
      );
    }
    if (_loading && _results == null) {
      return const LoadingView();
    }
    if (_error != null && _results == null) {
      return ErrorView(message: _error.toString(), onRetry: () => _run(_query));
    }

    final customers = _group('customers');
    final loans = _group('loans');
    final team = _group('team');
    final savings = _group('savings');
    final isEmpty = customers.isEmpty && loans.isEmpty && team.isEmpty && savings.isEmpty;

    if (isEmpty) {
      return EmptyView(message: 'No results found for "$_query"', icon: Icons.search_off);
    }

    return ListView(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (customers.isNotEmpty) ...[
          _header('Customers', Icons.person_outline),
          ...customers.map(_customerTile),
        ],
        if (loans.isNotEmpty) ...[
          _header('Loans', Icons.account_balance_wallet_outlined),
          ...loans.map(_loanTile),
        ],
        if (team.isNotEmpty) ...[
          _header('Team Members', Icons.groups_outlined),
          ...team.map(_teamTile),
        ],
        if (savings.isNotEmpty) ...[
          _header('Savings Accounts', Icons.savings_outlined),
          ...savings.map(_savingsTile),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _header(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerTile(Map<String, dynamic> c) {
    final name = _customerName(c);
    final id = c['id']?.toString();
    final subtitle = [c['customerId'], c['phone']].where((e) => e != null && e.toString().isNotEmpty).join(' • ');
    return ListTile(
      leading: Avatar(name: name.isEmpty ? '?' : name, size: 40),
      title: Text(name.isEmpty ? '-' : name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: id == null ? null : () => context.push('/customers/$id'),
    );
  }

  Widget _loanTile(Map<String, dynamic> l) {
    final id = l['id']?.toString();
    final loanNumber = l['loanNumber']?.toString() ?? '-';
    final customer = _customerName(l['customer'] is Map ? Map<String, dynamic>.from(l['customer']) : null);
    final parts = <String>[
      if (customer.isNotEmpty) customer,
      formatCurrency(l['principalAmount']),
      if (l['status'] != null) l['status'].toString(),
    ];
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 20),
      ),
      title: Text(loanNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(parts.join(' • ')),
      onTap: id == null ? null : () => context.push('/loans/$id'),
    );
  }

  Widget _teamTile(Map<String, dynamic> t) {
    final id = t['id']?.toString();
    final name = t['name']?.toString() ?? '-';
    final subtitle = [t['email'], t['role'] != null ? titleCase(t['role'].toString()) : null]
        .where((e) => e != null && e.toString().isNotEmpty)
        .join(' • ');
    return ListTile(
      leading: Avatar(name: name, size: 40),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: id == null ? null : () => context.push('/team/$id'),
    );
  }

  Widget _savingsTile(Map<String, dynamic> s) {
    final id = s['id']?.toString();
    final accountNumber = s['accountNumber']?.toString() ?? '-';
    final customer = _customerName(s['customer'] is Map ? Map<String, dynamic>.from(s['customer']) : null);
    final parts = <String>[
      if (customer.isNotEmpty) customer,
      if (s['accountType'] != null) titleCase(s['accountType'].toString()),
      formatCurrency(s['balance']),
    ];
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(Icons.savings_outlined, color: AppColors.primary, size: 20),
      ),
      title: Text(accountNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(parts.join(' • ')),
      onTap: id == null ? null : () => context.push('/savings/$id'),
    );
  }
}
