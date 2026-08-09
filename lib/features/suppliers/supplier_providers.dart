import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'supplier_repository.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(ref.watch(apiClientProvider));
});

final supplierSearchProvider = StateProvider<String>((ref) => '');

final supplierListProvider = FutureProvider.autoDispose<List<SupplierDto>>((ref) async {
  final search = ref.watch(supplierSearchProvider);
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.list(search: search.isEmpty ? null : search);
});

final supplierByIdProvider = FutureProvider.autoDispose.family<SupplierDto, String>((ref, id) async {
  return ref.watch(supplierRepositoryProvider).get(id);
});
