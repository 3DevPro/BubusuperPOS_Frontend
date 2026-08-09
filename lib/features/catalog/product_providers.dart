import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(apiClientProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(apiClientProvider));
});

final productSearchProvider = StateProvider<String>((ref) => '');

final productListProvider = FutureProvider.autoDispose<List<ProductDto>>((ref) async {
  final search = ref.watch(productSearchProvider);
  final repo = ref.watch(productRepositoryProvider);
  return repo.list(search: search.isEmpty ? null : search);
});

final categoryListProvider = FutureProvider.autoDispose<List<CategoryDto>>((ref) async {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.list();
});

/// There's no GET /products/{id} on the backend — list is small enough for
/// MVP shops that finding-by-id in the already-fetched catalog is simpler
/// than adding a single-item endpoint just for this lookup.
final productByIdProvider = Provider.family<AsyncValue<ProductDto?>, String>((ref, id) {
  final asyncList = ref.watch(productListProvider);
  return asyncList.whenData((products) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  });
});
