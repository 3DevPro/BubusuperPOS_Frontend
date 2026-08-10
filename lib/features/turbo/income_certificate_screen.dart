import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../shared/formatters.dart';
import '../settings/settings_providers.dart';
import 'income_certificate_pdf.dart';
import 'turbo_providers.dart';
import 'turbo_repository.dart';

const _creditTierLabels = {
  'none': 'ยังไม่ปลดล็อก',
  'tier_1': 'ระดับ 1 (ปลดล็อกแล้ว)',
  'tier_2': 'ระดับ 2 (ปลดล็อกแล้ว)',
  'tier_3': 'ระดับ 3 (ปลดล็อกแล้ว)',
};

class IncomeCertificateScreen extends ConsumerStatefulWidget {
  const IncomeCertificateScreen({super.key});

  @override
  ConsumerState<IncomeCertificateScreen> createState() => _IncomeCertificateScreenState();
}

class _IncomeCertificateScreenState extends ConsumerState<IncomeCertificateScreen> {
  bool _sharing = false;

  Future<void> _share(IncomeProfileDto profile) async {
    setState(() => _sharing = true);
    try {
      final shopName = ref.read(tenantSettingsProvider).asData?.value.name ?? '';
      final bytes = await buildIncomeCertificatePdf(profile: profile, shopName: shopName);
      await Printing.sharePdf(bytes: bytes, filename: 'income_certificate.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('สร้างใบรับรองรายได้ PDF ไม่สำเร็จ')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(incomeProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ใบรับรองรายได้'),
        actions: [
          profileAsync.maybeWhen(
            data: (profile) => IconButton(
              icon: _sharing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share),
              tooltip: 'ส่งออก PDF',
              onPressed: _sharing ? null : () => _share(profile),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $err')),
        data: (profile) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(incomeProfileProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StreakCard(profile: profile),
              const SizedBox(height: 16),
              _RevenueCard(profile: profile),
              const SizedBox(height: 16),
              _CreditCard(profile: profile),
              if (profile.zeroDays.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ZeroDaysCard(profile: profile),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.profile});
  final IncomeProfileDto profile;

  @override
  Widget build(BuildContext context) {
    // next_tier_in_days is null once the streak has already unlocked tier 1,
    // in which case there's nothing left to add — the ring is simply full.
    final total = profile.streakDays + (profile.nextTierInDays ?? 0);
    final progress = total > 0 ? (profile.streakDays / total).clamp(0.0, 1.0) : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.withAlpha(40),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFE5007D)),
                    ),
                  ),
                  Text('${profile.streakDays}/${total > 0 ? total : 30}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ความคืบหน้าใบรับรองรายได้', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    profile.creditTier == 'tier_1'
                        ? 'ปลดล็อกวงเงินแรกแล้ว จากประวัติ ${profile.streakDays} วันติดต่อกัน'
                        : 'อีก ${profile.nextTierInDays} วันจะปลดล็อกวงเงินแรก',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.profile});
  final IncomeProfileDto profile;

  @override
  Widget build(BuildContext context) {
    final verifiedPct = (profile.verifiedRatio.toDouble() * 100).toStringAsFixed(0);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('รายได้เฉลี่ยต่อวัน', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(formatBaht(profile.avgDailyRevenue), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _splitRow(context, 'รายได้ที่ verify ได้ (QR/บัตร)', profile.verifiedAvgDailyRevenue, const Color(0xFF66BB6A)),
            const SizedBox(height: 8),
            _splitRow(context, 'รายได้เงินสด (แจ้งเอง)', profile.cashAvgDailyRevenue, const Color(0xFFFFA726)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: profile.verifiedRatio.toDouble().clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: const Color(0xFFFFA726).withAlpha(60),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF66BB6A)),
            ),
            const SizedBox(height: 4),
            Text('$verifiedPct% ของรายได้ verify ได้', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _splitRow(BuildContext context, String label, Decimal amount, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(formatBaht(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.profile});
  final IncomeProfileDto profile;

  @override
  Widget build(BuildContext context) {
    final unlocked = profile.creditTier != 'none';
    final color = unlocked ? const Color(0xFF42A5F5) : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: color),
              const SizedBox(width: 8),
              Text(_creditTierLabels[profile.creditTier] ?? profile.creditTier,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text('วงเงินที่ขอได้: ${formatBaht(profile.creditLimit)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'คำนวณจากรายได้ที่ verify เต็มจำนวน + เงินสดครึ่งหนึ่ง เฉลี่ย ${formatBaht(profile.creditWeightedAvgDailyRevenue)}/วัน',
            style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
          ),
          if (profile.nextTierRequirement != null) ...[
            const SizedBox(height: 8),
            Text(profile.nextTierRequirement!, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
          if (unlocked) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/turbo/loans/apply'),
                child: const Text('ยื่นขอสินเชื่อ'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZeroDaysCard extends StatelessWidget {
  const _ZeroDaysCard({required this.profile});
  final IncomeProfileDto profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFA726).withAlpha(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFFFA726)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ร้านปิดโดยไม่มีรายได้ ${profile.zeroDays.length} วัน ในช่วง ${profile.windowDays} วันล่าสุด',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
