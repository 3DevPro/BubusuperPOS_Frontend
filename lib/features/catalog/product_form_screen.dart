import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/barcode_scanner_screen.dart';
import 'product_providers.dart';
import 'product_repository.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});
  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockQtyController = TextEditingController();
  final _lowStockController = TextEditingController(text: '5');
  final _imageUrlController = TextEditingController();

  String? _categoryId;
  bool _trackStock = true;
  bool _submitting = false;
  String? _error;
  bool _loadedInitialValues = false;

  bool _lookingUp = false;
  ProductLookupDto? _referencePrice;

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _sellPriceController.dispose();
    _costPriceController.dispose();
    _stockQtyController.dispose();
    _lowStockController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _fillFrom(ProductDto product) {
    _nameController.text = product.name;
    _skuController.text = product.sku ?? '';
    _barcodeController.text = product.barcode ?? '';
    _sellPriceController.text = product.sellPrice.toString();
    _costPriceController.text = product.costPrice.toString();
    _stockQtyController.text = '${product.stockQty}';
    _lowStockController.text = '${product.lowStockThreshold}';
    _imageUrlController.text = product.imageUrl ?? '';
    _categoryId = product.categoryId;
    _trackStock = product.trackStock;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final sellPrice = Decimal.tryParse(_sellPriceController.text.trim());
    if (name.isEmpty || sellPrice == null) {
      setState(() => _error = 'กรอกชื่อสินค้าและราคาขายให้ถูกต้อง');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(productRepositoryProvider);
      if (widget.isEditing) {
        await repo.update(widget.productId!, {
          'name': name,
          'sku': _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
          'barcode': _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
          'category_id': _categoryId,
          'image_url': _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
          'sell_price': sellPrice.toString(),
          'cost_price': (Decimal.tryParse(_costPriceController.text.trim()) ?? Decimal.zero).toString(),
          'track_stock': _trackStock,
          'low_stock_threshold': int.tryParse(_lowStockController.text.trim()) ?? 5,
        });
      } else {
        await repo.create(
          name: name,
          sellPrice: sellPrice,
          costPrice: Decimal.tryParse(_costPriceController.text.trim()),
          sku: _skuController.text.trim(),
          barcode: _barcodeController.text.trim(),
          categoryId: _categoryId,
          imageUrl: _imageUrlController.text.trim(),
          trackStock: _trackStock,
          stockQty: int.tryParse(_stockQtyController.text.trim()) ?? 0,
          lowStockThreshold: int.tryParse(_lowStockController.text.trim()) ?? 5,
        );
      }
      ref.invalidate(productListProvider);
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'บันทึกไม่สำเร็จ';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบสินค้านี้?'),
        content: const Text('สินค้าจะถูกซ่อนจากหน้าขาย แต่ประวัติการขายเดิมยังอยู่'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(productRepositoryProvider).delete(widget.productId!);
    ref.invalidate(productListProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _lookupBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty || _lookingUp) return;

    setState(() {
      _lookingUp = true;
      _referencePrice = null;
    });

    try {
      final result = await ref.read(productRepositoryProvider).lookupBarcode(trimmed);
      if (!mounted) return;

      if (!result.found) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลสินค้านี้ กรอกเองได้เลย')),
        );
        return;
      }

      setState(() {
        // Only fill in blanks — never overwrite what the user already typed.
        if (_nameController.text.trim().isEmpty && result.name != null) {
          _nameController.text = result.name!;
        }
        if (_imageUrlController.text.trim().isEmpty && result.imageUrl != null) {
          _imageUrlController.text = result.imageUrl!;
        }
        if (result.price != null) {
          if (result.currency == 'THB' && _sellPriceController.text.trim().isEmpty) {
            _sellPriceController.text = result.price.toString();
          } else if (result.currency != 'THB') {
            // Foreign-currency price isn't a safe THB prefill — surface it as
            // a reference the user taps to apply, instead of silently
            // dropping a USD figure into a "ราคาขาย ฿" field.
            _referencePrice = result;
          }
        }
      });
    } on DioException {
      // Best-effort prefill — a network hiccup here shouldn't block manual entry.
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('เพิ่มหมวดหมู่ใหม่'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'ชื่อหมวดหมู่')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      final category = await ref.read(categoryRepositoryProvider).create(name);
      ref.invalidate(categoryListProvider);
      if (mounted) setState(() => _categoryId = category.id);
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'เพิ่มหมวดหมู่ไม่สำเร็จ';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
    }
  }

  Widget _form(List<CategoryDto> categories) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'ชื่อสินค้า *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _skuController,
                decoration: const InputDecoration(labelText: 'รหัสสินค้า (SKU)', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _barcodeController,
                onSubmitted: _lookupBarcode,
                decoration: InputDecoration(
                  labelText: 'บาร์โค้ด',
                  border: const OutlineInputBorder(),
                  suffixIcon: _lookingUp
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          tooltip: 'สแกนบาร์โค้ด',
                          onPressed: () async {
                            final code = await Navigator.of(
                              context,
                            ).push<String>(MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()));
                            if (code != null && mounted) {
                              _barcodeController.text = code;
                              await _lookupBarcode(code);
                            }
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'หมวดหมู่', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('ไม่ระบุ')),
                  for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              icon: const Icon(Icons.add),
              tooltip: 'เพิ่มหมวดหมู่ใหม่',
              onPressed: _addCategory,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'ลิงก์รูปสินค้า', border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _imageUrlController.text.trim().isEmpty
                  ? Container(
                      width: 48,
                      height: 48,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_outlined, size: 20),
                    )
                  : Image.network(
                      _imageUrlController.text.trim(),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 48,
                        height: 48,
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: const Icon(Icons.broken_image_outlined, size: 20),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _sellPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'ราคาขาย *',
                  prefixText: '฿ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _costPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'ต้นทุน',
                  prefixText: '฿ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        if (_referencePrice != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              onTap: () => setState(() {
                _sellPriceController.text = _referencePrice!.price.toString();
                _referencePrice = null;
              }),
              child: Text(
                'ราคาอ้างอิง ${_referencePrice!.price} ${_referencePrice!.currency} '
                '(${_referencePrice!.source}) — แตะเพื่อใช้',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('นับสต็อกสินค้านี้'),
          value: _trackStock,
          onChanged: (value) => setState(() => _trackStock = value),
        ),
        if (_trackStock) ...[
          if (!widget.isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _stockQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'จำนวนเริ่มต้น', border: OutlineInputBorder()),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'สต็อกปัจจุบัน: ${_stockQtyController.text} ชิ้น — ปรับได้ที่หน้า "ปรับสต็อก"',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          TextField(
            controller: _lowStockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'แจ้งเตือนเมื่อเหลือ', border: OutlineInputBorder()),
          ),
        ],
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
              : Text(widget.isEditing ? 'บันทึกการแก้ไข' : 'เพิ่มสินค้า'),
        ),
        if (widget.isEditing) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _delete,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบสินค้านี้'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);

    Widget body() {
      return categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดหมวดหมู่ไม่สำเร็จ: $err')),
        data: (categories) {
          if (!widget.isEditing) return _form(categories);

          final productAsync = ref.watch(productByIdProvider(widget.productId!));
          return productAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $err')),
            data: (product) {
              if (product == null) return const Center(child: Text('ไม่พบสินค้านี้'));
              if (!_loadedInitialValues) {
                _fillFrom(product);
                _loadedInitialValues = true;
              }
              return _form(categories);
            },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'แก้ไขสินค้า' : 'เพิ่มสินค้า')),
      body: body(),
    );
  }
}
