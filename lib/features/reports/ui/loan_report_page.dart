import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import 'report_export.dart';

const _loanTypeFeatureMap = {
  'PERSONAL':'enablePersonalLoan','GOLD':'enableGoldLoan','GROUP':'enableGroupLoan',
  'VEHICLE':'enableVehicleLoan','PROPERTY':'enableMortgage','BUSINESS':'enableBusinessLoan',
  'AGRICULTURE':'enableAgricultureLoan','EDUCATION':'enableEducationLoan','DAILY':'enableDailyLoan','WEEKLY':'enableWeeklyLoan',
};
const _loanTypeLabels = {
  'PERSONAL':'Personal','GOLD':'Gold','GROUP':'Group','VEHICLE':'Vehicle','PROPERTY':'Mortgage',
  'BUSINESS':'Business','AGRICULTURE':'Agriculture','EDUCATION':'Education','DAILY':'Daily','WEEKLY':'Weekly',
};
const _statuses = ['PENDING','APPROVED','ACTIVE','CLOSED','REJECTED','DEFAULTED'];

class LoanReportPage extends ConsumerStatefulWidget {
  const LoanReportPage({super.key});
  @override
  ConsumerState<LoanReportPage> createState() => _LoanReportPageState();
}

class _LoanReportPageState extends ConsumerState<LoanReportPage> {
  String? _type;
  String? _status;
  late DateTime _from;
  late DateTime _to;
  List<Map<String,dynamic>> _data = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = now;
    _fetch();
  }

  void _resetFilters() {
    final now = DateTime.now();
    setState(() {
      _type = null;
      _status = null;
      _from = DateTime(now.year, now.month, 1);
      _to = now;
    });
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final q = <String,dynamic>{};
      if (_type != null) q['loanType'] = _type;
      if (_status != null) q['status'] = _status;
      q['fromDate'] = formatInputDate(_from);
      q['toDate'] = formatInputDate(_to);
      final api = ref.read(apiClientProvider);
      final d = await api.get('/reports/loans', query: q);
      final list = d is List ? d : (d is Map && d['data'] is List ? d['data'] : const []);
      setState(() => _data = (list as List).map((e) => Map<String,dynamic>.from(e as Map)).toList());
    } catch (e) { setState(() => _error = e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _exportCsv() {
    exportAndShareCsv(
      context,
      filename: 'loan_report',
      subject: 'Loan Report',
      headers: const ['Loan Number', 'Customer', 'Type', 'Status', 'Principal', 'Disbursed', 'Interest', 'Outstanding'],
      rows: _data.map((r) => [
        r['loanNumber'] ?? '',
        r['customer'] ?? '',
        _loanTypeLabels[r['type']] ?? r['type'] ?? '',
        r['status'] ?? '',
        toNum(r['principal']),
        toNum(r['disbursed']),
        toNum(r['interest']),
        toNum(r['outstanding']),
      ]).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(authProvider).org?.features ?? const {};
    final types = _loanTypeLabels.entries.where((e) => features[_loanTypeFeatureMap[e.key]] == true || _loanTypeFeatureMap[e.key] == null).toList();
    final totalDisbursed = _data.fold<num>(0, (s, r) => s + toNum(r['disbursed']));
    final totalInterest = _data.fold<num>(0, (s, r) => s + toNum(r['interest']));
    final totalOutstanding = _data.fold<num>(0, (s, r) => s + toNum(r['outstanding']));
    // The backend nulls interest/outstanding when the org hides those fields from
    // this role (numbers otherwise), so null means "redacted for me" — drop the cards.
    final interestHidden = _data.any((r) => r['interest'] == null);
    final outstandingHidden = _data.any((r) => r['outstanding'] == null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Report'),
        actions: [
          if (_data.isNotEmpty)
            IconButton(icon: const Icon(Icons.ios_share), tooltip: 'Share / Export CSV', onPressed: _exportCsv),
          TextButton(onPressed: _resetFilters, child: const Text('Reset', style: TextStyle(fontSize: 12))),
        ],
      ),
      body: Column(
        children: [
          _filterBar(types),
          if (_loading) const Expanded(child: LoadingView())
          else if (_error != null) Expanded(child: ErrorView(message: _error.toString(), onRetry: _fetch))
          else Expanded(
            child: RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if (_data.isNotEmpty) Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: _sumCard('Total Disbursed', formatCurrency(totalDisbursed), '${_data.length} loans', AppColors.primary)),
                        if (!interestHidden) ...[
                          const SizedBox(width: 8),
                          Expanded(child: _sumCard('Interest Earned', formatCurrency(totalInterest), '', AppColors.accent)),
                        ],
                      ]),
                      if (!outstandingHidden) ...[
                        const SizedBox(height: 8),
                        _sumCard('Outstanding', formatCurrency(totalOutstanding), '', AppColors.danger),
                      ],
                    ]),
                  ),
                  if (_data.isEmpty) const EmptyView(message: 'No data for selected filters') else ..._data.map(_loanTile),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar(List<MapEntry<String,String>> types) => Container(
    padding: const EdgeInsets.all(10),
    color: Colors.white,
    child: Wrap(spacing: 8, runSpacing: 8, children: [
      _dropdown('Type', _type, [const DropdownMenuItem(value: null, child: Text('All Types')), ...types.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))], (v) { _type = v; _fetch(); }),
      _dropdown('Status', _status, [const DropdownMenuItem(value: null, child: Text('All Statuses')), ..._statuses.map((s) => DropdownMenuItem(value: s, child: Text(s)))], (v) { _status = v; _fetch(); }),
      _dateBtn('From', _from, (d) { _from = d; _fetch(); }),
      _dateBtn('To', _to, (d) { _to = d; _fetch(); }),
    ]),
  );

  Widget _dropdown(String label, String? value, List<DropdownMenuItem<String?>> items, ValueChanged<String?> on) => SizedBox(
    width: 160,
    child: DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      items: items,
      onChanged: on,
    ),
  );

  Widget _dateBtn(String label, DateTime v, ValueChanged<DateTime> on) => OutlinedButton.icon(
    onPressed: () async {
      final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: v);
      if (d != null) on(d);
    },
    icon: const Icon(Icons.calendar_today, size: 14),
    label: Text('$label: ${formatDate(v)}', style: const TextStyle(fontSize: 12)),
  );

  Widget _sumCard(String label, String value, String sub, Color color) => Card(
    color: color.withValues(alpha: 0.08),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withValues(alpha: 0.3))),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
        if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
      ]),
    ),
  );

  Widget _loanTile(Map<String,dynamic> r) => Card(
    child: ListTile(
      dense: true,
      title: Text(r['loanNumber']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r['customer'] ?? ''} • ${_loanTypeLabels[r['type']] ?? r['type'] ?? ''}', style: const TextStyle(fontSize: 12)),
        Text('Principal: ${formatCurrency(r['principal'])} • Outstanding: ${formatCurrency(r['outstanding'])}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
      trailing: StatusChip(label: r['status']?.toString() ?? '', color: statusColor(r['status']?.toString())),
      onTap: r['id'] != null ? () => context.push('/loans/${r['id']}') : null,
    ),
  );
}
