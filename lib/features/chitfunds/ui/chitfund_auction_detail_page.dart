import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/chitfund_repo.dart';

final chitfundAuctionDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, ({String chitfundId, String auctionId})>((ref, key) async {
  return ref.read(chitfundRepoProvider).auctionDetail(key.chitfundId, key.auctionId);
});

class ChitfundAuctionDetailPage extends ConsumerWidget {
  final String chitfundId;
  final String auctionId;
  const ChitfundAuctionDetailPage({super.key, required this.chitfundId, required this.auctionId});

  ({String chitfundId, String auctionId}) get _key => (chitfundId: chitfundId, auctionId: auctionId);

  Future<void> _reverse(BuildContext context, WidgetRef ref, Map<String, dynamic> auction) async {
    final isExtra = auction['isExtra'] == true;
    final ok = await confirmDialog(
      context,
      title: 'Reverse Auction',
      message: 'Reverse ${isExtra ? 'this extra auction' : 'month ${auction['monthNumber']}'}? '
          'The winner, dividend, and auto-created payout will be rolled back. This will fail if any '
          'collections exist for this month or if the payout is already settled.',
      confirmText: 'Reverse',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(chitfundRepoProvider).reverseAuction(chitfundId, auctionId);
      showToast('Auction reversed');
      if (context.mounted) context.go('/chitfunds/$chitfundId');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  Future<void> _deletePayment(BuildContext context, WidgetRef ref, Map<String, dynamic> payment) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete Payment',
      message: "Delete this ${formatCurrency(payment['amount'])} payment? The member's total paid will be decreased.",
      confirmText: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(chitfundRepoProvider).deletePayment(chitfundId, payment['id'].toString());
      showToast('Payment deleted');
      ref.invalidate(chitfundAuctionDetailProvider(_key));
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(chitfundAuctionDetailProvider(_key));
    final auth = ref.watch(authProvider);
    final canManage = auth.hasPermission('chitfunds.create') || auth.hasRole('ORG_ADMIN') || auth.hasRole('MANAGER');

    return Scaffold(
      appBar: AppBar(title: const Text('Auction Detail')),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (d) {
          final auction = Map<String, dynamic>.from(d['auction'] as Map? ?? {});
          final c = Map<String, dynamic>.from(d['chitfund'] as Map? ?? {});
          final winner = d['winner'] != null ? Map<String, dynamic>.from(d['winner'] as Map) : null;
          final payout = d['payout'] != null ? Map<String, dynamic>.from(d['payout'] as Map) : null;
          final dividendDist = (d['dividendDistribution'] as List?) ?? const [];
          final collections = (d['collections'] as List?) ?? const [];
          final isCompleted = auction['status'] == 'COMPLETED';
          final dividendType = c['dividendType']?.toString() ?? 'SPLIT';

          final collectionsTotal = collections.fold<num>(0, (s, p) => s + toNum((p as Map)['amount']));
          final eligibleDivCount = dividendDist.where((x) => (x as Map)['eligible'] == true).length;
          final totalDivDistributed = dividendDist.fold<num>(0, (s, x) => s + toNum((x as Map)['amount']));

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c['name'] ?? ''} - Month ${auction['monthNumber']}${auction['isExtra'] == true ? ' (Extra)' : ''}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          StatusChip(
                            label: auction['status']?.toString() ?? 'SCHEDULED',
                            color: statusColor(auction['status']?.toString()),
                          ),
                          StatusChip(
                            label: dividendType +
                                (dividendType == 'SPLIT'
                                    ? ' · ${c['splitAudience'] == 'NON_WINNERS' ? 'Non-winners' : 'All'}'
                                    : ''),
                            color: AppColors.info,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SectionCard(
                title: 'Summary',
                child: Column(
                  children: [
                    KeyValueRow(label: 'Auction Date', value: formatDate(auction['auctionDate'])),
                    KeyValueRow(label: 'Chit Value', value: formatCurrency(c['totalAmount'])),
                    KeyValueRow(label: 'Commission', value: formatCurrency(d['commissionAmount'])),
                    KeyValueRow(
                      label: dividendType == 'ACCUMULATED' ? 'Pool Added' : 'Surplus',
                      value: formatCurrency(dividendType == 'ACCUMULATED' ? d['poolImpact'] : d['surplus']),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                SectionCard(
                  title: 'Winner & Payout',
                  child: Column(
                    children: [
                      KeyValueRow(
                        label: 'Winner',
                        value: winner != null
                            ? '#${winner['ticketNumber']} - ${winner['customerName'] ?? 'Member'}'
                            : '-',
                      ),
                      KeyValueRow(label: 'Phone', value: winner?['phone']?.toString() ?? '-'),
                      KeyValueRow(label: 'Bid Amount', value: formatCurrency(auction['bidAmount'])),
                      KeyValueRow(label: 'Winner Payout', value: formatCurrency(auction['netPayoutToWinner'])),
                      KeyValueRow(
                        label: 'Dividend / Member',
                        value: toNum(auction['dividendPerMember']) > 0 ? formatCurrency(auction['dividendPerMember']) : '-',
                      ),
                      KeyValueRow(label: 'Dividend Recipients', value: '$eligibleDivCount'),
                      KeyValueRow(label: 'Total Dividend', value: formatCurrency(totalDivDistributed)),
                      if (payout != null)
                        KeyValueRow(
                          label: 'Payout Status',
                          value: payout['status']?.toString() ?? 'PENDING',
                          valueColor: statusColor(payout['status']?.toString()),
                        ),
                      if (payout != null) ...[
                        KeyValueRow(label: 'Payout Amount', value: formatCurrency(payout['amount'])),
                        KeyValueRow(label: 'Mode', value: payout['paymentMode']?.toString() ?? '-'),
                        KeyValueRow(label: 'Settled On', value: formatDate(payout['paidDate'])),
                        KeyValueRow(label: 'Reference', value: payout['reference']?.toString() ?? '-'),
                      ],
                    ],
                  ),
                )
              else
                const SectionCard(
                  title: 'Winner & Payout',
                  child: Text('This auction has not been conducted yet.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              if (isCompleted && canManage)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    icon: const Icon(Icons.undo),
                    label: const Text('Reverse Auction'),
                    onPressed: () => _reverse(context, ref, auction),
                  ),
                ),
              if (isCompleted && dividendType == 'SPLIT')
                SectionCard(
                  title: 'Dividend Distribution',
                  child: Column(
                    children: [
                      for (final raw in dividendDist) _dividendRow(Map<String, dynamic>.from(raw as Map)),
                    ],
                  ),
                ),
              SectionCard(
                title: 'Collections for Month ${auction['monthNumber']}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${collections.length} of ${dividendDist.length} members paid · ${formatCurrency(collectionsTotal)} collected',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    if (collections.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No collections recorded yet for this month.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      for (final raw in collections)
                        _collectionTile(context, ref, Map<String, dynamic>.from(raw as Map), canManage),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dividendRow(Map<String, dynamic> d) {
    final isWinner = d['isWinner'] == true;
    final eligible = d['eligible'] == true;
    final label = isWinner
        ? 'Winner'
        : eligible
            ? 'Eligible'
            : 'Not eligible';
    final color = isWinner ? AppColors.info : (eligible ? AppColors.accent : AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text('#${d['ticketNumber']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(d['customerName']?.toString() ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          StatusChip(label: label, color: color),
          const SizedBox(width: 8),
          Text(eligible ? formatCurrency(d['amount']) : '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _collectionTile(BuildContext context, WidgetRef ref, Map<String, dynamic> p, bool canManage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(p['memberTicket'] != null ? '#${p['memberTicket']}' : '-',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['memberName']?.toString() ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(
                  '${p['paymentMode'] ?? '-'} · ${formatDate(p['paidDate'])}${p['reference'] != null ? ' · ${p['reference']}' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(formatCurrency(p['amount']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
              onPressed: () => _deletePayment(context, ref, p),
            ),
        ],
      ),
    );
  }
}
