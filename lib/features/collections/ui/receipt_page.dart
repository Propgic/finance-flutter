import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
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

  Future<void> _editAmount(Map<String, dynamic> collection) async {
    final amountCtrl = TextEditingController(text: (collection['amount'] ?? '').toString());
    final notesCtrl = TextEditingController(text: collection['notes']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    final raw = amountCtrl.text.trim();
    if (raw.isEmpty) return showToast('Enter an amount', error: true);
    final amount = double.tryParse(raw);
    if (amount == null || amount < 0) return showToast('Enter a valid amount', error: true);
    // Amount 0 removes the collection entirely — confirm before the destructive action.
    if (amount == 0) {
      if (!mounted) return;
      final ok = await confirmDialog(
        context,
        title: 'Remove collection?',
        message: 'Setting the amount to 0 will remove this collection.',
        confirmText: 'Remove',
        destructive: true,
      );
      if (!ok) return;
    }
    try {
      final result = await ref.read(collectionRepoProvider).update(
            widget.id,
            amount: amount,
            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          );
      if (result['deleted'] == true) {
        showToast('Collection removed');
        if (mounted) Navigator.of(context).pop();
        return;
      }
      showToast('Collection amount updated');
      if (mounted) setState(() => _future = ref.read(collectionRepoProvider).getReceipt(widget.id));
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
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
          final auth = ref.watch(authProvider);
          final role = auth.user?.role;
          final isPending = (collection['verificationStatus']?.toString() ?? '') == 'PENDING';
          // Field officers may only edit the collected amount within 24 hours of recording it.
          final created = DateTime.tryParse(collection['createdAt']?.toString() ?? '');
          final withinFieldOfficerEditWindow =
              created != null && DateTime.now().difference(created.toLocal()) <= const Duration(hours: 24);
          final canEdit = isPending &&
              (role == 'ORG_ADMIN' ||
                  role == 'MANAGER' ||
                  (role == 'FIELD_OFFICER' &&
                      collection['collectedById'] == auth.user?.id &&
                      withinFieldOfficerEditWindow));
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (canEdit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton.icon(
                    onPressed: () => _editAmount(collection),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Amount'),
                  ),
                ),
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
