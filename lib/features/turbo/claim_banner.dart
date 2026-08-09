import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import 'turbo_providers.dart';

/// Shown on the dashboard when the tenant has an active daily-income policy
/// and the auto-claim scan (see Backend's claim_service.detect_claimable_periods)
/// has found sick/accident days not yet claimed — the "เราเห็นว่าร้านปิด 3
/// วัน กดยืนยันเพื่อรับ ฿4,500" moment from the pitch.
class ClaimBanner extends ConsumerWidget {
  const ClaimBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyAsync = ref.watch(activeDailyIncomePolicyProvider);

    return policyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (policy) => policy == null ? const SizedBox.shrink() : _DetectedSummary(policyId: policy.id),
    );
  }
}

class _DetectedSummary extends ConsumerWidget {
  const _DetectedSummary({required this.policyId});
  final String policyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detectedAsync = ref.watch(detectedClaimsProvider(policyId));

    return detectedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (detected) {
        if (detected.isEmpty) return const SizedBox.shrink();

        final totalDays = detected.fold<int>(0, (sum, d) => sum + d.days);
        final totalBenefit = detected.fold<Decimal>(Decimal.zero, (sum, d) => sum + d.benefitAmount);

        return Card(
          color: const Color(0xFF66BB6A).withAlpha(25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: const Color(0xFF66BB6A).withAlpha(80)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Color(0xFF66BB6A)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('เราเห็นว่าร้านปิด $totalDays วัน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('กดยืนยันเพื่อรับเงินชดเชย ${formatBaht(totalBenefit)}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(onPressed: () => context.push('/turbo/insurance'), child: const Text('ดู')),
              ],
            ),
          ),
        );
      },
    );
  }
}
