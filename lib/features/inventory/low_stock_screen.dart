import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'inventory_providers.dart';
import 'inventory_repository.dart';

class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockAsync = ref.watch(lowStockProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(title: const Text('สินค้าใกล้หมด')),
      body: lowStockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดไม่สำเร็จ: $err')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('ไม่มีสินค้าใกล้หมด 🎉'));
          }
          return isWide ? _LowStockTable(items: items) : _LowStockList(items: items);
        },
      ),
    );
  }
}

class _LowStockList extends StatelessWidget {
  const _LowStockList({required this.items});
  final List<LowStockItemDto> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: const Icon(Icons.warning_amber, color: Colors.orange),
          title: Text(item.name),
          subtitle: Text('เกณฑ์แจ้งเตือน: ${item.lowStockThreshold} ชิ้น'),
          trailing: Text(
            '${item.stockQty} ชิ้น',
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
          onTap: () => context.push('/products/${item.id}/stock-adjust'),
        );
      },
    );
  }
}

class _LowStockTable extends StatelessWidget {
  const _LowStockTable({required this.items});
  final List<LowStockItemDto> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('สินค้า')),
          DataColumn(label: Text('เกณฑ์แจ้งเตือน')),
          DataColumn(label: Text('คงเหลือ')),
          DataColumn(label: Text('จัดการ')),
        ],
        rows: [
          for (final item in items)
            DataRow(
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Text(item.name),
                    ],
                  ),
                ),
                DataCell(Text('${item.lowStockThreshold} ชิ้น')),
                DataCell(
                  Text(
                    '${item.stockQty} ชิ้น',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  TextButton(
                    onPressed: () => context.push('/products/${item.id}/stock-adjust'),
                    child: const Text('ปรับสต็อก'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
