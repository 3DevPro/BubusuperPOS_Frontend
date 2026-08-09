import 'package:app/features/catalog/product_repository.dart';
import 'package:app/features/pos/cart_notifier.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

ProductDto _product({
  String id = 'p1',
  String name = 'กาแฟ',
  String sellPrice = '45.00',
  int stockQty = 10,
  bool trackStock = true,
}) {
  return ProductDto(
    id: id,
    name: name,
    sellPrice: Decimal.parse(sellPrice),
    costPrice: Decimal.parse('20.00'),
    trackStock: trackStock,
    stockQty: stockQty,
    lowStockThreshold: 5,
    isActive: true,
  );
}

void main() {
  late CartNotifier cart;

  setUp(() => cart = CartNotifier());

  test('adding a product creates one line with qty 1', () {
    cart.addProduct(_product());
    expect(cart.state.lines, hasLength(1));
    expect(cart.state.lines.first.qty, 1);
    expect(cart.state.itemCount, 1);
  });

  test('adding the same product again increments qty instead of duplicating', () {
    final product = _product();
    cart.addProduct(product);
    cart.addProduct(product);
    cart.addProduct(product);

    expect(cart.state.lines, hasLength(1));
    expect(cart.state.lines.first.qty, 3);
    expect(cart.state.itemCount, 3);
  });

  test('setQty updates the line quantity', () {
    final product = _product();
    cart.addProduct(product);
    cart.setQty(product.id, 5);

    expect(cart.state.lines.first.qty, 5);
  });

  test('setQty to zero removes the line', () {
    final product = _product();
    cart.addProduct(product);
    cart.setQty(product.id, 0);

    expect(cart.state.lines, isEmpty);
  });

  test('removeProduct drops only the matching line', () {
    final a = _product(id: 'a', name: 'กาแฟ');
    final b = _product(id: 'b', name: 'ชา');
    cart.addProduct(a);
    cart.addProduct(b);
    cart.removeProduct('a');

    expect(cart.state.lines.map((l) => l.product.id), ['b']);
  });

  test('subtotal and total reflect price * qty across lines', () {
    cart.addProduct(_product(id: 'a', sellPrice: '45.00'));
    cart.addProduct(_product(id: 'b', sellPrice: '40.00'));
    cart.setQty('a', 2);

    // (45 * 2) + (40 * 1) = 130
    expect(cart.state.subtotal, Decimal.parse('130.00'));
    expect(cart.state.total, Decimal.parse('130.00'));
  });

  test('discount reduces total but never below zero', () {
    cart.addProduct(_product(sellPrice: '45.00'));
    cart.setDiscount(Decimal.parse('10.00'));
    expect(cart.state.total, Decimal.parse('35.00'));

    cart.setDiscount(Decimal.parse('999.00'));
    expect(cart.state.total, Decimal.zero);
  });

  test('stockWarnings flags lines that oversell tracked stock', () {
    cart.addProduct(_product(id: 'a', stockQty: 3));
    cart.setQty('a', 5);

    expect(cart.state.stockWarnings, hasLength(1));
    expect(cart.state.stockWarnings.first, contains('สต็อกเหลือ 3'));
  });

  test('stockWarnings ignores products with track_stock disabled', () {
    cart.addProduct(_product(id: 'a', stockQty: 0, trackStock: false));
    cart.setQty('a', 10);

    expect(cart.state.stockWarnings, isEmpty);
  });

  test('setItemDiscount reduces that line\'s lineTotal only', () {
    cart.addProduct(_product(id: 'a', sellPrice: '45.00'));
    cart.addProduct(_product(id: 'b', sellPrice: '40.00'));
    cart.setQty('a', 2);
    cart.setItemDiscount('a', Decimal.parse('10.00'));

    final lineA = cart.state.lines.firstWhere((l) => l.product.id == 'a');
    final lineB = cart.state.lines.firstWhere((l) => l.product.id == 'b');
    // (45*2) - 10 = 80
    expect(lineA.lineTotal, Decimal.parse('80.00'));
    expect(lineB.lineTotal, Decimal.parse('40.00'));
  });

  test('subtotal and total reflect per-item discounts', () {
    cart.addProduct(_product(id: 'a', sellPrice: '45.00'));
    cart.setItemDiscount('a', Decimal.parse('5.00'));

    expect(cart.state.subtotal, Decimal.parse('40.00'));
    expect(cart.state.total, Decimal.parse('40.00'));
  });

  test('setQty preserves an existing item discount', () {
    cart.addProduct(_product(id: 'a', sellPrice: '45.00'));
    cart.setItemDiscount('a', Decimal.parse('5.00'));
    cart.setQty('a', 3);

    expect(cart.state.lines.first.discount, Decimal.parse('5.00'));
    // (45*3) - 5 = 130
    expect(cart.state.lines.first.lineTotal, Decimal.parse('130.00'));
  });
}
