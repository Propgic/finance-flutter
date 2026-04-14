import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';

class CollectionReportPage extends ConsumerStatefulWidget {
  const CollectionReportPage({super.key});
  @override
  ConsumerState<CollectionReportPage> createState() => _CollectionReportPageState();
}

class _CollectionReportPageState extends ConsumerState<CollectionReportPage> {
  DateTime? _from;
  DateTime? _to;
  String? _mode;
  List<Map<String,dynamic>> _data = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final q = <String,dynamic>{};
      if (_from != null) q['dateFrom'] = formatInputDate(_from!);
      if (_to != null) q['dateTo'] = formatInputDate(_to!);
      if (_mode != null) q['paymentMode'] = _mode;
      final api = ref.read(apiClientProvider);
      final d = await api.get('/reports/collections', query: q);
      final body = d is Map ? d : {};
      final list = body['collections'] is List ? body['collections'] as List : (d is List ? d : const []);
      setState(() => _data = list.map((e) => Map<String,dynamic>.from(e as Map)).toList());
    } catch (e) { setState(() => _error = e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final total = _data.fold<num>(0, (s, r) => s + toNum(r['amount']));
    return Scaffold(
      appBar: AppBar(title: const Text('Collection Report')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _from ?? DateTime.now());
                if (d != null) { _from = d; _fetch(); }
              }, icon: const Icon(Icons.calendar_today, size: 14), label: Text('From: ${_from == null ? "-" : formatDate(_from)}', style: const TextStyle(fontSize: 12))),
              OutlinedButton.icon(onPressed: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _to ?? DateTime.now());
                if (d != null) { _to = d; _fetch(); }
              }, icon: const Icon(Icons.calendar_today, size: 14), label: Text('To: ${_to == null ? "-" : formatDate(_to)}', style: const TextStyle(fontSize: 12))),
              SizedBox(width: 160, child: DropdownButtonFormField<String?>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Mode', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Modes')),
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank')),
                  DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                  DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                ],
                onChanged: (v) { _mode = v; _fetch(); },
              )),
            ]),
          ),
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
                    child: Card(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Total Collected', style: TextStyle(fontSize: 12, color: AppColors.accent)),
                            Text(formatCurrency(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent)),
                          ])),
                          Text('${_data.length} txns', style: const TextStyle(fontSize: 12, color: AppColors.accent)),
                        ]),
                      ),
                    ),
                  ),
                  if (_data.isEmpty) const EmptyView(message: 'No collection data')
                  else ..._data.map((r) => Card(
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.receipt_long_outlined, color: AppColors.accent),
                      title: Text(r['customerName']?.toString() ?? ''),
                      subtitle: Text('${r['receiptNumber'] ?? ''} • ${r['loanNumber'] ?? ''} • ${r['paymentMode'] ?? ''}', style: const TextStyle(fontSize: 11)),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(formatCurrency(r['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(formatDate(r['date']), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ]),
                    ),
                  )),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
