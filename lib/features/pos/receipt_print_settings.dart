import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paper width the receipt is laid out for. This is a per-device choice
/// (which physical printer is hooked up to this till), not a tenant
/// setting, so it lives in shared_preferences like the offline sale queue
/// rather than going through the backend.
enum ReceiptPaperSize {
  mm58('58mm', PdfPageFormat.roll57),
  mm80('80mm', PdfPageFormat.roll80),
  a4('A4', PdfPageFormat.a4);

  const ReceiptPaperSize(this.label, this.pageFormat);
  final String label;
  final PdfPageFormat pageFormat;
}

class ReceiptPrintSettings {
  const ReceiptPrintSettings({required this.paperSize, required this.autoPrintAfterCheckout});

  final ReceiptPaperSize paperSize;
  final bool autoPrintAfterCheckout;

  ReceiptPrintSettings copyWith({ReceiptPaperSize? paperSize, bool? autoPrintAfterCheckout}) =>
      ReceiptPrintSettings(
        paperSize: paperSize ?? this.paperSize,
        autoPrintAfterCheckout: autoPrintAfterCheckout ?? this.autoPrintAfterCheckout,
      );

  factory ReceiptPrintSettings.fromJson(Map<String, dynamic> json) => ReceiptPrintSettings(
    paperSize: ReceiptPaperSize.values.firstWhere(
      (s) => s.name == json['paper_size'],
      orElse: () => ReceiptPaperSize.mm80,
    ),
    autoPrintAfterCheckout: json['auto_print'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {'paper_size': paperSize.name, 'auto_print': autoPrintAfterCheckout};

  static const defaults = ReceiptPrintSettings(paperSize: ReceiptPaperSize.mm80, autoPrintAfterCheckout: false);
}

class ReceiptPrintSettingsNotifier extends AsyncNotifier<ReceiptPrintSettings> {
  static const _prefsKey = 'receipt_print_settings';

  @override
  Future<ReceiptPrintSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return ReceiptPrintSettings.defaults;
    return ReceiptPrintSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> updateSettings({ReceiptPaperSize? paperSize, bool? autoPrintAfterCheckout}) async {
    final current = state.valueOrNull ?? await future;
    final next = current.copyWith(paperSize: paperSize, autoPrintAfterCheckout: autoPrintAfterCheckout);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
    state = AsyncData(next);
  }
}

final receiptPrintSettingsProvider = AsyncNotifierProvider<ReceiptPrintSettingsNotifier, ReceiptPrintSettings>(
  ReceiptPrintSettingsNotifier.new,
);
