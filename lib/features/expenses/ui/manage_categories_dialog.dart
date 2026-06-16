import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/expense_repo.dart';

/// ORG_ADMIN-only management of expense categories.
///
/// Categories are objects `{key, label, color}` (matches web + backend).
/// SALARY is a locked system category that cannot be removed or renamed.
/// Saves via `PUT /expenses/categories` with body `{categories: [...]}`.
Future<bool> showManageCategoriesDialog(BuildContext context) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => const _ManageCategoriesDialog(),
  );
  return changed ?? false;
}

class _ManageCategoriesDialog extends ConsumerStatefulWidget {
  const _ManageCategoriesDialog();
  @override
  ConsumerState<_ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _CategoryEntry {
  final TextEditingController keyCtrl;
  final TextEditingController label;
  String color;
  String get key => keyCtrl.text;
  bool get isSalary => key == 'SALARY';
  _CategoryEntry({required String key, required String label, required this.color})
      : keyCtrl = TextEditingController(text: key),
        label = TextEditingController(text: label);
  void dispose() {
    keyCtrl.dispose();
    label.dispose();
  }
}

class _ManageCategoriesDialogState extends ConsumerState<_ManageCategoriesDialog> {
  static const _colors = ['blue', 'red', 'green', 'yellow', 'purple', 'indigo', 'pink', 'gray', 'amber', 'teal'];

  List<_CategoryEntry>? _entries;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final cats = await ref.read(expenseRepoProvider).categories();
      setState(() {
        _entries = cats.map((c) {
          final m = c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{'key': c.toString(), 'label': c.toString(), 'color': 'gray'};
          return _CategoryEntry(
            key: m['key']?.toString() ?? '',
            label: m['label']?.toString() ?? '',
            color: m['color']?.toString() ?? 'gray',
          );
        }).toList();
      });
    } on ApiException catch (e) {
      setState(() => _loadError = e.message);
    } catch (e) {
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final e in _entries ?? const <_CategoryEntry>[]) {
      e.dispose();
    }
    super.dispose();
  }

  void _add() {
    setState(() {
      _entries!.add(_CategoryEntry(key: 'CUSTOM_${DateTime.now().millisecondsSinceEpoch}', label: '', color: 'gray'));
    });
  }

  Future<void> _save() async {
    final entries = _entries!;
    for (final e in entries) {
      if (e.keyCtrl.text.trim().isEmpty || e.label.text.trim().isEmpty) {
        return showToast('All categories must have a key and label', error: true);
      }
    }
    final keys = entries.map((e) => e.keyCtrl.text.trim()).toList();
    if (keys.toSet().length != keys.length) {
      return showToast('Duplicate category keys are not allowed', error: true);
    }
    if (!keys.contains('SALARY')) {
      return showToast('Salary category cannot be removed', error: true);
    }
    setState(() => _saving = true);
    try {
      final payload = entries
          .map((e) => {'key': e.keyCtrl.text.trim(), 'label': e.label.text.trim(), 'color': e.color})
          .toList();
      await ref.read(expenseRepoProvider).updateCategories(payload);
      showToast('Expense categories saved');
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
      title: Row(
        children: [
          const Expanded(child: Text('Expense Categories')),
          if (!_loading && _loadError == null)
            TextButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(height: 120, child: LoadingView())
            : _loadError != null
                ? SizedBox(height: 120, child: ErrorView(message: _loadError!, onRetry: _load))
                : _entries!.isEmpty
                    ? const SizedBox(height: 120, child: EmptyView(message: 'No categories. Tap Add to create one.', icon: Icons.category_outlined))
                    : ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _entries!.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _row(_entries![i]),
                        ),
                      ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saving || _loading || _loadError != null ? null : _save, child: Text(_saving ? 'Saving...' : 'Save')),
      ],
    );
  }

  Widget _row(_CategoryEntry e) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: e.isSalary ? AppColors.info.withValues(alpha: 0.06) : null,
        border: Border.all(color: e.isSalary ? AppColors.info.withValues(alpha: 0.3) : AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: e.label,
                  enabled: !e.isSalary,
                  decoration: const InputDecoration(labelText: 'Label', isDense: true),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: e.keyCtrl,
                        enabled: !e.isSalary,
                        decoration: const InputDecoration(labelText: 'Key', isDense: true, hintText: 'e.g. FUEL'),
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (v) {
                          final clean = v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_]'), '');
                          if (clean != v) {
                            e.keyCtrl.value = TextEditingValue(text: clean, selection: TextSelection.collapsed(offset: clean.length));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _colors.contains(e.color) ? e.color : 'gray',
                        decoration: const InputDecoration(labelText: 'Color', isDense: true),
                        items: _colors.map((c) => DropdownMenuItem(value: c, child: Text(titleCaseColor(c)))).toList(),
                        onChanged: (v) => setState(() => e.color = v ?? 'gray'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          e.isSalary
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: Tooltip(message: 'Salary is a system category', child: Icon(Icons.lock_outline, size: 18, color: AppColors.info)),
                )
              : IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  tooltip: 'Remove',
                  onPressed: () => setState(() => _entries!.remove(e)),
                ),
        ],
      ),
    );
  }
}

String titleCaseColor(String c) => c.isEmpty ? c : c[0].toUpperCase() + c.substring(1);
