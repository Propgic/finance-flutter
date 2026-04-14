import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/investor_repo.dart';

final investorDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(investorRepoProvider).get(id);
});
final investorInvestmentsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  return ref.read(investorRepoProvider).investments(id);
});

class InvestorDetailPage extends ConsumerWidget {
  final String id;
  const InvestorDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(investorDetailProvider(id));
    final investments = ref.watch(investorInvestmentsProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investor'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () => context.push('/investors/$id/edit')),
        ],
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (inv) => ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Avatar(name: inv['name']?.toString() ?? '', size: 64),
                    const SizedBox(height: 8),
                    Text(inv['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(inv['phone']?.toString() ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            SectionCard(
              title: 'Details',
              child: Column(
                children: [
                  KeyValueRow(label: 'Email', value: inv['email']?.toString() ?? '-'),
                  KeyValueRow(label: 'PAN', value: inv['panNumber']?.toString() ?? '-'),
                  KeyValueRow(label: 'Aadhaar', value: inv['aadhaarNumber']?.toString() ?? '-'),
                  KeyValueRow(label: 'Address', value: inv['address']?.toString() ?? '-'),
                  KeyValueRow(label: 'Share %', value: '${inv['sharePercentage'] ?? 0}%'),
                  KeyValueRow(label: 'Total Invested', value: formatCurrency(inv['totalInvested'])),
                  KeyValueRow(label: 'Active Investments', value: '${inv['activeInvestments'] ?? 0}'),
                ],
              ),
            ),
            SectionCard(
              title: 'Investments',
              actions: [
                TextButton(onPressed: () => context.push('/investments/new'), child: const Text('Add')),
              ],
              child: investments.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (items) {
                  if (items.isEmpty) return const EmptyView(message: 'No investments yet');
                  return Column(
                    children: items.map((i) {
                      final m = Map<String, dynamic>.from(i as Map);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => context.push('/investments/${m['id']}'),
                        title: Text(formatCurrency(m['amount'])),
                        subtitle: Text('${m['interestRate'] ?? 0}% • ${formatDate(m['startDate'])}'),
                        trailing: StatusChip(label: m['status']?.toString() ?? '', color: statusColor(m['status']?.toString())),
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
