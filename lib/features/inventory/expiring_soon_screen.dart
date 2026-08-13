import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import 'inventory_providers.dart';
import 'inventory_repository.dart';

class ExpiringSoonScreen extends ConsumerWidget {
  const ExpiringSoonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiringAsync = ref.watch(expiringSoonProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(title: const Text('สินค้าใกล้หมดอายุ')),
      body: expiringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดไม่สำเร็จ: $err')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('ไม่มีสินค้าใกล้หมดอายุ 🎉'));
          }
          return isWide ? _ExpiringSoonTable(items: items) : _ExpiringSoonList(items: items);
        },
      ),
    );
  }
}

class _ExpiringSoonList extends StatelessWidget {
  const _ExpiringSoonList({required this.items});
  final List<ExpiringSoonItemDto> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: Icon(Icons.event_busy, color: item.isExpired ? Colors.red : Colors.orange),
          title: Text(item.name),
          subtitle: Text(item.isExpired ? 'หมดอายุแล้ว' : 'หมดอายุ ${formatThaiDate(item.expiryDate)}'),
          trailing: Text(
            '${item.stockQty} ชิ้น',
            style: TextStyle(
              color: item.isExpired ? Colors.red : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () => context.push('/products/${item.id}/edit'),
        );
      },
    );
  }
}

class _ExpiringSoonTable extends StatelessWidget {
  const _ExpiringSoonTable({required this.items});
  final List<ExpiringSoonItemDto> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('สินค้า')),
          DataColumn(label: Text('วันหมดอายุ')),
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
                      Icon(Icons.event_busy, color: item.isExpired ? Colors.red : Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Text(item.name),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    item.isExpired ? 'หมดอายุแล้ว' : formatThaiDate(item.expiryDate),
                    style: TextStyle(
                      color: item.isExpired ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(Text('${item.stockQty} ชิ้น')),
                DataCell(
                  TextButton(
                    onPressed: () => context.push('/products/${item.id}/edit'),
                    child: const Text('แก้ไข'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
