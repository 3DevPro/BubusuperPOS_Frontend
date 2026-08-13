import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import 'barcode_label_pdf.dart';
import 'product_providers.dart';
import 'product_repository.dart';

enum _LabelLayout { sheet, roll }

class BarcodeLabelScreen extends ConsumerStatefulWidget {
  const BarcodeLabelScreen({super.key});

  @override
  ConsumerState<BarcodeLabelScreen> createState() => _BarcodeLabelScreenState();
}

class _BarcodeLabelScreenState extends ConsumerState<BarcodeLabelScreen> {
  final Map<String, int> _copies = {};
  bool _missingOnly = false;
  _LabelLayout _layout = _LabelLayout.sheet;
  final _startAtController = TextEditingController(text: '1');
  bool _generating = false;
  bool _printing = false;
  String? _error;

  @override
  void dispose() {
    _startAtController.dispose();
    super.dispose();
  }

  void _toggle(ProductDto product, bool selected) {
    setState(() {
      if (selected) {
        _copies[product.id] = 1;
      } else {
        _copies.remove(product.id);
      }
    });
  }

  Future<void> _assignMissingBarcodes(List<ProductDto> selectedWithoutBarcode) async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await ref
          .read(productRepositoryProvider)
          .assignBarcodesBulk(productIds: [for (final p in selectedWithoutBarcode) p.id]);
      ref.invalidate(productListProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('สร้างบาร์โค้ดให้ ${selectedWithoutBarcode.length} รายการแล้ว')));
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'สร้างบาร์โค้ดไม่สำเร็จ';
      });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _print(List<ProductDto> products) async {
    final items = [
      for (final p in products)
        if (_copies[p.id] != null && p.barcode != null) LabelJobItem(product: p, copies: _copies[p.id]!),
    ];
    if (items.isEmpty) {
      setState(() => _error = 'เลือกสินค้าที่มีบาร์โค้ดแล้วอย่างน้อย 1 รายการ');
      return;
    }
    setState(() {
      _printing = true;
      _error = null;
    });
    try {
      final startAt = int.tryParse(_startAtController.text.trim()) ?? 1;
      await Printing.layoutPdf(
        name: 'สติกเกอร์บาร์โค้ด',
        onLayout: (_) => _layout == _LabelLayout.sheet
            ? buildLabelSheetPdf(items: items, startAtLabel: startAt)
            : buildLabelRollPdf(items: items),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'สร้าง PDF สติกเกอร์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('พิมพ์สติกเกอร์บาร์โค้ด')),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดสินค้าไม่สำเร็จ: $err')),
        data: (allProducts) {
          final products = _missingOnly ? allProducts.where((p) => p.barcode == null).toList() : allProducts;
          final selected = [for (final p in allProducts) if (_copies.containsKey(p.id)) p];
          final selectedWithoutBarcode = selected.where((p) => p.barcode == null).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FilterChip(
                  label: const Text('แสดงเฉพาะสินค้าที่ยังไม่มีบาร์โค้ด'),
                  selected: _missingOnly,
                  onSelected: (v) => setState(() => _missingOnly = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isSelected = _copies.containsKey(product.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (v) => _toggle(product, v ?? false),
                      title: Text(product.name),
                      subtitle: Text(product.barcode ?? 'ยังไม่มีบาร์โค้ด'),
                      secondary: isSelected
                          ? SizedBox(
                              width: 120,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => setState(() {
                                      final current = _copies[product.id] ?? 1;
                                      if (current > 1) _copies[product.id] = current - 1;
                                    }),
                                  ),
                                  Text('${_copies[product.id]}'),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () =>
                                        setState(() => _copies[product.id] = (_copies[product.id] ?? 1) + 1),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.inventory_2_outlined),
                                    tooltip: 'ตามจำนวนสต็อก',
                                    onPressed: () =>
                                        setState(() => _copies[product.id] = product.stockQty.clamp(1, 999)),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              if (selectedWithoutBarcode.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: OutlinedButton(
                    onPressed: _generating ? null : () => _assignMissingBarcodes(selectedWithoutBarcode),
                    child: _generating
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('สร้างบาร์โค้ดให้สินค้า ${selectedWithoutBarcode.length} รายการ'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<_LabelLayout>(
                            segments: const [
                              ButtonSegment(value: _LabelLayout.sheet, label: Text('แผ่น A4')),
                              ButtonSegment(value: _LabelLayout.roll, label: Text('ม้วน 40x30มม.')),
                            ],
                            selected: {_layout},
                            onSelectionChanged: (s) => setState(() => _layout = s.first),
                          ),
                        ),
                      ],
                    ),
                    if (_layout == _LabelLayout.sheet) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _startAtController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'เริ่มพิมพ์ที่ดวงที่ (สำหรับแผ่นที่ใช้ไปแล้วบางส่วน)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _printing ? null : () => _print(allProducts),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _printing
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('พิมพ์สติกเกอร์', style: TextStyle(fontSize: 16)),
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
