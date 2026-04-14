import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';

class DailyCashReportPage extends ConsumerStatefulWidget {
  const DailyCashReportPage({super.key});
  @override
  ConsumerState<DailyCashReportPage> createState() => _DailyCashReportPageState();
}

class _DailyCashReportPageState extends ConsumerState<DailyCashReportPage> {
  DateTime _date = DateTime.now();
  Map<String,dynamic>? _r;
  bool _loading = true;
  Object? _error;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ref.read(apiClientProvider).get('/reports/daily-cash', query: {'date': formatInputDate(_date)});
      setState(() => _r = Map<String,dynamic>.from(d as Map));
    } catch (e) { setState(() => _error = e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Cash Report'), actions: [
        TextButton.icon(
          onPressed: () async {
            final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _date);
            if (d != null) { _date = d; _fetch(); }
          },
          icon: const Icon(Icons.calendar_today, size: 14),
          label: Text(formatDate(_date), style: const TextStyle(fontSize: 12)),
        ),
      ]),
      body: _loading ? const LoadingView()
        : _error != null ? ErrorView(message: _error.toString(), onRetry: _fetch)
        : _buildBody(_r ?? const {}),
    );
  }

  Widget _buildBody(Map<String,dynamic> r) {
    final txns = (r['transactions'] as List?) ?? const [];
    final cap = Map<String,dynamic>.from(r['capitalSummary'] ?? {});
    final open = toNum(r['openingBalance']);
    final close = toNum(r['closingBalance']);
    final net = toNum(r['netCash']);
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
            childAspectRatio: 2,
            children: [
              _stat('Opening', formatCurrency(open), open < 0 ? AppColors.danger : AppColors.textPrimary, Colors.white),
              _stat('Inflow', '+${formatCurrency(r['totalInflow'])}', AppColors.accent, AppColors.accent.withValues(alpha: 0.08)),
              _stat('Outflow', '-${formatCurrency(r['totalOutflow'])}', AppColors.danger, AppColors.danger.withValues(alpha: 0.08)),
              _stat('Net Today', formatCurrency(net), net >= 0 ? AppColors.primary : AppColors.danger, Colors.white),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: close >= 0 ? AppColors.primary.withValues(alpha: 0.08) : AppColors.danger.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Text('Closing Balance', style: TextStyle(fontSize: 13)),
                const Spacer(),
                Text(formatCurrency(close), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: close >= 0 ? AppColors.primary : AppColors.danger)),
              ]),
            ),
          ),
          if (cap.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('CAPITAL POSITION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2,
              children: [
                _capTile('Investor Capital', cap['investorCapital'], Icons.account_balance, Colors.indigo),
                _capTile('Savings Deposits', cap['savingsDeposits'], Icons.savings, AppColors.purple),
                _capTile('Total Disbursed', cap['totalDisbursed'], Icons.payments, AppColors.primary),
                _capTile('Total Collected', cap['totalCollected'], Icons.receipt_long, AppColors.accent),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text('Transactions (${txns.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (txns.isEmpty) const EmptyView(message: 'No transactions for this date')
          else ...txns.map((t) => _txnTile(Map<String,dynamic>.from(t as Map))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color textColor, Color bg) => Card(
    margin: EdgeInsets.zero,
    color: bg,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );

  Widget _capTile(String label, dynamic v, IconData icon, Color color) => Card(
    margin: EdgeInsets.zero,
    color: color.withValues(alpha: 0.08),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 10, color: color))]),
        const SizedBox(height: 2),
        Text(formatCurrency(v), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );

  Widget _txnTile(Map<String,dynamic> t) {
    final typ = t['type']?.toString() ?? '';
    final isIn = typ.contains('Deposit') || typ == 'Loan Collection' || typ == 'Investment Received';
    final isOut = typ.contains('Withdrawal') || typ == 'Loan Disbursement' || typ == 'Investment Payout';
    final color = isIn ? AppColors.accent : isOut ? AppColors.danger : AppColors.info;
    final inflow = toNum(t['inflow']);
    final outflow = toNum(t['outflow']);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: Icon(isIn ? Icons.arrow_downward : isOut ? Icons.arrow_upward : Icons.sync_alt, color: color, size: 18),
        title: Text(t['description']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
        subtitle: Text('${t['mode'] ?? '-'} • ${formatDateTime(t['time'])}', style: const TextStyle(fontSize: 11)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (inflow > 0) Text('+${formatCurrency(inflow)}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 12)),
          if (outflow > 0) Text('-${formatCurrency(outflow)}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      ),
    );
  }
}
