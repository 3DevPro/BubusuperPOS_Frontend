import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../shared/formatters.dart';
import '../auth/auth_provider.dart';
import '../settings/settings_providers.dart';
import '../settings/tenant_repository.dart';
import 'checkout_screen.dart' show salesRepositoryProvider;
import 'receipt_pdf.dart';
import 'receipt_print_settings.dart';
import 'sales_repository.dart';

final saleDetailProvider = FutureProvider.autoDispose.family<SaleResultDto, String>((ref, saleId) {
  return ref.watch(salesRepositoryProvider).get(saleId);
});

const _paymentMethodLabels = {'cash': 'เงินสด', 'transfer_qr': 'โอน/QR', 'card': 'บัตร'};
const _saleStatusLabels = {
  'completed': null, // don't clutter the normal case with a badge
  'partially_refunded': 'คืนเงินบางส่วน',
  'refunded': 'คืนเงินแล้ว',
  'void': 'ยกเลิกแล้ว',
};

class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.saleId, this.autoPrint = false});
  final String saleId;
  // Set only on the navigation straight out of checkout (see checkout_screen
  // .dart) — never on a later visit from sales history — so the "print
  // automatically after checkout" setting doesn't reprint every time the
  // receipt is reopened.
  final bool autoPrint;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  bool _sharing = false;
  bool _printing = false;
  bool _autoPrintTriggered = false;

  TenantSettingsDto? get _tenant => ref.read(tenantSettingsProvider).asData?.value;

  Future<void> _shareReceipt(SaleResultDto sale) async {
    final tenant = _tenant;
    if (tenant == null) return;
    setState(() => _sharing = true);
    try {
      final bytes = await buildReceiptPdf(sale: sale, tenant: tenant);
      await Printing.sharePdf(bytes: bytes, filename: '${sale.receiptNo}.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('สร้างใบเสร็จ PDF ไม่สำเร็จ')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _printReceipt(SaleResultDto sale) async {
    final tenant = _tenant;
    if (tenant == null) return;
    final paperSize = ref.read(receiptPrintSettingsProvider).asData?.value.paperSize ?? ReceiptPaperSize.mm80;
    setState(() => _printing = true);
    try {
      await Printing.layoutPdf(
        name: sale.receiptNo,
        format: paperSize.pageFormat,
        onLayout: (format) => buildReceiptPdf(sale: sale, tenant: tenant, pageFormat: format),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('พิมพ์ใบเสร็จไม่สำเร็จ')));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  void _showPrintSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final settingsAsync = ref.watch(receiptPrintSettingsProvider);
          final settings = settingsAsync.valueOrNull ?? ReceiptPrintSettings.defaults;
          return AlertDialog(
            title: const Text('ตั้งค่าการพิมพ์'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ขนาดกระดาษ'),
                const SizedBox(height: 8),
                RadioGroup<ReceiptPaperSize>(
                  groupValue: settings.paperSize,
                  onChanged: (v) => ref.read(receiptPrintSettingsProvider.notifier).updateSettings(paperSize: v),
                  child: Column(
                    children: [
                      for (final size in ReceiptPaperSize.values)
                        RadioListTile<ReceiptPaperSize>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(size.label),
                          value: size,
                        ),
                    ],
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('พิมพ์อัตโนมัติหลังชำระเงิน'),
                  value: settings.autoPrintAfterCheckout,
                  onChanged: (v) =>
                      ref.read(receiptPrintSettingsProvider.notifier).updateSettings(autoPrintAfterCheckout: v),
                ),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('เสร็จสิ้น'))],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saleAsync = ref.watch(saleDetailProvider(widget.saleId));
    final tenantAsync = ref.watch(tenantSettingsProvider);
    final printSettingsAsync = ref.watch(receiptPrintSettingsProvider);
    final role = ref.watch(authControllerProvider).me?['role'];
    final canRefund = role == 'owner' || role == 'manager';

    if (widget.autoPrint && !_autoPrintTriggered) {
      final sale = saleAsync.valueOrNull;
      final settings = printSettingsAsync.valueOrNull;
      if (sale != null && tenantAsync.hasValue && settings != null && settings.autoPrintAfterCheckout) {
        _autoPrintTriggered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _printReceipt(sale));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ใบเสร็จ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'ตั้งค่าการพิมพ์',
            onPressed: () => _showPrintSettings(context),
          ),
          saleAsync.maybeWhen(
            data: (sale) => IconButton(
              icon: _printing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.print),
              tooltip: 'พิมพ์ใบเสร็จ',
              onPressed: _printing ? null : () => _printReceipt(sale),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          saleAsync.maybeWhen(
            data: (sale) => IconButton(
              icon: _sharing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.share),
              tooltip: 'แชร์ใบเสร็จ',
              onPressed: _sharing ? null : () => _shareReceipt(sale),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          saleAsync.maybeWhen(
            data: (sale) => (canRefund && sale.canRefund)
                ? TextButton(
                    onPressed: () => context.push('/receipt/${widget.saleId}/refund'),
                    child: const Text('คืนสินค้า', style: TextStyle(color: Colors.white)),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: saleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดใบเสร็จไม่สำเร็จ: $err')),
        data: (sale) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 56),
                  const SizedBox(height: 8),
                  Text(sale.receiptNo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(formatThaiDateTime(sale.createdAt)),
                  if (_saleStatusLabels[sale.status] != null) ...[
                    const SizedBox(height: 4),
                    Chip(label: Text(_saleStatusLabels[sale.status]!)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (sale.warnings.isNotEmpty)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final w in sale.warnings) Text('⚠️ $w')],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final item in sale.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text('${item.name} x${item.qty}')),
                            Text(formatBaht(item.lineTotal)),
                          ],
                        ),
                      ),
                    const Divider(),
                    _summaryRow('รวม', sale.subtotal),
                    if (sale.discount.toDouble() > 0) _summaryRow('ส่วนลด', -sale.discount),
                    if (sale.tax.toDouble() > 0) _summaryRow('ภาษีมูลค่าเพิ่ม', sale.tax),
                    if (sale.pointsDiscount.toDouble() > 0)
                      _summaryRow('ใช้แต้ม ${formatPoints(sale.pointsRedeemed)} แต้ม', -sale.pointsDiscount),
                    _summaryRow('ยอดสุทธิ', sale.total, bold: true),
                    if (sale.refundedTotal.toDouble() > 0) ...[
                      const SizedBox(height: 4),
                      _summaryRow('คืนเงินแล้ว', -sale.refundedTotal),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ชำระโดย'),
                        Text(_paymentMethodLabels[sale.paymentMethod] ?? sale.paymentMethod),
                      ],
                    ),
                    if (sale.pointsEarned > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('แต้มที่ได้รับ'),
                          Text('+${formatPoints(sale.pointsEarned)} แต้ม'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/pos'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('เสร็จสิ้น', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, Decimal amount, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 18 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(formatBaht(amount), style: style)],
      ),
    );
  }
}
