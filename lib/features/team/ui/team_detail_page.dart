import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/team_repo.dart';

final teamDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(teamRepoProvider).get(id);
});

class TeamDetailPage extends ConsumerWidget {
  final String id;
  const TeamDetailPage({super.key, required this.id});

  Future<void> _toggle(WidgetRef ref) async {
    try { await ref.read(teamRepoProvider).toggleStatus(id); ref.invalidate(teamDetailProvider(id)); showToast('Status updated'); }
    on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'New Password')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset'))],
      ),
    );
    if (ok != true) return;
    try { await ref.read(teamRepoProvider).resetPassword(id, pw.text); showToast('Password reset'); }
    on ApiException catch (e) { showToast(e.message, error: true); }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(context, message: 'Delete member?', destructive: true, confirmText: 'Delete');
    if (!ok) return;
    try { await ref.read(teamRepoProvider).delete(id); if (context.mounted) context.go('/team'); showToast('Deleted'); }
    on ApiException catch (e) { showToast(e.message, error: true); }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(teamDetailProvider(id));
    final isAdmin = ref.watch(authProvider).hasRole('ORG_ADMIN');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Member'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () => context.push('/team/$id/edit')),
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'toggle') _toggle(ref);
                if (v == 'reset') _reset(context, ref);
                if (v == 'delete') _delete(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'toggle', child: Text('Toggle Active')),
                PopupMenuItem(value: 'reset', child: Text('Reset Password')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (u) => ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Avatar(url: u['photo']?.toString(), name: u['name']?.toString() ?? '', size: 64),
                    const SizedBox(height: 8),
                    Text(u['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(u['role']?.toString() ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    StatusChip(label: u['isActive'] == true ? 'ACTIVE' : 'INACTIVE', color: u['isActive'] == true ? AppColors.accent : AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            SectionCard(
              title: 'Contact',
              child: Column(
                children: [
                  KeyValueRow(label: 'Email', value: u['email']?.toString() ?? '-'),
                  KeyValueRow(label: 'Phone', value: u['phone']?.toString() ?? '-'),
                ],
              ),
            ),
            SectionCard(
              title: 'Compensation',
              child: Column(
                children: [
                  KeyValueRow(label: 'Mode', value: u['salaryMode']?.toString() ?? '-'),
                  KeyValueRow(label: 'Salary', value: formatCurrency(u['salary'])),
                  KeyValueRow(label: 'Salary Type', value: u['salaryType']?.toString() ?? '-'),
                  KeyValueRow(label: 'Commission', value: '${u['commissionPercentage'] ?? 0}%'),
                ],
              ),
            ),
            SectionCard(
              title: 'Bank',
              child: Column(
                children: [
                  KeyValueRow(label: 'Bank', value: u['bankName']?.toString() ?? '-'),
                  KeyValueRow(label: 'Account', value: u['bankAccountNumber']?.toString() ?? '-'),
                  KeyValueRow(label: 'IFSC', value: u['bankIfsc']?.toString() ?? '-'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
