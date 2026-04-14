import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/collection_repo.dart';

class DailySummaryPage extends ConsumerStatefulWidget {
  const DailySummaryPage({super.key});
  @override
  ConsumerState<DailySummaryPage> createState() => _DailySummaryPageState();
}

class _DailySummaryPageState extends ConsumerState<DailySummaryPage> {
  DateTime _date = DateTime.now();
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() { super.initState(); _load(); }

  void _load() { _future = ref.read(collectionRepoProvider).dailySummary(date: formatInputDate(_date)); setState(() {}); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _date);
              if (d != null) { _date = d; _load(); }
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
          if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _load);
          final s = snap.data ?? {};
          final collections = (s['collections'] as List?) ?? [];
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(formatDate(_date), style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text(formatCurrency(s['totalAmount']), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      Text('${s['totalCount'] ?? 0} collections', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              SectionCard(
                title: 'By Payment Mode',
                child: Column(
                  children: ((s['byMode'] as List?) ?? []).map((m) {
                    final mm = Map<String, dynamic>.from(m as Map);
                    return KeyValueRow(label: mm['mode']?.toString() ?? '', value: '${formatCurrency(mm['amount'])} (${mm['count'] ?? 0})');
                  }).toList(),
                ),
              ),
              SectionCard(
                title: 'Collections',
                child: collections.isEmpty
                    ? const EmptyView(message: 'No collections today')
                    : Column(
                        children: collections.map((c) {
                          final mm = Map<String, dynamic>.from(c as Map);
                          final cust = Map<String, dynamic>.from(mm['customer'] ?? {});
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim()),
                            subtitle: Text(formatDateTime(mm['collectedAt'])),
                            trailing: Text(formatCurrency(mm['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
