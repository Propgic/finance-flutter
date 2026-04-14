import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/common.dart';

class NavItem {
  final String label;
  final IconData icon;
  final String route;
  final String? featureFlag;
  final String? permission;
  final String? role;
  const NavItem(this.label, this.icon, this.route, {this.featureFlag, this.permission, this.role});
}

const _navItems = <NavItem>[
  NavItem('Dashboard', Icons.dashboard_outlined, '/dashboard'),
  NavItem('Customers', Icons.people_outline, '/customers', permission: 'customers.view'),
  NavItem('Loans', Icons.request_quote_outlined, '/loans', featureFlag: 'enableLoans', permission: 'loans.view'),
  NavItem('Loan Groups', Icons.groups_outlined, '/loan-groups', featureFlag: 'enableGroupLoan', permission: 'loans.view'),
  NavItem('Collections', Icons.payments_outlined, '/collections', featureFlag: 'enableLoans', permission: 'collections.view'),
  NavItem('Savings', Icons.savings_outlined, '/savings', featureFlag: 'enableSavings', permission: 'savings.view'),
  NavItem('Chitfunds', Icons.account_balance_wallet_outlined, '/chitfunds', featureFlag: 'enableChitfund', permission: 'chitfunds.view'),
  NavItem('Investors', Icons.trending_up, '/investors', featureFlag: 'enableInvestments', permission: 'investors.view'),
  NavItem('Expenses', Icons.receipt_long_outlined, '/expenses'),
  NavItem('Reports', Icons.bar_chart_outlined, '/reports', featureFlag: 'enableReports', permission: 'reports.view'),
  NavItem('Team', Icons.group_outlined, '/team', permission: 'team.view'),
  NavItem('Settings', Icons.settings_outlined, '/settings', role: 'ORG_ADMIN'),
];

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final items = _navItems.where((it) {
      if (it.featureFlag != null && auth.org?.feature(it.featureFlag!) != true) return false;
      if (it.permission != null && !auth.hasPermission(it.permission!)) return false;
      if (it.role != null && !auth.hasRole(it.role!)) return false;
      return true;
    }).toList();
    final location = GoRouter.of(context).routeInformationProvider.value.uri.path;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Avatar(url: auth.org?.logo, name: auth.org?.name ?? 'Org', size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.org?.name ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(auth.user?.role ?? '',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: items.map((it) {
                  final selected = location == it.route || location.startsWith('${it.route}/');
                  return ListTile(
                    leading: Icon(it.icon, color: selected ? AppColors.primary : AppColors.textSecondary),
                    title: Text(it.label,
                        style: TextStyle(
                          color: selected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        )),
                    selected: selected,
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                    onTap: () {
                      Navigator.pop(context);
                      context.go(it.route);
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Avatar(url: auth.user?.photo, name: auth.user?.name ?? '', size: 36),
              title: Text(auth.user?.name ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(auth.user?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Logout', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(context);
                final ok = await confirmDialog(context, message: 'Sign out of your account?', destructive: true, confirmText: 'Logout');
                if (ok) {
                  await ref.read(authProvider.notifier).logout();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
