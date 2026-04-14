import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/customer_repo.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  final String? id;
  const CustomerFormPage({super.key, this.id});
  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{
    for (final k in [
      'firstName','lastName','fatherName','phone','alternatePhone','email','aadhaarNumber','panNumber',
      'address','city','district','state','pincode','occupation','monthlyIncome',
      'bankName','accountNumber','ifscCode','nomineeName','nomineeRelation','nomineePhone',
    ]) k: TextEditingController(),
  };
  String _gender = 'MALE';
  DateTime? _dob;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await ref.read(customerRepoProvider).get(widget.id!);
      _c.forEach((k, ctrl) => ctrl.text = c[k]?.toString() ?? '');
      _gender = c['gender']?.toString() ?? 'MALE';
      _dob = tryParseDate(c['dateOfBirth']?.toString());
    } catch (e) {
      showToast('Failed to load: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'gender': _gender,
        if (_dob != null) 'dateOfBirth': formatInputDate(_dob!),
      };
      _c.forEach((k, ctrl) {
        final v = ctrl.text.trim();
        if (v.isNotEmpty) {
          if (k == 'monthlyIncome') {
            body[k] = double.tryParse(v);
          } else {
            body[k] = v;
          }
        }
      });
      if (widget.id == null) {
        await ref.read(customerRepoProvider).create(body);
        showToast('Customer created');
      } else {
        await ref.read(customerRepoProvider).update(widget.id!, body);
        showToast('Customer updated');
      }
      if (mounted) context.go('/customers');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _text(String key, String label, {bool required = false, TextInputType? keyboard, int maxLines = 1, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _c[key],
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: required ? '$label *' : label),
        validator: validator ??
            (required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.id != null;
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('Customer')), body: const LoadingView());
    }
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Customer' : 'New Customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SectionCard(
              title: 'Personal',
              child: Column(
                children: [
                  _text('firstName', 'First Name', required: true),
                  _text('lastName', 'Last Name'),
                  _text('fatherName', 'Father Name', required: true),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(labelText: 'Gender *'),
                    items: const [
                      DropdownMenuItem(value: 'MALE', child: Text('Male')),
                      DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _gender = v ?? 'MALE'),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_dob == null ? 'Date of Birth' : formatDate(_dob)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now(),
                        initialDate: _dob ?? DateTime(2000),
                      );
                      if (d != null) setState(() => _dob = d);
                    },
                  ),
                  _text('phone', 'Phone', required: true, keyboard: TextInputType.phone, validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!RegExp(r'^\d{10}$').hasMatch(v)) return 'Must be 10 digits';
                    return null;
                  }),
                  _text('alternatePhone', 'Alt Phone', keyboard: TextInputType.phone),
                  _text('email', 'Email', keyboard: TextInputType.emailAddress),
                  _text('aadhaarNumber', 'Aadhaar', required: true, keyboard: TextInputType.number, validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!RegExp(r'^\d{12}$').hasMatch(v)) return 'Must be 12 digits';
                    return null;
                  }),
                  _text('panNumber', 'PAN (optional)'),
                ],
              ),
            ),
            SectionCard(
              title: 'Address',
              child: Column(
                children: [
                  _text('address', 'Address', required: true, maxLines: 2),
                  _text('city', 'City', required: true),
                  _text('district', 'District', required: true),
                  _text('state', 'State', required: true),
                  _text('pincode', 'Pincode', required: true, keyboard: TextInputType.number, validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'Must be 6 digits';
                    return null;
                  }),
                ],
              ),
            ),
            SectionCard(
              title: 'Employment & Banking',
              child: Column(
                children: [
                  _text('occupation', 'Occupation'),
                  _text('monthlyIncome', 'Monthly Income', keyboard: TextInputType.number),
                  _text('bankName', 'Bank Name'),
                  _text('accountNumber', 'Account Number'),
                  _text('ifscCode', 'IFSC'),
                ],
              ),
            ),
            SectionCard(
              title: 'Nominee',
              child: Column(
                children: [
                  _text('nomineeName', 'Nominee Name'),
                  _text('nomineeRelation', 'Relation'),
                  _text('nomineePhone', 'Nominee Phone', keyboard: TextInputType.phone),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(editing ? 'Update Customer' : 'Create Customer'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
