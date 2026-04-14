import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/investor_repo.dart';
import '../../app_shell.dart';

class InvestorListPage extends ConsumerStatefulWidget {
  const InvestorListPage({super.key});
  @override
  ConsumerState<InvestorListPage> createState() => _InvestorListPageState();
}

class _InvestorListPageState extends ConsumerState<InvestorListPage> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() { super.initState(); _load(); }
  void _load() { _future = ref.read(investorRepoProvider).list(); setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(authProvider).hasPermission('investors.create');
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Investors'),
        leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
        actions: [
          IconButton(icon: const Icon(Icons.add_card_outlined), tooltip: 'New Investment', onPressed: () => context.push('/investments/new')),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(onPressed: () => context.push('/investors/new'), icon: const Icon(Icons.add), label: const Text('New'))
          : null,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
          if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _load);
          final items = extractList(snap.data?['data'] ?? snap.data);
          if (items.isEmpty) return const EmptyView(message: 'No investors', icon: Icons.trending_up);
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final inv = Map<String, dynamic>.from(items[i] as Map);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    onTap: () => context.push('/investors/${inv['id']}'),
                    leading: Avatar(name: inv['name']?.toString() ?? ''),
                    title: Text(inv['name']?.toString() ?? ''),
                    subtitle: Text(inv['phone']?.toString() ?? ''),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatCurrency(inv['totalInvested']), style: const TextStyle(fontWeight: FontWeight.w600)),
                        StatusChip(label: inv['isActive'] == true ? 'ACTIVE' : 'INACTIVE', color: inv['isActive'] == true ? AppColors.accent : AppColors.textSecondary),
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
