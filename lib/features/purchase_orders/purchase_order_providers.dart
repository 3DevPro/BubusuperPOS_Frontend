import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'purchase_order_repository.dart';

final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>((ref) {
  return PurchaseOrderRepository(ref.watch(apiClientProvider));
});

final purchaseOrderListProvider = FutureProvider.autoDispose<List<PurchaseOrderListItemDto>>((ref) async {
  return ref.watch(purchaseOrderRepositoryProvider).list();
});

final purchaseOrderDetailProvider = FutureProvider.autoDispose.family<PurchaseOrderResultDto, String>((
  ref,
  id,
) async {
  return ref.watch(purchaseOrderRepositoryProvider).get(id);
});
