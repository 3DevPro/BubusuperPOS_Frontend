import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import '../inventory/inventory_providers.dart';
import '../catalog/product_providers.dart';
import 'purchase_order_providers.dart';
import 'purchase_order_repository.dart';

const _statusLabels = {
  'ordered': 'สั่งซื้อแล้ว',
  'partially_received': 'รับของบางส่วน',
  'received': 'รับของครบแล้ว',
  'cancelled': 'ยกเลิกแล้ว',
};

class PurchaseOrderDetailScreen extends ConsumerStatefulWidget {
  const PurchaseOrderDetailScreen({super.key, required this.purchaseOrderId});
  final String purchaseOrderId;

  @override
  ConsumerState<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends ConsumerState<PurchaseOrderDetailScreen> {
  final Map<String, int> _selectedQty = {};
  bool _submitting = false;
  String? _error;

  void _receiveAll(PurchaseOrderResultDto po) {
    setState(() {
      for (final item in po.items) {
        _selectedQty[item.id] = item.remainingQty;
      }
    });
  }

  Future<void> _confirmAndReceive(PurchaseOrderResultDto po) async {
    final targets = _selectedQty.entries.where((e) => e.value > 0).toList();
    if (targets.isEmpty) {
      setState(() => _error = 'เลือกจำนวนที่จะรับอย่างน้อย 1 ชิ้น');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันรับของ'),
        content: const Text('สต็อกสินค้าที่เลือกจะถูกเพิ่มเข้าคลังทันที ยืนยันหรือไม่?'),
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
          .read(purchaseOrderRepositoryProvider)
          .receive(po.id, [for (final e in targets) PurchaseOrderReceiveItemRequest(purchaseOrderItemId: e.key, qty: e.value)]);
      ref.invalidate(purchaseOrderDetailProvider(widget.purchaseOrderId));
      ref.invalidate(purchaseOrderListProvider);
      ref.invalidate(productListProvider);
      ref.invalidate(lowStockProvider);
      if (mounted) setState(() => _selectedQty.clear());
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'รับของไม่สำเร็จ ลองอีกครั้ง';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(PurchaseOrderResultDto po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกใบสั่งซื้อนี้?'),
        content: const Text('ใช้ได้เฉพาะใบที่ยังไม่ได้รับของเลย'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ไม่ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ยกเลิกใบสั่งซื้อ')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(purchaseOrderRepositoryProvider).cancel(po.id);
      ref.invalidate(purchaseOrderDetailProvider(widget.purchaseOrderId));
      ref.invalidate(purchaseOrderListProvider);
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'ยกเลิกไม่สำเร็จ';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final poAsync = ref.watch(purchaseOrderDetailProvider(widget.purchaseOrderId));

    return Scaffold(
      appBar: AppBar(
        title: Text(poAsync.asData?.value.orderNo ?? 'ใบสั่งซื้อ'),
        actions: [
          poAsync.maybeWhen(
            data: (po) => po.canReceive
                ? TextButton(
                    onPressed: () => _receiveAll(po),
                    child: const Text('รับทั้งหมด', style: TextStyle(color: Colors.white)),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: poAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $err')),
        data: (po) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_statusLabels[po.status] ?? po.status, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(formatThaiDateTime(po.createdAt)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final item in po.items)
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
                                          ? 'รับแล้ว ${item.qtyReceived}/${item.qtyOrdered}'
                                          : 'สั่ง ${item.qtyOrdered} ชิ้น'
                                                '${item.qtyReceived > 0 ? " • รับแล้ว ${item.qtyReceived}" : ""}',
                                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                                    ),
                                    Text(
                                      'ต้นทุน ${formatBaht(item.unitCost)}/หน่วย',
                                      style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (po.canReceive && item.remainingQty > 0)
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
                    if (po.notes != null && po.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('หมายเหตุ: ${po.notes}', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ],
                  ],
                ),
              ),
              if (po.canReceive) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          if (po.canCancel) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _submitting ? null : () => _cancel(po),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('ยกเลิกใบสั่งซื้อ'),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: _submitting ? null : () => _confirmAndReceive(po),
                              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                              child: _submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('รับของเข้าสต็อก'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
