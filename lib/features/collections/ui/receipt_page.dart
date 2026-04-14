import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/collection_repo.dart';

class ReceiptPage extends ConsumerStatefulWidget {
  final String id;
  const ReceiptPage({super.key, required this.id});
  @override
  ConsumerState<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends ConsumerState<ReceiptPage> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(collectionRepoProvider).getReceipt(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(message: snap.error.toString(), onRetry: () {
              setState(() => _future = ref.read(collectionRepoProvider).getReceipt(widget.id));
            });
          }
          final r = snap.data ?? {};
          final collection = Map<String, dynamic>.from(r['collection'] ?? r);
          final cust = Map<String, dynamic>.from(collection['customer'] ?? {});
          final loan = Map<String, dynamic>.from(collection['loan'] ?? {});
          final orgRaw = r['org'] ?? r['organization'];
          final org = Map<String, dynamic>.from(orgRaw is Map ? orgRaw : {});
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.verified, color: AppColors.accent, size: 48),
                      const SizedBox(height: 10),
                      Text(org['name']?.toString() ?? 'Organization', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Divider(),
                      const SizedBox(height: 4),
                      Text('Receipt #${collection['receiptNumber'] ?? collection['id']}',
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 14),
                      Text(formatCurrency(collection['amount']), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
              SectionCard(
                title: 'Details',
                child: Column(
                  children: [
                    KeyValueRow(label: 'Customer', value: '${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim()),
                    KeyValueRow(label: 'Loan #', value: loan['loanNumber']?.toString() ?? '-'),
                    KeyValueRow(label: 'Date', value: formatDateTime(collection['collectedAt'])),
                    KeyValueRow(label: 'Payment Mode', value: collection['paymentMode']?.toString() ?? '-'),
                    if (collection['paymentReference'] != null)
                      KeyValueRow(label: 'Reference', value: collection['paymentReference'].toString()),
                    KeyValueRow(label: 'Status', value: collection['verificationStatus']?.toString() ?? '-'),
                    KeyValueRow(label: 'Collected By', value: (collection['collectedBy'] is Map ? collection['collectedBy']['name']?.toString() : null) ?? '-'),
                    KeyValueRow(label: 'Total Paid on Loan', value: formatCurrency(r['totalPaidOnLoan'])),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
