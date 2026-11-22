import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/screens/favorites_screen.dart';
import 'package:whatcanicook/screens/home_screen.dart';
import 'package:whatcanicook/screens/profile_screen.dart';
import 'package:whatcanicook/screens/recipes_screen.dart';
import 'package:whatcanicook/screens/scan_screen.dart';

final navigationIndexProvider = NotifierProvider<NavigationIndexNotifier, int>(
  NavigationIndexNotifier.new,
);

class NavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const int home = 0;
  static const int explore = 1;
  static const int create = 2;
  static const int favorites = 3;
  static const int profile = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navigationIndexProvider);

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: const [
            HomeScreen(),
            RecipesScreen(),
            ScanScreen(),
            FavoritesScreen(),
            ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _PremiumBottomNav(
        selectedIndex: index,
        onSelected: (value) {
          ref.read(navigationIndexProvider.notifier).select(value);
        },
      ),
    );
  }
}

class _PremiumBottomNav extends StatelessWidget {
  const _PremiumBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Inicio',
                selected: selectedIndex == AppShell.home,
                onTap: () => onSelected(AppShell.home),
              ),
              _NavItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book_rounded,
                label: 'Explorar',
                selected: selectedIndex == AppShell.explore,
                onTap: () => onSelected(AppShell.explore),
              ),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    selected: selectedIndex == AppShell.create,
                    child: GestureDetector(
                      onTap: () => onSelected(AppShell.create),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppColors.goldBright, AppColors.gold],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.28),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: selectedIndex == AppShell.create
                                    ? AppColors.textPrimary
                                    : AppColors.goldDark,
                                width: selectedIndex == AppShell.create ? 2 : 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.background,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Crear',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.goldBright,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.favorite_border_rounded,
                activeIcon: Icons.favorite_rounded,
                label: 'Favoritos',
                selected: selectedIndex == AppShell.favorites,
                onTap: () => onSelected(AppShell.favorites),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Perfil',
                selected: selectedIndex == AppShell.profile,
                onTap: () => onSelected(AppShell.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.goldBright : AppColors.textSecondary;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 23),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
