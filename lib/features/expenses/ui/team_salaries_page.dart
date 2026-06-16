import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/expense_repo.dart';

/// Team salary breakdown from `GET /expenses/team-salaries?month=<MMMM YYYY>`.
/// Per member shows: name/role, salary mode, estimated/calculated salary,
/// commission for percentage modes, amount already paid this month, and the
/// last salary payment. Tapping a member opens the salary expense form
/// pre-scoped to the SALARY category.
class TeamSalariesPage extends ConsumerStatefulWidget {
  const TeamSalariesPage({super.key});
  @override
  ConsumerState<TeamSalariesPage> createState() => _TeamSalariesPageState();
}

class _TeamSalariesPageState extends ConsumerState<TeamSalariesPage> {
  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  late List<String> _monthOptions;
  late String _month;
  Future<List<dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    // Match web: current month plus previous 11, labelled "<Month> <Year>".
    final now = DateTime.now();
    _monthOptions = List.generate(12, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return '${_months[d.month - 1]} ${d.year}';
    });
    _month = _monthOptions.first;
    _load();
  }

  void _load() {
    _future = ref.read(expenseRepoProvider).teamSalaries(month: _month);
    setState(() {});
  }

  bool _isPercentage(String? mode) => mode == 'PERCENTAGE' || mode == 'FIXED_AND_PERCENTAGE';

  String _modeLabel(String? mode) {
    switch (mode) {
      case 'PERCENTAGE':
        return 'Commission';
      case 'FIXED_AND_PERCENTAGE':
        return 'Fixed + Commission';
      case 'FIXED':
        return 'Fixed';
      default:
        return mode == null || mode.isEmpty ? 'Salary' : titleCase(mode.replaceAll('_', ' '));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team Salaries')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: DropdownButtonFormField<String>(
              value: _month,
              decoration: const InputDecoration(labelText: 'Salary Month', isDense: true),
              items: _monthOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _month = v);
                _load();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _load);
                final members = snap.data ?? const [];
                if (members.isEmpty) {
                  return const EmptyView(message: 'No team members with salary configured', icon: Icons.groups_outlined);
                }
                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      _summaryBar(members),
                      const SizedBox(height: 4),
                      ...members.map((m) => _memberCard(Map<String, dynamic>.from(m as Map))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBar(List<dynamic> members) {
    double estimated = 0;
    double paid = 0;
    for (final raw in members) {
      final m = Map<String, dynamic>.from(raw as Map);
      paid += toNum(m['salaryPaidThisMonth']).toDouble();
      if (_isPercentage(m['salaryMode']?.toString())) {
        estimated += toNum(m['calculatedSalary']).toDouble();
      } else {
        estimated += toNum(m['salary']).toDouble();
      }
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _summaryCell('Estimated Payroll', formatCurrency(estimated))),
          Container(width: 1, height: 34, color: Colors.white24),
          Expanded(child: _summaryCell('Paid This Month', formatCurrency(paid))),
          Container(width: 1, height: 34, color: Colors.white24),
          Expanded(child: _summaryCell('Members', '${members.length}')),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _memberCard(Map<String, dynamic> m) {
    final mode = m['salaryMode']?.toString();
    final isPct = _isPercentage(mode);
    final paid = toNum(m['salaryPaidThisMonth']).toDouble();
    final isPaid = paid > 0;
    final estimated = isPct ? toNum(m['calculatedSalary']).toDouble() : toNum(m['salary']).toDouble();
    final lastPayment = m['lastPayment'] is Map ? Map<String, dynamic>.from(m['lastPayment'] as Map) : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(url: m['photo']?.toString(), name: m['name']?.toString() ?? '', size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m['name']?.toString() ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if ((m['role']?.toString() ?? '').isNotEmpty) ...[
                            Text(titleCase((m['role']?.toString() ?? '').replaceAll('_', ' ')), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 6),
                          ],
                          StatusChip(label: _modeLabel(mode), color: AppColors.info),
                        ],
                      ),
                    ],
                  ),
                ),
                StatusChip(label: isPaid ? 'Paid' : 'Pending', color: isPaid ? AppColors.accent : AppColors.warning),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),
            KeyValueRow(label: isPct ? 'Estimated Salary' : 'Monthly Salary', value: formatCurrency(estimated)),
            if (isPct) ...[
              KeyValueRow(label: 'Collections', value: formatCurrency(toNum(m['collectionAmount']))),
              KeyValueRow(label: 'Commission %', value: '${m['commissionPercentage'] ?? 0}%'),
              KeyValueRow(label: 'Commission', value: formatCurrency(toNum(m['commissionAmount']))),
            ],
            KeyValueRow(label: 'Paid This Month', value: formatCurrency(paid), valueColor: isPaid ? AppColors.accent : null),
            if (lastPayment != null)
              KeyValueRow(
                label: 'Last Payment',
                value: '${formatCurrency(lastPayment['amount'])} • ${lastPayment['month'] ?? formatDate(lastPayment['expenseDate'])}',
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/expenses/new'),
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: Text(isPaid ? 'Pay Again' : 'Pay Salary'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
