import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';

final permDefinitionsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final d = await api.get('/permissions/definitions');
  return Map<String, dynamic>.from(d as Map);
});

final rolePermissionsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final d = await api.get('/permissions');
  return Map<String, dynamic>.from(d as Map);
});

class RolesPermissionsPage extends ConsumerStatefulWidget {
  const RolesPermissionsPage({super.key});
  @override
  ConsumerState<RolesPermissionsPage> createState() => _RolesPermissionsPageState();
}

class _RolesPermissionsPageState extends ConsumerState<RolesPermissionsPage> {
  String? _activeRole;
  Map<String, Set<String>> _perms = {};
  bool _dirty = false;
  bool _saving = false;

  void _hydrate(Map<String, dynamic> data) {
    if (_perms.isNotEmpty) return;
    final roles = Map<String, dynamic>.from(data['rolePermissions'] ?? data);
    roles.forEach((role, perms) {
      _perms[role] = (perms as List).map((e) => e.toString()).toSet();
    });
    _activeRole ??= _perms.keys.where((r) => r != 'ORG_ADMIN').firstOrNull ?? _perms.keys.firstOrNull;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{};
      _perms.forEach((role, set) {
        if (role != 'ORG_ADMIN') body[role] = set.toList();
      });
      await api.put('/permissions', data: {'rolePermissions': body});
      showToast('Permissions saved');
      setState(() => _dirty = false);
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    final ok = await confirmDialog(context, message: 'Reset all role permissions to defaults?', destructive: true, confirmText: 'Reset');
    if (!ok) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/permissions/reset');
      setState(() {
        _perms = {};
        _dirty = false;
      });
      ref.invalidate(rolePermissionsProvider);
      showToast('Reset to defaults');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defs = ref.watch(permDefinitionsProvider);
    final rolePerms = ref.watch(rolePermissionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles & Permissions'),
        actions: [
          TextButton(onPressed: _reset, child: const Text('Reset')),
          TextButton(
            onPressed: _dirty && !_saving ? _save : null,
            child: Text(_saving ? '...' : 'Save'),
          ),
        ],
      ),
      body: defs.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (defsData) => rolePerms.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: e.toString()),
          data: (rp) {
            _hydrate(rp);
            final roles = _perms.keys.where((r) => r != 'ORG_ADMIN').toList();
            final categories = Map<String, dynamic>.from(defsData['categories'] ?? defsData);
            return Column(
              children: [
                Container(
                  height: 52,
                  color: Colors.white,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: roles.map((r) {
                      final sel = r == _activeRole;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: ChoiceChip(
                          label: Text(r),
                          selected: sel,
                          onSelected: (_) => setState(() => _activeRole = r),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _activeRole == null
                      ? const EmptyView(message: 'No roles available')
                      : ListView(
                          children: categories.entries.map((e) {
                            final perms = (e.value as List).map((p) => Map<String, dynamic>.from(p as Map)).toList();
                            return ExpansionTile(
                              initiallyExpanded: true,
                              title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                              children: perms.map((p) {
                                final key = p['key'].toString();
                                final label = p['label']?.toString() ?? key;
                                final selected = _perms[_activeRole]?.contains(key) ?? false;
                                return CheckboxListTile(
                                  title: Text(label),
                                  subtitle: p['description'] != null ? Text(p['description'].toString(), style: const TextStyle(fontSize: 12)) : null,
                                  value: selected,
                                  dense: true,
                                  onChanged: (v) {
                                    setState(() {
                                      final set = _perms[_activeRole!] ??= <String>{};
                                      if (v == true) {
                                        set.add(key);
                                      } else {
                                        set.remove(key);
                                      }
                                      _dirty = true;
                                    });
                                  },
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
