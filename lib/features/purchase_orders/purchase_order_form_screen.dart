import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import '../catalog/product_providers.dart';
import '../catalog/product_repository.dart';
import '../suppliers/supplier_providers.dart';
import 'purchase_order_providers.dart';
import 'purchase_order_repository.dart';

class _POLine {
  _POLine(this.product)
    : qtyController = TextEditingController(text: '1'),
      costController = TextEditingController(text: product.costPrice.toString());

  final ProductDto product;
  final TextEditingController qtyController;
  final TextEditingController costController;

  void dispose() {
    qtyController.dispose();
    costController.dispose();
  }
}

class PurchaseOrderFormScreen extends ConsumerStatefulWidget {
  const PurchaseOrderFormScreen({super.key});

  @override
  ConsumerState<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends ConsumerState<PurchaseOrderFormScreen> {
  final _notesController = TextEditingController();
  final _lines = <_POLine>[];
  String? _supplierId;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _addProduct() async {
    final picked = await showModalBottomSheet<ProductDto>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: const _ProductPickerSheet(),
      ),
    );
    if (picked == null) return;
    final existing = _lines.indexWhere((l) => l.product.id == picked.id);
    if (existing >= 0) return; // already added — adjust qty inline instead
    setState(() => _lines.add(_POLine(picked)));
  }

  void _removeLine(_POLine line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  Future<void> _submit() async {
    if (_supplierId == null) {
      setState(() => _error = 'เลือกซัพพลายเออร์');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'เพิ่มสินค้าอย่างน้อย 1 รายการ');
      return;
    }

    final items = <PurchaseOrderItemRequest>[];
    for (final line in _lines) {
      final qty = int.tryParse(line.qtyController.text.trim());
      final cost = Decimal.tryParse(line.costController.text.trim());
      if (qty == null || qty <= 0 || cost == null || cost < Decimal.zero) {
        setState(() => _error = 'ตรวจสอบจำนวนและต้นทุนของ "${line.product.name}"');
        return;
      }
      items.add(PurchaseOrderItemRequest(productId: line.product.id, qty: qty, unitCost: cost));
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final po = await ref
          .read(purchaseOrderRepositoryProvider)
          .create(supplierId: _supplierId!, items: items, notes: _notesController.text.trim());
      ref.invalidate(purchaseOrderListProvider);
      if (mounted) context.pushReplacement('/purchase-orders/${po.id}');
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'สั่งซื้อไม่สำเร็จ';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('สั่งซื้อสินค้าใหม่')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          suppliersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('โหลดซัพพลายเออร์ไม่สำเร็จ: $err'),
            data: (suppliers) => DropdownButtonFormField<String>(
              initialValue: _supplierId,
              decoration: const InputDecoration(labelText: 'ซัพพลายเออร์ *', border: OutlineInputBorder()),
              items: [for (final s in suppliers) DropdownMenuItem(value: s.id, child: Text(s.name))],
              onChanged: (value) => setState(() => _supplierId = value),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/suppliers/new'),
              child: const Text('ยังไม่มีในลิสต์? เพิ่มซัพพลายเออร์ใหม่'),
            ),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('รายการสินค้า', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('เพิ่มสินค้า')),
            ],
          ),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('ยังไม่มีสินค้าในใบสั่งซื้อ'),
            ),
          for (final line in _lines)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: line.qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'จำนวน', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: line.costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'ต้นทุน/หน่วย', prefixText: '฿', isDense: true),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeLine(line),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
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
                : const Text('สร้างใบสั่งซื้อ'),
          ),
        ],
      ),
    );
  }
}

/// Search-and-pick a product to add as a line item — same shape as
/// CustomerPickerSheet, minus the quick-add (products are managed from the
/// catalog screen, not created inline mid-purchase-order).
class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  Future<List<ProductDto>>? _future;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    setState(() {
      _future = ref.read(productRepositoryProvider).list(search: value.isEmpty ? null : value);
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'ค้นหาสินค้า ชื่อ/รหัส/บาร์โค้ด',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<ProductDto>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('โหลดสินค้าไม่สำเร็จ: ${snapshot.error}'));
              }
              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return const Center(child: Text('ไม่พบสินค้า'));
              }
              return ListView.separated(
                itemCount: products.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text('${formatBaht(product.sellPrice)} • เหลือ ${product.stockQty} ชิ้น'),
                    onTap: () => Navigator.of(context).pop(product),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
