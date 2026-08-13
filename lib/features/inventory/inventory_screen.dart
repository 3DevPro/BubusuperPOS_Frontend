import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import '../auth/auth_provider.dart';
import '../catalog/product_providers.dart';
import '../catalog/product_repository.dart';
import 'inventory_providers.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productListProvider);
    final lowStockAsync = ref.watch(lowStockProvider);
    final expiringSoonAsync = ref.watch(expiringSoonProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final role = ref.watch(authControllerProvider).me?['role'];
    // Cashiers can browse stock (Permission.view_products) but not edit
    // products or adjust stock (manage_products/adjust_inventory) — those
    // routes are now blocked by the router, so the affordances that would
    // push there are hidden too rather than shown-then-bounced-back.
    final canManage = role == 'owner' || role == 'manager';

    return Scaffold(
      appBar: AppBar(
        title: const Text('สต็อกสินค้า'),
        actions: [
          lowStockAsync.maybeWhen(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Badge(label: Text('${items.length}'), child: const Icon(Icons.warning_amber)),
                    tooltip: 'สินค้าใกล้หมด',
                    onPressed: () => context.push('/low-stock'),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          expiringSoonAsync.maybeWhen(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Badge(label: Text('${items.length}'), child: const Icon(Icons.event_busy)),
                    tooltip: 'สินค้าใกล้หมดอายุ',
                    onPressed: () => context.push('/expiring-soon'),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดสินค้าไม่สำเร็จ: $err')),
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('ยังไม่มีสินค้า — กด + เพื่อเพิ่มสินค้าแรก'));
          }
          return isWide
              ? _ProductTable(products: products, canManage: canManage)
              : _ProductList(products: products, canManage: canManage);
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => context.push('/products/new'),
              tooltip: 'เพิ่มสินค้า',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({required this.products, required this.canManage});
  final List<ProductDto> products;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = products[index];
        return ListTile(
          title: Text(product.name),
          subtitle: Text(formatBaht(product.sellPrice)),
          onTap: canManage ? () => context.push('/products/${product.id}/edit') : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.isExpiringSoon)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.event_busy, color: Colors.red, size: 18),
                ),
              Text(
                product.trackStock ? '${product.stockQty} ชิ้น' : 'ไม่นับสต็อก',
                style: TextStyle(
                  color: product.isLowStock ? Colors.orange : null,
                  fontWeight: product.isLowStock ? FontWeight.bold : null,
                ),
              ),
              if (product.trackStock && canManage)
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'ปรับสต็อก',
                  onPressed: () => context.push('/products/${product.id}/stock-adjust'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductTable extends ConsumerWidget {
  const _ProductTable({required this.products, required this.canManage});
  final List<ProductDto> products;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final categoryNames = categoriesAsync.maybeWhen(
      data: (categories) => {for (final c in categories) c.id: c.name},
      orElse: () => <String, String>{},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ชื่อ')),
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('หมวดหมู่')),
          DataColumn(label: Text('ราคา')),
          DataColumn(label: Text('สต็อก')),
          DataColumn(label: Text('จัดการ')),
        ],
        rows: [
          for (final product in products)
            DataRow(
              onSelectChanged: canManage ? (_) => context.push('/products/${product.id}/edit') : null,
              cells: [
                DataCell(Text(product.name)),
                DataCell(Text(product.sku ?? '-')),
                DataCell(Text(categoryNames[product.categoryId] ?? '-')),
                DataCell(Text(formatBaht(product.sellPrice))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (product.isExpiringSoon)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.event_busy, color: Colors.red, size: 16),
                        ),
                      Text(
                        product.trackStock ? '${product.stockQty} ชิ้น' : 'ไม่นับสต็อก',
                        style: TextStyle(
                          color: product.isLowStock ? Colors.orange : null,
                          fontWeight: product.isLowStock ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  product.trackStock && canManage
                      ? IconButton(
                          icon: const Icon(Icons.tune),
                          tooltip: 'ปรับสต็อก',
                          onPressed: () => context.push('/products/${product.id}/stock-adjust'),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
