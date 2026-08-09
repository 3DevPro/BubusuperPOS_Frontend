import 'package:app/core/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('allowedRolesForRoute', () {
    test('open routes have no restriction', () {
      for (final path in ['/pos', '/inventory', '/chat', '/more', '/settings', '/checkout']) {
        expect(allowedRolesForRoute(path), isNull, reason: path);
      }
    });

    test('customers stay open to every role (matches Permission.manage_customers)', () {
      for (final path in ['/customers', '/customers/new', '/customers/abc123/edit']) {
        expect(allowedRolesForRoute(path), isNull, reason: path);
      }
    });

    test('owner-only routes', () {
      for (final path in ['/staff', '/audit-log']) {
        expect(allowedRolesForRoute(path), {'owner'}, reason: path);
      }
    });

    test('owner/manager routes (matches adjust_inventory / manage_products / view_reports / refund_sale)', () {
      final paths = [
        '/reports',
        '/categories',
        '/suppliers',
        '/suppliers/new',
        '/suppliers/abc/edit',
        '/purchase-orders',
        '/purchase-orders/new',
        '/purchase-orders/abc',
        '/products/new',
        '/products/abc/edit',
        '/products/abc/stock-adjust',
        '/receipt/abc/refund',
      ];
      for (final path in paths) {
        expect(allowedRolesForRoute(path), {'owner', 'manager'}, reason: path);
      }
    });

    test('receipt view (not refund) stays open to every role', () {
      expect(allowedRolesForRoute('/receipt/abc123'), isNull);
    });
  });
}
