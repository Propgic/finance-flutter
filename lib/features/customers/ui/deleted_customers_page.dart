import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/customer_repo.dart';

class DeletedCustomersPage extends ConsumerStatefulWidget {
  const DeletedCustomersPage({super.key});
  @override
  ConsumerState<DeletedCustomersPage> createState() => _DeletedCustomersPageState();
}

class _DeletedCustomersPageState extends ConsumerState<DeletedCustomersPage> {
  Future<List<dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(customerRepoProvider).listDeleted();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deleted Customers')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
          if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _load);
          final items = snap.data ?? [];
          if (items.isEmpty) return const EmptyView(message: 'No deleted customers', icon: Icons.delete_outline);
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final c = Map<String, dynamic>.from(items[i] as Map);
              final name = '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: Avatar(url: c['photo']?.toString(), name: name),
                  title: Text(name),
                  subtitle: Text('${c['customerId'] ?? ''} • Deleted ${formatDate(c['deletedAt'])}'),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore'),
                    onPressed: () async {
                      final ok = await confirmDialog(context, message: 'Restore $name?');
                      if (!ok) return;
                      try {
                        await ref.read(customerRepoProvider).restore(c['id'].toString());
                        showToast('Customer restored');
                        _load();
                      } on ApiException catch (e) {
                        showToast(e.message, error: true);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
