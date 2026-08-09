import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import 'checkout_screen.dart' show salesRepositoryProvider;
import 'sales_repository.dart';

final salesHistoryProvider = FutureProvider.autoDispose<List<SaleListItemDto>>((ref) {
  return ref.watch(salesRepositoryProvider).list();
});

const _statusBadgeLabels = {'partially_refunded': 'คืนบางส่วน', 'refunded': 'คืนแล้ว', 'void': 'ยกเลิก'};

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการขาย')),
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดประวัติไม่สำเร็จ: $err')),
        data: (sales) {
          if (sales.isEmpty) {
            return const Center(child: Text('ยังไม่มีการขาย'));
          }
          return ListView.separated(
            itemCount: sales.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final sale = sales[index];
              final badge = _statusBadgeLabels[sale.status];
              return ListTile(
                title: Row(
                  children: [
                    Text(sale.receiptNo),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(badge, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ],
                ),
                subtitle: Text(formatThaiDateTime(sale.createdAt)),
                trailing: Text(formatBaht(sale.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => context.push('/receipt/${sale.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
