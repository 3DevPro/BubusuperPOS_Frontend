import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/barcode_scanner_screen.dart';
import '../../shared/formatters.dart';
import '../catalog/product_providers.dart';
import '../catalog/product_repository.dart';
import 'cart_notifier.dart';
import 'cart_panel.dart';
import 'offline/offline_sale_queue.dart';
import 'offline/offline_sync_service.dart';

/// Compares a scanned code against a stored barcode, tolerant of the
/// UPC-A/EAN-13 leading-zero difference (a 12-digit UPC-A scan and its
/// 13-digit EAN-13 equivalent otherwise fail a strict `==` check even
/// though they identify the same product).
bool _barcodesMatch(String scanned, String? stored) {
  if (stored == null) return false;
  if (scanned == stored) return true;
  if (scanned.length == 12 && stored.length == 13 && stored.startsWith('0')) {
    return stored.substring(1) == scanned;
  }
  if (stored.length == 12 && scanned.length == 13 && scanned.startsWith('0')) {
    return scanned.substring(1) == stored;
  }
  return false;
}

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(productSearchProvider.notifier).state = value;
    });
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()));
    if (code == null || !mounted) return;

    final products = await ref.read(productRepositoryProvider).list(search: code);
    final exactMatches = products.where((p) => _barcodesMatch(code, p.barcode)).toList();

    if (!mounted) return;
    if (exactMatches.length == 1) {
      ref.read(cartProvider.notifier).addProduct(exactMatches.first);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เพิ่ม ${exactMatches.first.name} แล้ว'), duration: const Duration(seconds: 1)));
    } else {
      _searchController.text = code;
      ref.read(productSearchProvider.notifier).state = code;
      if (exactMatches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่พบสินค้าที่มีบาร์โค้ด $code')));
      }
    }
  }

  void _openCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: const CartPanel(),
      ),
    );
  }

  void _openPendingSalesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: const _PendingSalesSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final cart = ref.watch(cartProvider);
    final productsAsync = ref.watch(productListProvider);
    final pendingSalesCount = ref.watch(offlineSaleQueueProvider).valueOrNull?.length ?? 0;

    final grid = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'ค้นหาสินค้า ชื่อ/รหัส/บาร์โค้ด',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'สแกนบาร์โค้ด',
                onPressed: _scanBarcode,
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('โหลดสินค้าไม่สำเร็จ: $err')),
            data: (products) {
              if (products.isEmpty) {
                return const Center(child: Text('ยังไม่มีสินค้า — เพิ่มสินค้าที่แท็บสต็อกก่อน'));
              }
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 4 : 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.1,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _ProductCard(
                    product: product,
                    onTap: () => ref.read(cartProvider.notifier).addProduct(product),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('ขาย'),
        actions: [
          if (pendingSalesCount > 0)
            IconButton(
              icon: Badge(
                label: Text('$pendingSalesCount'),
                child: const Icon(Icons.cloud_upload_outlined),
              ),
              tooltip: 'ออเดอร์รอซิงค์',
              onPressed: _openPendingSalesSheet,
            ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'ประวัติการขาย',
            onPressed: () => context.push('/sales-history'),
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                Expanded(child: grid),
                const VerticalDivider(width: 1),
                const SizedBox(width: 360, child: CartPanel()),
              ],
            )
          : grid,
      floatingActionButton: isWide || cart.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCartSheet,
              icon: const Icon(Icons.shopping_cart),
              label: Text('${cart.itemCount} รายการ • ${formatBaht(cart.total)}'),
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final ProductDto product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  // BoxFit.contain (not cover) so a photo shot in a different
                  // aspect ratio than this card never gets cropped away —
                  // seeing the whole product matters more than filling the tile.
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (product.isLowStock)
                    Text('เหลือ ${product.stockQty}', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                  Text(formatBaht(product.sellPrice), style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingSalesSheet extends ConsumerWidget {
  const _PendingSalesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(offlineSaleQueueProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ออเดอร์รอซิงค์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              FilledButton.icon(
                onPressed: () => ref.read(offlineSyncServiceProvider).flush(),
                icon: const Icon(Icons.sync),
                label: const Text('ลองส่งอีกครั้ง'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: pendingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('โหลดไม่สำเร็จ: $err')),
            data: (pending) {
              if (pending.isEmpty) {
                return const Center(child: Text('ไม่มีออเดอร์ค้างส่ง'));
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(offlineSyncServiceProvider).flush(),
                child: ListView.separated(
                  itemCount: pending.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sale = pending[index];
                    return ListTile(
                      leading: Icon(
                        sale.lastError != null ? Icons.error_outline : Icons.hourglass_top,
                        color: sale.lastError != null ? Colors.red : Colors.orange,
                      ),
                      title: Text('${sale.items.length} รายการ'),
                      subtitle: Text(sale.lastError ?? formatThaiDateTime(sale.createdAt)),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
