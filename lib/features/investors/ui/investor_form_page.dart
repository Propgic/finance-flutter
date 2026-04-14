import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/common.dart';
import '../data/investor_repo.dart';

class InvestorFormPage extends ConsumerStatefulWidget {
  final String? id;
  const InvestorFormPage({super.key, this.id});
  @override
  ConsumerState<InvestorFormPage> createState() => _InvestorFormPageState();
}

class _InvestorFormPageState extends ConsumerState<InvestorFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pan = TextEditingController();
  final _aadhaar = TextEditingController();
  final _address = TextEditingController();
  final _share = TextEditingController();
  bool _saving = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final i = await ref.read(investorRepoProvider).get(widget.id!);
      _name.text = i['name']?.toString() ?? '';
      _phone.text = i['phone']?.toString() ?? '';
      _email.text = i['email']?.toString() ?? '';
      _pan.text = i['panNumber']?.toString() ?? '';
      _aadhaar.text = i['aadhaarNumber']?.toString() ?? '';
      _address.text = i['address']?.toString() ?? '';
      _share.text = i['sharePercentage']?.toString() ?? '';
    } catch (e) {
      showToast('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        if (_pan.text.trim().isNotEmpty) 'panNumber': _pan.text.trim(),
        if (_aadhaar.text.trim().isNotEmpty) 'aadhaarNumber': _aadhaar.text.trim(),
        if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
        if (_share.text.trim().isNotEmpty) 'sharePercentage': double.tryParse(_share.text),
      };
      final repo = ref.read(investorRepoProvider);
      if (widget.id == null) {
        await repo.create(body);
        showToast('Investor created');
      } else {
        await repo.update(widget.id!, body);
        showToast('Investor updated');
      }
      if (mounted) context.go('/investors');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(title: const Text('Investor')), body: const LoadingView());
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'New Investor' : 'Edit Investor')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SectionCard(
              title: 'Details',
              child: Column(
                children: [
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name *'), validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                  const SizedBox(height: 10),
                  TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone *'), validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                  const SizedBox(height: 10),
                  TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _pan, decoration: const InputDecoration(labelText: 'PAN')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _aadhaar, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Aadhaar')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _share, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Share Percentage')),
                ],
              ),
            ),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : (widget.id == null ? 'Create Investor' : 'Update Investor')))),
          ],
        ),
      ),
    );
  }
}
