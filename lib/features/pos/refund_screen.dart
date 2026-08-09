import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../shared/formatters.dart';
import 'checkout_screen.dart' show salesRepositoryProvider;
import 'receipt_screen.dart' show saleDetailProvider;
import 'sales_repository.dart';

class RefundScreen extends ConsumerStatefulWidget {
  const RefundScreen({super.key, required this.saleId});
  final String saleId;

  @override
  ConsumerState<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends ConsumerState<RefundScreen> {
  final _clientUuid = const Uuid().v4();
  final _reasonController = TextEditingController();
  final Map<String, int> _selectedQty = {};
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _refundAll(SaleResultDto sale) {
    setState(() {
      for (final item in sale.items) {
        _selectedQty[item.id] = item.remainingQty;
      }
    });
  }

  Decimal _previewAmount(SaleResultDto sale) {
    // Same proportional-share formula as backend refund_service.refund_sale —
    // preview only, the server recomputes authoritatively on submit.
    Decimal total = Decimal.zero;
    for (final item in sale.items) {
      final qty = _selectedQty[item.id] ?? 0;
      if (qty == 0 || item.qty == 0) continue;
      final unitNet = (item.lineTotal / Decimal.fromInt(item.qty)).toDecimal(scaleOnInfinitePrecision: 6);
      final gross = unitNet * Decimal.fromInt(qty);
      final discountShare = sale.subtotal == Decimal.zero
          ? Decimal.zero
          : (sale.discount * gross / sale.subtotal).toDecimal(scaleOnInfinitePrecision: 6);
      final netBeforeTax = gross - discountShare;
      // Mirror refund_service.py exactly: in price-includes-tax mode the
      // refund amount IS the net share (tax is only disclosed, never added
      // on top) — adding tax here would overstate what the backend actually
      // refunds, same mistake the checkout math would make if it ignored
      // priceIncludesTax.
      var amount = netBeforeTax;
      if (!sale.priceIncludesTax && sale.tax > Decimal.zero && sale.total > Decimal.zero) {
        final taxFraction = (sale.tax / sale.total).toDecimal(scaleOnInfinitePrecision: 6);
        amount = netBeforeTax + netBeforeTax * taxFraction;
      }
      // Round.toDecimal() truncates by default — round(scale: 2) matches the
      // backend's per-line ROUND_HALF_UP quantize in refund_service.py.
      total += amount.round(scale: 2);
    }
    return total;
  }

  Future<void> _confirmAndSubmit(SaleResultDto sale) async {
    final targets = _selectedQty.entries.where((e) => e.value > 0).toList();
    if (targets.isEmpty) {
      setState(() => _error = 'เลือกจำนวนที่จะคืนอย่างน้อย 1 ชิ้น');
      return;
    }

    final preview = _previewAmount(sale);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการคืนเงิน'),
        content: Text('คืนเงิน ${formatBaht(preview)} ให้ลูกค้า และเติมสต็อกคืน ยืนยันหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(salesRepositoryProvider)
          .refund(
            saleId: widget.saleId,
            clientUuid: _clientUuid,
            items: [for (final e in targets) RefundItemRequest(saleItemId: e.key, qty: e.value)],
            reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
          );
      ref.invalidate(saleDetailProvider(widget.saleId));
      if (mounted) context.pop();
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null)
            ? data['detail'].toString()
            : 'คืนเงินไม่สำเร็จ ลองอีกครั้ง';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saleAsync = ref.watch(saleDetailProvider(widget.saleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('คืนสินค้า'),
        actions: [
          saleAsync.maybeWhen(
            data: (sale) => TextButton(
              onPressed: () => _refundAll(sale),
              child: const Text('คืนทั้งหมด', style: TextStyle(color: Colors.white)),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: saleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $err')),
        data: (sale) {
          if (!sale.canRefund) {
            return const Center(child: Text('บิลนี้คืนเงินไม่ได้แล้ว (คืนครบแล้ว หรือยกเลิกแล้ว)'));
          }
          final preview = _previewAmount(sale);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final item in sale.items)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(
                                      item.remainingQty == 0
                                          ? 'คืนแล้ว ${item.refundedQty}/${item.qty}'
                                          : 'ซื้อ ${item.qty} ชิ้น'
                                                '${item.refundedQty > 0 ? " • คืนแล้ว ${item.refundedQty}" : ""}',
                                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.remainingQty > 0)
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: (_selectedQty[item.id] ?? 0) > 0
                                          ? () => setState(() => _selectedQty[item.id] = (_selectedQty[item.id] ?? 0) - 1)
                                          : null,
                                    ),
                                    Text('${_selectedQty[item.id] ?? 0}', style: const TextStyle(fontSize: 16)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: (_selectedQty[item.id] ?? 0) < item.remainingQty
                                          ? () => setState(() => _selectedQty[item.id] = (_selectedQty[item.id] ?? 0) + 1)
                                          : null,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reasonController,
                      decoration: const InputDecoration(labelText: 'เหตุผล (ไม่บังคับ)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ยอดคืนโดยประมาณ', style: TextStyle(fontSize: 16)),
                        Text(
                          formatBaht(preview),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : () => _confirmAndSubmit(sale),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: _submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('คืนเงิน', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
