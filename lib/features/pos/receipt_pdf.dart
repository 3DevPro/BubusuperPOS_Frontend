import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/formatters.dart';
import '../settings/tenant_repository.dart';
import 'sales_repository.dart';

const _paymentMethodLabels = {'cash': 'เงินสด', 'transfer_qr': 'โอน/QR', 'card': 'บัตร'};

/// Renders as an 80mm-wide page by default (auto height) so it looks right
/// whether the cashier prints it on receipt paper or just shares the PDF —
/// pass a different [pageFormat] (e.g. PdfPageFormat.roll57 or a4) to match
/// the printer actually in use. Thai text needs an actual Thai-capable font
/// — the default PDF base fonts (Helvetica etc.) have no Thai glyphs — so
/// this fetches Noto Sans Thai via PdfGoogleFonts (cached after the first
/// call) rather than bundling a font file as an asset.
///
/// Renders as an abbreviated tax invoice (ใบกำกับภาษีอย่างย่อ) — header,
/// address, tax ID, branch, and a VAT breakdown — only when the tenant has
/// both VAT enabled and a tax ID on file; otherwise it's the same plain
/// receipt this always was, so tenants who haven't set up tax invoicing see
/// zero change.
Future<Uint8List> buildReceiptPdf({
  required SaleResultDto sale,
  required TenantSettingsDto tenant,
  PdfPageFormat? pageFormat,
}) async {
  final regular = await PdfGoogleFonts.notoSansThaiRegular();
  final bold = await PdfGoogleFonts.notoSansThaiBold();
  final doc = pw.Document();
  final isTaxInvoice = tenant.vatEnabled && tenant.taxId != null && tenant.taxId!.isNotEmpty;

  doc.addPage(
    pw.Page(
      pageFormat: pageFormat ?? PdfPageFormat.roll80,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(child: pw.Text(tenant.name, style: pw.TextStyle(font: bold, fontSize: 14))),
            if (isTaxInvoice) ...[
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text('ใบกำกับภาษีอย่างย่อ', style: pw.TextStyle(font: bold, fontSize: 11))),
              if (tenant.address != null && tenant.address!.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    tenant.address!,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              pw.Center(
                child: pw.Text(
                  'เลขประจำตัวผู้เสียภาษี ${tenant.taxId}'
                  '${(tenant.branchCode != null && tenant.branchCode!.isNotEmpty) ? ' สาขา ${tenant.branchCode}' : ''}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text(sale.receiptNo)),
            pw.Center(child: pw.Text(formatThaiDateTime(sale.createdAt), style: const pw.TextStyle(fontSize: 10))),
            pw.SizedBox(height: 8),
            pw.Divider(),
            for (final item in sale.items)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: pw.Text('${item.name} x${item.qty}')),
                    pw.Text(formatBaht(item.lineTotal)),
                  ],
                ),
              ),
            pw.Divider(),
            if (isTaxInvoice) ...[
              _row('มูลค่าสินค้า', formatBaht(sale.total - sale.tax)),
              _row('ภาษีมูลค่าเพิ่ม ${tenant.vatRate}%', formatBaht(sale.tax)),
              pw.SizedBox(height: 4),
              _row('รวมทั้งสิ้น', formatBaht(sale.total), bold: bold),
            ] else ...[
              _row('รวม', formatBaht(sale.subtotal)),
              if (sale.discount.toDouble() > 0) _row('ส่วนลด', '-${formatBaht(sale.discount)}'),
              if (sale.tax.toDouble() > 0) _row('ภาษีมูลค่าเพิ่ม', formatBaht(sale.tax)),
              if (sale.pointsDiscount.toDouble() > 0)
                _row('ใช้แต้ม ${formatPoints(sale.pointsRedeemed)} แต้ม', '-${formatBaht(sale.pointsDiscount)}'),
              pw.SizedBox(height: 4),
              _row('ยอดสุทธิ', formatBaht(sale.total), bold: bold),
            ],
            if (sale.refundedTotal.toDouble() > 0) _row('คืนเงินแล้ว', '-${formatBaht(sale.refundedTotal)}'),
            pw.SizedBox(height: 4),
            _row('ชำระโดย', _paymentMethodLabels[sale.paymentMethod] ?? sale.paymentMethod),
            if (sale.pointsEarned > 0) _row('แต้มที่ได้รับ', '+${formatPoints(sale.pointsEarned)} แต้ม'),
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text(
                (tenant.receiptFooter != null && tenant.receiptFooter!.isNotEmpty)
                    ? tenant.receiptFooter!
                    : 'ขอบคุณที่ใช้บริการ',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _row(String label, String value, {pw.Font? bold}) {
  final style = bold != null ? pw.TextStyle(font: bold) : null;
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [pw.Text(label, style: style), pw.Text(value, style: style)],
  );
}
