import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';

class SavingsReportPage extends ConsumerStatefulWidget {
  const SavingsReportPage({super.key});
  @override
  ConsumerState<SavingsReportPage> createState() => _SavingsReportPageState();
}

class _SavingsReportPageState extends ConsumerState<SavingsReportPage> {
  String? _type;
  String? _status;
  List<Map<String,dynamic>> _data = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final q = <String,dynamic>{};
      if (_type != null) q['accountType'] = _type;
      if (_status != null) q['status'] = _status;
      final api = ref.read(apiClientProvider);
      final d = await api.get('/reports/savings', query: q);
      final body = d is Map ? d : {};
      final list = body['accounts'] is List ? body['accounts'] as List : (d is List ? d : const []);
      setState(() => _data = list.map((e) => Map<String,dynamic>.from(e as Map)).toList());
    } catch (e) { setState(() => _error = e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final total = _data.fold<num>(0, (s, r) => s + toNum(r['balance']));
    return Scaffold(
      appBar: AppBar(title: const Text('Savings Report'), bottom: PreferredSize(
        preferredSize: const Size.fromHeight(30),
        child: Padding(padding: const EdgeInsets.only(left: 16, bottom: 10, right: 16), child: Align(alignment: Alignment.centerLeft, child: Text('Total Balance: ${formatCurrency(total)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)))),
      )),
      body: Column(
        children: [
          Container(color: Colors.white, padding: const EdgeInsets.all(10), child: Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(width: 170, child: DropdownButtonFormField<String?>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: const [
                DropdownMenuItem(value: null, child: Text('All Types')),
                DropdownMenuItem(value: 'SAVINGS', child: Text('Savings')),
                DropdownMenuItem(value: 'PIGMI', child: Text('Pigmi')),
                DropdownMenuItem(value: 'RD', child: Text('RD')),
                DropdownMenuItem(value: 'FD', child: Text('FD')),
              ],
              onChanged: (v) { _type = v; _fetch(); },
            )),
            SizedBox(width: 170, child: DropdownButtonFormField<String?>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: const [
                DropdownMenuItem(value: null, child: Text('All Statuses')),
                DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
                DropdownMenuItem(value: 'MATURED', child: Text('Matured')),
              ],
              onChanged: (v) { _status = v; _fetch(); },
            )),
          ])),
          if (_loading) const Expanded(child: LoadingView())
          else if (_error != null) Expanded(child: ErrorView(message: _error.toString(), onRetry: _fetch))
          else _data.isEmpty ? const Expanded(child: EmptyView(message: 'No savings data', icon: Icons.savings_outlined))
          : Expanded(child: RefreshIndicator(onRefresh: _fetch, child: ListView.builder(
            itemCount: _data.length,
            itemBuilder: (ctx, i) {
              final r = _data[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                    child: Text(r['type']?.toString().substring(0,1) ?? '?', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(r['customer']?.toString() ?? ''),
                  subtitle: Text('${r['accountNumber'] ?? ''} • ${r['type'] ?? ''}${r['interestRate'] != null ? " • ${r['interestRate']}%" : ""}', style: const TextStyle(fontSize: 11)),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(formatCurrency(r['balance']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    StatusChip(label: r['status']?.toString() ?? '', color: statusColor(r['status']?.toString())),
                  ]),
                ),
              );
            },
          ))),
        ],
      ),
    );
  }
}
