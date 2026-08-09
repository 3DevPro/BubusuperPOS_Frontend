import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import 'customer_providers.dart';
import 'customer_repository.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});
  final String? customerId;

  bool get isEditing => customerId != null;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _submitting = false;
  String? _error;
  bool _loadedInitialValues = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _fillFrom(CustomerDto customer) {
    _nameController.text = customer.name;
    _phoneController.text = customer.phone ?? '';
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
      final repo = ref.read(customerRepositoryProvider);
      final phone = _phoneController.text.trim();
      if (widget.isEditing) {
        await repo.update(widget.customerId!, {'name': name, 'phone': phone.isEmpty ? null : phone});
      } else {
        await repo.create(name: name, phone: phone);
      }
      ref.invalidate(customerListProvider);
      if (widget.isEditing) ref.invalidate(customerByIdProvider(widget.customerId!));
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'บันทึกไม่สำเร็จ';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _form(CustomerDto? customer) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'ชื่อลูกค้า *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'เบอร์โทร', border: OutlineInputBorder()),
        ),
        if (customer != null) ...[
          const SizedBox(height: 12),
          Text(
            'แต้มสะสม: ${formatPoints(customer.pointsBalance)} แต้ม',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _submitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.isEditing ? 'บันทึกการแก้ไข' : 'เพิ่มลูกค้า'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body() {
      if (!widget.isEditing) return _form(null);

      final customerAsync = ref.watch(customerByIdProvider(widget.customerId!));
      return customerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $err')),
        data: (customer) {
          if (!_loadedInitialValues) {
            _fillFrom(customer);
            _loadedInitialValues = true;
          }
          return _form(customer);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'แก้ไขลูกค้า' : 'เพิ่มลูกค้า')),
      body: body(),
    );
  }
}
