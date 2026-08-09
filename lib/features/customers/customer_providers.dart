import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(apiClientProvider));
});

final customerSearchProvider = StateProvider<String>((ref) => '');

final customerListProvider = FutureProvider.autoDispose<List<CustomerDto>>((ref) async {
  final search = ref.watch(customerSearchProvider);
  final repo = ref.watch(customerRepositoryProvider);
  return repo.list(search: search.isEmpty ? null : search);
});

final customerByIdProvider = FutureProvider.autoDispose.family<CustomerDto, String>((ref, id) async {
  return ref.watch(customerRepositoryProvider).get(id);
});
