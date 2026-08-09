import 'package:app/features/catalog/product_repository.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductLookupDto.fromJson', () {
    test('parses a found result with a THB price', () {
      final dto = ProductLookupDto.fromJson({
        'found': true,
        'name': 'Coca-Cola 325ml',
        'image_url': 'https://example.com/coke.jpg',
        'price': '12.50',
        'currency': 'THB',
        'brand': 'Coca-Cola',
        'source': 'openfoodfacts',
        'cached': false,
      });

      expect(dto.found, isTrue);
      expect(dto.name, 'Coca-Cola 325ml');
      expect(dto.price, Decimal.parse('12.50'));
      expect(dto.currency, 'THB');
      expect(dto.cached, isFalse);
    });

    test('parses a not-found result with all optional fields null', () {
      final dto = ProductLookupDto.fromJson({
        'found': false,
        'name': null,
        'image_url': null,
        'price': null,
        'currency': null,
        'brand': null,
        'source': null,
        'cached': false,
      });

      expect(dto.found, isFalse);
      expect(dto.name, isNull);
      expect(dto.price, isNull);
    });

    test('parses a price returned as a bare JSON number, not just a string', () {
      // Real backend responses send price as a decimal-string, but the
      // parser shouldn't break if a provider ever serializes it as a number.
      final dto = ProductLookupDto.fromJson({
        'found': true,
        'name': 'Chips',
        'image_url': null,
        'price': 42,
        'currency': 'USD',
        'brand': null,
        'source': 'upcitemdb',
        'cached': false,
      });

      expect(dto.price, Decimal.parse('42'));
    });
  });
}
