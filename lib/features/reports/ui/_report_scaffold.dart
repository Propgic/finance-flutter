import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/report_repo.dart';

class ReportScaffold extends ConsumerStatefulWidget {
  final String title;
  final String endpoint;
  final bool showDateRange;
  final Map<String, dynamic>? extraParams;
  final Widget Function(BuildContext, Map<String, dynamic>) bodyBuilder;
  const ReportScaffold({
    super.key,
    required this.title,
    required this.endpoint,
    required this.bodyBuilder,
    this.showDateRange = true,
    this.extraParams,
  });
  @override
  ConsumerState<ReportScaffold> createState() => _ReportScaffoldState();
}

class _ReportScaffoldState extends ConsumerState<ReportScaffold> {
  DateTime? _from;
  DateTime? _to;
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.showDateRange) {
      _from = DateTime.now().subtract(const Duration(days: 30));
      _to = DateTime.now();
    }
    _load();
  }

  void _load() {
    final params = <String, dynamic>{...?widget.extraParams};
    if (_from != null) params['fromDate'] = formatInputDate(_from!);
    if (_to != null) params['toDate'] = formatInputDate(_to!);
    _future = ref.read(reportRepoProvider).fetch(widget.endpoint, params: params.isEmpty ? null : params);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          if (widget.showDateRange)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: _dateBtn('From', _from, (d) { _from = d; _load(); })),
                  const SizedBox(width: 8),
                  Expanded(child: _dateBtn('To', _to, (d) { _to = d; _load(); })),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _load);
                return widget.bodyBuilder(ctx, snap.data ?? {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateBtn(String label, DateTime? v, void Function(DateTime) on) {
    return OutlinedButton.icon(
      onPressed: () async {
        final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: v ?? DateTime.now());
        if (d != null) on(d);
      },
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text('$label: ${v == null ? "-" : formatDate(v)}', style: const TextStyle(fontSize: 12)),
    );
  }
}

class ReportSummaryGrid extends StatelessWidget {
  final List<MapEntry<String, String>> items;
  const ReportSummaryGrid({super.key, required this.items});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.2,
        children: items.map((e) => Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(e.value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}
