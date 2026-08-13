import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import 'notification_providers.dart';
import 'notification_repository.dart';

const _kindIcons = {
  'low_stock': Icons.inventory_2_outlined,
  'daily_summary': Icons.summarize_outlined,
  'system': Icons.info_outline,
};

class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});

  Future<void> _markRead(WidgetRef ref, NotificationDto n) async {
    if (n.isRead) return;
    await ref.read(notificationRepositoryProvider).markRead(n.id);
    ref.invalidate(notificationListProvider);
    ref.read(unreadCountProvider.notifier).refresh();
  }

  Future<void> _markAllRead(WidgetRef ref) async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    ref.invalidate(notificationListProvider);
    ref.read(unreadCountProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('การแจ้งเตือน'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(ref),
            child: const Text('อ่านทั้งหมด', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดการแจ้งเตือนไม่สำเร็จ: $err')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('ยังไม่มีการแจ้งเตือน'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationListProvider),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = items[index];
                return ListTile(
                  leading: Icon(_kindIcons[n.kind] ?? Icons.notifications_outlined),
                  title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatThaiDateTime(n.createdAt), style: const TextStyle(fontSize: 11)),
                      if (!n.isRead)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  onTap: () => _markRead(ref, n),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
