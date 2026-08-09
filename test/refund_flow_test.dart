import 'package:app/features/pos/checkout_screen.dart' show salesRepositoryProvider;
import 'package:app/features/pos/refund_screen.dart';
import 'package:app/features/pos/sales_repository.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSalesRepository implements SalesRepository {
  _FakeSalesRepository({this.sale});
  bool refundCalled = false;
  List<RefundItemRequest>? lastItems;
  final SaleResultDto? sale;

  static SaleResultDto _defaultSale() => SaleResultDto(
    id: 's1',
    receiptNo: 'R000001',
    customerId: null,
    subtotal: Decimal.parse('135.00'),
    discount: Decimal.zero,
    tax: Decimal.zero,
    priceIncludesTax: true,
    total: Decimal.parse('135.00'),
    pointsEarned: 0,
    pointsRedeemed: 0,
    pointsDiscount: Decimal.zero,
    paymentMethod: 'cash',
    status: 'partially_refunded',
    refundedTotal: Decimal.parse('45.00'),
    createdAt: DateTime(2026, 1, 1),
    items: [
      SaleItemResultDto(
        id: 'si1',
        productId: 'p1',
        name: 'กาแฟ',
        price: Decimal.parse('45.00'),
        qty: 3,
        discount: Decimal.zero,
        lineTotal: Decimal.parse('135.00'),
        refundedQty: 1,
      ),
    ],
    refunds: const [],
    warnings: const [],
  );

  @override
  Future<SaleResultDto> get(String id) async => sale ?? _defaultSale();

  @override
  Future<RefundResultDto> refund({
    required String saleId,
    required String clientUuid,
    List<RefundItemRequest>? items,
    String? reason,
  }) async {
    refundCalled = true;
    lastItems = items;
    throw StateError('refund() should not be reached before the confirm dialog is accepted in this test');
  }

  @override
  Future<SaleResultDto> checkout({
    required String clientUuid,
    required List<CheckoutItem> items,
    required Decimal discount,
    required String paymentMethod,
    String? customerId,
    int redeemPoints = 0,
  }) => throw UnimplementedError();

  @override
  Future<List<SaleListItemDto>> list({DateTime? startDate, DateTime? endDate}) => throw UnimplementedError();
}

void main() {
  testWidgets('quantity stepper is capped at the remaining refundable qty', (tester) async {
    final fake = _FakeSalesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [salesRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: RefundScreen(saleId: 's1')),
      ),
    );
    await tester.pumpAndSettle();

    // remaining = qty(3) - refundedQty(1) = 2
    final plusButton = find.widgetWithIcon(IconButton, Icons.add_circle_outline);
    await tester.tap(plusButton);
    await tester.pump();
    await tester.tap(plusButton);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    // A third tap must not push it past the remaining cap of 2 — the button
    // becomes disabled once the cap is reached.
    final buttonWidget = tester.widget<IconButton>(plusButton);
    expect(buttonWidget.onPressed, isNull);
  });

  testWidgets('"refund all" pre-fills every remaining line to its max', (tester) async {
    final fake = _FakeSalesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [salesRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: RefundScreen(saleId: 's1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('คืนทั้งหมด'));
    await tester.pump();

    expect(find.text('2'), findsOneWidget); // remaining qty for the one line
  });

  testWidgets('confirm dialog appears before the refund API call fires', (tester) async {
    final fake = _FakeSalesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [salesRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: RefundScreen(saleId: 's1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('คืนทั้งหมด'));
    await tester.pump();
    await tester.tap(find.text('คืนเงิน'));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันการคืนเงิน'), findsOneWidget);
    expect(fake.refundCalled, isFalse);
  });

  testWidgets('preview does not add tax on top for a price-inclusive-VAT sale', (tester) async {
    // Regression: refund_service.py never adds tax on top when
    // price_includes_tax is true (it's only disclosed, already inside the
    // line amount) — the client preview must branch the same way or it
    // overstates the refund versus what the backend actually records.
    final vatSale = SaleResultDto(
      id: 's1',
      receiptNo: 'R000001',
      customerId: null,
      subtotal: Decimal.parse('300.00'),
      discount: Decimal.zero,
      tax: Decimal.parse('19.63'),
      priceIncludesTax: true,
      total: Decimal.parse('300.00'),
      pointsEarned: 0,
      pointsRedeemed: 0,
      pointsDiscount: Decimal.zero,
      paymentMethod: 'cash',
      status: 'completed',
      refundedTotal: Decimal.zero,
      createdAt: DateTime(2026, 1, 1),
      items: [
        SaleItemResultDto(
          id: 'si1',
          productId: 'p1',
          name: 'กาแฟทดสอบ VAT',
          price: Decimal.parse('107.00'),
          qty: 3,
          discount: Decimal.parse('21.00'),
          lineTotal: Decimal.parse('300.00'),
          refundedQty: 0,
        ),
      ],
      refunds: const [],
      warnings: const [],
    );
    final fake = _FakeSalesRepository(sale: vatSale);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [salesRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: RefundScreen(saleId: 's1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline));
    await tester.pump();

    // unit_net = 300/3 = 100 exactly — must show ฿100.00, not ฿106.54.
    expect(find.text('฿100.00'), findsOneWidget);
    expect(find.text('฿106.54'), findsNothing);
  });
}
