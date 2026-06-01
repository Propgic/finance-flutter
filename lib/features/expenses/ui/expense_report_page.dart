import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/expense_repo.dart';

class ExpenseReportPage extends ConsumerStatefulWidget {
  const ExpenseReportPage({super.key});
  @override
  ConsumerState<ExpenseReportPage> createState() => _ExpenseReportPageState();
}

class _ExpenseReportPageState extends ConsumerState<ExpenseReportPage> {
  late DateTime _monthStart;
  late DateTime _monthEnd;
  Map<String, dynamic>? _summary;
  List<dynamic> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthStart = DateTime(now.year, now.month, 1);
    _monthEnd = DateTime(now.year, now.month + 1, 0);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(expenseRepoProvider);
      final from = formatInputDate(_monthStart);
      final to = formatInputDate(_monthEnd);
      final results = await Future.wait([
        repo.list(from: from, to: to, limit: 500),
        repo.summary(from: from, to: to),
      ]);
      setState(() {
        final listData = results[0] as Map<String, dynamic>;
        _expenses = extractList(listData['data'] ?? listData);
        _summary = results[1] as Map<String, dynamic>;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _changeMonth(int delta) {
    final m = DateTime(_monthStart.year, _monthStart.month + delta, 1);
    setState(() {
      _monthStart = m;
      _monthEnd = DateTime(m.year, m.month + 1, 0);
    });
    _load();
  }

  String get _monthLabel {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[_monthStart.month - 1]} ${_monthStart.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Report')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                Text(_monthLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _buildSummaryCards(),
                        if (_summary != null) _buildCategoryBreakdown(),
                        const SizedBox(height: 12),
                        Text('All Expenses (${_expenses.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        ..._expenses.map((item) {
                          final e = Map<String, dynamic>.from(item as Map);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: _expenseCard(e),
                            ),
                          );
                        }),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final total = double.tryParse(_summary?['totalExpenses']?.toString() ?? '0') ?? 0;
    final byCategory = (_summary?['byCategory'] as List?) ?? [];
    final salaryAmt = byCategory.where((c) => (c as Map)['category'] == 'SALARY').fold<double>(0, (s, c) => s + (double.tryParse((c as Map)['amount']?.toString() ?? '0') ?? 0));
    final otherAmt = total - salaryAmt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: _summaryCard('Total', total, const Color(0xFFE11D48))),
          const SizedBox(width: 8),
          Expanded(child: _summaryCard('Salary', salaryAmt, const Color(0xFF2563EB))),
          const SizedBox(width: 8),
          Expanded(child: _summaryCard('Other', otherAmt, const Color(0xFFD97706))),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(formatCurrency(amount), style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _expenseCard(Map<String, dynamic> e) {
    final user = e['user'] is Map ? Map<String, dynamic>.from(e['user'] as Map) : null;
    final recordedBy = e['recordedBy'] is Map ? Map<String, dynamic>.from(e['recordedBy'] as Map) : null;
    final description = e['description']?.toString().trim();
    final month = e['month']?.toString();
    final paymentMode = e['paymentMode']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  e['category']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatCurrency(e['amount']),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (user != null) _personRow('Team Member', user),
        if (recordedBy != null) ...[
          if (user != null) const SizedBox(height: 6),
          _personRow('Entered By', recordedBy),
        ],
        if (user != null || recordedBy != null) const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            _meta(Icons.calendar_today_outlined, formatDate(e['expenseDate'])),
            if (month != null && month.isNotEmpty) _meta(Icons.event_outlined, month),
            if (paymentMode != null && paymentMode.isNotEmpty) _meta(Icons.payment_outlined, paymentMode),
          ],
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ],
    );
  }

  Widget _personRow(String label, Map<String, dynamic> person) {
    final photo = resolveUrl(person['photo']?.toString());
    final name = person['name']?.toString() ?? '';
    return Row(
      children: [
        if (photo != null)
          CircleAvatar(radius: 12, backgroundImage: NetworkImage(photo))
        else
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey.shade200,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildCategoryBreakdown() {
    final byCategory = (_summary?['byCategory'] as List?) ?? [];
    if (byCategory.isEmpty) return const SizedBox.shrink();
    final total = double.tryParse(_summary?['totalExpenses']?.toString() ?? '1') ?? 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category Breakdown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            ...byCategory.map((c) {
              final cat = c as Map;
              final amt = double.tryParse(cat['amount']?.toString() ?? '0') ?? 0;
              final pct = total > 0 ? amt / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cat['category']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                        Text('${formatCurrency(amt)} (${(pct * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: Colors.grey.shade200, color: const Color(0xFF2563EB)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
