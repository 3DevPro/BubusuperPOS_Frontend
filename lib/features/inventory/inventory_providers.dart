import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(apiClientProvider));
});

final lowStockProvider = FutureProvider.autoDispose<List<LowStockItemDto>>((ref) {
  return ref.watch(inventoryRepositoryProvider).lowStock();
});

final expiringSoonProvider = FutureProvider.autoDispose<List<ExpiringSoonItemDto>>((ref) {
  return ref.watch(inventoryRepositoryProvider).expiringSoon();
});
