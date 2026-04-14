import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';

class OverdueReportPage extends ConsumerStatefulWidget {
  const OverdueReportPage({super.key});
  @override
  ConsumerState<OverdueReportPage> createState() => _OverdueReportPageState();
}

class _OverdueReportPageState extends ConsumerState<OverdueReportPage> {
  List<Map<String,dynamic>> _data = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final d = await api.get('/reports/overdue');
      final body = d is Map ? d : {};
      final list = body['emis'] is List ? body['emis'] as List : (d is List ? d : const []);
      setState(() => _data = list.map((e) => Map<String,dynamic>.from(e as Map)).toList());
    } catch (e) { setState(() => _error = e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  ({String label, Color color}) _severity(dynamic dueDate) {
    final d = DateTime.tryParse(dueDate?.toString() ?? '');
    if (d == null) return (label: 'Low', color: AppColors.info);
    final days = DateTime.now().difference(d).inDays;
    if (days > 90) return (label: 'Critical', color: AppColors.danger);
    if (days > 30) return (label: 'High', color: AppColors.orange);
    if (days > 7) return (label: 'Medium', color: AppColors.warning);
    return (label: 'Low', color: AppColors.info);
  }

  @override
  Widget build(BuildContext context) {
    final total = _data.fold<num>(0, (s, r) => s + toNum(r['totalDue']));
    return Scaffold(
      appBar: AppBar(title: const Text('Overdue Report'), bottom: PreferredSize(
        preferredSize: const Size.fromHeight(30),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 10, right: 16),
          child: Row(children: [
            Expanded(child: Text('Total Overdue: ${formatCurrency(total)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
            Text('${_data.length} EMIs', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      )),
      body: _loading ? const LoadingView()
        : _error != null ? ErrorView(message: _error.toString(), onRetry: _fetch)
        : _data.isEmpty ? const EmptyView(message: 'No overdue EMIs', icon: Icons.check_circle_outline)
        : RefreshIndicator(
          onRefresh: _fetch,
          child: ListView.builder(
            itemCount: _data.length,
            itemBuilder: (ctx, i) {
              final r = _data[i];
              final sev = _severity(r['dueDate']);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: sev.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.warning_amber, color: sev.color, size: 20),
                  ),
                  title: Text('${r['customer'] ?? ''} • EMI #${r['emiNumber']}'),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['loanNumber'] ?? ''} • ${r['phone'] ?? ''}', style: const TextStyle(fontSize: 11)),
                    Text('Due ${formatDate(r['dueDate'])} • ${r['daysOverdue'] ?? '-'}d overdue', style: const TextStyle(fontSize: 11, color: AppColors.danger)),
                  ]),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(formatCurrency(r['totalDue']), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
                    StatusChip(label: sev.label, color: sev.color),
                  ]),
                ),
              );
            },
          ),
        ),
    );
  }
}
