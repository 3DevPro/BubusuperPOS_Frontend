import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supplier_providers.dart';
import 'supplier_repository.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  const SupplierFormScreen({super.key, this.supplierId});
  final String? supplierId;

  bool get isEditing => supplierId != null;

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _submitting = false;
  String? _error;
  bool _loadedInitialValues = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _fillFrom(SupplierDto supplier) {
    _nameController.text = supplier.name;
    _phoneController.text = supplier.phone ?? '';
    _emailController.text = supplier.email ?? '';
    _addressController.text = supplier.address ?? '';
    _notesController.text = supplier.notes ?? '';
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'กรอกชื่อซัพพลายเออร์');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(supplierRepositoryProvider);
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final address = _addressController.text.trim();
      final notes = _notesController.text.trim();
      if (widget.isEditing) {
        await repo.update(widget.supplierId!, {
          'name': name,
          'phone': phone.isEmpty ? null : phone,
          'email': email.isEmpty ? null : email,
          'address': address.isEmpty ? null : address,
          'notes': notes.isEmpty ? null : notes,
        });
      } else {
        await repo.create(name: name, phone: phone, email: email, address: address, notes: notes);
      }
      ref.invalidate(supplierListProvider);
      if (widget.isEditing) ref.invalidate(supplierByIdProvider(widget.supplierId!));
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

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'ชื่อซัพพลายเออร์ *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'เบอร์โทร', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'อีเมล', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'ที่อยู่', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'หมายเหตุ', border: OutlineInputBorder()),
        ),
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
              : Text(widget.isEditing ? 'บันทึกการแก้ไข' : 'เพิ่มซัพพลายเออร์'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body() {
      if (!widget.isEditing) return _form();

      final supplierAsync = ref.watch(supplierByIdProvider(widget.supplierId!));
      return supplierAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $err')),
        data: (supplier) {
          if (!_loadedInitialValues) {
            _fillFrom(supplier);
            _loadedInitialValues = true;
          }
          return _form();
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'แก้ไขซัพพลายเออร์' : 'เพิ่มซัพพลายเออร์')),
      body: body(),
    );
  }
}
