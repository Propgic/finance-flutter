import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';

final notificationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final d = await api.get('/notifications');
  if (d is List) return d;
  if (d is Map && d['data'] is List) return d['data'];
  if (d is Map && d['notifications'] is List) return d['notifications'];
  return const [];
});

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  Future<void> _markAllRead(BuildContext ctx, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).patch('/notifications/read-all');
      ref.invalidate(notificationsProvider);
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  Future<void> _markRead(WidgetRef ref, String id) async {
    try {
      await ref.read(apiClientProvider).patch('/notifications/$id/read');
      ref.invalidate(notificationsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: () => _markAllRead(context, ref), child: const Text('Mark all read')),
        ],
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(notificationsProvider)),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No notifications', icon: Icons.notifications_none);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final n = Map<String, dynamic>.from(items[i] as Map);
                final read = n['isRead'] == true;
                return Card(
                  color: read ? null : AppColors.primary.withValues(alpha: 0.04),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (read ? AppColors.textMuted : AppColors.primary).withValues(alpha: 0.15),
                      child: Icon(Icons.notifications_outlined, color: read ? AppColors.textMuted : AppColors.primary, size: 18),
                    ),
                    title: Text(n['title']?.toString() ?? '',
                        style: TextStyle(fontWeight: read ? FontWeight.w500 : FontWeight.w700)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n['message']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(formatDateTime(n['createdAt']),
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    ),
                    onTap: () { if (!read) _markRead(ref, n['id'].toString()); },
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
