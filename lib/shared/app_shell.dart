import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/inventory/inventory_providers.dart';

class _NavDestination {
  const _NavDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

const _destinations = [
  _NavDestination(Icons.point_of_sale, 'ขาย'),
  _NavDestination(Icons.inventory_2, 'สต็อก'),
  _NavDestination(Icons.bar_chart, 'รายงาน'),
  _NavDestination(Icons.smart_toy, 'ผู้ช่วย'),
  _NavDestination(Icons.more_horiz, 'เพิ่มเติม'),
];

// Index into _destinations that the low-stock count badges — kept as a
// constant so the badge placement stays correct if the nav order changes.
const _stockTabIndex = 1;

/// One shell, two layouts: bottom nav on phones (checkout wants the full
/// screen), a NavigationRail on wider screens (web dashboard / tablet).
/// `navigationShell` is go_router's StatefulNavigationShell — each branch
/// keeps its own navigation stack, so switching tabs doesn't lose state.
///
/// A ConsumerWidget (not Stateless) so the low-stock count on the "สต็อก" tab
/// stays visible from any tab — proactive, without the cashier having to open
/// the inventory screen first to notice it's running low.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _wideBreakpoint = 900.0;

  void _onSelect(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Widget _icon(WidgetRef ref, int index, IconData icon) {
    if (index != _stockTabIndex) return Icon(icon);
    final count = ref.watch(lowStockProvider).valueOrNull?.length ?? 0;
    if (count == 0) return Icon(icon);
    return Badge(label: Text('$count'), child: Icon(icon));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (!isWide) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onSelect,
          destinations: [
            for (final (index, d) in _destinations.indexed)
              NavigationDestination(icon: _icon(ref, index, d.icon), label: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onSelect,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final (index, d) in _destinations.indexed)
                NavigationRailDestination(icon: _icon(ref, index, d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
