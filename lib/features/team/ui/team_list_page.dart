import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/team_repo.dart';
import '../../app_shell.dart';

final teamListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async => ref.read(teamRepoProvider).list());

class TeamListPage extends ConsumerWidget {
  const TeamListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(teamListProvider);
    final canCreate = ref.watch(authProvider).hasPermission('team.create');
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Team'),
        leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(onPressed: () => context.push('/team/new'), icon: const Icon(Icons.add), label: const Text('Add'))
          : null,
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(teamListProvider)),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No team members', icon: Icons.group_outlined);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(teamListProvider),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final u = Map<String, dynamic>.from(items[i] as Map);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    onTap: () => context.push('/team/${u['id']}'),
                    leading: Avatar(url: u['photo']?.toString(), name: u['name']?.toString() ?? ''),
                    title: Text(u['name']?.toString() ?? ''),
                    subtitle: Text('${u['role'] ?? ''} • ${u['phone'] ?? ''}'),
                    trailing: StatusChip(
                      label: u['isActive'] == true ? 'ACTIVE' : 'INACTIVE',
                      color: u['isActive'] == true ? AppColors.accent : AppColors.textSecondary,
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
