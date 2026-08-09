import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import '../auth/auth_provider.dart';
import 'audit_log_providers.dart';
import 'audit_log_repository.dart';

IconData _iconFor(String action) {
  final prefix = action.split('.').first;
  return switch (prefix) {
    'staff' => Icons.badge_outlined,
    'category' => Icons.category_outlined,
    'product' => Icons.inventory_2_outlined,
    'inventory' => Icons.tune,
    'tenant_settings' => Icons.settings_outlined,
    _ => Icons.history,
  };
}

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(authControllerProvider).me?['role'] == 'owner';

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('ประวัติการใช้งาน')),
        body: const Center(child: Text('เฉพาะเจ้าของร้านเท่านั้นที่เข้าถึงหน้านี้ได้')),
      );
    }

    final logAsync = ref.watch(auditLogListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการใช้งาน')),
      body: logAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดประวัติไม่สำเร็จ: $err')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('ยังไม่มีประวัติการใช้งาน'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(auditLogListProvider.future),
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _AuditLogTile(entry: entries[index]),
            ),
          );
        },
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.entry});
  final AuditLogEntryDto entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_iconFor(entry.action)),
      title: Text(entry.summary),
      subtitle: Text('${entry.actorName} · ${formatThaiDateTime(entry.createdAt)}'),
    );
  }
}
