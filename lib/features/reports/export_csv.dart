import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../pos/checkout_screen.dart' show salesRepositoryProvider;

const _paymentMethodLabels = {'cash': 'เงินสด', 'transfer_qr': 'โอน/QR', 'card': 'บัตร'};
const _statusLabels = {
  'completed': 'สำเร็จ',
  'partially_refunded': 'คืนบางส่วน',
  'refunded': 'คืนแล้ว',
  'void': 'ยกเลิก',
};

/// Fetches the sales for whichever period the reports screen is currently
/// showing and shares them as a CSV file. Canned periods (today/7d/30d/...)
/// have no matching /sales date-filter of their own — GET /sales only
/// understands an explicit start_date/end_date — so this recomputes the
/// equivalent local calendar range client-side, using device-local time.
/// That's the same approximation the rest of the client already makes
/// everywhere it calls `.toLocal()`, and is accurate as long as the
/// cashier's device is in the shop's own timezone.
Future<void> exportSalesCsv({
  required WidgetRef ref,
  required String period,
  required DateTimeRange? range,
}) async {
  final effectiveRange = _rangeForPeriod(period, range);
  final sales = await ref
      .read(salesRepositoryProvider)
      .list(startDate: effectiveRange.start, endDate: effectiveRange.end);

  final buffer = StringBuffer();
  buffer.writeln(_csvRow(['วันที่', 'เลขที่ใบเสร็จ', 'ช่องทางชำระเงิน', 'สถานะ', 'ยอดรวม']));
  for (final sale in sales) {
    buffer.writeln(
      _csvRow([
        _formatDateTime(sale.createdAt),
        sale.receiptNo,
        _paymentMethodLabels[sale.paymentMethod] ?? sale.paymentMethod,
        _statusLabels[sale.status] ?? sale.status,
        sale.total.toString(),
      ]),
    );
  }

  // A UTF-8 BOM so Excel (which otherwise guesses Windows-1252) renders Thai
  // text correctly instead of mojibake.
  final bytes = Uint8List.fromList(utf8.encode('﻿$buffer'));
  final filename = 'sales_${_isoDate(effectiveRange.start)}_${_isoDate(effectiveRange.end)}.csv';
  await SharePlus.instance.share(
    ShareParams(files: [XFile.fromData(bytes, name: filename, mimeType: 'text/csv')]),
  );
}

DateTimeRange _rangeForPeriod(String period, DateTimeRange? custom) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  if (period == 'custom') {
    return custom ?? DateTimeRange(start: todayStart, end: todayStart);
  }
  if (period == 'yesterday') {
    final yesterday = todayStart.subtract(const Duration(days: 1));
    return DateTimeRange(start: yesterday, end: yesterday);
  }
  if (period == '7d') {
    return DateTimeRange(start: todayStart.subtract(const Duration(days: 6)), end: todayStart);
  }
  if (period == '30d') {
    return DateTimeRange(start: todayStart.subtract(const Duration(days: 29)), end: todayStart);
  }
  return DateTimeRange(start: todayStart, end: todayStart); // 'today' and any unknown value
}

String _csvRow(List<String> fields) => fields.map(_csvEscape).join(',');

String _csvEscape(String field) {
  if (field.contains(',') || field.contains('"') || field.contains('\n')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  return '${_isoDate(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
