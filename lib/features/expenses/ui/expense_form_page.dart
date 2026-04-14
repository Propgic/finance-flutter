import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/expense_repo.dart';

class ExpenseFormPage extends ConsumerStatefulWidget {
  const ExpenseFormPage({super.key});
  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  String? _category;
  List<String> _categories = [];
  final _amount = TextEditingController();
  String _mode = 'CASH';
  final _reference = TextEditingController();
  final _description = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() { super.initState(); _loadCats(); }

  Future<void> _loadCats() async {
    try {
      final cats = await ref.read(expenseRepoProvider).categories();
      setState(() {
        _categories = cats.map((e) => e.toString()).toList();
        if (_categories.isNotEmpty) _category = _categories.first;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _category!.isEmpty) return showToast('Select category', error: true);
    setState(() => _saving = true);
    try {
      await ref.read(expenseRepoProvider).create({
        'category': _category,
        'amount': double.tryParse(_amount.text),
        'paymentMode': _mode,
        if (_reference.text.trim().isNotEmpty) 'paymentReference': _reference.text.trim(),
        if (_description.text.trim().isNotEmpty) 'description': _description.text.trim(),
        'expenseDate': formatInputDate(_date),
      });
      showToast('Expense created');
      if (mounted) context.go('/expenses');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SectionCard(
              title: 'Details',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category *'),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ '), validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Required'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _mode,
                    decoration: const InputDecoration(labelText: 'Payment Mode'),
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
                  TextFormField(controller: _reference, decoration: const InputDecoration(labelText: 'Reference')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Date: ${formatDate(_date)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _date);
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save Expense'))),
          ],
        ),
      ),
    );
  }
}
