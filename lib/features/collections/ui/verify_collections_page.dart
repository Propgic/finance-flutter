import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/collection_repo.dart';

const _loanTypeLabels = {
  'PERSONAL': 'Personal',
  'GOLD': 'Gold',
  'GROUP': 'Group',
  'VEHICLE': 'Vehicle',
  'PROPERTY': 'Property',
  'BUSINESS': 'Business',
  'AGRICULTURE': 'Agriculture',
  'EDUCATION': 'Education',
  'DAILY': 'Daily',
  'WEEKLY': 'Weekly',
};

const _paymentModeLabels = {
  'CASH': 'Cash',
  'UPI': 'UPI',
  'BANK_TRANSFER': 'Bank',
  'CHEQUE': 'Cheque',
  'ONLINE': 'Online',
};

class VerifyCollectionsPage extends ConsumerStatefulWidget {
  const VerifyCollectionsPage({super.key});
  @override
  ConsumerState<VerifyCollectionsPage> createState() => _VerifyCollectionsPageState();
}

class _VerifyCollectionsPageState extends ConsumerState<VerifyCollectionsPage> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _summary;
  bool _loading = true;
  Object? _error;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.raw(() => api.dio.get('/collections/pending-verification', queryParameters: {'limit': 200}));
      final body = res.data;
      final data = body is Map && body['data'] is List ? body['data'] as List : const [];
      if (body is Map && body['summary'] != null) {
        _summary = Map<String, dynamic>.from(body['summary'] as Map);
      }
      setState(() => _items = data.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) { setState(() => _error = e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _verify(String id, bool approve) async {
    try {
      await ref.read(collectionRepoProvider).verify(id, approve: approve);
      showToast(approve ? 'Verified' : 'Rejected');
      _fetch();
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Collections')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error.toString(), onRetry: _fetch)
              : _items.isEmpty
                  ? const EmptyView(message: 'Nothing pending', icon: Icons.check_circle_outline)
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (_summary != null) ...[
                            Row(children: [
                              _metricCard('To Be Verified', formatCurrency(_summary!['pendingAmount']), AppColors.warning),
                              const SizedBox(width: 8),
                              _metricCard("Today's Pending", formatCurrency(_summary!['todayPendingAmount']), AppColors.textPrimary),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              _metricCard('Collectors', '${_summary!['collectorsCount'] ?? 0}', AppColors.primary),
                              const SizedBox(width: 8),
                              _metricCard('Older Pending', formatCurrency(toNum(_summary!['pendingAmount']) - toNum(_summary!['todayPendingAmount'])), AppColors.danger),
                            ]),
                            const SizedBox(height: 12),
                          ],
                          ..._items.map(_collectionCard),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
    );
  }

  Widget _miniBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _metricCard(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ]),
    ),
  );

  Widget _collectionCard(Map<String, dynamic> c) {
    final cust = Map<String, dynamic>.from(c['customer'] ?? {});
    final loan = Map<String, dynamic>.from(c['loan'] ?? {});
    final collector = Map<String, dynamic>.from(c['collectedBy'] ?? {});
    final overdueEmis = (loan['emiSchedule'] as List?) ?? [];
    final overdueAmt = overdueEmis.fold<double>(0, (s, e) {
      final m = Map<String, dynamic>.from(e as Map);
      return s + toNum(m['emiAmount']) + toNum(m['lateFee']) - toNum(m['paidAmount']);
    });

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
                GestureDetector(
                  onTap: () => showImageViewer(context, cust['photo']?.toString()),
                  child: Avatar(
                    url: cust['photo']?.toString(),
                    name: '${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim(),
                    size: 44,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim(),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (loan['loanType'] != null)
                            _miniBadge(_loanTypeLabels[loan['loanType']?.toString()] ?? loan['loanType'].toString(), const Color(0xFF7C3AED)),
                          if (c['paymentMode'] != null)
                            _miniBadge(_paymentModeLabels[c['paymentMode']?.toString()] ?? c['paymentMode'].toString(), AppColors.primary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Flexible(child: Text(loan['loanNumber']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                        if (loan['id'] != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => context.push('/loans/${loan['id']}'),
                            child: const Text('View Loan', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatCurrency(c['amount']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text('Collected by ${collector['name'] ?? ''} • ${formatDateTime(c['collectedAt'])}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
              if (overdueEmis.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Overdue: ${formatCurrency(overdueAmt)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.danger)),
                ),
            ]),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _verify(c['id'].toString(), false),
                    icon: const Icon(Icons.close, color: AppColors.danger),
                    label: const Text('Reject', style: TextStyle(color: AppColors.danger)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _verify(c['id'].toString(), true),
                    icon: const Icon(Icons.check),
                    label: const Text('Verify'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
