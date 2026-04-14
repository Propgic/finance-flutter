import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/collection_repo.dart';
import '../../loans/data/loan_repo.dart';

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
  'PROPERTY': 'Mortgage',
  'BUSINESS': 'Business',
  'AGRICULTURE': 'Agriculture',
  'EDUCATION': 'Education',
  'DAILY': 'Daily',
  'WEEKLY': 'Weekly',
};

class CollectionFormPage extends ConsumerStatefulWidget {
  const CollectionFormPage({super.key});
  @override
  ConsumerState<CollectionFormPage> createState() => _CollectionFormPageState();
}

class _CollectionFormPageState extends ConsumerState<CollectionFormPage> {
  String? _loanTypeFilter;
  String? _assigneeFilter;
  List<Map<String, dynamic>> _assignees = [];
  List<Map<String, dynamic>> _loans = [];
  Map<String, dynamic>? _selectedLoan;
  List<Map<String, dynamic>> _emis = [];
  List<Map<String, dynamic>> _pendingEmis = [];
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _mode = 'CASH';
  bool _saving = false;
  bool _loadingLoans = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAssignees();
    _loadLoans();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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
      setState(() => _assignees = (rawList as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((u) => u['isActive'] == true)
          .toList());
    } catch (e) {
      debugPrint('team load failed: $e');
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadLoans);
  }

  Future<void> _loadLoans() async {
    setState(() => _loadingLoans = true);
    try {
      final api = ref.read(apiClientProvider);
      final params = <String, dynamic>{'status': 'ACTIVE', 'limit': 30};
      if (_searchCtrl.text.trim().length >= 2) params['search'] = _searchCtrl.text.trim();
      if (_loanTypeFilter != null) params['loanType'] = _loanTypeFilter;
      if (_assigneeFilter != null) params['assignedToId'] = _assigneeFilter;
      final res = await api.raw(() => api.dio.get('/loans', queryParameters: params));
      final body = res.data;
      final list = (body is Map && body['data'] is List ? body['data'] : body is List ? body : const []) as List;
      final mapped = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      mapped.sort((a, b) {
        final ac = Map<String, dynamic>.from(a['customer'] ?? {});
        final bc = Map<String, dynamic>.from(b['customer'] ?? {});
        final an = '${ac['firstName'] ?? ''} ${ac['lastName'] ?? ''}'.trim().toLowerCase();
        final bn = '${bc['firstName'] ?? ''} ${bc['lastName'] ?? ''}'.trim().toLowerCase();
        return an.compareTo(bn);
      });
      setState(() => _loans = mapped);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingLoans = false);
    }
  }

  Future<void> _loadEmis(String loanId) async {
    try {
      final list = await ref.read(loanRepoProvider).emiSchedule(loanId);
      final mapped = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final pending = mapped.where((e) {
        final s = e['status']?.toString();
        return s == 'PENDING' || s == 'OVERDUE' || s == 'PARTIALLY_PAID';
      }).toList();
      setState(() {
        _emis = mapped;
        _pendingEmis = pending;
      });
    } catch (_) {
      setState(() { _emis = []; _pendingEmis = []; });
    }
  }

  void _selectLoan(Map<String, dynamic> loan) {
    setState(() {
      _selectedLoan = loan;
      _searchCtrl.text = '';
    });
    _loadEmis(loan['id'].toString());
  }

  Future<void> _submit() async {
    if (_selectedLoan == null) return showToast('Select a loan', error: true);
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return showToast('Enter valid amount', error: true);
    setState(() => _saving = true);
    try {
      final res = await ref.read(collectionRepoProvider).create({
        'loanId': _selectedLoan!['id'],
        'amount': amount,
        'paymentMode': _mode,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      showToast('Collection recorded');
      if (mounted) context.pushReplacement('/collections/${res['id']}/receipt');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canFilterAssignee = auth.hasRole('ORG_ADMIN') || auth.hasRole('MANAGER');
    final features = auth.org?.features ?? const {};
    final loanTypeItems = _loanTypeLabels.entries
        .where((e) => !_loanTypeFeatureMap.containsKey(e.key) || features[_loanTypeFeatureMap[e.key]] == true)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Record Collection')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          SectionCard(
            title: 'Filter',
            child: Column(
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _loanTypeFilter,
                  decoration: const InputDecoration(labelText: 'Loan Type'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All Loan Types')),
                    ...loanTypeItems.map((e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
                  ],
                  onChanged: (v) {
                    setState(() { _loanTypeFilter = v; _selectedLoan = null; });
                    _loadLoans();
                  },
                ),
                if (canFilterAssignee) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: _assigneeFilter,
                    decoration: const InputDecoration(labelText: 'Assignee'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Assignees')),
                      ..._assignees.map((a) => DropdownMenuItem<String?>(value: a['id']?.toString(), child: Text(a['name']?.toString() ?? ''))),
                    ],
                    onChanged: (v) {
                      setState(() { _assigneeFilter = v; _selectedLoan = null; });
                      _loadLoans();
                    },
                  ),
                ],
              ],
            ),
          ),
          if (_selectedLoan == null)
            SectionCard(
              title: 'Select Active Loan',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search by loan #, customer name...',
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () { _searchCtrl.clear(); _loadLoans(); },
                            ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 8),
                  if (_loadingLoans)
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  else if (_loans.isEmpty)
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No active loans', style: TextStyle(color: AppColors.textSecondary))))
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _loans.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final l = _loans[i];
                          final c = Map<String, dynamic>.from(l['customer'] ?? {});
                          final assignee = Map<String, dynamic>.from(l['assignedTo'] ?? {});
                          return InkWell(
                            onTap: () => _selectLoan(l),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim(),
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(l['loanType']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${l['loanNumber'] ?? ''}${assignee['name'] != null ? ' · Agent: ${assignee['name']}' : ''}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(formatCurrency(l['totalPayable']), style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          if (_selectedLoan != null) _selectedLoanCard(),
          if (_pendingEmis.isNotEmpty) _nextEmiCard(),
          if (_selectedLoan != null)
            SectionCard(
              title: 'Payment',
              child: Column(
                children: [
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ '),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _mode,
                    decoration: const InputDecoration(labelText: 'Payment Mode'),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                      DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                    ],
                    onChanged: (v) => setState(() => _mode = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
                ],
              ),
            ),
          if (_selectedLoan != null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => context.go('/collections'),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(_saving ? 'Saving...' : 'Record Collection'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _selectedLoanCard() {
    final loan = _selectedLoan!;
    final c = Map<String, dynamic>.from(loan['customer'] ?? {});
    final assignee = Map<String, dynamic>.from(loan['assignedTo'] ?? {});
    final totalPaid = _emis.fold<num>(0, (s, e) => s + toNum(e['paidAmount']));
    final totalPayable = toNum(loan['totalPayable']);
    final balance = totalPayable - totalPaid;
    final overdue = _emis
        .where((e) => e['status'] == 'OVERDUE')
        .fold<num>(0, (s, e) => s + toNum(e['emiAmount']) + toNum(e['lateFee']) - toNum(e['paidAmount']));
    return Card(
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''} - ${loan['loanNumber'] ?? ''}'.trim(),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (assignee['name'] != null)
                        Text('Agent: ${assignee['name']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _selectedLoan = null;
                    _emis = [];
                    _pendingEmis = [];
                  }),
                  child: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _miniStat('Total Payable', formatCurrency(totalPayable)),
                _miniStat('Total Paid', formatCurrency(totalPaid), color: AppColors.accent),
                _miniStat('Balance', formatCurrency(balance)),
                if (overdue > 0) _miniStat('Overdue', formatCurrency(overdue), color: AppColors.danger),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, {Color? color}) {
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _nextEmiCard() {
    final e = _pendingEmis.first;
    final status = e['status']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Next EMI', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('EMI #${e['emiNumber']} — ${formatCurrency(e['emiAmount'])}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Due: ${formatDate(e['dueDate'])}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (status == 'PARTIALLY_PAID')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Partially paid: ${formatCurrency(e['paidAmount'])} — Remaining: ${formatCurrency(toNum(e['emiAmount']) + toNum(e['lateFee']) - toNum(e['paidAmount']))}',
                  style: const TextStyle(fontSize: 11, color: AppColors.warning),
                ),
              ),
            if (status == 'OVERDUE')
              const Padding(padding: EdgeInsets.only(top: 4), child: Text('Overdue', style: TextStyle(fontSize: 11, color: AppColors.danger))),
          ],
        ),
      ),
    );
  }
}
