import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/loan_group_repo.dart';
import '../../app_shell.dart';
import '../../../core/widgets/app_bottom_nav.dart';

class LoanGroupListPage extends ConsumerStatefulWidget {
  const LoanGroupListPage({super.key});
  @override
  ConsumerState<LoanGroupListPage> createState() => _LoanGroupListPageState();
}

class _LoanGroupListPageState extends ConsumerState<LoanGroupListPage> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(loanGroupRepoProvider).list();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(authProvider).hasPermission('loans.create');
    return Scaffold(
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Loan Groups'),
        leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(onPressed: () => context.push('/loan-groups/new'), icon: const Icon(Icons.add), label: const Text('New'))
          : null,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
          if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _load);
          final items = ((snap.data?['data']) as List?) ?? [];
          if (items.isEmpty) return const EmptyView(message: 'No loan groups', icon: Icons.groups_outlined);
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final g = Map<String, dynamic>.from(items[i] as Map);
                final counts = Map<String, dynamic>.from(g['_count'] ?? {});
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    onTap: () => context.push('/loan-groups/${g['id']}'),
                    title: Text(g['name']?.toString() ?? '-'),
                    subtitle: Text(g['leaderName']?.toString() ?? ''),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${counts['loans'] ?? 0} loans',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        StatusChip(
                          label: g['isActive'] == true ? 'ACTIVE' : 'INACTIVE',
                          color: g['isActive'] == true ? AppColors.accent : AppColors.textSecondary,
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
