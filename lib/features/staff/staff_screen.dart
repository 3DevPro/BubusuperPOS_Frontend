import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import 'staff_providers.dart';
import 'staff_repository.dart';

const _roleLabels = {'owner': 'เจ้าของร้าน', 'manager': 'ผู้จัดการ', 'cashier': 'แคชเชียร์'};

String _errorDetail(DioException e, String fallback) {
  final data = e.response?.data;
  return (data is Map && data['detail'] != null) ? data['detail'].toString() : fallback;
}

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(authControllerProvider).me?['role'] == 'owner';

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('จัดการพนักงาน')),
        body: const Center(child: Text('เฉพาะเจ้าของร้านเท่านั้นที่เข้าถึงหน้านี้ได้')),
      );
    }

    final staffAsync = ref.watch(staffListProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการพนักงาน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'เพิ่มพนักงาน',
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดรายชื่อพนักงานไม่สำเร็จ: $err')),
        data: (staff) {
          if (staff.isEmpty) {
            return const Center(child: Text('ยังไม่มีพนักงาน — กดปุ่ม + เพื่อเพิ่ม'));
          }
          return isWide ? _StaffTable(staff: staff) : _StaffList(staff: staff);
        },
      ),
    );
  }
}

class _StaffList extends StatelessWidget {
  const _StaffList({required this.staff});
  final List<StaffDto> staff;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: staff.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final member = staff[index];
        return ListTile(
          title: Text(member.name),
          subtitle: Text(_roleLabels[member.role] ?? member.role),
          trailing: _StaffRowActions(member: member),
          enabled: member.isActive,
        );
      },
    );
  }
}

class _StaffTable extends StatelessWidget {
  const _StaffTable({required this.staff});
  final List<StaffDto> staff;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ชื่อ')),
          DataColumn(label: Text('บทบาท')),
          DataColumn(label: Text('สถานะ')),
          DataColumn(label: Text('จัดการ')),
        ],
        rows: [
          for (final member in staff)
            DataRow(
              cells: [
                DataCell(Text(member.name)),
                DataCell(Text(_roleLabels[member.role] ?? member.role)),
                DataCell(
                  Text(
                    member.isActive ? 'ใช้งานอยู่' : 'ปิดใช้งาน',
                    style: TextStyle(color: member.isActive ? Colors.green : Colors.grey),
                  ),
                ),
                DataCell(_StaffRowActions(member: member)),
              ],
            ),
        ],
      ),
    );
  }
}

class _StaffRowActions extends ConsumerWidget {
  const _StaffRowActions({required this.member});
  final StaffDto member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authControllerProvider).me?['id'] as String?;
    final isSelf = myId == member.id;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<String>(
          value: member.role,
          underline: const SizedBox.shrink(),
          items: [
            for (final role in _roleLabels.keys) DropdownMenuItem(value: role, child: Text(_roleLabels[role]!)),
          ],
          onChanged: (role) async {
            if (role == null || role == member.role) return;
            await _updateStaff(context, ref, id: member.id, role: role);
          },
        ),
        Switch(
          value: member.isActive,
          onChanged: isSelf
              ? null
              : (active) async {
                  await _updateStaff(context, ref, id: member.id, isActive: active);
                },
        ),
        IconButton(
          icon: const Icon(Icons.password),
          tooltip: 'รีเซ็ต PIN',
          onPressed: () => _showResetPinDialog(context, ref, member.id),
        ),
      ],
    );
  }
}

Future<void> _updateStaff(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  String? role,
  bool? isActive,
  String? pin,
}) async {
  try {
    await ref.read(staffRepositoryProvider).update(id, role: role, isActive: isActive, pin: pin);
    ref.invalidate(staffListProvider);
  } on DioException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorDetail(e, 'บันทึกไม่สำเร็จ'))));
    }
  }
}

void _showResetPinDialog(BuildContext context, WidgetRef ref, String staffId) {
  final controller = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('รีเซ็ต PIN'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(labelText: 'PIN ใหม่ (4-6 หลัก)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: () async {
            final pin = controller.text.trim();
            if (pin.length < 4) return;
            Navigator.pop(dialogContext);
            await _updateStaff(context, ref, id: staffId, pin: pin);
          },
          child: const Text('บันทึก'),
        ),
      ],
    ),
  );
}

void _showCreateDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(context: context, builder: (dialogContext) => const _CreateStaffDialog());
}

class _CreateStaffDialog extends ConsumerStatefulWidget {
  const _CreateStaffDialog();

  @override
  ConsumerState<_CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends ConsumerState<_CreateStaffDialog> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  String _role = 'cashier';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    if (name.isEmpty || pin.length < 4) {
      setState(() => _error = 'กรอกชื่อและ PIN อย่างน้อย 4 หลัก');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(staffRepositoryProvider).create(name: name, role: _role, pin: pin);
      ref.invalidate(staffListProvider);
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      setState(() => _error = _errorDetail(e, 'เพิ่มพนักงานไม่สำเร็จ'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มพนักงาน'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'ชื่อ')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'บทบาท'),
            items: const [
              DropdownMenuItem(value: 'manager', child: Text('ผู้จัดการ')),
              DropdownMenuItem(value: 'cashier', child: Text('แคชเชียร์')),
            ],
            onChanged: (value) => setState(() => _role = value ?? 'cashier'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'PIN (4-6 หลัก)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('เพิ่ม'),
        ),
      ],
    );
  }
}
