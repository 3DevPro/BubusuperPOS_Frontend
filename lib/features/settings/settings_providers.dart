import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'tenant_repository.dart';

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepository(ref.watch(apiClientProvider));
});

final tenantSettingsProvider = FutureProvider.autoDispose<TenantSettingsDto>((ref) {
  return ref.watch(tenantRepositoryProvider).getSettings();
});
