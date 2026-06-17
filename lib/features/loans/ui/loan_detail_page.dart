import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/loan_repo.dart';

final loanDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(loanRepoProvider).get(id);
});

final loanEmiProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  return ref.read(loanRepoProvider).emiSchedule(id);
});

class LoanDetailPage extends ConsumerStatefulWidget {
  final String id;
  const LoanDetailPage({super.key, required this.id});
  @override
  ConsumerState<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends ConsumerState<LoanDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _doAction(Future<void> Function() fn, String msg) async {
    try {
      await fn();
      ref.invalidate(loanDetailProvider(widget.id));
      showToast(msg);
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(loanDetailProvider(widget.id));
    final auth = ref.watch(authProvider);
    final isMgr = auth.hasRole('ORG_ADMIN') || auth.hasRole('MANAGER');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Details'), Tab(text: 'EMI Schedule')],
        ),
        actions: [
          data.maybeWhen(
            data: (l) => PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'disburse') {
                  final ok = await confirmDialog(context, message: 'Disburse this loan?');
                  if (ok) _doAction(() => ref.read(loanRepoProvider).disburse(widget.id), 'Loan disbursed');
                }
                if (v == 'reject') {
                  final ok = await confirmDialog(context, message: 'Reject this loan?', destructive: true, confirmText: 'Reject');
                  if (ok) _doAction(() => ref.read(loanRepoProvider).reject(widget.id), 'Loan rejected');
                }
                if (v == 'close') {
                  final ok = await confirmDialog(context, message: 'Close this loan?');
                  if (ok) _doAction(() => ref.read(loanRepoProvider).close(widget.id), 'Loan closed');
                }
                if (v == 'archive') {
                  final ok = await confirmDialog(context,
                      title: 'Archive Loan',
                      message: 'Archiving keeps the loan and its history but removes it from Outstanding, Overdue and Amount-in-Market totals. Nothing is marked paid or closed. You can unarchive it any time.',
                      confirmText: 'Archive');
                  if (ok) _doAction(() => ref.read(loanRepoProvider).archive(widget.id), 'Loan archived');
                }
                if (v == 'unarchive') {
                  final ok = await confirmDialog(context, message: 'Restore this loan to the active book?', confirmText: 'Unarchive');
                  if (ok) _doAction(() => ref.read(loanRepoProvider).unarchive(widget.id), 'Loan unarchived');
                }
              },
              itemBuilder: (_) => [
                if (isMgr && l['status'] == 'APPROVED') const PopupMenuItem(value: 'disburse', child: Text('Disburse')),
                if (isMgr && (l['status'] == 'PENDING' || l['status'] == 'APPROVED')) const PopupMenuItem(value: 'reject', child: Text('Reject')),
                if (isMgr && l['status'] == 'ACTIVE') const PopupMenuItem(value: 'close', child: Text('Close Loan')),
                if (isMgr && l['archivedAt'] == null && (l['status'] == 'ACTIVE' || l['status'] == 'DEFAULTED'))
                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
                if (isMgr && l['archivedAt'] != null)
                  const PopupMenuItem(value: 'unarchive', child: Text('Unarchive')),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(loanDetailProvider(widget.id))),
        data: (l) => TabBarView(
          controller: _tabs,
          children: [_infoTab(l), _emiTab()],
        ),
      ),
    );
  }

  Widget _infoTab(Map<String, dynamic> l) {
    final c = Map<String, dynamic>.from(l['customer'] ?? {});
    final assignee = Map<String, dynamic>.from(l['assignedTo'] ?? {});

    // Payment overview: group Overdue, Due Amount and Total Due Payable together so the
    // amount the customer must pay now is never confused with individual figures.
    final nextEmi = Map<String, dynamic>.from(l['nextEMI'] ?? {});
    final dueAmount = nextEmi.isEmpty
        ? 0
        : toNum(nextEmi['emiAmount']) + toNum(nextEmi['lateFee']) - toNum(nextEmi['paidAmount']);
    final overdueEmis = toNum(l['overdueEMIs']);
    final showOverdue = overdueEmis > 0;
    final showDue = l['status'] == 'ACTIVE' && dueAmount > 0;
    // Total Due Payable = currently due EMI + overdue amount (what's payable right now).
    final totalDuePayable = (showDue ? dueAmount : 0) + toNum(l['overdueAmount']);

    final overviewCards = <Widget>[];
    if (showOverdue) {
      overviewCards.add(_amountCard(
        label: 'Overdue',
        value: formatCurrency(l['overdueAmount']),
        color: AppColors.danger,
        subtitle: '${overdueEmis.toInt()} installment${overdueEmis > 1 ? 's' : ''} overdue',
      ));
    }
    if (showDue) {
      overviewCards.add(_amountCard(
        label: 'Due Amount',
        value: formatCurrency(dueAmount),
        color: AppColors.warning,
        subtitle: nextEmi.isEmpty ? null : 'EMI #${nextEmi['emiNumber']} · ${formatDate(nextEmi['dueDate'])}',
      ));
    }
    overviewCards.add(_amountCard(
      label: 'Total Due Payable',
      value: formatCurrency(totalDuePayable),
      color: AppColors.primary,
      subtitle: 'Currently due + overdue',
    ));

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (l['archivedAt'] != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.archive_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Archived — excluded from Outstanding, Overdue and Amount-in-Market totals.'
                    '${(l['archiveReason']?.toString().isNotEmpty ?? false) ? '\n${l['archiveReason']}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l['loanNumber']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                    StatusChip(label: l['status']?.toString() ?? '', color: statusColor(l['status']?.toString())),
                  ],
                ),
                const SizedBox(height: 4),
                Text(l['loanType']?.toString() ?? '', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < overviewCards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: overviewCards[i]),
                ],
              ],
            ),
          ),
        ),
        SectionCard(
          title: 'Customer',
          actions: [
            TextButton(
              onPressed: () => context.push('/customers/${c['id']}'),
              child: const Text('View'),
            ),
          ],
          child: Column(
            children: [
              KeyValueRow(label: 'Name', value: '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim()),
              KeyValueRow(label: 'Phone', value: c['phone']?.toString() ?? '-',
                  onTap: c['phone'] != null ? () => launchUrl(Uri.parse('tel:${c['phone']}')) : null),
            ],
          ),
        ),
        SectionCard(
          title: 'Loan Terms',
          child: Column(
            children: [
              KeyValueRow(label: 'Principal', value: formatCurrency(l['principalAmount'])),
              if (!loanFieldHidden(l, 'interestRate'))
                KeyValueRow(label: 'Interest Rate', value: '${l['interestRate'] ?? '-'}%'),
              KeyValueRow(label: 'Tenure', value: '${l['tenure'] ?? ''} ${l['tenureType'] ?? ''}'),
              KeyValueRow(label: 'EMI', value: formatCurrency(l['emiAmount'])),
              if (!loanFieldHidden(l, 'totalPayable'))
                KeyValueRow(label: 'Total Payable', value: formatCurrency(l['totalPayable'])),
              if (!loanFieldHidden(l, 'processingFee'))
                KeyValueRow(label: 'Processing Fee', value: formatCurrency(l['processingFee'])),
              KeyValueRow(label: 'Start Date', value: formatDate(l['startDate'])),
              KeyValueRow(label: 'Disbursed', value: formatDate(l['disbursedDate'])),
              KeyValueRow(label: 'Maturity', value: formatDate(l['maturityDate'])),
              if (l['disbursedDate'] != null)
                KeyValueRow(
                  label: 'Day',
                  value: () {
                    final disbursed = DateTime.tryParse(l['disbursedDate'].toString());
                    if (disbursed == null) return '-';
                    final days = DateTime.now().difference(disbursed).inDays + 1;
                    if (days <= 0) return '-';
                    if (l['loanType'] == 'WEEKLY') {
                      final weeks = days ~/ 7;
                      return weeks < 1 ? '-' : 'Week $weeks';
                    }
                    return 'Day $days';
                  }(),
                  valueColor: const Color(0xFFEA580C),
                ),
            ],
          ),
        ),
        SectionCard(
          title: 'Payment Status',
          child: Column(
            children: [
              KeyValueRow(label: 'Paid', value: formatCurrency(l['totalPaid']), valueColor: AppColors.accent),
              KeyValueRow(label: 'Outstanding', value: formatCurrency(l['outstanding']), valueColor: AppColors.danger),
            ],
          ),
        ),
        if (assignee.isNotEmpty)
          SectionCard(
            title: 'Assigned To',
            child: KeyValueRow(label: assignee['name']?.toString() ?? '-', value: assignee['role']?.toString() ?? '-'),
          ),
        if (l['notes'] != null && l['notes'].toString().isNotEmpty)
          SectionCard(title: 'Notes', child: Text(l['notes'].toString())),
        _documentsSection(l),
      ],
    );
  }

  bool _isImageDoc(String? url) {
    final u = (url ?? '').toLowerCase();
    return u.endsWith('.jpg') || u.endsWith('.jpeg') || u.endsWith('.png') || u.endsWith('.webp') || u.endsWith('.gif');
  }

  Widget _documentsSection(Map<String, dynamic> l) {
    final auth = ref.watch(authProvider);
    final canManage = auth.hasPermission('loans.create') || auth.hasRole('ORG_ADMIN') || auth.hasRole('MANAGER');
    final docs = (l['documents'] is List) ? List<dynamic>.from(l['documents'] as List) : const <dynamic>[];

    return SectionCard(
      title: 'Documents',
      actions: [
        if (canManage)
          TextButton.icon(
            onPressed: _addDocument,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Add'),
          ),
      ],
      child: docs.isEmpty
          ? const EmptyView(message: 'No documents uploaded', icon: Icons.description_outlined)
          : Column(
              children: [
                for (var i = 0; i < docs.length; i++) _documentTile(Map<String, dynamic>.from(docs[i] as Map), i, canManage),
              ],
            ),
    );
  }

  Widget _documentTile(Map<String, dynamic> doc, int index, bool canManage) {
    final url = (doc['url'] ?? doc['path'])?.toString();
    final title = (doc['title'] ?? doc['name'] ?? 'Document').toString();
    final isImage = _isImageDoc(url);
    final uploadedBy = doc['uploadedBy']?.toString();
    final uploadedAt = doc['uploadedAt'];
    final subtitleParts = <String>[
      if (uploadedBy != null && uploadedBy.isNotEmpty) 'By $uploadedBy',
      if (uploadedAt != null) formatDate(uploadedAt),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, color: AppColors.primary),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · '), style: const TextStyle(fontSize: 12)),
        onTap: () => _openDocument(url, isImage),
        trailing: canManage
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () => _deleteDocument(index, title),
              )
            : Icon(isImage ? Icons.open_in_full : Icons.open_in_new, size: 18, color: AppColors.textSecondary),
      ),
    );
  }

  void _openDocument(String? url, bool isImage) {
    if (url == null || url.isEmpty) return;
    if (isImage) {
      showImageViewer(context, url);
    } else {
      final full = resolveUrl(url);
      if (full != null) launchUrl(Uri.parse(full), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _addDocument() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final XFile? x;
    try {
      x = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    } catch (_) {
      showToast('Could not access ${source == ImageSource.camera ? 'camera' : 'gallery'}', error: true);
      return;
    }
    if (x == null) return;
    await _doAction(
      () => ref.read(loanRepoProvider).uploadDocuments(widget.id, [File(x!.path)]),
      'Document uploaded',
    );
  }

  Future<void> _deleteDocument(int index, String title) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete Document',
      message: 'Delete "$title"?',
      confirmText: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await _doAction(() => ref.read(loanRepoProvider).deleteDocument(widget.id, index), 'Document deleted');
  }

  Widget _amountCard({required String label, required String value, required Color color, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emiTab() {
    final emis = ref.watch(loanEmiProvider(widget.id));
    return emis.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No EMI schedule');
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final e = Map<String, dynamic>.from(items[i] as Map);
            final status = e['status']?.toString() ?? '';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor(status).withValues(alpha: 0.15),
                  child: Text('${e['emiNumber']}', style: TextStyle(color: statusColor(status), fontWeight: FontWeight.bold)),
                ),
                title: Text(formatDate(e['dueDate'])),
                subtitle: Text('EMI: ${formatCurrency(e['emiAmount'])}${toNum(e['lateFee']) > 0 ? ' • Late: ${formatCurrency(e['lateFee'])}' : ''}'),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatusChip(label: status, color: statusColor(status)),
                    if (toNum(e['paidAmount']) > 0)
                      Text(formatCurrency(e['paidAmount']), style: const TextStyle(fontSize: 11, color: AppColors.accent)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
