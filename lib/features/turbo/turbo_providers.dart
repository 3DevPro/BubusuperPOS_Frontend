import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'turbo_repository.dart';

final turboRepositoryProvider = Provider<TurboRepository>((ref) {
  return TurboRepository(ref.watch(apiClientProvider));
});

// A 1-day window is enough to find today's close row without pulling the
// full 30-day history the income-certificate screen needs.
final todayCloseProvider = FutureProvider.autoDispose<DailyCloseDto?>((ref) async {
  final closes = await ref.watch(turboRepositoryProvider).listCloses(days: 1);
  return closes.isEmpty ? null : closes.first;
});

final incomeProfileProvider = FutureProvider.autoDispose<IncomeProfileDto>((ref) {
  return ref.watch(turboRepositoryProvider).incomeProfile();
});

final insuranceProductsProvider = FutureProvider.autoDispose<List<InsuranceProductDto>>((ref) {
  return ref.watch(turboRepositoryProvider).insuranceProducts();
});

final insurancePoliciesProvider = FutureProvider.autoDispose<List<InsurancePolicyDto>>((ref) {
  return ref.watch(turboRepositoryProvider).insurancePolicies();
});

final insuranceClaimsProvider = FutureProvider.autoDispose<List<InsuranceClaimDto>>((ref) {
  return ref.watch(turboRepositoryProvider).insuranceClaims();
});

final detectedClaimsProvider = FutureProvider.autoDispose.family<List<DetectedClaimDto>, String>((ref, policyId) {
  return ref.watch(turboRepositoryProvider).detectedClaims(policyId);
});

// Only the daily_income product has auto-claim detection — this resolves the
// tenant's active policy for it (if any) so the dashboard banner knows
// whether to even ask about detected claims. Null means either the product
// hasn't been purchased yet, or the catalog/policy calls are still loading.
final activeDailyIncomePolicyProvider = FutureProvider.autoDispose<InsurancePolicyDto?>((ref) async {
  final products = await ref.watch(insuranceProductsProvider.future);
  final policies = await ref.watch(insurancePoliciesProvider.future);

  String? dailyIncomeProductId;
  for (final product in products) {
    if (product.kind == 'daily_income') {
      dailyIncomeProductId = product.id;
      break;
    }
  }
  if (dailyIncomeProductId == null) return null;

  for (final policy in policies) {
    if (policy.productId == dailyIncomeProductId && policy.status == 'active') return policy;
  }
  return null;
});
