import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'audit_log_repository.dart';

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepository(ref.watch(apiClientProvider));
});

final auditLogListProvider = FutureProvider.autoDispose<List<AuditLogEntryDto>>((ref) {
  return ref.watch(auditLogRepositoryProvider).list();
});
