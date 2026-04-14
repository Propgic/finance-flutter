import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  static const _items = [
    ('/dashboard', Icons.home_outlined, Icons.home, 'Home'),
    ('/loans', Icons.request_quote_outlined, Icons.request_quote, 'Loans'),
    ('/collections', Icons.payments_outlined, Icons.payments, 'Collections'),
    ('/profile', Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouter.of(context).routeInformationProvider.value.uri.path;
    int current = 0;
    for (var i = 0; i < _items.length; i++) {
      if (location == _items[i].$1 || location.startsWith('${_items[i].$1}/')) {
        current = i;
        break;
      }
    }
    return BottomNavigationBar(
      currentIndex: current,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      onTap: (i) {
        final route = _items[i].$1;
        if (location != route) context.go(route);
      },
      items: _items
          .map((it) => BottomNavigationBarItem(
                icon: Icon(it.$2),
                activeIcon: Icon(it.$3),
                label: it.$4,
              ))
          .toList(),
    );
  }
}
