import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/report_repo.dart';

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

const _loanStatuses = ['ACTIVE', 'CLOSED', 'DEFAULTED', 'PENDING'];

class LoanReportPage extends ConsumerStatefulWidget {
  const LoanReportPage({super.key});
  @override
  ConsumerState<LoanReportPage> createState() => _LoanReportPageState();
}

class _LoanReportPageState extends ConsumerState<LoanReportPage> {
  DateTime? _from;
  DateTime? _to;
  String? _typeFilter;
  String? _statusFilter;
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _from = DateTime.now().subtract(const Duration(days: 30));
    _to = DateTime.now();
    _load();
  }

  void _load() {
    final params = <String, dynamic>{};
    if (_from != null) params['fromDate'] = formatInputDate(_from!);
    if (_to != null) params['toDate'] = formatInputDate(_to!);
    if (_typeFilter != null) params['loanType'] = _typeFilter;
    if (_statusFilter != null) params['status'] = _statusFilter;
    _future = ref.read(reportRepoProvider).fetch('loans', params: params.isEmpty ? null : params);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(authProvider).org;
    final typeOptions = _loanTypeLabels.entries.where((e) {
      final flag = _loanTypeFeatureMap[e.key];
      return flag == null || org?.feature(flag) == true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/reports');
            }
          },
        ),
        title: const Text('Loan Report'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _dateBtn('From', _from, (d) { setState(() => _from = d); _load(); })),
                const SizedBox(width: 8),
                Expanded(child: _dateBtn('To', _to, (d) { setState(() => _to = d); _load(); })),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _typeFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Types')),
                      ...typeOptions.map((e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
                    ],
                    onChanged: (v) { setState(() => _typeFilter = v); _load(); },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _statusFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Statuses')),
                      ..._loanStatuses.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
                    ],
                    onChanged: (v) { setState(() => _statusFilter = v); _load(); },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _load);
                final data = snap.data ?? {};
                final list = (data['data'] as List?) ?? const [];
                final totalDisbursed = list.fold<double>(0, (s, e) => s + ((e is Map ? (e['disbursed'] ?? 0) : 0) as num).toDouble());
                final totalOutstanding = list.fold<double>(0, (s, e) => s + ((e is Map ? (e['outstanding'] ?? 0) : 0) as num).toDouble());
                return ListView(
                  children: [
                    if (list.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                        child: Row(
                          children: [
                            Expanded(child: _summaryCard('Total Disbursed', formatCurrency(totalDisbursed), AppColors.primary, subtitle: '${list.length} loans')),
                            const SizedBox(width: 8),
                            Expanded(child: _summaryCard('Total Outstanding', formatCurrency(totalOutstanding), Colors.red)),
                          ],
                        ),
                      ),
                    if (list.isEmpty)
                      const Padding(padding: EdgeInsets.all(24), child: EmptyView(message: 'No data for selected filters'))
                    else
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (int i = 0; i < list.length; i++) ...[
                                _loanTile(Map<String, dynamic>.from(list[i] as Map)),
                                if (i < list.length - 1) const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, {String? subtitle}) {
    return Card(
      margin: EdgeInsets.zero,
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _loanTile(Map<String, dynamic> l) {
    final type = l['type']?.toString() ?? '';
    final typeLabel = _loanTypeLabels[type] ?? type;
    final status = l['status']?.toString() ?? '';
    return ListTile(
      dense: true,
      title: Row(
        children: [
          Expanded(
            child: Text(
              l['customer']?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(formatCurrency(l['outstanding']), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l['loanNumber'] ?? '-'} • $typeLabel • $status', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              'Principal ${formatCurrency(l['principal'])} • Disbursed ${formatCurrency(l['disbursed'])} • ${formatDate(l['date'])}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateBtn(String label, DateTime? v, void Function(DateTime) on) {
    return OutlinedButton.icon(
      onPressed: () async {
        final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: v ?? DateTime.now());
        if (d != null) on(d);
      },
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text('$label: ${v == null ? "-" : formatDate(v)}', style: const TextStyle(fontSize: 12)),
    );
  }
}
