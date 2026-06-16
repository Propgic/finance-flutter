import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../team/data/team_repo.dart';
import '../data/loan_repo.dart';

/// Bulk "Assign Loan" screen — pick an employee, then tick the active loans that
/// should be theirs. Loans held by a different agent are locked: to move one, that
/// agent must release it first (open them, untick, Save), then assign it here.
class AssignLoanPage extends ConsumerStatefulWidget {
  const AssignLoanPage({super.key});
  @override
  ConsumerState<AssignLoanPage> createState() => _AssignLoanPageState();
}

class _AssignLoanPageState extends ConsumerState<AssignLoanPage> {
  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _error;
  String? _employeeId;
  final Set<String> _checked = {};
  String _search = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ref.read(teamRepoProvider).list(limit: 500),
        ref.read(loanRepoProvider).assignable(),
      ]);
      final members = (results[0])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => m['isActive'] == true)
          .toList();
      final loans = (results[1])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _employees = members;
        _loans = loans;
        _loading = false;
        _syncChecked();
      });
    } on ApiException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // Reset the ticks to exactly the selected employee's current basket.
  void _syncChecked() {
    _checked.clear();
    if (_employeeId == null) return;
    for (final l in _loans) {
      if (_assigneeId(l) == _employeeId) _checked.add(l['id'].toString());
    }
  }

  String? _assigneeId(Map<String, dynamic> l) {
    final a = l['assignedTo'];
    return a is Map ? a['id']?.toString() : null;
  }

  String? _assigneeName(Map<String, dynamic> l) {
    final a = l['assignedTo'];
    return a is Map ? a['name']?.toString() : null;
  }

  bool _locked(Map<String, dynamic> l) =>
      _assigneeId(l) != null && _assigneeId(l) != _employeeId;

  List<Map<String, dynamic>> get _filtered {
    if (_search.trim().isEmpty) return _loans;
    final q = _search.trim().toLowerCase();
    return _loans.where((l) {
      final name = (l['customerName'] ?? '').toString().toLowerCase();
      final num = (l['loanNumber'] ?? '').toString().toLowerCase();
      final agent = (_assigneeName(l) ?? '').toLowerCase();
      return name.contains(q) || num.contains(q) || agent.contains(q);
    }).toList();
  }

  int get _unassignedCount => _loans.where((l) => _assigneeId(l) == null).length;
  int get _additions =>
      _loans.where((l) => _checked.contains(l['id'].toString()) && _assigneeId(l) == null).length;
  List<Map<String, dynamic>> get _releases => _loans
      .where((l) => _assigneeId(l) == _employeeId && !_checked.contains(l['id'].toString()))
      .toList();

  void _toggle(String id) => setState(() {
        if (!_checked.remove(id)) _checked.add(id);
      });

  void _selectAllUnassigned() => setState(() {
        for (final l in _loans) {
          if (_assigneeId(l) == null) _checked.add(l['id'].toString());
        }
      });

  String get _employeeName =>
      _employees.firstWhere((e) => e['id'].toString() == _employeeId,
          orElse: () => {'name': ''})['name']?.toString() ?? '';

  Future<void> _save() async {
    if (_employeeId == null) { showToast('Select an employee first', error: true); return; }
    final releases = _releases.length;
    if (releases > 0) {
      final ok = await confirmDialog(
        context,
        title: 'Release loans?',
        message: '$releases loan${releases == 1 ? '' : 's'} will be removed from $_employeeName and left unassigned. Continue?',
        confirmText: 'Save',
      );
      if (!ok) return;
    }
    setState(() => _saving = true);
    try {
      final msg = await ref.read(loanRepoProvider).assignBasket(_employeeId!, _checked.toList());
      showToast(msg);
      await _load();
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Loans')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
      bottomNavigationBar: _employeeId == null ? null : _saveBar(),
    );
  }

  Widget _buildBody() {
    final filtered = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _employeeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Employee Name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                hint: const Text('Select an employee'),
                items: _employees
                    .map((e) => DropdownMenuItem(
                          value: e['id'].toString(),
                          child: Text(e['name']?.toString() ?? '-', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() { _employeeId = v; _syncChecked(); }),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Loan #, customer, current officer...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              if (_employeeId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Loans assigned to another agent are locked. To move one, open that agent, untick it and Save first.',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_employeeId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Agent Collection Report',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (_unassignedCount > 0)
                  TextButton(
                    onPressed: _selectAllUnassigned,
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 0)),
                    child: Text('Select all unassigned ($_unassignedCount)', style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _employeeId == null
              ? const EmptyView(message: 'Select an employee to start assigning loans.')
              : filtered.isEmpty
                  ? const EmptyView(message: 'No matching loans.')
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _loanRow(filtered[i]),
                    ),
        ),
      ],
    );
  }

  Widget _loanRow(Map<String, dynamic> l) {
    final id = l['id'].toString();
    final locked = _locked(l);
    final aName = _assigneeName(l);
    final aId = _assigneeId(l);
    final Color tagColor = aName == null
        ? AppColors.textMuted
        : (aId == _employeeId ? AppColors.accent : AppColors.danger);
    return CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      value: _checked.contains(id),
      onChanged: locked ? null : (_) => _toggle(id),
      title: Text(
        '${l['loanNumber']}.${l['customerName']}',
        style: TextStyle(
          fontSize: 14,
          color: locked ? AppColors.textMuted : AppColors.textPrimary,
        ),
      ),
      subtitle: Row(
        children: [
          Text(formatCurrency(l['balance']),
              style: TextStyle(fontSize: 12, color: locked ? AppColors.textMuted : AppColors.accent, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              aName == null ? '(unassigned)' : '($aName)',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: tagColor),
            ),
          ),
          if (locked) const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.lock_outline, size: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _saveBar() {
    final releases = _releases.length;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${_checked.length} for $_employeeName',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '$_additions new${releases > 0 ? '  ·  $releases to release' : ''}',
                    style: TextStyle(fontSize: 12, color: releases > 0 ? AppColors.warning : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
