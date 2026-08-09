import 'package:app/features/pos/promptpay.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal EMV TLV parser (tag: 2 chars, length: 2-digit decimal, value:
/// `length` chars) used only to inspect our own output in these tests.
List<(String tag, String value)> _parseTlv(String s) {
  final out = <(String, String)>[];
  var pos = 0;
  while (pos < s.length) {
    final tag = s.substring(pos, pos + 2);
    final len = int.parse(s.substring(pos + 2, pos + 4));
    final value = s.substring(pos + 4, pos + 4 + len);
    out.add((tag, value));
    pos += 4 + len;
  }
  return out;
}

void main() {
  test('payload matches an independently-computed reference value', () {
    // Cross-checked against a Python port of the same EMV TLV + CRC-16/
    // CCITT-FALSE algorithm, which was itself verified against a published
    // real-world PromptPay payload (phone 0899999999, static/no-amount
    // mode) before this Dart port was written.
    final payload = buildPromptPayPayload(promptPayId: '0812345678', amount: Decimal.parse('45.00'));

    expect(
      payload,
      '00020101021229370016A000000677010111011300668123456785303764540545.005802TH630479AF',
    );
  });

  test('payload structure decodes to the expected PromptPay fields', () {
    final payload = buildPromptPayPayload(promptPayId: '0812345678', amount: Decimal.parse('45.00'));
    final fields = Map.fromEntries(_parseTlv(payload).map((e) => MapEntry(e.$1, e.$2)));

    expect(fields['00'], '01'); // payload format indicator
    expect(fields['01'], '12'); // dynamic (amount present)
    expect(fields['53'], '764'); // THB
    expect(fields['54'], '45.00');
    expect(fields['58'], 'TH');
    expect(fields['63'], hasLength(4)); // CRC

    final merchantFields = Map.fromEntries(_parseTlv(fields['29']!).map((e) => MapEntry(e.$1, e.$2)));
    expect(merchantFields['00'], 'A000000677010111'); // PromptPay GUID
    // 0812345678 -> strip leading 0, prefix country code 66
    expect(merchantFields['01'], '0066812345678');
  });

  test('a 13-digit id is encoded as a citizen/tax ID, not a phone number', () {
    final payload = buildPromptPayPayload(promptPayId: '1234567890123', amount: Decimal.parse('10.00'));
    final fields = Map.fromEntries(_parseTlv(payload).map((e) => MapEntry(e.$1, e.$2)));
    final merchantFields = Map.fromEntries(_parseTlv(fields['29']!).map((e) => MapEntry(e.$1, e.$2)));

    expect(merchantFields.containsKey('02'), isTrue);
    expect(merchantFields['02'], '1234567890123');
    expect(merchantFields.containsKey('01'), isFalse);
  });

  test('non-digit characters in the promptpay id are stripped', () {
    final withDashes = buildPromptPayPayload(promptPayId: '081-234-5678', amount: Decimal.parse('1.00'));
    final plain = buildPromptPayPayload(promptPayId: '0812345678', amount: Decimal.parse('1.00'));
    expect(withDashes, plain);
  });
}
