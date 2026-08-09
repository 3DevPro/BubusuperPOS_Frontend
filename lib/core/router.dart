import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/audit_log/audit_log_screen.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/catalog/category_management_screen.dart';
import '../features/catalog/product_form_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/customers/customer_form_screen.dart';
import '../features/customers/customer_list_screen.dart';
import '../features/purchase_orders/purchase_order_detail_screen.dart';
import '../features/purchase_orders/purchase_order_form_screen.dart';
import '../features/purchase_orders/purchase_order_list_screen.dart';
import '../features/suppliers/supplier_form_screen.dart';
import '../features/suppliers/supplier_list_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/inventory/low_stock_screen.dart';
import '../features/inventory/stock_adjust_screen.dart';
import '../features/more/more_screen.dart';
import '../features/pos/checkout_screen.dart';
import '../features/pos/pos_screen.dart';
import '../features/pos/receipt_screen.dart';
import '../features/pos/refund_screen.dart';
import '../features/pos/sales_history_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/staff/staff_screen.dart';
import '../shared/app_shell.dart';

/// Bridges Riverpod state changes into go_router's `refreshListenable`, so
/// the router just re-runs its `redirect` callback on auth changes instead of
/// being torn down and rebuilt — GoRouter owns real navigation/platform
/// state, and recreating it on every auth change is what caused the app to
/// occasionally strand itself on the wrong screen after login.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

const _ownerOnly = {'owner'};
const _ownerAndManager = {'owner', 'manager'};

/// Mirrors the backend's Permission grants (see
/// `backend/app/core/permissions.py`) so a cashier can't even land on a
/// screen whose API calls would all 403 — this is a UX fix, not a security
/// boundary; the server enforces the real permission check regardless of
/// what this returns. Returns null for routes open to any authenticated
/// role (including ones like /customers that are cashier-accessible on
/// purpose, and /settings which is viewable by all but only editable by
/// owner inside the screen itself).
@visibleForTesting
Set<String>? allowedRolesForRoute(String path) {
  if (path == '/staff' || path == '/audit-log') return _ownerOnly;
  if (path == '/reports') return _ownerAndManager; // Permission.view_reports
  if (path == '/categories') return _ownerAndManager; // inline create/edit/delete needs manage_products
  if (path.startsWith('/suppliers') || path.startsWith('/purchase-orders')) {
    return _ownerAndManager; // Permission.adjust_inventory
  }
  if (path == '/products/new') return _ownerAndManager; // Permission.manage_products
  if (path.startsWith('/products/') && (path.endsWith('/edit') || path.endsWith('/stock-adjust'))) {
    return _ownerAndManager; // manage_products / adjust_inventory
  }
  if (path.startsWith('/receipt/') && path.endsWith('/refund')) return _ownerAndManager; // Permission.refund_sale
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/pos',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      // Session restore hasn't resolved yet — stay put rather than bouncing to login.
      if (authState.status == AuthStatus.unknown) return null;
      if (authState.status != AuthStatus.authenticated && !loggingIn) return '/login';
      if (authState.status == AuthStatus.authenticated && loggingIn) return '/pos';

      final allowedRoles = allowedRolesForRoute(state.matchedLocation);
      final role = authState.me?['role'] as String?;
      if (allowedRoles != null && role != null && !allowedRoles.contains(role)) {
        return '/pos';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      // Full-screen, outside the tab shell — these don't need the bottom nav visible.
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutScreen()),
      GoRoute(
        path: '/receipt/:saleId',
        builder: (context, state) => ReceiptScreen(saleId: state.pathParameters['saleId']!),
      ),
      GoRoute(
        path: '/receipt/:saleId/refund',
        builder: (context, state) => RefundScreen(saleId: state.pathParameters['saleId']!),
      ),
      GoRoute(path: '/sales-history', builder: (context, state) => const SalesHistoryScreen()),
      GoRoute(path: '/low-stock', builder: (context, state) => const LowStockScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/staff', builder: (context, state) => const StaffScreen()),
      GoRoute(path: '/categories', builder: (context, state) => const CategoryManagementScreen()),
      GoRoute(path: '/audit-log', builder: (context, state) => const AuditLogScreen()),
      GoRoute(path: '/customers', builder: (context, state) => const CustomerListScreen()),
      GoRoute(path: '/customers/new', builder: (context, state) => const CustomerFormScreen()),
      GoRoute(
        path: '/customers/:customerId/edit',
        builder: (context, state) => CustomerFormScreen(customerId: state.pathParameters['customerId']!),
      ),
      GoRoute(path: '/suppliers', builder: (context, state) => const SupplierListScreen()),
      GoRoute(path: '/suppliers/new', builder: (context, state) => const SupplierFormScreen()),
      GoRoute(
        path: '/suppliers/:supplierId/edit',
        builder: (context, state) => SupplierFormScreen(supplierId: state.pathParameters['supplierId']!),
      ),
      GoRoute(path: '/purchase-orders', builder: (context, state) => const PurchaseOrderListScreen()),
      GoRoute(path: '/purchase-orders/new', builder: (context, state) => const PurchaseOrderFormScreen()),
      GoRoute(
        path: '/purchase-orders/:purchaseOrderId',
        builder: (context, state) =>
            PurchaseOrderDetailScreen(purchaseOrderId: state.pathParameters['purchaseOrderId']!),
      ),
      GoRoute(path: '/products/new', builder: (context, state) => const ProductFormScreen()),
      GoRoute(
        path: '/products/:productId/edit',
        builder: (context, state) => ProductFormScreen(productId: state.pathParameters['productId']!),
      ),
      GoRoute(
        path: '/products/:productId/stock-adjust',
        builder: (context, state) => StockAdjustScreen(productId: state.pathParameters['productId']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/pos', builder: (context, state) => const PosScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/inventory', builder: (context, state) => const InventoryScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/chat', builder: (context, state) => const ChatScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/more', builder: (context, state) => const MoreScreen())],
          ),
        ],
      ),
    ],
  );
});
