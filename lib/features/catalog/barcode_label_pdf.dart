import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/formatters.dart';
import 'product_repository.dart';

/// One (product, copies) pair queued for printing — a product picked twice
/// with different copy counts isn't meaningful, so the label screen keeps
/// this as a flat list keyed by product.
class LabelJobItem {
  const LabelJobItem({required this.product, required this.copies});
  final ProductDto product;
  final int copies;
}

const _labelSheetCols = 5;
const _labelSheetRows = 13;
// 38.1x21.2mm — the common Avery-equivalent A4 label stock (65 labels/sheet)
// sold for POS/office use in Thailand.
const _labelWidthMm = 38.1;
const _labelHeightMm = 21.2;

List<LabelJobItem> _expand(List<LabelJobItem> items) => [
  for (final item in items)
    for (var i = 0; i < item.copies; i++) LabelJobItem(product: item.product, copies: 1),
];

/// A4 sheet of labels in a 5x13 grid. [startAtLabel] (1-indexed) lets the
/// cashier resume on a partially-used sheet instead of wasting the labels
/// already peeled off before it.
Future<Uint8List> buildLabelSheetPdf({required List<LabelJobItem> items, int startAtLabel = 1}) async {
  final regular = await PdfGoogleFonts.notoSansThaiRegular();
  final flat = _expand(items);
  final offset = (startAtLabel - 1).clamp(0, _labelSheetCols * _labelSheetRows - 1);

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      theme: pw.ThemeData.withFont(base: regular),
      build: (context) => [
        pw.GridView(
          crossAxisCount: _labelSheetCols,
          childAspectRatio: _labelWidthMm / _labelHeightMm,
          children: [
            for (var i = 0; i < offset; i++) pw.SizedBox(),
            for (final item in flat) _label(item.product, regular),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

/// One label per page at exactly the roll's dimensions — for a thermal
/// label-roll printer instead of a sheet-fed one.
Future<Uint8List> buildLabelRollPdf({required List<LabelJobItem> items}) async {
  final regular = await PdfGoogleFonts.notoSansThaiRegular();
  final flat = _expand(items);
  final format = PdfPageFormat(_labelWidthMm * PdfPageFormat.mm, _labelHeightMm * PdfPageFormat.mm, marginAll: 1 * PdfPageFormat.mm);

  final doc = pw.Document();
  for (final item in flat) {
    doc.addPage(
      pw.Page(pageFormat: format, theme: pw.ThemeData.withFont(base: regular), build: (context) => _label(item.product, regular)),
    );
  }
  return doc.save();
}

pw.Widget _label(ProductDto product, pw.Font font) {
  return pw.Container(
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.all(2),
    child: pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          product.name,
          maxLines: 2,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: font, fontSize: 7),
        ),
        pw.Text(formatBaht(product.sellPrice), style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold)),
        if (product.barcode != null)
          pw.BarcodeWidget(
            data: product.barcode!,
            barcode: pw.Barcode.ean13(),
            drawText: true,
            width: 90,
            height: 28,
            textStyle: pw.TextStyle(font: font, fontSize: 6),
          ),
      ],
    ),
  );
}
