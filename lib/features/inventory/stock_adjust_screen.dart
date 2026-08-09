import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/product_providers.dart';
import 'inventory_providers.dart';

class StockAdjustScreen extends ConsumerStatefulWidget {
  const StockAdjustScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<StockAdjustScreen> createState() => _StockAdjustScreenState();
}

class _StockAdjustScreenState extends ConsumerState<StockAdjustScreen> {
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'purchase'; // purchase (+) or waste (-); 'adjust' covers manual corrections
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      setState(() => _error = 'กรอกจำนวนให้ถูกต้อง');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final signedQty = _type == 'waste' ? -qty : qty;
      await ref
          .read(inventoryRepositoryProvider)
          .adjustStock(
            productId: widget.productId,
            qtyDelta: signedQty,
            type: _type == 'waste' ? 'waste' : _type,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );
      ref.invalidate(productListProvider);
      ref.invalidate(lowStockProvider);
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'ปรับสต็อกไม่สำเร็จ';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productByIdProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(title: const Text('ปรับสต็อก')),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $err')),
        data: (product) {
          if (product == null) {
            return const Center(child: Text('ไม่พบสินค้านี้'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('สต็อกปัจจุบัน: ${product.stockQty} ชิ้น'),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'purchase', label: Text('รับเข้า'), icon: Icon(Icons.add_box)),
                  ButtonSegment(value: 'waste', label: Text('ตัดออก/ของเสีย'), icon: Icon(Icons.remove_circle)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'หมายเหตุ (ไม่บังคับ)', border: OutlineInputBorder()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }
}
