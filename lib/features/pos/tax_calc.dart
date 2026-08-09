import 'package:decimal/decimal.dart';

// Rational.toDecimal() truncates toward zero by default — computing to extra
// precision first and then Decimal.round(scale:) (half-up) is what actually
// matches the backend's Decimal.quantize(..., ROUND_HALF_UP).
Decimal _roundedDiv(Decimal a, Decimal b) => (a / b).toDecimal(scaleOnInfinitePrecision: 6).round(scale: 2);

/// Client-side mirror of the backend's `pricing.calc_totals` (see
/// `backend/app/services/pricing.py`) — used only to preview the VAT
/// breakdown before checkout. The server recomputes authoritatively at
/// commit time, same as how `CartState.stockWarnings` is advisory, not
/// the final word.
class TaxTotals {
  const TaxTotals({required this.subtotal, required this.discount, required this.tax, required this.total});

  final Decimal subtotal;
  final Decimal discount;
  final Decimal tax;
  final Decimal total;
}

final _hundred = Decimal.fromInt(100);

TaxTotals calcTotals({
  required List<Decimal> lineTotals,
  required Decimal saleDiscount,
  required bool vatEnabled,
  required Decimal vatRate,
  required bool priceIncludesTax,
}) {
  final subtotal = lineTotals.fold(Decimal.zero, (sum, l) => sum + l);
  final net = subtotal - saleDiscount;
  final clampedNet = net < Decimal.zero ? Decimal.zero : net;

  if (!vatEnabled || vatRate == Decimal.zero) {
    return TaxTotals(subtotal: subtotal, discount: saleDiscount, tax: Decimal.zero, total: clampedNet);
  }

  if (priceIncludesTax) {
    final tax = _roundedDiv(clampedNet * vatRate, _hundred + vatRate);
    return TaxTotals(subtotal: subtotal, discount: saleDiscount, tax: tax, total: clampedNet);
  }

  final tax = _roundedDiv(clampedNet * vatRate, _hundred);
  return TaxTotals(subtotal: subtotal, discount: saleDiscount, tax: tax, total: clampedNet + tax);
}
