import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/common.dart';
import '../../team/data/team_repo.dart';

/// Bottom-sheet picker of active field officers. Returns the chosen team-member
/// map ({id, name, phone, ...}), or null if dismissed. Shared by the chit create
/// form and the detail-page "assign officer" action. Mirrors the loan create flow.
Future<Map<String, dynamic>?> showFieldOfficerPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FieldOfficerSheet(ref: ref),
  );
}

class _FieldOfficerSheet extends StatefulWidget {
  final WidgetRef ref;
  const _FieldOfficerSheet({required this.ref});
  @override
  State<_FieldOfficerSheet> createState() => _FieldOfficerSheetState();
}

class _FieldOfficerSheetState extends State<_FieldOfficerSheet> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future = _fetch('');

  Future<List<Map<String, dynamic>>> _fetch(String search) async {
    final list = await widget.ref.read(teamRepoProvider).list(limit: 500);
    var users = list
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .where((u) => u['isActive'] == true && u['role'] == 'FIELD_OFFICER')
        .toList();
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      users = users.where((u) => (u['name']?.toString() ?? '').toLowerCase().contains(q)).toList();
    }
    return users;
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

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
                const Expanded(child: Text('Assign Field Officer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search...'),
              onSubmitted: (v) => setState(() => _future = _fetch(v)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                if (snap.hasError) return ErrorView(message: snap.error.toString());
                final items = snap.data ?? [];
                if (items.isEmpty) return const EmptyView(message: 'No field officers');
                return ListView.builder(
                  controller: ctrl,
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => ListTile(
                    title: Text(items[i]['name']?.toString() ?? ''),
                    subtitle: Text(items[i]['phone']?.toString() ?? ''),
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
