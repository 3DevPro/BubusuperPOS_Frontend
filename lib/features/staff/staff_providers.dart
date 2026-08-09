import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'staff_repository.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository(ref.watch(apiClientProvider));
});

final staffListProvider = FutureProvider.autoDispose<List<StaffDto>>((ref) {
  return ref.watch(staffRepositoryProvider).list();
});
