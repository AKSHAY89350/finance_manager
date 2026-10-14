import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recurring_provider.dart';
import '../utils/app_colors.dart';
import 'home/dashboard_screen.dart';
import 'transactions/transaction_list_screen.dart';
import 'reports/reports_screen.dart';
import 'investments/investment_screen.dart';
import 'settings/settings_screen.dart';

/// Provides the currently selected tab index across the app.
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// Main scaffold with bottom navigation bar.
/// All 5 tabs are defined here — matching the roadmap.
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recurringProvider.notifier).processDueAutoDebits(context: context);
    });
  }

  static const List<_TabItem> _tabs = [
    _TabItem(
      label: 'Home',
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
    ),
    _TabItem(
      label: 'Transactions',
      activeIcon: Icons.receipt_long_rounded,
      inactiveIcon: Icons.receipt_long_outlined,
    ),
    _TabItem(
      label: 'Reports',
      activeIcon: Icons.bar_chart_rounded,
      inactiveIcon: Icons.bar_chart_outlined,
    ),
    _TabItem(
      label: 'Invest',
      activeIcon: Icons.trending_up_rounded,
      inactiveIcon: Icons.trending_up_outlined,
    ),
    _TabItem(
      label: 'Settings',
      activeIcon: Icons.settings_rounded,
      inactiveIcon: Icons.settings_outlined,
    ),
  ];

  static const List<Widget> _screens = [
    DashboardScreen(),
    TransactionListScreen(),
    ReportsScreen(),
    InvestmentScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(
        // IndexedStack keeps all screens alive (preserves scroll position)
        index: selectedTab,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(context, ref, selectedTab),
      // FAB on Home and Transactions tabs for quick entry
      floatingActionButton: (selectedTab == 0 || selectedTab == 1)
          ? _buildFAB(context, ref)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBottomNav(BuildContext context, WidgetRef ref, int selected) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_tabs.length, (index) {
              final tab   = _tabs[index];
              final isActive = index == selected;
              return Expanded(
                child: InkWell(
                  onTap: () => ref.read(selectedTabProvider.notifier).state = index,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Active tab gets a colored indicator above icon
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          width: isActive ? 24 : 0,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Icon(
                          isActive ? tab.activeIcon : tab.inactiveIcon,
                          color: isActive ? AppColors.primary : AppColors.textHint,
                          size: isActive ? 26 : 24,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      onPressed: () => _showAddOptions(context, ref),
      elevation: 4,
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
    );
  }

  /// Bottom sheet with 3 quick-add options
  void _showAddOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Quick Add',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _QuickAddTile(
              icon: Icons.arrow_downward_rounded,
              color: AppColors.expense,
              label: 'Add Expense',
              subtitle: 'Record a new spend',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/add-expense');
              },
            ),
            _QuickAddTile(
              icon: Icons.arrow_upward_rounded,
              color: AppColors.income,
              label: 'Add Income',
              subtitle: 'Salary, bonus, other credit',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/add-income');
              },
            ),
            _QuickAddTile(
              icon: Icons.swap_horiz_rounded,
              color: AppColors.transfer,
              label: 'Bank Transfer',
              subtitle: 'Move money between banks',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/transfer');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Data class for a tab item ──────────────────────────────────────
class _TabItem {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  const _TabItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
  });
}

// ── Quick Add option tile in the bottom sheet ──────────────────────
class _QuickAddTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAddTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
    );
  }
}
