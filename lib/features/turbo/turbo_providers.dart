import 'package:dio/dio.dart';
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

final loanProductsProvider = FutureProvider.autoDispose<List<LoanProductDto>>((ref) {
  return ref.watch(turboRepositoryProvider).loanProducts();
});

final loanApplicationsProvider = FutureProvider.autoDispose<List<LoanApplicationDto>>((ref) {
  return ref.watch(turboRepositoryProvider).loanApplications();
});

final loanEligibilityProvider = FutureProvider.autoDispose<LoanEligibilityDto>((ref) {
  return ref.watch(turboRepositoryProvider).loanEligibility();
});

const loanStatusPollInterval = Duration(seconds: 10);

// The app's first polling provider — everything before this (e.g.
// _SlaCountdown in branch_home_screen.dart) is a Timer that only repaints a
// countdown already known client-side; this one actually refetches.
//
// autoDispose does the cleanup a Timer-in-ConsumerStatefulWidget would need
// manual dispose()/mounted-guard bookkeeping for: leaving the screen drops
// the last listener, which cancels this stream's subscription and stops the
// polling loop on its own — no stray Timer, no double-cancellation risk.
// await-then-delay (not Timer.periodic) also means a slow response can't
// cause overlapping in-flight requests.
final loanApplicationDetailProvider = StreamProvider.autoDispose
    .family<LoanApplicationDetailDto, String>((ref, applicationId) async* {
      final repo = ref.watch(turboRepositoryProvider);
      var failures = 0;
      while (true) {
        try {
          final detail = await repo.loanApplication(applicationId);
          failures = 0;
          yield detail;
          if (isTerminalLoanStatus(detail.status)) return;
        } on DioException {
          // A transient network hiccup shouldn't end the stream — a
          // StreamProvider that throws stops for good, silently leaving the
          // tenant on a status screen that never updates again.
          if (++failures >= 3) rethrow;
        }
        await Future<void>.delayed(loanStatusPollInterval);
      }
    });

final loanAccountSummaryProvider = FutureProvider.autoDispose<LoanAccountSummaryDto?>((ref) {
  return ref.watch(turboRepositoryProvider).loanAccountSummary();
});

final loanInstallmentsProvider = FutureProvider.autoDispose.family<List<LoanInstallmentDto>, String>((
  ref,
  accountId,
) {
  return ref.watch(turboRepositoryProvider).loanInstallments(accountId);
});

final creditStandingProvider = FutureProvider.autoDispose<CreditStandingDto>((ref) {
  return ref.watch(turboRepositoryProvider).creditStanding();
});
