import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';

class InvestmentReportPage extends ConsumerStatefulWidget {
  const InvestmentReportPage({super.key});
  @override
  ConsumerState<InvestmentReportPage> createState() => _InvestmentReportPageState();
}

class _InvestmentReportPageState extends ConsumerState<InvestmentReportPage> {
  String? _status;
  List<Map<String,dynamic>> _data = const [];
  Map<String,dynamic>? _summary;
  bool _loading = true;
  Object? _error;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final q = <String,dynamic>{};
      if (_status != null) q['status'] = _status;
      final d = await ref.read(apiClientProvider).get('/reports/investments', query: q);
      final body = d is Map ? d : {};
      final list = body['investments'] is List ? body['investments'] as List : (d is List ? d : const []);
      setState(() {
        _data = list.map((e) => Map<String,dynamic>.from(e as Map)).toList();
        _summary = body['summary'] is Map ? Map<String,dynamic>.from(body['summary']) : null;
      });
    } catch (e) { setState(() => _error = e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Investment Report')),
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.all(10), child: SizedBox(
          width: double.infinity,
          child: DropdownButtonFormField<String?>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: const [
              DropdownMenuItem(value: null, child: Text('All Statuses')),
              DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
              DropdownMenuItem(value: 'MATURED', child: Text('Matured')),
              DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
              DropdownMenuItem(value: 'WITHDRAWN', child: Text('Withdrawn')),
            ],
            onChanged: (v) { _status = v; _fetch(); },
          ),
        )),
        if (_loading) const Expanded(child: LoadingView())
        else if (_error != null) Expanded(child: ErrorView(message: _error.toString(), onRetry: _fetch))
        else Expanded(child: RefreshIndicator(onRefresh: _fetch, child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_summary != null) GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              children: [
                _sumTile('Total Invested', formatCurrency(_summary!['totalInvested']), '${_summary!['uniqueInvestors'] ?? 0} investors', AppColors.primary),
                _sumTile('Interest Liability', formatCurrency(_summary!['totalInterestLiability']), '', AppColors.warning),
                _sumTile('Maturity Payout', formatCurrency(_summary!['totalMaturityAmount']), '', AppColors.danger),
                _sumTile('Active/Matured', '${_summary!['activeCount'] ?? 0} / ${_summary!['maturedCount'] ?? 0}', '', AppColors.accent),
              ],
            ),
            const SizedBox(height: 8),
            if (_data.isEmpty) const EmptyView(message: 'No investments found')
            else ..._data.map(_investmentTile),
            const SizedBox(height: 20),
          ],
        ))),
      ]),
    );
  }

  Widget _sumTile(String label, String value, String sub, Color color) => Card(
    margin: EdgeInsets.zero,
    color: color.withValues(alpha: 0.08),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
      ]),
    ),
  );

  Widget _investmentTile(Map<String,dynamic> inv) {
    final days = toNum(inv['daysToMaturity']).toInt();
    final nearMaturity = inv['status'] == 'ACTIVE' && days <= 30 && days > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(inv['investor']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
            StatusChip(label: inv['status']?.toString() ?? '', color: statusColor(inv['status']?.toString())),
          ]),
          Text('${inv['investmentNumber'] ?? ''} • ${inv['phone'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const Divider(height: 18),
          Row(children: [
            Expanded(child: _miniField('Principal', formatCurrency(inv['principal']))),
            Expanded(child: _miniField('Rate', '${inv['interestRate']}% ${inv['interestType'] == 'COMPOUND' ? '(C)' : '(S)'}')),
            Expanded(child: _miniField('Tenure', '${inv['tenure']}m')),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _miniField('Interest', formatCurrency(inv['expectedInterest']), color: AppColors.warning)),
            Expanded(child: _miniField('Maturity', formatCurrency(inv['maturityAmount']), color: AppColors.primary, bold: true)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.event, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(formatDate(inv['maturityDate']), style: const TextStyle(fontSize: 11)),
            if (nearMaturity) ...[
              const SizedBox(width: 8),
              Text('${days}d left', style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600)),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _miniField(String label, String value, {Color? color, bool bold = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
    ],
  );
}
