import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/expense_repo.dart';

class ExpenseFormPage extends ConsumerStatefulWidget {
  final String? expenseId;
  const ExpenseFormPage({super.key, this.expenseId});
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
  bool _loading = false;

  // Optional chit attribution — only when the org runs chitfunds. Booking an expense
  // under a chit counts it against that chit's returns (income − expenses).
  bool _chitEnabled = false;
  List<Map<String, dynamic>> _chitfunds = [];
  String? _chitfundId;
  final _monthNumber = TextEditingController();

  bool get isEdit => widget.expenseId != null;

  Map<String, dynamic>? get _selectedChit {
    if (_chitfundId == null) return null;
    for (final c in _chitfunds) {
      if (c['id'].toString() == _chitfundId) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _chitEnabled = ref.read(authProvider).org?.features['enableChitfund'] == true;
    _loadCats();
    if (_chitEnabled) _loadChitfunds();
    if (isEdit) _loadExpense();
  }

  Future<void> _loadChitfunds() async {
    try {
      // Load all (active/upcoming first) so trailing costs on a completed chit can
      // still be attributed. Mirrors the chit picker in the web expense form.
      final d = await ref.read(apiClientProvider).get('/chitfunds', query: {'limit': 200});
      if (mounted) setState(() => _chitfunds = extractList(d).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {}
  }

  Future<void> _loadCats() async {
    try {
      final cats = await ref.read(expenseRepoProvider).categories();
      setState(() {
        _categories = cats.map((e) => e.toString()).toList();
        if (!isEdit && _categories.isNotEmpty) _category = _categories.first;
      });
    } catch (_) {}
  }

  Future<void> _loadExpense() async {
    setState(() => _loading = true);
    try {
      final e = await ref.read(expenseRepoProvider).get(widget.expenseId!);
      setState(() {
        _category = e['category']?.toString();
        _amount.text = (e['amount'] ?? '').toString();
        _mode = e['paymentMode']?.toString() ?? 'CASH';
        _reference.text = e['paymentReference']?.toString() ?? '';
        _description.text = e['description']?.toString() ?? '';
        if (e['expenseDate'] != null) {
          _date = DateTime.tryParse(e['expenseDate'].toString()) ?? DateTime.now();
        }
        _chitfundId = e['chitfundId']?.toString();
        if (e['monthNumber'] != null) _monthNumber.text = e['monthNumber'].toString();
      });
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _category!.isEmpty) return showToast('Select category', error: true);
    setState(() => _saving = true);
    try {
      final body = {
        'category': _category,
        'amount': double.tryParse(_amount.text),
        'paymentMode': _mode,
        if (_reference.text.trim().isNotEmpty) 'paymentReference': _reference.text.trim(),
        if (_description.text.trim().isNotEmpty) 'description': _description.text.trim(),
        'expenseDate': formatInputDate(_date),
        // Send explicitly (even null) so an edit can clear the chit link; monthNumber
        // only rides along with a chit.
        'chitfundId': _chitfundId,
        'monthNumber': (_chitfundId != null && _monthNumber.text.trim().isNotEmpty)
            ? int.tryParse(_monthNumber.text.trim())
            : null,
      };
      if (isEdit) {
        await ref.read(expenseRepoProvider).update(widget.expenseId!, body);
        showToast('Expense updated');
      } else {
        await ref.read(expenseRepoProvider).create(body);
        showToast('Expense created');
      }
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
      appBar: AppBar(title: Text(isEdit ? 'Edit Expense' : 'New Expense')),
      body: _loading
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  SectionCard(
                    title: 'Details',
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _categories.contains(_category) ? _category : null,
                          decoration: const InputDecoration(labelText: 'Category *'),
                          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _category = v),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ '), validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Required'),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _mode,
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
                  if (_chitEnabled && _chitfunds.isNotEmpty)
                    SectionCard(
                      title: 'Book under Chitfund (optional)',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String?>(
                            value: _chitfundId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Chitfund'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Not linked to a chit')),
                              ..._chitfunds.map((c) => DropdownMenuItem<String?>(
                                    value: c['id'].toString(),
                                    child: Text('${c['name']} (${c['chitNumber']})', overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _chitfundId = v),
                          ),
                          if (_selectedChit != null) ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _monthNumber,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Auction Month (optional)',
                                hintText: '1 – ${_selectedChit!['durationMonths']}',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Counts against ${_selectedChit!['name']}'s returns (income − expenses) on the chit's page.",
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : isEdit ? 'Update Expense' : 'Save Expense'))),
                ],
              ),
            ),
    );
  }
}
