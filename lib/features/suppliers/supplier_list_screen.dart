import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'supplier_providers.dart';

class SupplierListScreen extends ConsumerStatefulWidget {
  const SupplierListScreen({super.key});

  @override
  ConsumerState<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends ConsumerState<SupplierListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(supplierSearchProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ซัพพลายเออร์')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'ค้นหาซัพพลายเออร์ ชื่อ/เบอร์โทร',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: suppliersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('โหลดซัพพลายเออร์ไม่สำเร็จ: $err')),
              data: (suppliers) {
                if (suppliers.isEmpty) {
                  return const Center(child: Text('ยังไม่มีซัพพลายเออร์ — กด + เพื่อเพิ่มรายแรก'));
                }
                return ListView.separated(
                  itemCount: suppliers.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index];
                    return ListTile(
                      title: Text(supplier.name),
                      subtitle: supplier.phone == null ? null : Text(supplier.phone!),
                      onTap: () => context.push('/suppliers/${supplier.id}/edit'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/suppliers/new'),
        tooltip: 'เพิ่มซัพพลายเออร์',
        child: const Icon(Icons.add),
      ),
    );
  }
}
