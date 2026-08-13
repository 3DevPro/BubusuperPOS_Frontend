import 'package:app/features/pos/offline/pending_sale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PendingSaleItem round-trips its discount through JSON', () {
    const item = PendingSaleItem(productId: 'p1', qty: 2, discount: '5.50');

    final decoded = PendingSaleItem.fromJson(item.toJson());

    expect(decoded.productId, 'p1');
    expect(decoded.qty, 2);
    expect(decoded.discount, '5.50');
  });

  test('PendingSaleItem.fromJson defaults discount to 0 for pre-existing queued entries', () {
    // Simulates a sale that was queued (and persisted to shared_preferences)
    // before the discount field existed on this class — it must still parse.
    final decoded = PendingSaleItem.fromJson({'product_id': 'p1', 'qty': 2});

    expect(decoded.discount, '0');
  });

  test('PendingSale round-trips a discounted line through JSON', () {
    final sale = PendingSale(
      clientUuid: 'c1',
      items: const [PendingSaleItem(productId: 'p1', qty: 2, discount: '5.50')],
      discount: '0',
      paymentMethod: 'cash',
      createdAt: DateTime(2026, 1, 1),
    );

    final decoded = PendingSale.fromJson(sale.toJson());

    expect(decoded.items.single.discount, '5.50');
  });
}
