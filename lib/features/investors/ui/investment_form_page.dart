import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/investor_repo.dart';

class InvestmentFormPage extends ConsumerStatefulWidget {
  const InvestmentFormPage({super.key});
  @override
  ConsumerState<InvestmentFormPage> createState() => _InvestmentFormPageState();
}

class _InvestmentFormPageState extends ConsumerState<InvestmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _investor;
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  String _type = 'SIMPLE';
  DateTime _start = DateTime.now();
  DateTime? _maturity;
  final _notes = TextEditingController();
  bool _saving = false;

  Future<void> _pickInvestor() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InvPicker(ref: ref),
    );
    if (picked != null) setState(() => _investor = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_investor == null) return showToast('Select an investor', error: true);
    setState(() => _saving = true);
    try {
      await ref.read(investmentRepoProvider).create({
        'investorId': _investor!['id'],
        'amount': double.tryParse(_amount.text),
        'interestRate': double.tryParse(_rate.text),
        'startDate': formatInputDate(_start),
        if (_maturity != null) 'maturityDate': formatInputDate(_maturity!),
        'interestType': _type,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
      showToast('Investment created');
      if (mounted) context.go('/investors');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Investment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SectionCard(
              title: 'Investor',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person),
                title: Text(_investor == null ? 'Select Investor *' : _investor!['name']?.toString() ?? ''),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickInvestor,
              ),
            ),
            SectionCard(
              title: 'Details',
              child: Column(
                children: [
                  TextFormField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ '), validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Required'),
                  const SizedBox(height: 10),
                  TextFormField(controller: _rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Interest Rate (%) *'), validator: (v) => double.tryParse(v ?? '') != null ? null : 'Required'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Interest Type'),
                    items: const [
                      DropdownMenuItem(value: 'SIMPLE', child: Text('Simple')),
                      DropdownMenuItem(value: 'COMPOUND', child: Text('Compound')),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Start: ${formatDate(_start)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _start);
                      if (d != null) setState(() => _start = d);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_maturity == null ? 'Maturity date (optional)' : 'Maturity: ${formatDate(_maturity)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(context: context, firstDate: _start, lastDate: DateTime.now().add(const Duration(days: 365 * 10)), initialDate: _maturity ?? _start.add(const Duration(days: 365)));
                      if (d != null) setState(() => _maturity = d);
                    },
                  ),
                  TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
                ],
              ),
            ),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Create Investment'))),
          ],
        ),
      ),
    );
  }
}

class _InvPicker extends StatefulWidget {
  final WidgetRef ref;
  const _InvPicker({required this.ref});
  @override
  State<_InvPicker> createState() => _InvPickerState();
}

class _InvPickerState extends State<_InvPicker> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.ref.read(investorRepoProvider).list(limit: 100);
      setState(() => _items = ((r['data'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Expanded(child: Text('Select Investor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))])),
          Expanded(
            child: _loading
                ? const LoadingView()
                : ListView.builder(
                    controller: ctrl,
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final x = _items[i];
                      return ListTile(title: Text(x['name']?.toString() ?? ''), subtitle: Text(x['phone']?.toString() ?? ''), onTap: () => Navigator.pop(context, x));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
