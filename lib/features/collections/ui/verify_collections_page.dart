import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/collection_repo.dart';

final pendingVerificationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.read(collectionRepoProvider).pendingVerifications();
});

class VerifyCollectionsPage extends ConsumerWidget {
  const VerifyCollectionsPage({super.key});

  Future<void> _verify(BuildContext context, WidgetRef ref, String id, bool approve) async {
    try {
      await ref.read(collectionRepoProvider).verify(id, approve: approve);
      ref.invalidate(pendingVerificationsProvider);
      showToast(approve ? 'Verified' : 'Rejected');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(pendingVerificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Collections')),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'Nothing pending', icon: Icons.check_circle_outline);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingVerificationsProvider),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final c = Map<String, dynamic>.from(items[i] as Map);
                final cust = Map<String, dynamic>.from(c['customer'] ?? {});
                final loan = Map<String, dynamic>.from(c['loan'] ?? {});
                final collector = Map<String, dynamic>.from(c['collectedBy'] ?? {});
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim(),
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(loan['loanNumber']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Text(formatCurrency(c['amount']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Collected by ${collector['name'] ?? ''} • ${formatDateTime(c['collectedAt'])}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _verify(context, ref, c['id'].toString(), false),
                                icon: const Icon(Icons.close, color: AppColors.danger),
                                label: const Text('Reject', style: TextStyle(color: AppColors.danger)),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _verify(context, ref, c['id'].toString(), true),
                                icon: const Icon(Icons.check),
                                label: const Text('Verify'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
