import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/loan_repo.dart';
import '../../customers/data/customer_repo.dart';

class LoanCreatePage extends ConsumerStatefulWidget {
  const LoanCreatePage({super.key});
  @override
  ConsumerState<LoanCreatePage> createState() => _LoanCreatePageState();
}

class _LoanCreatePageState extends ConsumerState<LoanCreatePage> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _customer;
  Map<String, dynamic>? _assignee;
  String _loanType = 'PERSONAL';
  String _tenureType = 'MONTHS';
  DateTime _startDate = DateTime.now();
  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _tenure = TextEditingController();
  final _fee = TextEditingController(text: '0');
  final _lateFee = TextEditingController(text: '0');
  final _notes = TextEditingController();
  // type-specific
  final _goldWeight = TextEditingController();
  final _goldPurity = TextEditingController();
  final _vehType = TextEditingController();
  final _vehMake = TextEditingController();
  final _vehModel = TextEditingController();
  final _propType = TextEditingController();
  final _propAddr = TextEditingController();
  final _propValue = TextEditingController();
  final _guarantorName = TextEditingController();
  final _guarantorPhone = TextEditingController();
  bool _saving = false;

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickerSheet<Map<String, dynamic>>(
        title: 'Select Customer',
        fetcher: (search) async {
          final r = await ref.read(customerRepoProvider).list(page: 1, limit: 20, search: search, forLoan: true);
          return ((r['data'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        },
        labelBuilder: (m) => '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim(),
        subtitleBuilder: (m) => '${m['customerId'] ?? ''} • ${m['phone'] ?? ''}',
      ),
    );
    if (picked != null) setState(() => _customer = picked);
  }

  Future<void> _pickAssignee() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickerSheet<Map<String, dynamic>>(
        title: 'Assign To',
        fetcher: (search) async {
          final api = ref.read(apiClientProvider);
          final d = await api.get('/team');
          final list = d is List ? d : (d is Map && d['data'] is List ? d['data'] : const []);
          var users = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          if (search.isNotEmpty) {
            users = users.where((u) {
              final nm = (u['name']?.toString() ?? '').toLowerCase();
              return nm.contains(search.toLowerCase());
            }).toList();
          }
          return users;
        },
        labelBuilder: (m) => m['name']?.toString() ?? '',
        subtitleBuilder: (m) => m['role']?.toString() ?? '',
      ),
    );
    if (picked != null) setState(() => _assignee = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customer == null) return showToast('Select a customer', error: true);
    if (_assignee == null) return showToast('Assign to a team member', error: true);
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'customerId': _customer!['id'],
        'assignedToId': _assignee!['id'],
        'loanType': _loanType,
        'principalAmount': double.tryParse(_principal.text),
        'interestRate': double.tryParse(_rate.text),
        'tenure': int.tryParse(_tenure.text),
        'tenureType': _tenureType,
        'startDate': formatInputDate(_startDate),
        'processingFee': double.tryParse(_fee.text) ?? 0,
        'lateFeePerDay': double.tryParse(_lateFee.text) ?? 0,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      };
      if (_loanType == 'GOLD') {
        body['goldWeight'] = double.tryParse(_goldWeight.text);
        body['goldPurity'] = _goldPurity.text.trim();
      }
      if (_loanType == 'VEHICLE') {
        body['vehicleType'] = _vehType.text.trim();
        body['vehicleMake'] = _vehMake.text.trim();
        body['vehicleModel'] = _vehModel.text.trim();
      }
      if (_loanType == 'PROPERTY') {
        body['propertyType'] = _propType.text.trim();
        body['propertyAddress'] = _propAddr.text.trim();
        body['propertyValue'] = double.tryParse(_propValue.text);
      }
      if (_guarantorName.text.trim().isNotEmpty) body['guarantorName'] = _guarantorName.text.trim();
      if (_guarantorPhone.text.trim().isNotEmpty) body['guarantorPhone'] = _guarantorPhone.text.trim();

      await ref.read(loanRepoProvider).create(body);
      showToast('Loan created');
      if (mounted) context.go('/loans');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Loan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SectionCard(
              title: 'Basics',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person),
                    title: Text(_customer == null ? 'Select Customer *' : '${_customer!['firstName']} ${_customer!['lastName'] ?? ''}'.trim()),
                    subtitle: _customer == null ? null : Text(_customer!['phone']?.toString() ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickCustomer,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.assignment_ind),
                    title: Text(_assignee == null ? 'Assign To *' : _assignee!['name']?.toString() ?? ''),
                    subtitle: _assignee == null ? null : Text(_assignee!['role']?.toString() ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickAssignee,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _loanType,
                    decoration: const InputDecoration(labelText: 'Loan Type *'),
                    items: const [
                      DropdownMenuItem(value: 'PERSONAL', child: Text('Personal')),
                      DropdownMenuItem(value: 'GOLD', child: Text('Gold')),
                      DropdownMenuItem(value: 'VEHICLE', child: Text('Vehicle')),
                      DropdownMenuItem(value: 'PROPERTY', child: Text('Property/Mortgage')),
                      DropdownMenuItem(value: 'BUSINESS', child: Text('Business')),
                      DropdownMenuItem(value: 'AGRICULTURE', child: Text('Agriculture')),
                      DropdownMenuItem(value: 'EDUCATION', child: Text('Education')),
                      DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                      DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                    ],
                    onChanged: (v) => setState(() => _loanType = v!),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Terms',
              child: Column(
                children: [
                  TextFormField(
                    controller: _principal,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Principal Amount *', prefixText: '₹ '),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Required',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _rate,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Interest Rate (%) *'),
                    validator: (v) => double.tryParse(v ?? '') != null ? null : 'Required',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tenure,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Tenure *'),
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Required',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _tenureType,
                          decoration: const InputDecoration(labelText: 'Unit'),
                          items: const [
                            DropdownMenuItem(value: 'DAYS', child: Text('Days')),
                            DropdownMenuItem(value: 'WEEKS', child: Text('Weeks')),
                            DropdownMenuItem(value: 'MONTHS', child: Text('Months')),
                            DropdownMenuItem(value: 'YEARS', child: Text('Years')),
                          ],
                          onChanged: (v) => setState(() => _tenureType = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Start Date: ${formatDate(_startDate)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        initialDate: _startDate,
                      );
                      if (d != null) setState(() => _startDate = d);
                    },
                  ),
                  TextFormField(controller: _fee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Processing Fee')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _lateFee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Late Fee Per Day')),
                ],
              ),
            ),
            if (_loanType == 'GOLD')
              SectionCard(
                title: 'Gold Details',
                child: Column(
                  children: [
                    TextFormField(controller: _goldWeight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (grams) *')),
                    const SizedBox(height: 10),
                    TextFormField(controller: _goldPurity, decoration: const InputDecoration(labelText: 'Purity (e.g. 22K) *')),
                  ],
                ),
              ),
            if (_loanType == 'VEHICLE')
              SectionCard(
                title: 'Vehicle Details',
                child: Column(
                  children: [
                    TextFormField(controller: _vehType, decoration: const InputDecoration(labelText: 'Type *')),
                    const SizedBox(height: 10),
                    TextFormField(controller: _vehMake, decoration: const InputDecoration(labelText: 'Make *')),
                    const SizedBox(height: 10),
                    TextFormField(controller: _vehModel, decoration: const InputDecoration(labelText: 'Model *')),
                  ],
                ),
              ),
            if (_loanType == 'PROPERTY')
              SectionCard(
                title: 'Property Details',
                child: Column(
                  children: [
                    TextFormField(controller: _propType, decoration: const InputDecoration(labelText: 'Type *')),
                    const SizedBox(height: 10),
                    TextFormField(controller: _propAddr, maxLines: 2, decoration: const InputDecoration(labelText: 'Address *')),
                    const SizedBox(height: 10),
                    TextFormField(controller: _propValue, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Value *')),
                  ],
                ),
              ),
            SectionCard(
              title: 'Guarantor (optional)',
              child: Column(
                children: [
                  TextFormField(controller: _guarantorName, decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _guarantorPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                ],
              ),
            ),
            SectionCard(
              title: 'Notes',
              child: TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(hintText: 'Additional notes')),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Loan'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _PickerSheet<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function(String search) fetcher;
  final String Function(T) labelBuilder;
  final String Function(T) subtitleBuilder;
  const _PickerSheet({required this.title, required this.fetcher, required this.labelBuilder, required this.subtitleBuilder});
  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final _search = TextEditingController();
  Future<List<T>>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher('');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search...'),
              onSubmitted: (v) => setState(() => _future = widget.fetcher(v)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<T>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                if (snap.hasError) return ErrorView(message: snap.error.toString());
                final items = snap.data ?? [];
                if (items.isEmpty) return const EmptyView(message: 'No results');
                return ListView.builder(
                  controller: ctrl,
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => ListTile(
                    title: Text(widget.labelBuilder(items[i])),
                    subtitle: Text(widget.subtitleBuilder(items[i])),
                    onTap: () => Navigator.pop(context, items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
