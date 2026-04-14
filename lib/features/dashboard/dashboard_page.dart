import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/common.dart';
import '../app_shell.dart';

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/dashboard');
  return Map<String, dynamic>.from(res as Map);
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider);
    final auth = ref.watch(authProvider);
    return Scaffold(
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(dashboardProvider)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardProvider.future),
        child: data.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(dashboardProvider)),
          data: (d) => _buildBody(context, d, auth),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> d, AuthState auth) {
    final role = auth.user?.role;
    final isFieldOfficer = role == 'FIELD_OFFICER';
    final isAdmin = role == 'ORG_ADMIN' || role == 'MANAGER';
    final features = auth.org?.features ?? const {};

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (isFieldOfficer)
          _fieldOfficerStats(d)
        else ...[
          _daySummaryCard(d),
          if ((features['enableLoans'] == true) && role == 'ORG_ADMIN') _outstandingCard(d),
          if (features['enableSavings'] == true) _savingsPoolCard(d),
          _dayReportCard(d),
        ],
        if (role == 'MANAGER') _todayLoansIssuedList(context, d),
        if (isFieldOfficer) _pendingVerificationList(d),
        if (!isFieldOfficer) ...[
          if (features['enableLoans'] == true) _upcomingOverdueCard(context, d, isAdmin),
          if (isAdmin) _pendingVerificationByAgentCard(context, d),
          if (features['enableLoans'] == true && !isFieldOfficer) ...[
            _loansByTypeCard(d),
            _loansByStatusCard(d),
          ],
          if (features['enableLoans'] == true) ...[
            _monthlyCollectionsChart(d),
            _monthlyDisbursementsChart(d),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // === Field officer: 4 stat cards ===
  Widget _fieldOfficerStats(Map<String, dynamic> d) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.3,
      children: [
        _statTile("Today's Loan Issues", formatCurrency(d['todayLoanIssuedAmount'] ?? d['todayDisbursedAmount']),
            subtitle: '${d['todayDisbursedCount'] ?? 0} loans', icon: Icons.payments, color: AppColors.accent),
        _statTile("Today's Collection", formatCurrency(d['totalCollectionsToday']),
            icon: Icons.receipt_long, color: AppColors.warning),
        _statTile('Total Due to Company', formatCurrency(d['companyAmountInMarket']),
            icon: Icons.trending_up, color: AppColors.danger),
        _statTile('Active Customers', '${d['activeCustomers'] ?? 0}',
            subtitle: 'assigned to you', icon: Icons.people, color: AppColors.primary),
      ],
    );
  }

  Widget _statTile(String label, String value, {String? subtitle, required IconData icon, required Color color}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // === Day summary card ===
  Widget _daySummaryCard(Map<String, dynamic> d) {
    return SectionCard(
      title: 'Day Summary',
      child: Column(
        children: [
          _kvRow('Today\'s Collection', formatCurrency(d['totalCollectionsToday']), color: AppColors.accent),
          const Divider(height: 1),
          _kvRow('Today\'s Loans Issued', formatCurrency(d['todayLoanIssuedAmount'] ?? d['todayDisbursedAmount'])),
          const Divider(height: 1),
          _kvRow('Today\'s Expenses', formatCurrency(d['todayExpensesAmount']), color: AppColors.danger),
        ],
      ),
    );
  }

  Widget _outstandingCard(Map<String, dynamic> d) {
    return SectionCard(
      title: 'Outstanding',
      child: Column(
        children: [
          _kvRow('Total Loans Issued', formatCurrency(d['totalActiveLoansIssued'])),
          const Divider(height: 1),
          _kvRow('Total Amount Collected', formatCurrency(d['totalActiveLoansCollected'])),
          const Divider(height: 1),
          _kvRow('Total Amount In Market', formatCurrency(d['companyAmountInMarket']), color: AppColors.danger),
        ],
      ),
    );
  }

  Widget _savingsPoolCard(Map<String, dynamic> d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.savings, color: Colors.purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Savings Pool', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(formatCurrency(d['totalSavingsBalance']),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayReportCard(Map<String, dynamic> d) {
    final openBal = toNum(d['openBalance']);
    final closing = toNum(d['closingBalance']);
    return SectionCard(
      title: 'Day Report',
      child: Column(
        children: [
          _kvRow('Open Balance', formatCurrency(openBal), color: openBal < 0 ? AppColors.danger : null),
          _kvRow('Day Investment', formatCurrency(d['todayInvestmentAmount'])),
          _kvRow('Day Collection', formatCurrency(d['totalCollectionsToday'])),
          _kvRow('Day Loan Issue', formatCurrency(d['todayDisbursedAmount'])),
          _kvRow('Day Expenses', formatCurrency(d['todayExpensesAmount'])),
          const Divider(),
          _kvRow('Closing Balance', formatCurrency(closing),
              color: closing < 0 ? AppColors.danger : AppColors.accent, bold: true),
        ],
      ),
    );
  }

  Widget _kvRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                color: color,
              )),
        ],
      ),
    );
  }

  // === Lists ===
  Widget _todayLoansIssuedList(BuildContext context, Map<String, dynamic> d) {
    final loans = (d['todayDisbursedLoans'] as List?) ?? const [];
    if (loans.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: "Today's Loans Issued (${d['todayDisbursedCount'] ?? loans.length})",
      actions: [TextButton(onPressed: () => context.go('/loans'), child: const Text('View all'))],
      child: Column(
        children: loans.map((l) {
          final m = Map<String, dynamic>.from(l as Map);
          final c = Map<String, dynamic>.from(m['customer'] ?? {});
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.payments_outlined, color: AppColors.primary),
            title: Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim()),
            subtitle: Text('${m['loanNumber'] ?? ''} · ${m['loanType'] ?? ''}', style: const TextStyle(fontSize: 11)),
            trailing: Text(formatCurrency(m['principalAmount']), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => context.push('/loans/${m['id']}'),
          );
        }).toList(),
      ),
    );
  }

  Widget _pendingVerificationList(Map<String, dynamic> d) {
    final list = (d['pendingCollections'] as List?) ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Pending Verification (${list.length})',
      child: Column(
        children: list.map((c) {
          final m = Map<String, dynamic>.from(c as Map);
          final cust = Map<String, dynamic>.from(m['customer'] ?? {});
          final loan = Map<String, dynamic>.from(m['loan'] ?? {});
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.shield_outlined, color: AppColors.warning),
            title: Text('${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim()),
            subtitle: Text('Loan #${loan['loanNumber'] ?? '-'} · ${m['receiptNumber'] ?? '-'}', style: const TextStyle(fontSize: 11)),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(formatCurrency(m['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(formatDate(m['collectedAt']), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _upcomingOverdueCard(BuildContext context, Map<String, dynamic> d, bool isAdmin) {
    final upcoming = Map<String, dynamic>.from(d['upcomingEMIs'] ?? {});
    final pendingCount = toNum(d['pendingVerificationCount']);
    return SectionCard(
      title: 'Upcoming & Overdue',
      child: Column(
        children: [
          _iconRow(
            icon: Icons.arrow_upward,
            iconColor: Colors.orange,
            label: 'Upcoming EMIs (next 7 days)',
            value: '${upcoming['count'] ?? 0} EMIs',
            trailing: Text(formatCurrency(upcoming['totalAmount']), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          _iconRow(
            icon: Icons.warning_amber,
            iconColor: AppColors.danger,
            label: 'Total Overdue',
            value: formatCurrency(d['totalOverdue']),
            valueColor: AppColors.danger,
            trailing: OutlinedButton(onPressed: () => context.push('/loans/overdue'), child: const Text('View')),
          ),
          if (isAdmin && pendingCount > 0)
            _iconRow(
              icon: Icons.shield_outlined,
              iconColor: AppColors.warning,
              label: 'Pending Verification',
              value: '${pendingCount.toInt()} collections · ${formatCurrency(d['pendingVerificationAmount'])}',
              trailing: OutlinedButton(onPressed: () => context.push('/collections/verify'), child: const Text('Verify')),
            ),
          _iconRow(
            icon: Icons.currency_rupee,
            iconColor: AppColors.primary,
            label: "This Month's Collections",
            value: formatCurrency(d['totalCollectionsThisMonth']),
          ),
        ],
      ),
    );
  }

  Widget _iconRow({required IconData icon, required Color iconColor, required String label, required String value, Color? valueColor, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _pendingVerificationByAgentCard(BuildContext context, Map<String, dynamic> d) {
    final list = (d['pendingCollections'] as List?) ?? const [];
    final Map<String, Map<String, dynamic>> byAgent = {};
    for (final c in list) {
      final m = Map<String, dynamic>.from(c as Map);
      final agent = Map<String, dynamic>.from(m['collectedBy'] ?? {});
      final id = m['collectedById']?.toString() ?? agent['name']?.toString() ?? 'Unknown';
      final existing = byAgent[id];
      final amt = toNum(m['amount']);
      if (existing == null) {
        byAgent[id] = {
          'id': m['collectedById'],
          'name': agent['name'] ?? 'Unknown',
          'photo': agent['photo'],
          'count': 1,
          'total': amt,
        };
      } else {
        existing['count'] = (existing['count'] as num) + 1;
        existing['total'] = (existing['total'] as num) + amt;
      }
    }
    final agents = byAgent.values.toList()..sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));
    return SectionCard(
      title: 'Pending Verification (${d['pendingVerificationCount'] ?? list.length})',
      actions: agents.isEmpty ? null : [TextButton(onPressed: () => context.push('/collections/verify'), child: const Text('Verify all'))],
      child: agents.isEmpty
          ? const EmptyView(message: 'No collections pending verification', icon: Icons.shield_outlined)
          : Column(
              children: agents.map((a) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onTap: () => context.push('/collections/verify'),
                  leading: Avatar(url: a['photo']?.toString(), name: a['name']?.toString() ?? 'U', size: 32),
                  title: Text(a['name']?.toString() ?? 'Unknown'),
                  subtitle: Text('${a['count']} collection${a['count'] == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11)),
                  trailing: Text(formatCurrency(a['total']), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                );
              }).toList(),
            ),
    );
  }

  Widget _loansByTypeCard(Map<String, dynamic> d) {
    final items = ((d['loansByType'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final maxCount = items.isEmpty ? 1 : items.map((e) => toNum(e['count'])).reduce((a, b) => a > b ? a : b);
    return SectionCard(
      title: 'Loans by Type',
      child: items.isEmpty
          ? const EmptyView(message: 'No loan data yet', icon: Icons.request_quote_outlined)
          : Column(
              children: items.map((item) {
                final count = toNum(item['count']);
                final ratio = maxCount > 0 ? (count / maxCount).toDouble() : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item['type']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                          Text('${count.toInt()}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          SizedBox(width: 80, child: Text(formatCurrency(item['amount']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: AppColors.bg,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _loansByStatusCard(Map<String, dynamic> d) {
    final items = ((d['loansByStatus'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return SectionCard(
      title: 'Loans by Status',
      child: items.isEmpty
          ? const EmptyView(message: 'No loan data yet', icon: Icons.request_quote_outlined)
          : Column(
              children: items.map((item) {
                final status = item['status']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        StatusChip(label: status, color: statusColor(status)),
                        const Spacer(),
                        Text('${toNum(item['count']).toInt()}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _monthlyCollectionsChart(Map<String, dynamic> d) {
    final items = ((d['monthlyCollectionTrend'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return SectionCard(
      title: 'Monthly Collections',
      child: SizedBox(
        height: 200,
        child: items.isEmpty
            ? const EmptyView(message: 'No collection data yet', icon: Icons.trending_up)
            : LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(_shortNum(v), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= items.length) return const SizedBox.shrink();
                          final month = items[i]['month']?.toString() ?? '';
                          return Padding(padding: const EdgeInsets.only(top: 6), child: Text(month.split(' ').first, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)));
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < items.length; i++) FlSpot(i.toDouble(), toNum(items[i]['amount']).toDouble())],
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _monthlyDisbursementsChart(Map<String, dynamic> d) {
    final items = ((d['monthlyDisbursementTrend'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return SectionCard(
      title: 'Loan Disbursements',
      child: SizedBox(
        height: 200,
        child: items.isEmpty
            ? const EmptyView(message: 'No disbursement data yet', icon: Icons.account_balance_wallet_outlined)
            : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(_shortNum(v), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= items.length) return const SizedBox.shrink();
                          final month = items[i]['month']?.toString() ?? '';
                          return Padding(padding: const EdgeInsets.only(top: 6), child: Text(month.split(' ').first, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)));
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < items.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: toNum(items[i]['amount']).toDouble(),
                          color: AppColors.primary,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ])
                  ],
                ),
              ),
      ),
    );
  }

  String _shortNum(double v) {
    if (v.abs() >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v.abs() >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}
