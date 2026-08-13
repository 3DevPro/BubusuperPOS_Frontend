import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/audit_log/audit_log_screen.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/branch/branch_home_screen.dart';
import '../features/branch/branch_signup_screen.dart';
import '../features/branch/public_quote_screen.dart';
import '../features/catalog/barcode_label_screen.dart';
import '../features/catalog/category_management_screen.dart';
import '../features/catalog/product_form_screen.dart';
import '../features/notifications/notification_inbox_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/customers/customer_form_screen.dart';
import '../features/customers/customer_list_screen.dart';
import '../features/purchase_orders/purchase_order_detail_screen.dart';
import '../features/purchase_orders/purchase_order_form_screen.dart';
import '../features/purchase_orders/purchase_order_list_screen.dart';
import '../features/suppliers/supplier_form_screen.dart';
import '../features/suppliers/supplier_list_screen.dart';
import '../features/inventory/expiring_soon_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/inventory/low_stock_screen.dart';
import '../features/inventory/stock_adjust_screen.dart';
import '../features/dashboard/daily_dashboard_screen.dart';
import '../features/more/more_screen.dart';
import '../features/more/profile_screen.dart';
import '../features/pos/checkout_screen.dart';
import '../features/pos/pos_screen.dart';
import '../features/pos/receipt_screen.dart';
import '../features/pos/refund_screen.dart';
import '../features/pos/sales_history_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/staff/staff_screen.dart';
import '../features/turbo/income_certificate_screen.dart';
import '../features/turbo/insurance_screen.dart';
import '../features/turbo/loan_account_screen.dart';
import '../features/turbo/loan_apply_screen.dart';
import '../features/turbo/loan_payment_screen.dart';
import '../features/turbo/loan_status_screen.dart';
import '../features/turbo/turbo_home_screen.dart';
import '../features/turbo/turbo_repository.dart' show LoanInstallmentDto;
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

// Redirect away from these if already authenticated (to the right "home"
// for that account type) — unlike /quote, which is a standalone public page
// nobody gets redirected to or away from.
const _publicOnlyPaths = {'/login', '/signup', '/branch-signup'};

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
  if (path == '/turbo/income-certificate') return _ownerAndManager; // Permission.view_reports
  if (path == '/turbo/insurance') return _ownerAndManager; // Permission.manage_insurance
  // /turbo itself (the tab) has no restriction — TurboHomeScreen shows a
  // permission notice to cashiers itself instead of bouncing them off the
  // tab they just tapped, same UX rationale as /dashboard's canManageInsurance.
  if (path.startsWith('/turbo/loans')) return _ownerAndManager; // Permission.manage_loans
  if (path == '/categories') return _ownerAndManager; // inline create/edit/delete needs manage_products
  if (path.startsWith('/suppliers') || path.startsWith('/purchase-orders')) {
    return _ownerAndManager; // Permission.adjust_inventory
  }
  if (path == '/products/new') return _ownerAndManager; // Permission.manage_products
  if (path.startsWith('/products/') && (path.endsWith('/edit') || path.endsWith('/stock-adjust'))) {
    return _ownerAndManager; // manage_products / adjust_inventory
  }
  if (path == '/barcode-labels') return _ownerAndManager; // Permission.manage_products
  if (path.startsWith('/receipt/') && path.endsWith('/refund')) return _ownerAndManager; // Permission.refund_sale
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/pos',
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.matchedLocation;
      // A standalone public page (the O2O "เช็คเบี้ยใน 3 คลิก" quote form) —
      // works the same whether or not the caller happens to be logged in,
      // so it's never redirected to or away from.
      if (path == '/quote') return null;

      final authState = ref.read(authControllerProvider);
      final loggingIn = _publicOnlyPaths.contains(path);

      // Session restore hasn't resolved yet — stay put rather than bouncing to login.
      if (authState.status == AuthStatus.unknown) return null;
      if (authState.status != AuthStatus.authenticated) {
        return loggingIn ? null : '/login';
      }

      final role = authState.me?['role'] as String?;
      final isBranchChampion = role == 'branch_champion';

      if (loggingIn) {
        return isBranchChampion ? '/branch' : '/dashboard';
      }

      // Branch accounts have no tenant_id and live entirely outside the shop
      // shell (see Backend's UserRole.branch_champion) — every tenant route
      // would just 403 for them, and vice versa a shop account has nothing
      // to see under /branch.
      if (isBranchChampion) {
        return path.startsWith('/branch') ? null : '/branch';
      }
      if (path.startsWith('/branch')) {
        return '/pos';
      }

      final allowedRoles = allowedRolesForRoute(path);
      if (allowedRoles != null && role != null && !allowedRoles.contains(role)) {
        return '/pos';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/branch-signup', builder: (context, state) => const BranchSignupScreen()),
      GoRoute(path: '/quote', builder: (context, state) => const PublicQuoteScreen()),
      GoRoute(path: '/branch', builder: (context, state) => const BranchHomeScreen()),
      // Full-screen, outside the tab shell — these don't need the bottom nav visible.
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutScreen()),
      GoRoute(
        path: '/receipt/:saleId',
        builder: (context, state) => ReceiptScreen(
          saleId: state.pathParameters['saleId']!,
          autoPrint: state.uri.queryParameters['autoprint'] == '1',
        ),
      ),
      GoRoute(
        path: '/receipt/:saleId/refund',
        builder: (context, state) => RefundScreen(saleId: state.pathParameters['saleId']!),
      ),
      GoRoute(path: '/sales-history', builder: (context, state) => const SalesHistoryScreen()),
      GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
      GoRoute(path: '/turbo/income-certificate', builder: (context, state) => const IncomeCertificateScreen()),
      GoRoute(path: '/turbo/insurance', builder: (context, state) => const InsuranceScreen()),
      GoRoute(
        path: '/turbo/loans/apply',
        builder: (context, state) => LoanApplyScreen(productCode: state.uri.queryParameters['product']),
      ),
      GoRoute(path: '/turbo/loans/account', builder: (context, state) => const LoanAccountScreen()),
      GoRoute(
        path: '/turbo/loans/status/:applicationId',
        builder: (context, state) =>
            LoanStatusScreen(applicationId: state.pathParameters['applicationId']!),
      ),
      // No single "get installment by id" endpoint exists on Backend (only
      // list-by-account and pay-by-id), so the full DTO the account screen
      // already loaded travels via `extra` instead of being re-fetched by a
      // path param — same go_router idiom used for the pending-action cards
      // elsewhere in this app.
      GoRoute(
        path: '/turbo/loans/installments/pay',
        builder: (context, state) => LoanPaymentScreen(installment: state.extra as LoanInstallmentDto),
      ),
      GoRoute(path: '/low-stock', builder: (context, state) => const LowStockScreen()),
      GoRoute(path: '/barcode-labels', builder: (context, state) => const BarcodeLabelScreen()),
      GoRoute(path: '/expiring-soon', builder: (context, state) => const ExpiringSoonScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationInboxScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
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
            routes: [GoRoute(path: '/dashboard', builder: (context, state) => const DailyDashboardScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/turbo', builder: (context, state) => const TurboHomeScreen())],
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
