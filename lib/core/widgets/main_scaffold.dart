import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../theme/app_theme.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/budget')) return 1;
    if (location.startsWith('/tasks')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _locationToIndex(location);
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: isDark
              ? const Color(0xFF6E6E8A)
              : const Color(0xFF9E9EC0),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/expenses');
                break;
              case 1:
                context.go('/budget');
                break;
              case 2:
                context.go('/tasks');
                break;
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: _NavIcon(
                icon: Icons.account_balance_wallet_outlined,
                isSelected: currentIndex == 0,
              ),
              activeIcon: _NavIcon(
                icon: Icons.account_balance_wallet,
                isSelected: true,
              ),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(
                icon: Icons.pie_chart_outline,
                isSelected: currentIndex == 1,
              ),
              activeIcon: _NavIcon(icon: Icons.pie_chart, isSelected: true),
              label: 'Budget',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(
                icon: Icons.check_circle_outline,
                isSelected: currentIndex == 2,
              ),
              activeIcon: _NavIcon(icon: Icons.check_circle, isSelected: true),
              label: 'Tasks',
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;

  const _NavIcon({required this.icon, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: 22),
    );
  }
}
