import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '_report_scaffold.dart';

class PortfolioReportPage extends StatelessWidget {
  const PortfolioReportPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ReportScaffold(
      title: 'Portfolio Report',
      endpoint: 'portfolio',
      bodyBuilder: (ctx, data) {
        final Map l = (data['summary'] is Map ? data : {'summary': {}, 'data': data['data'] ?? data});
        final list = (data['data'] as List?) ?? (data['items'] as List?) ?? const [];
        return ListView(
          children: [
            ReportSummaryGrid(items: [
              MapEntry("Total Loans", (l['summary']['totalLoans'] ?? 0).toString()),
              MapEntry("Active", (l['summary']['activeLoans'] ?? 0).toString()),
              MapEntry("Total Value", formatCurrency(l['summary']['totalValue'])),
              MapEntry("Outstanding", formatCurrency(l['summary']['outstanding'])),
            ]),
            if (list.isEmpty)
              const EmptyView(message: 'No data')
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: Column(
                    children: list.map((item) {
                      final m = Map<String, dynamic>.from(item as Map);
                      return ListTile(
                        dense: true,
                        title: Text(_titleOf(m)),
                        subtitle: Text(_subtitleOf(m)),
                        trailing: Text(_trailingOf(m), style: const TextStyle(fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _titleOf(Map<String, dynamic> m) {
    if (m['customer'] is Map) {
      final c = Map<String, dynamic>.from(m['customer'] as Map);
      return '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
    }
    return m['name']?.toString() ?? m['loanNumber']?.toString() ?? m['accountNumber']?.toString() ?? m['category']?.toString() ?? '-';
  }

  String _subtitleOf(Map<String, dynamic> m) {
    final parts = <String>[];
    if (m['loanNumber'] != null) parts.add(m['loanNumber'].toString());
    if (m['status'] != null) parts.add(m['status'].toString());
    if (m['date'] != null) parts.add(formatDate(m['date']));
    if (m['collectedAt'] != null) parts.add(formatDate(m['collectedAt']));
    return parts.join(' • ');
  }

  String _trailingOf(Map<String, dynamic> m) {
    for (final k in ['amount', 'principalAmount', 'outstandingAmount', 'balance', 'totalAmount']) {
      if (m[k] != null) return formatCurrency(m[k]);
    }
    return '';
  }
}
