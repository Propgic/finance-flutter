import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '_report_scaffold.dart';

// Plain Indian-grouped number (no currency symbol) — the Progress table mixes counts and money.
final _grp = NumberFormat('#,##0.##', 'en_IN');
String _n(dynamic v) => v == null ? '' : _grp.format(toNum(v));

const _hdr = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary);
const _cell = TextStyle(fontSize: 13);

class ProgressReportPage extends StatelessWidget {
  const ProgressReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ReportScaffold(
      title: 'Progress Report',
      endpoint: 'progress',
      bodyBuilder: (ctx, r) => _body(ctx, r),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> r) {
    final progress = (r['progress'] as List?) ?? const [];
    final receipts = (r['receipts'] as List?) ?? const [];
    final payments = (r['payments'] as List?) ?? const [];
    final totals = Map<String, dynamic>.from(r['totals'] ?? {});
    if (progress.isEmpty && receipts.isEmpty) {
      return const EmptyView(message: 'No data for this period');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Progress Report',
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              headingRowHeight: 38,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 46,
              columns: const [
                DataColumn(label: Text('Particulars', style: _hdr)),
                DataColumn(label: Text('Begin', style: _hdr), numeric: true),
                DataColumn(label: Text('Added', style: _hdr), numeric: true),
                DataColumn(label: Text('Dropped', style: _hdr), numeric: true),
                DataColumn(label: Text('End', style: _hdr), numeric: true),
              ],
              rows: progress.map((e) {
                final row = Map<String, dynamic>.from(e as Map);
                final indent = row['indent'] == true;
                return DataRow(cells: [
                  DataCell(Padding(
                    padding: EdgeInsets.only(left: indent ? 14 : 0),
                    child: Text(
                      row['particular']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: indent ? AppColors.textSecondary : AppColors.textPrimary,
                        fontWeight: indent ? FontWeight.w400 : FontWeight.w500,
                      ),
                    ),
                  )),
                  DataCell(Text(_n(row['begin']), style: _cell)),
                  DataCell(Text(_n(row['added']), style: _cell)),
                  DataCell(Text(_n(row['dropped']), style: _cell)),
                  DataCell(Text(_n(row['end']), style: _cell)),
                ]);
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Receipts',
          child: Column(children: [
            ...receipts.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return _line(m['label']?.toString() ?? '', _n(m['amount']));
            }),
            const Divider(height: 18),
            _line('Total Receipts', _n(totals['totalReceipts']), bold: true, color: AppColors.accent),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Payments',
          child: Column(children: [
            ...payments.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return _line(m['label']?.toString() ?? '', _n(m['amount']));
            }),
            const Divider(height: 18),
            _line('Cash Closing Balance', _n(totals['closingCashBalance']), bold: true, color: AppColors.danger),
            _line('Total Payments', _n(totals['totalPayments']), bold: true, color: AppColors.accent),
          ]),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _line(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color ?? AppColors.textPrimary)),
        ),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? AppColors.textPrimary)),
      ]),
    );
  }
}
