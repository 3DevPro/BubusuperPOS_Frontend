import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'branch_repository.dart';

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository(ref.watch(apiClientProvider));
});

final prospectsProvider = FutureProvider.autoDispose<List<ProspectDto>>((ref) {
  return ref.watch(branchRepositoryProvider).listProspects();
});

final leadsProvider = FutureProvider.autoDispose<List<LeadDto>>((ref) {
  return ref.watch(branchRepositoryProvider).listLeads();
});

final leaderboardProvider = FutureProvider.autoDispose<List<LeaderboardEntryDto>>((ref) {
  return ref.watch(branchRepositoryProvider).leaderboard();
});

final loanTermBoundsProvider = FutureProvider.autoDispose<List<LoanTermBoundsDto>>((ref) {
  return ref.watch(branchRepositoryProvider).publicLoanTermBounds();
});
