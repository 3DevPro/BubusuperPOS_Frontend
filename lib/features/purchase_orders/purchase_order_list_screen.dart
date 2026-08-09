import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import 'purchase_order_providers.dart';

const _statusLabels = {
  'ordered': 'สั่งซื้อแล้ว',
  'partially_received': 'รับของบางส่วน',
  'received': 'รับของครบแล้ว',
  'cancelled': 'ยกเลิกแล้ว',
};

const _statusColors = {
  'ordered': Colors.blue,
  'partially_received': Colors.orange,
  'received': Colors.green,
  'cancelled': Colors.grey,
};

class PurchaseOrderListScreen extends ConsumerWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(purchaseOrderListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ใบสั่งซื้อ')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดใบสั่งซื้อไม่สำเร็จ: $err')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('ยังไม่มีใบสั่งซื้อ — กด + เพื่อสั่งซื้อครั้งแรก'));
          }
          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final po = orders[index];
              return ListTile(
                title: Text(po.orderNo),
                subtitle: Text(formatThaiDateTime(po.createdAt)),
                trailing: Chip(
                  label: Text(_statusLabels[po.status] ?? po.status, style: const TextStyle(fontSize: 12)),
                  backgroundColor: (_statusColors[po.status] ?? Colors.grey).withValues(alpha: 0.15),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
                onTap: () => context.push('/purchase-orders/${po.id}'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/purchase-orders/new'),
        tooltip: 'สั่งซื้อใหม่',
        child: const Icon(Icons.add),
      ),
    );
  }
}
