import 'package:app/features/pos/tax_calc.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vat disabled leaves totals unchanged', () {
    final result = calcTotals(
      lineTotals: [Decimal.parse('60.00')],
      saleDiscount: Decimal.zero,
      vatEnabled: false,
      vatRate: Decimal.zero,
      priceIncludesTax: true,
    );
    expect(result.tax, Decimal.zero);
    expect(result.total, Decimal.parse('60.00'));
  });

  test('vat inclusive backs out tax without changing total', () {
    final result = calcTotals(
      lineTotals: [Decimal.parse('107.00')],
      saleDiscount: Decimal.zero,
      vatEnabled: true,
      vatRate: Decimal.parse('7'),
      priceIncludesTax: true,
    );
    expect(result.tax, Decimal.parse('7.00'));
    expect(result.total, Decimal.parse('107.00'));
  });

  test('vat exclusive adds tax on top of total', () {
    final result = calcTotals(
      lineTotals: [Decimal.parse('100.00')],
      saleDiscount: Decimal.zero,
      vatEnabled: true,
      vatRate: Decimal.parse('7'),
      priceIncludesTax: false,
    );
    expect(result.tax, Decimal.parse('7.00'));
    expect(result.total, Decimal.parse('107.00'));
  });

  test('vat inclusive rounds half-up on a repeating decimal, not truncates', () {
    // 300 * 7 / 107 = 19.6261682... must round to 19.63, not truncate to 19.62
    // (regression: Rational.toDecimal() truncates toward zero by default).
    final result = calcTotals(
      lineTotals: [Decimal.parse('300.00')],
      saleDiscount: Decimal.zero,
      vatEnabled: true,
      vatRate: Decimal.parse('7'),
      priceIncludesTax: true,
    );
    expect(result.tax, Decimal.parse('19.63'));
  });

  test('sale-level discount reduces the taxable base before vat', () {
    final result = calcTotals(
      lineTotals: [Decimal.parse('100.00')],
      saleDiscount: Decimal.parse('20.00'),
      vatEnabled: true,
      vatRate: Decimal.parse('7'),
      priceIncludesTax: false,
    );
    // net after discount = 80; tax = 80 * 7% = 5.60
    expect(result.tax, Decimal.parse('5.60'));
    expect(result.total, Decimal.parse('85.60'));
  });
}
