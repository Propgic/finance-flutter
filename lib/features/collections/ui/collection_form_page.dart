import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/collection_repo.dart';
import '../../loans/data/loan_repo.dart';

class CollectionFormPage extends ConsumerStatefulWidget {
  const CollectionFormPage({super.key});
  @override
  ConsumerState<CollectionFormPage> createState() => _CollectionFormPageState();
}

class _CollectionFormPageState extends ConsumerState<CollectionFormPage> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _loan;
  final _amount = TextEditingController();
  String _mode = 'CASH';
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  Future<void> _pickLoan() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LoanPickerSheet(ref: ref),
    );
    if (picked != null) setState(() => _loan = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_loan == null) return showToast('Select a loan', error: true);
    if (_mode != 'CASH' && _reference.text.trim().isEmpty) return showToast('Reference required for non-cash', error: true);
    setState(() => _saving = true);
    try {
      final res = await ref.read(collectionRepoProvider).create({
        'loanId': _loan!['id'],
        'amount': double.tryParse(_amount.text),
        'paymentMode': _mode,
        if (_reference.text.trim().isNotEmpty) 'paymentReference': _reference.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
      showToast('Collection recorded');
      if (mounted) context.push('/collections/${res['id']}/receipt');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Collection')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SectionCard(
              title: 'Loan',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.request_quote),
                    title: Text(_loan == null ? 'Select Active Loan *' : _loan!['loanNumber']?.toString() ?? ''),
                    subtitle: _loan == null ? null : Text('Outstanding: ${formatCurrency(_loan!['outstandingAmount'])}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickLoan,
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Payment',
              child: Column(
                children: [
                  TextFormField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ '),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Required',
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _mode,
                    decoration: const InputDecoration(labelText: 'Payment Mode *'),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                      DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                    ],
                    onChanged: (v) => setState(() => _mode = v!),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(controller: _reference, decoration: InputDecoration(labelText: _mode == 'CASH' ? 'Reference (optional)' : 'Reference *')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
                ],
              ),
            ),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Record Collection'))),
          ],
        ),
      ),
    );
  }
}

class _LoanPickerSheet extends StatefulWidget {
  final WidgetRef ref;
  const _LoanPickerSheet({required this.ref});
  @override
  State<_LoanPickerSheet> createState() => _LoanPickerSheetState();
}

class _LoanPickerSheetState extends State<_LoanPickerSheet> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _load(''); }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final r = await widget.ref.read(loanRepoProvider).list(page: 1, limit: 30, search: q.isEmpty ? null : q, status: 'ACTIVE');
      setState(() => _items = ((r['data'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Expanded(child: Text('Select Active Loan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: TextField(controller: _search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search)), onSubmitted: _load)),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _items.isEmpty
                    ? const EmptyView(message: 'No active loans')
                    : ListView.builder(
                        controller: ctrl,
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final l = _items[i];
                          final c = Map<String, dynamic>.from(l['customer'] ?? {});
                          return ListTile(
                            title: Text(l['loanNumber']?.toString() ?? ''),
                            subtitle: Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''} • Outstanding: ${formatCurrency(l['outstandingAmount'])}'),
                            onTap: () => Navigator.pop(context, l),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
