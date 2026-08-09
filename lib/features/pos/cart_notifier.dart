import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/product_repository.dart';
import '../customers/customer_repository.dart';

class CartLine {
  // Decimal.zero isn't a compile-time constant, so it can't be a default
  // parameter value — resolve it in the initializer list instead.
  CartLine({required this.product, required this.qty, Decimal? discount}) : discount = discount ?? Decimal.zero;

  final ProductDto product;
  final int qty;
  final Decimal discount;

  Decimal get gross => product.sellPrice * Decimal.fromInt(qty);
  Decimal get lineTotal => gross - discount;

  CartLine copyWith({int? qty, Decimal? discount}) =>
      CartLine(product: product, qty: qty ?? this.qty, discount: discount ?? this.discount);
}

class CartState {
  // Decimal.zero isn't a compile-time constant, so it can't be a default
  // parameter value — resolve it in the initializer list instead.
  CartState({this.lines = const [], Decimal? discount, this.customer, this.pointsToRedeem = 0})
    : discount = discount ?? Decimal.zero;

  final List<CartLine> lines;
  final Decimal discount;
  // Optional loyalty-program customer attached at checkout. Points-to-redeem
  // is a plain count entered by the cashier (see cart_panel.dart) — the
  // actual baht value is computed server-side from the tenant's
  // point_value_baht rate, never assumed client-side.
  final CustomerDto? customer;
  final int pointsToRedeem;

  Decimal get subtotal => lines.fold(Decimal.zero, (sum, line) => sum + line.lineTotal);

  Decimal get total {
    final t = subtotal - discount;
    return t < Decimal.zero ? Decimal.zero : t;
  }

  int get itemCount => lines.fold(0, (sum, line) => sum + line.qty);

  bool get isEmpty => lines.isEmpty;

  /// Lines whose quantity already exceeds tracked stock — surfaced as
  /// warnings, not blockers: the sale is still allowed to go through.
  List<String> get stockWarnings => [
    for (final line in lines)
      if (line.product.trackStock && line.qty > line.product.stockQty)
        '${line.product.name} สต็อกเหลือ ${line.product.stockQty} แต่ขาย ${line.qty}',
  ];
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void addProduct(ProductDto product) {
    final lines = [...state.lines];
    final index = lines.indexWhere((l) => l.product.id == product.id);
    if (index >= 0) {
      lines[index] = lines[index].copyWith(qty: lines[index].qty + 1);
    } else {
      lines.add(CartLine(product: product, qty: 1));
    }
    state = CartState(
      lines: lines,
      discount: state.discount,
      customer: state.customer,
      pointsToRedeem: state.pointsToRedeem,
    );
  }

  void setQty(String productId, int qty) {
    if (qty <= 0) {
      removeProduct(productId);
      return;
    }
    state = CartState(
      lines: [
        for (final l in state.lines) l.product.id == productId ? l.copyWith(qty: qty) : l,
      ],
      discount: state.discount,
      customer: state.customer,
      pointsToRedeem: state.pointsToRedeem,
    );
  }

  void removeProduct(String productId) {
    state = CartState(
      lines: state.lines.where((l) => l.product.id != productId).toList(),
      discount: state.discount,
      customer: state.customer,
      pointsToRedeem: state.pointsToRedeem,
    );
  }

  void setItemDiscount(String productId, Decimal discount) {
    state = CartState(
      lines: [
        for (final l in state.lines) l.product.id == productId ? l.copyWith(discount: discount) : l,
      ],
      discount: state.discount,
      customer: state.customer,
      pointsToRedeem: state.pointsToRedeem,
    );
  }

  void setDiscount(Decimal discount) {
    state = CartState(
      lines: state.lines,
      discount: discount,
      customer: state.customer,
      pointsToRedeem: state.pointsToRedeem,
    );
  }

  void setCustomer(CustomerDto? customer) {
    // Redemption only makes sense with a customer attached — dropping the
    // customer (or swapping to a different one) clears any pending
    // redemption rather than silently carrying a stale point count over.
    state = CartState(lines: state.lines, discount: state.discount, customer: customer, pointsToRedeem: 0);
  }

  void setPointsToRedeem(int points) {
    state = CartState(
      lines: state.lines,
      discount: state.discount,
      customer: state.customer,
      pointsToRedeem: points,
    );
  }

  void clear() {
    state = CartState();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
