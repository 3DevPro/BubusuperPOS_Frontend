import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../shared/formatters.dart';
import '../settings/settings_providers.dart';
import 'cart_notifier.dart';
import 'offline/network_error.dart';
import 'offline/offline_sale_queue.dart';
import 'offline/pending_sale.dart';
import 'promptpay.dart';
import 'sales_repository.dart';
import 'tax_calc.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(apiClientProvider));
});

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  // Generated once and reused across retries of the SAME checkout attempt —
  // that's what makes a resubmission after a network hiccup idempotent on
  // the backend instead of double-charging the sale.
  final _clientUuid = const Uuid().v4();
  final _receivedController = TextEditingController();

  String _paymentMethod = 'cash';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }

  Future<void> _submit(CartState cart) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final sale = await ref
          .read(salesRepositoryProvider)
          .checkout(
            clientUuid: _clientUuid,
            items: [
              for (final line in cart.lines)
                CheckoutItem(productId: line.product.id, qty: line.qty, discount: line.discount),
            ],
            discount: cart.discount,
            paymentMethod: _paymentMethod,
            customerId: cart.customer?.id,
            redeemPoints: cart.pointsToRedeem,
          );
      ref.read(cartProvider.notifier).clear();
      if (mounted) context.go('/receipt/${sale.id}');
    } on DioException catch (e) {
      if (isNetworkError(e)) {
        // เน็ตหลุด — เก็บออเดอร์ไว้ในเครื่องด้วย client_uuid เดิม แล้วปล่อยให้
        // แคชเชียร์ทำงานต่อได้เลย ตัว offline sync service จะส่งซ้ำอัตโนมัติ
        // เมื่อเน็ตกลับมา (backend รองรับ idempotent retry อยู่แล้ว)
        await ref
            .read(offlineSaleQueueProvider.notifier)
            .enqueue(
              PendingSale(
                clientUuid: _clientUuid,
                items: [
                  for (final line in cart.lines) PendingSaleItem(productId: line.product.id, qty: line.qty),
                ],
                discount: cart.discount.toString(),
                paymentMethod: _paymentMethod,
                createdAt: DateTime.now(),
                customerId: cart.customer?.id,
                redeemPoints: cart.pointsToRedeem,
              ),
            );
        ref.read(cartProvider.notifier).clear();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('บันทึกออเดอร์ไว้แล้ว จะส่งอัตโนมัติเมื่อเน็ตกลับมา')));
          context.go('/pos');
        }
        return;
      }
      final data = e.response?.data;
      final message = (data is Map && data['detail'] != null)
          ? data['detail'].toString()
          : 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองกดยืนยันอีกครั้ง';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final settingsAsync = ref.watch(tenantSettingsProvider);
    final received = Decimal.tryParse(_receivedController.text) ?? Decimal.zero;

    final settings = settingsAsync.asData?.value;
    final totals = calcTotals(
      lineTotals: [for (final line in cart.lines) line.lineTotal],
      saleDiscount: cart.discount,
      vatEnabled: settings?.vatEnabled ?? false,
      vatRate: settings?.vatRate ?? Decimal.zero,
      priceIncludesTax: settings?.priceIncludesTax ?? true,
    );
    // Preview only — the server recomputes this authoritatively from the
    // tenant's point_value_baht at commit time, same disclaimer as totals
    // above.
    final pointsDiscount = cart.pointsToRedeem == 0
        ? Decimal.zero
        : (Decimal.fromInt(cart.pointsToRedeem) * (settings?.pointValueBaht ?? Decimal.zero));
    final cappedPointsDiscount = pointsDiscount > totals.total ? totals.total : pointsDiscount;
    final payableTotal = totals.total - cappedPointsDiscount;
    final change = received - payableTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('ชำระเงิน')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow('รวม', formatBaht(totals.subtotal)),
                  if (totals.discount > Decimal.zero) _SummaryRow('ส่วนลด', '-${formatBaht(totals.discount)}'),
                  if (settings?.vatEnabled ?? false)
                    _SummaryRow('ภาษีมูลค่าเพิ่ม (โดยประมาณ)', formatBaht(totals.tax)),
                  if (cart.customer != null) _SummaryRow('ลูกค้า', cart.customer!.name),
                  if (cappedPointsDiscount > Decimal.zero)
                    _SummaryRow(
                      'ใช้แต้ม ${formatPoints(cart.pointsToRedeem)} แต้ม',
                      '-${formatBaht(cappedPointsDiscount)}',
                    ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ยอดชำระ', style: TextStyle(fontSize: 16)),
                      Text(
                        formatBaht(payableTotal),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (cart.stockWarnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final w in cart.stockWarnings)
                      Text('⚠️ $w', style: const TextStyle(color: Colors.orange)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'cash', label: Text('เงินสด'), icon: Icon(Icons.payments)),
              ButtonSegment(value: 'transfer_qr', label: Text('โอน/QR'), icon: Icon(Icons.qr_code)),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: (selection) => setState(() => _paymentMethod = selection.first),
          ),
          if (_paymentMethod == 'cash') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _receivedController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'รับเงินมา',
                prefixText: '฿ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('เงินทอน', style: TextStyle(fontSize: 16)),
                Text(
                  formatBaht(change < Decimal.zero ? Decimal.zero : change),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: change < Decimal.zero ? Colors.red : null,
                  ),
                ),
              ],
            ),
          ],
          if (_paymentMethod == 'transfer_qr') ...[const SizedBox(height: 16), _PromptPayQr(amount: payableTotal)],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : () => _submit(cart),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('ยืนยันชำระเงิน', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value)]),
    );
  }
}

class _PromptPayQr extends ConsumerWidget {
  const _PromptPayQr({required this.amount});
  final Decimal amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(tenantSettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      error: (err, _) => Text('โหลดข้อมูลร้านไม่สำเร็จ: $err', style: const TextStyle(color: Colors.red)),
      data: (settings) {
        final promptpayId = settings.promptpayId;
        if (promptpayId == null) {
          return Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('ยังไม่ได้ตั้งค่าเลขพร้อมเพย์ของร้าน'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => context.push('/settings'),
                    child: const Text('ไปตั้งค่า'),
                  ),
                ],
              ),
            ),
          );
        }

        final payload = buildPromptPayPayload(promptPayId: promptpayId, amount: amount);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                QrImageView(data: payload, size: 220, backgroundColor: Colors.white),
                const SizedBox(height: 8),
                Text('สแกนจ่าย ${formatBaht(amount)} ผ่านแอปธนาคาร'),
              ],
            ),
          ),
        );
      },
    );
  }
}
