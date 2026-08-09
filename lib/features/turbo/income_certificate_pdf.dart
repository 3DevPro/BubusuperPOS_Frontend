import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/formatters.dart';
import 'turbo_repository.dart';

const _creditTierLabels = {'none': 'ยังไม่ปลดล็อก', 'tier_1': 'ระดับ 1 (ปลดล็อกแล้ว)'};

/// A4 document version of the income certificate the dashboard shows —
/// same Thai-font pattern as receipt_pdf.dart (the default PDF base fonts
/// have no Thai glyphs), sized for handing to a landlord/lender rather than
/// an 80mm receipt.
Future<Uint8List> buildIncomeCertificatePdf({required IncomeProfileDto profile, required String shopName}) async {
  final regular = await PdfGoogleFonts.notoSansThaiRegular();
  final bold = await PdfGoogleFonts.notoSansThaiBold();
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('ใบรับรองรายได้', style: pw.TextStyle(font: bold, fontSize: 22))),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text(shopName, style: const pw.TextStyle(fontSize: 14))),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'ออกโดยระบบ Turbo POS ณ วันที่ ${formatThaiDateTime(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Divider(),
              _row('ช่วงเวลาที่บันทึกข้อมูล', '${profile.windowDays} วันล่าสุด'),
              _row('จำนวนวันที่มีข้อมูล', '${profile.daysRecorded} วัน'),
              _row('จำนวนวันติดต่อกัน (streak)', '${profile.streakDays} วัน'),
              pw.Divider(),
              _row('รายได้เฉลี่ยต่อวัน', formatBaht(profile.avgDailyRevenue), bold: bold),
              _row('  · รายได้ที่ verify ได้ (QR/บัตร)', formatBaht(profile.verifiedAvgDailyRevenue)),
              _row('  · รายได้เงินสด (แจ้งเอง)', formatBaht(profile.cashAvgDailyRevenue)),
              _row(
                'สัดส่วนรายได้ที่ verify ได้',
                '${(profile.verifiedRatio.toDouble() * 100).toStringAsFixed(0)}%',
              ),
              pw.Divider(),
              _row('ระดับวงเงินที่ขอได้', _creditTierLabels[profile.creditTier] ?? profile.creditTier, bold: bold),
              _row('วงเงินที่ขอได้', formatBaht(profile.creditLimit), bold: bold),
              if (profile.nextTierInDays != null) _row('อีกกี่วันจะปลดล็อก', '${profile.nextTierInDays} วัน'),
              pw.SizedBox(height: 24),
              pw.Text(
                'เอกสารนี้สร้างจากข้อมูลการขายจริงในระบบ Turbo POS เพื่อใช้ประกอบการพิจารณาสินเชื่อ/เช่าพื้นที่ '
                'ตัวเลขคำนวณจากยอดขายที่บันทึกในระบบเท่านั้น ไม่ใช่เอกสารทางบัญชีอย่างเป็นทางการ',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _row(String label, String value, {pw.Font? bold}) {
  final style = bold != null ? pw.TextStyle(font: bold) : null;
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label, style: style), pw.Text(value, style: style)],
    ),
  );
}
