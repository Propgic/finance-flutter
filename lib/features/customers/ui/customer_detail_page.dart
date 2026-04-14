import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/customer_repo.dart';

final customerDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(customerRepoProvider).get(id);
});

class CustomerDetailPage extends ConsumerStatefulWidget {
  final String id;
  const CustomerDetailPage({super.key, required this.id});
  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _toggleStatus() async {
    try {
      await ref.read(customerRepoProvider).toggleStatus(widget.id);
      ref.invalidate(customerDetailProvider(widget.id));
      showToast('Status updated');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, message: 'Delete this customer?', destructive: true, confirmText: 'Delete');
    if (!ok) return;
    try {
      await ref.read(customerRepoProvider).delete(widget.id);
      if (mounted) context.go('/customers');
      showToast('Customer deleted');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(customerDetailProvider(widget.id));
    final canEdit = ref.watch(authProvider).hasPermission('customers.edit');
    final isAdmin = ref.watch(authProvider).hasRole('ORG_ADMIN');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer'),
        actions: [
          if (canEdit)
            IconButton(icon: const Icon(Icons.edit), onPressed: () => context.push('/customers/${widget.id}/edit')),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'toggle') _toggleStatus();
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'toggle', child: Text('Toggle Active')),
              if (isAdmin) const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: 'Loans'),
            Tab(text: 'Savings'),
            Tab(text: 'Ledger'),
          ],
        ),
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(customerDetailProvider(widget.id))),
        data: (c) => TabBarView(
          controller: _tabs,
          children: [
            _infoTab(c),
            _loansTab(),
            _savingsTab(),
            _ledgerTab(),
          ],
        ),
      ),
    );
  }

  Widget _infoTab(Map<String, dynamic> c) {
    final fullName = '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Center(
          child: Column(
            children: [
              Avatar(url: c['photo']?.toString(), name: fullName, size: 72),
              const SizedBox(height: 10),
              Text(fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('${c['customerId'] ?? ''}', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              StatusChip(
                label: c['isActive'] == true ? 'ACTIVE' : 'INACTIVE',
                color: c['isActive'] == true ? AppColors.accent : AppColors.textSecondary,
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Personal',
          child: Column(
            children: [
              KeyValueRow(label: 'Father', value: c['fatherName']?.toString() ?? '-'),
              KeyValueRow(label: 'Gender', value: c['gender']?.toString() ?? '-'),
              KeyValueRow(label: 'Date of Birth', value: formatDate(c['dateOfBirth'])),
              KeyValueRow(label: 'Phone', value: c['phone']?.toString() ?? '-'),
              KeyValueRow(label: 'Alt Phone', value: c['alternatePhone']?.toString() ?? '-'),
              KeyValueRow(label: 'Email', value: c['email']?.toString() ?? '-'),
              KeyValueRow(label: 'Aadhaar', value: c['aadhaarNumber']?.toString() ?? '-'),
              KeyValueRow(label: 'PAN', value: c['panNumber']?.toString() ?? '-'),
            ],
          ),
        ),
        SectionCard(
          title: 'Address',
          child: Column(
            children: [
              KeyValueRow(label: 'Address', value: c['address']?.toString() ?? '-'),
              KeyValueRow(label: 'City', value: c['city']?.toString() ?? '-'),
              KeyValueRow(label: 'District', value: c['district']?.toString() ?? '-'),
              KeyValueRow(label: 'State', value: c['state']?.toString() ?? '-'),
              KeyValueRow(label: 'Pincode', value: c['pincode']?.toString() ?? '-'),
            ],
          ),
        ),
        SectionCard(
          title: 'Employment & Banking',
          child: Column(
            children: [
              KeyValueRow(label: 'Occupation', value: c['occupation']?.toString() ?? '-'),
              KeyValueRow(label: 'Monthly Income', value: formatCurrency(c['monthlyIncome'])),
              KeyValueRow(label: 'Bank', value: c['bankName']?.toString() ?? '-'),
              KeyValueRow(label: 'Account', value: c['accountNumber']?.toString() ?? '-'),
              KeyValueRow(label: 'IFSC', value: c['ifscCode']?.toString() ?? '-'),
            ],
          ),
        ),
        if (c['nomineeName'] != null)
          SectionCard(
            title: 'Nominee',
            child: Column(
              children: [
                KeyValueRow(label: 'Name', value: c['nomineeName']?.toString() ?? '-'),
                KeyValueRow(label: 'Relation', value: c['nomineeRelation']?.toString() ?? '-'),
                KeyValueRow(label: 'Phone', value: c['nomineePhone']?.toString() ?? '-'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _loansTab() {
    return FutureBuilder<List<dynamic>>(
      future: ref.read(customerRepoProvider).loans(widget.id),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
        if (snap.hasError) return ErrorView(message: snap.error.toString());
        final loans = snap.data ?? [];
        if (loans.isEmpty) return const EmptyView(message: 'No loans yet', icon: Icons.request_quote_outlined);
        return ListView.builder(
          itemCount: loans.length,
          itemBuilder: (ctx, i) {
            final l = Map<String, dynamic>.from(loans[i] as Map);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                onTap: () => context.push('/loans/${l['id']}'),
                title: Text(l['loanNumber']?.toString() ?? 'Loan'),
                subtitle: Text('${l['loanType'] ?? ''} • ${formatCurrency(l['principalAmount'])}'),
                trailing: StatusChip(label: l['status']?.toString() ?? '-', color: statusColor(l['status']?.toString())),
              ),
            );
          },
        );
      },
    );
  }

  Widget _savingsTab() {
    return FutureBuilder<List<dynamic>>(
      future: ref.read(customerRepoProvider).savings(widget.id),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
        if (snap.hasError) return ErrorView(message: snap.error.toString());
        final items = snap.data ?? [];
        if (items.isEmpty) return const EmptyView(message: 'No savings accounts', icon: Icons.savings_outlined);
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final s = Map<String, dynamic>.from(items[i] as Map);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                onTap: () => context.push('/savings/${s['id']}'),
                title: Text(s['accountNumber']?.toString() ?? 'Account'),
                subtitle: Text(s['accountType']?.toString() ?? ''),
                trailing: Text(formatCurrency(s['balance']), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _ledgerTab() {
    return FutureBuilder<List<dynamic>>(
      future: ref.read(customerRepoProvider).ledger(widget.id),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
        if (snap.hasError) return ErrorView(message: snap.error.toString());
        final entries = snap.data ?? const [];
        if (entries.isEmpty) return const EmptyView(message: 'No ledger entries');
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (ctx, i) {
            final m = Map<String, dynamic>.from(entries[i] as Map);
            final type = m['type']?.toString() ?? '';
            final isDebit = type == 'WITHDRAWAL';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Icon(
                  isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isDebit ? AppColors.danger : AppColors.accent,
                ),
                title: Text(type),
                subtitle: Text('${m['ref'] ?? ''} • ${formatDateTime(m['date'])}'),
                trailing: Text(
                  formatCurrency(m['amount']),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDebit ? AppColors.danger : AppColors.accent,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
