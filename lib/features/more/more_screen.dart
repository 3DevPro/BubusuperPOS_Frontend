import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    final isOwner = me?['role'] == 'owner';
    // Matches Permission.adjust_inventory server-side — cashiers get 403 on
    // supplier/purchase-order endpoints, so their menu entries are hidden
    // rather than shown-then-blocked, same convention as isOwner above.
    final canManageInventory = isOwner || me?['role'] == 'manager';

    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มเติม')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (me != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(me['name'] as String),
                subtitle: Text('บทบาท: ${me['role']}'),
              ),
            ),
          const SizedBox(height: 8),
          if (canManageInventory) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.bar_chart_rounded),
                title: const Text('รายงานการขาย'),
                subtitle: const Text('ดูรายงานยอดขาย สินค้าขายดี ส่งออก CSV'),
                onTap: () => context.push('/reports'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('ตั้งค่าร้าน'),
              subtitle: const Text('เลขพร้อมเพย์สำหรับรับ QR'),
              onTap: () => context.push('/settings'),
            ),
          ),
          if (isOwner) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('จัดการพนักงาน'),
                subtitle: const Text('เพิ่ม/แก้บทบาท/ปิดใช้งาน'),
                onTap: () => context.push('/staff'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text('ประวัติการใช้งาน'),
                subtitle: const Text('บันทึกการเปลี่ยนแปลงของพนักงานทุกคน'),
                onTap: () => context.push('/audit-log'),
              ),
            ),
          ],
          if (canManageInventory) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('จัดการหมวดหมู่'),
                subtitle: const Text('เพิ่ม/แก้ชื่อ/ลบหมวดหมู่สินค้า'),
                onTap: () => context.push('/categories'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('ลูกค้า'),
              subtitle: const Text('รายชื่อลูกค้าและแต้มสะสม'),
              onTap: () => context.push('/customers'),
            ),
          ),
          if (canManageInventory) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('ซัพพลายเออร์'),
                subtitle: const Text('รายชื่อผู้ขายส่งสินค้าให้ร้าน'),
                onTap: () => context.push('/suppliers'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shopping_cart_checkout),
                title: const Text('ใบสั่งซื้อ'),
                subtitle: const Text('สั่งซื้อและรับของเข้าสต็อก'),
                onTap: () => context.push('/purchase-orders'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('ออกจากระบบ', style: TextStyle(color: Colors.red)),
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ),
        ],
      ),
    );
  }
}
