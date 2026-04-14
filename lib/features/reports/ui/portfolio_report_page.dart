import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';

class PortfolioReportPage extends ConsumerStatefulWidget {
  const PortfolioReportPage({super.key});
  @override
  ConsumerState<PortfolioReportPage> createState() => _PortfolioReportPageState();
}

class _PortfolioReportPageState extends ConsumerState<PortfolioReportPage> {
  Map<String,dynamic>? _r;
  bool _loading = true;
  Object? _error;

  static const _pieColors = [Color(0xFF1E40AF), Color(0xFF059669), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF7C3AED), Color(0xFF0891B2), Color(0xFFDB2777)];

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ref.read(apiClientProvider).get('/reports/portfolio');
      setState(() => _r = Map<String,dynamic>.from(d as Map));
    } catch (e) { setState(() => _error = e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio Report')),
      body: _loading ? const LoadingView()
        : _error != null ? ErrorView(message: _error.toString(), onRetry: _fetch)
        : _buildBody(_r ?? const {}),
    );
  }

  Widget _buildBody(Map<String,dynamic> r) {
    final byType = ((r['byType'] as List?) ?? const []).map((e) => Map<String,dynamic>.from(e as Map)).toList();
    final total = byType.fold<num>(0, (s, t) => s + toNum(t['amount']));
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              _metric(Icons.account_balance, 'Total AUM', formatCurrency(r['aum']), AppColors.primary),
              _metric(Icons.trending_up, 'Active Loans', '${r['activeLoans'] ?? 0}', AppColors.accent),
              _metric(Icons.warning_amber, 'NPA', formatCurrency(r['npa']), AppColors.danger),
              _metric(Icons.check_circle, 'Health Score', '${r['healthScore'] ?? 0}%', AppColors.purple),
            ],
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Portfolio by Loan Type',
            child: byType.isEmpty ? const EmptyView(message: 'No data')
              : Column(children: [
                SizedBox(
                  height: 200,
                  child: PieChart(PieChartData(
                    sections: [
                      for (var i = 0; i < byType.length; i++)
                        PieChartSectionData(
                          value: toNum(byType[i]['amount']).toDouble(),
                          title: total > 0 ? '${((toNum(byType[i]['amount']) / total) * 100).toStringAsFixed(0)}%' : '',
                          color: _pieColors[i % _pieColors.length],
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          radius: 70,
                        ),
                    ],
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  )),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (var i = 0; i < byType.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: _pieColors[i % _pieColors.length].withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: _pieColors[i % _pieColors.length], shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('${byType[i]['type'] ?? byType[i]['name'] ?? ''}: ${formatCurrency(byType[i]['amount'])}', style: const TextStyle(fontSize: 11)),
                      ]),
                    ),
                ]),
              ]),
          ),
          SectionCard(
            title: 'Portfolio Health',
            child: Column(children: [
              _bucket('Current (0-30d)', toNum(r['current']), toNum(r['currentPct']), AppColors.accent),
              _bucket('Sub-Standard (31-90d)', toNum(r['subStandard']), toNum(r['subStandardPct']), AppColors.warning),
              _bucket('Doubtful (91-180d)', toNum(r['doubtful']), toNum(r['doubtfulPct']), AppColors.orange),
              _bucket('Loss (180+d)', toNum(r['loss']), toNum(r['lossPct']), AppColors.danger),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value, Color color) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ]),
    ),
  );

  Widget _bucket(String label, num amount, num pct, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text(formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct.toDouble() / 100, minHeight: 6, backgroundColor: AppColors.bg, valueColor: AlwaysStoppedAnimation(color))),
    ]),
  );
}
