import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'product_providers.dart';
import 'product_repository.dart';

String _errorDetail(DioException e, String fallback) {
  final data = e.response?.data;
  return (data is Map && data['detail'] != null) ? data['detail'].toString() : fallback;
}

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการหมวดหมู่'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'เพิ่มหมวดหมู่',
            onPressed: () => _showEditDialog(context, ref),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดหมวดหมู่ไม่สำเร็จ: $err')),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('ยังไม่มีหมวดหมู่ — กดปุ่ม + เพื่อเพิ่ม'));
          }
          return ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'แก้ชื่อ',
                      onPressed: () => _showEditDialog(context, ref, category: category),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'ลบ',
                      onPressed: () => _delete(context, ref, category),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, CategoryDto category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบหมวดหมู่นี้?'),
        content: Text('"${category.name}" จะถูกลบ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(categoryRepositoryProvider).delete(category.id);
      ref.invalidate(categoryListProvider);
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorDetail(e, 'ลบไม่สำเร็จ'))));
      }
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, {CategoryDto? category}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _CategoryEditDialog(category: category),
    );
  }
}

class _CategoryEditDialog extends ConsumerStatefulWidget {
  const _CategoryEditDialog({this.category});
  final CategoryDto? category;

  @override
  ConsumerState<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends ConsumerState<_CategoryEditDialog> {
  late final _nameController = TextEditingController(text: widget.category?.name ?? '');
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.category != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'กรอกชื่อหมวดหมู่');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(categoryRepositoryProvider);
      if (_isEditing) {
        await repo.update(widget.category!.id, name);
      } else {
        await repo.create(name);
      }
      ref.invalidate(categoryListProvider);
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      setState(() => _error = _errorDetail(e, 'บันทึกไม่สำเร็จ'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'แก้ชื่อหมวดหมู่' : 'เพิ่มหมวดหมู่'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'ชื่อหมวดหมู่'),
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
              : const Text('บันทึก'),
        ),
      ],
    );
  }
}
