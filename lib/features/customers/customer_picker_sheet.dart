import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import 'customer_providers.dart';
import 'customer_repository.dart';

/// Search-and-pick a customer for checkout, with a quick "add new" escape
/// hatch so a cashier never has to leave the sale to register a walk-in
/// customer. Uses local state rather than the shared customerSearchProvider
/// so typing here doesn't leave stale filter text behind on the standalone
/// customer list screen.
class CustomerPickerSheet extends ConsumerStatefulWidget {
  const CustomerPickerSheet({super.key});

  @override
  ConsumerState<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  Future<List<CustomerDto>>? _future;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    setState(() {
      _future = ref.read(customerRepositoryProvider).list(search: value.isEmpty ? null : value);
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _quickAdd() async {
    final created = await showDialog<CustomerDto>(
      context: context,
      builder: (context) => const _QuickAddCustomerDialog(),
    );
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหาลูกค้า ชื่อ/เบอร์โทร',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(icon: const Icon(Icons.person_add), tooltip: 'เพิ่มลูกค้าใหม่', onPressed: _quickAdd),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<CustomerDto>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('โหลดลูกค้าไม่สำเร็จ: ${snapshot.error}'));
              }
              final customers = snapshot.data ?? [];
              if (customers.isEmpty) {
                return const Center(child: Text('ไม่พบลูกค้า — กด + เพื่อเพิ่มใหม่'));
              }
              return ListView.separated(
                itemCount: customers.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  return ListTile(
                    title: Text(customer.name),
                    subtitle: customer.phone == null ? null : Text(customer.phone!),
                    trailing: Text('${formatPoints(customer.pointsBalance)} แต้ม'),
                    onTap: () => Navigator.of(context).pop(customer),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickAddCustomerDialog extends ConsumerStatefulWidget {
  const _QuickAddCustomerDialog();

  @override
  ConsumerState<_QuickAddCustomerDialog> createState() => _QuickAddCustomerDialogState();
}

class _QuickAddCustomerDialogState extends ConsumerState<_QuickAddCustomerDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'กรอกชื่อลูกค้า');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final customer = await ref
          .read(customerRepositoryProvider)
          .create(name: name, phone: _phoneController.text.trim());
      ref.invalidate(customerListProvider);
      if (mounted) Navigator.of(context).pop(customer);
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'เพิ่มลูกค้าไม่สำเร็จ';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มลูกค้าใหม่'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'ชื่อลูกค้า *'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'เบอร์โทร'),
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
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('เพิ่ม'),
        ),
      ],
    );
  }
}
