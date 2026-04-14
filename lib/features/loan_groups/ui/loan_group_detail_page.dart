import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/loan_group_repo.dart';

final groupDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(loanGroupRepoProvider).get(id);
});
final groupLoansProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  return ref.read(loanGroupRepoProvider).loans(id);
});

class LoanGroupDetailPage extends ConsumerWidget {
  final String id;
  const LoanGroupDetailPage({super.key, required this.id});

  Future<void> _toggle(WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(loanGroupRepoProvider).toggleStatus(id);
      ref.invalidate(groupDetailProvider(id));
      showToast('Status updated');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(groupDetailProvider(id));
    final loans = ref.watch(groupLoansProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Group'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () => context.push('/loan-groups/$id/edit')),
          IconButton(icon: const Icon(Icons.toggle_on), tooltip: 'Toggle Status', onPressed: () => _toggle(ref, context)),
        ],
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (g) => ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    StatusChip(label: g['isActive'] == true ? 'ACTIVE' : 'INACTIVE', color: g['isActive'] == true ? AppColors.accent : AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            SectionCard(
              title: 'Details',
              child: Column(
                children: [
                  KeyValueRow(label: 'Leader', value: g['leaderName']?.toString() ?? '-'),
                  KeyValueRow(label: 'Leader Phone', value: g['leaderPhone']?.toString() ?? '-'),
                  KeyValueRow(label: 'Meeting Day', value: g['meetingDay']?.toString() ?? '-'),
                  KeyValueRow(label: 'Meeting Time', value: g['meetingTime']?.toString() ?? '-'),
                  KeyValueRow(label: 'Meeting Place', value: g['meetingPlace']?.toString() ?? '-'),
                  if (g['description'] != null) KeyValueRow(label: 'Description', value: g['description'].toString()),
                ],
              ),
            ),
            SectionCard(
              title: 'Loans',
              child: loans.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (items) {
                  if (items.isEmpty) return const EmptyView(message: 'No loans assigned');
                  return Column(
                    children: items.map((l) {
                      final m = Map<String, dynamic>.from(l as Map);
                      final c = Map<String, dynamic>.from(m['customer'] ?? {});
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => context.push('/loans/${m['id']}'),
                        title: Text(m['loanNumber']?.toString() ?? ''),
                        subtitle: Text('${c['firstName'] ?? ''} ${c['lastName'] ?? ''} • ${formatCurrency(m['principalAmount'])}'),
                        trailing: StatusChip(label: m['status']?.toString() ?? '-', color: statusColor(m['status']?.toString())),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
