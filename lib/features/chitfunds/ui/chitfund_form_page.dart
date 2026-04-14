import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/chitfund_repo.dart';

class ChitfundFormPage extends ConsumerStatefulWidget {
  const ChitfundFormPage({super.key});
  @override
  ConsumerState<ChitfundFormPage> createState() => _ChitfundFormPageState();
}

class _ChitfundFormPageState extends ConsumerState<ChitfundFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _totalAmount = TextEditingController();
  final _installment = TextEditingController();
  final _members = TextEditingController();
  final _duration = TextEditingController();
  final _commission = TextEditingController(text: '5');
  DateTime _start = DateTime.now();
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(chitfundRepoProvider).create({
        'name': _name.text.trim(),
        'totalAmount': double.tryParse(_totalAmount.text),
        'monthlyInstallment': double.tryParse(_installment.text),
        'totalMembers': int.tryParse(_members.text),
        'durationMonths': int.tryParse(_duration.text),
        'startDate': formatInputDate(_start),
        'commission': double.tryParse(_commission.text) ?? 5,
      });
      showToast('Chitfund created');
      if (mounted) context.go('/chitfunds');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Chitfund')),
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
                  TextFormField(controller: _totalAmount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Amount *'), validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Required'),
                  const SizedBox(height: 10),
                  TextFormField(controller: _installment, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly Installment *'), validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Required'),
                  const SizedBox(height: 10),
                  TextFormField(controller: _members, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Members *'), validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Required'),
                  const SizedBox(height: 10),
                  TextFormField(controller: _duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (months) *'), validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Required'),
                  const SizedBox(height: 10),
                  TextFormField(controller: _commission, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Commission (%)')),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Start Date: ${formatDate(_start)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: _start);
                      if (d != null) setState(() => _start = d);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Create Chitfund'))),
          ],
        ),
      ),
    );
  }
}
