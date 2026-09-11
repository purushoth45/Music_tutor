import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/constants/theme.dart';
import '../../../../core/user_session.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';

class MainTabsScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainTabsScreen({
    Key? key,
    required this.navigationShell,
  }) : super(key: key);

  void _onTabTapped(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isTrainer = (authState is AuthAuthenticated && authState.user.isTrainer) || UserSession.isTrainer;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          child: GlassCard(
            borderRadius: AppBorderRadius.lg,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context: context,
                  index: 0,
                  icon: LucideIcons.layoutDashboard,
                  label: 'Dashboard',
                ),
                _buildNavItem(
                  context: context,
                  index: 1,
                  icon: isTrainer ? LucideIcons.users : LucideIcons.music2,
                  label: isTrainer ? 'My Students' : 'Practice Hub',
                ),
                _buildNavItem(
                  context: context,
                  index: 2,
                  icon: isTrainer ? LucideIcons.userCheck : LucideIcons.user,
                  label: isTrainer ? 'Instructor' : 'Profile',
                ),
                _buildNavItem(
                  context: context,
                  index: 3,
                  icon: LucideIcons.settings,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = navigationShell.currentIndex == index;
    final theme = Theme.of(context);
    final activeColor = index == 0
        ? theme.colorScheme.primary
        : index == 1
            ? theme.colorScheme.secondary
            : index == 2
                ? AppColors.accent
                : theme.colorScheme.primary;

    final unselectedColor = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final selectedTextColor = theme.textTheme.bodyLarge?.color ?? Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabTapped(context, index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              color: isSelected
                  ? activeColor.withOpacity(0.15)
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              color: isSelected ? activeColor : unselectedColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? selectedTextColor : unselectedColor,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
