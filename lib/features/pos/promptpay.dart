import 'package:decimal/decimal.dart';

String _tlv(String tag, String value) {
  final len = value.length.toString().padLeft(2, '0');
  return '$tag$len$value';
}

String _formatProxy(String promptPayId) {
  final digits = promptPayId.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 13) {
    // National ID / Tax ID, used as-is.
    return _tlv('02', digits);
  }
  // Mobile number: strip the leading 0, prefix with country code 66.
  final local = digits.startsWith('0') ? digits.substring(1) : digits;
  return _tlv('01', '0066$local');
}

int _crc16CcittFalse(String data) {
  var crc = 0xFFFF;
  for (final byte in data.codeUnits) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc & 0xFFFF;
}

/// Builds an EMV QR ("Thai QR Payment") payload for PromptPay per the Bank
/// of Thailand spec: nested TLV fields plus a CRC-16/CCITT-FALSE checksum
/// over everything before the CRC field itself.
///
/// [promptPayId] is a 10-digit mobile number or 13-digit citizen/tax ID.
/// The TLV encoding, phone-number proxy formatting, and CRC algorithm here
/// were verified against a published reference PromptPay payload before
/// being ported to Dart — see promptpay_test.dart.
String buildPromptPayPayload({required String promptPayId, required Decimal amount}) {
  final merchantInfo = _tlv('00', 'A000000677010111') + _formatProxy(promptPayId);

  final fields = <String>[
    _tlv('00', '01'), // payload format indicator
    _tlv('01', '12'), // point of initiation method: dynamic (amount included)
    _tlv('29', merchantInfo),
    _tlv('53', '764'), // transaction currency: THB
    _tlv('54', amount.toStringAsFixed(2)),
    _tlv('58', 'TH'), // country code
  ];

  final payloadWithoutCrc = '${fields.join()}6304';
  final crc = _crc16CcittFalse(payloadWithoutCrc).toRadixString(16).toUpperCase().padLeft(4, '0');
  return payloadWithoutCrc + crc;
}
