import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/common.dart';
import '../data/loan_group_repo.dart';

class LoanGroupFormPage extends ConsumerStatefulWidget {
  final String? id;
  const LoanGroupFormPage({super.key, this.id});
  @override
  ConsumerState<LoanGroupFormPage> createState() => _LoanGroupFormPageState();
}

class _LoanGroupFormPageState extends ConsumerState<LoanGroupFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _leaderName = TextEditingController();
  final _leaderPhone = TextEditingController();
  final _meetingDay = TextEditingController();
  final _meetingTime = TextEditingController();
  final _meetingPlace = TextEditingController();
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
      final g = await ref.read(loanGroupRepoProvider).get(widget.id!);
      _name.text = g['name']?.toString() ?? '';
      _desc.text = g['description']?.toString() ?? '';
      _leaderName.text = g['leaderName']?.toString() ?? '';
      _leaderPhone.text = g['leaderPhone']?.toString() ?? '';
      _meetingDay.text = g['meetingDay']?.toString() ?? '';
      _meetingTime.text = g['meetingTime']?.toString() ?? '';
      _meetingPlace.text = g['meetingPlace']?.toString() ?? '';
    } catch (e) {
      showToast('Load failed: $e', error: true);
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
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        if (_leaderName.text.trim().isNotEmpty) 'leaderName': _leaderName.text.trim(),
        if (_leaderPhone.text.trim().isNotEmpty) 'leaderPhone': _leaderPhone.text.trim(),
        if (_meetingDay.text.trim().isNotEmpty) 'meetingDay': _meetingDay.text.trim(),
        if (_meetingTime.text.trim().isNotEmpty) 'meetingTime': _meetingTime.text.trim(),
        if (_meetingPlace.text.trim().isNotEmpty) 'meetingPlace': _meetingPlace.text.trim(),
      };
      final repo = ref.read(loanGroupRepoProvider);
      if (widget.id == null) {
        await repo.create(body);
        showToast('Group created');
      } else {
        await repo.update(widget.id!, body);
        showToast('Group updated');
      }
      if (mounted) context.go('/loan-groups');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(title: const Text('Group')), body: const LoadingView());
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'New Group' : 'Edit Group')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SectionCard(
              title: 'Group Details',
              child: Column(
                children: [
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name *'), validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                  const SizedBox(height: 10),
                  TextFormField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _leaderName, decoration: const InputDecoration(labelText: 'Leader Name')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _leaderPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Leader Phone')),
                ],
              ),
            ),
            SectionCard(
              title: 'Meeting',
              child: Column(
                children: [
                  TextFormField(controller: _meetingDay, decoration: const InputDecoration(labelText: 'Meeting Day (e.g. Monday)')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _meetingTime, decoration: const InputDecoration(labelText: 'Meeting Time')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _meetingPlace, decoration: const InputDecoration(labelText: 'Meeting Place')),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : (widget.id == null ? 'Create Group' : 'Update Group')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
