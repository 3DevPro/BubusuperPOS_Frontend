import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/formatters.dart';
import '../auth/auth_provider.dart';
import 'turbo_providers.dart';
import 'turbo_repository.dart';

const _collateralIcons = {
  'motorcycle': Icons.two_wheeler_rounded,
  'car': Icons.directions_car_rounded,
  'tractor': Icons.agriculture_rounded,
  'land_title': Icons.landscape_rounded,
};

const _creditTierLabels = {
  'none': 'ยังไม่ปลดล็อกวงเงิน',
  'tier_1': 'ระดับ 1',
  'tier_2': 'ระดับ 2',
  'tier_3': 'ระดับ 3',
};

String _shortDate(DateTime d) => '${d.day}/${d.month}/${d.year + 543}';

/// The "เทอร์โบ" tab — home for everything money-related: the income
/// certificate summary, the 4 secured-loan products, the tenant's own loan
/// account (if any), and their insurance. Owner/manager only — a cashier
/// sees a permission notice instead of the financial content, same UX
/// rationale as the dashboard's canManageInsurance gate.
class TurboHomeScreen extends ConsumerWidget {
  const TurboHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).me?['role'] as String?;
    final canManage = role == 'owner' || role == 'manager';

    return Scaffold(
      appBar: AppBar(title: const Text('เงินเทอร์โบ')),
      body: canManage ? const _TurboHomeBody() : const _PermissionNotice(),
    );
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('เมนูนี้สำหรับเจ้าของร้านหรือผู้จัดการเท่านั้น', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TurboHomeBody extends ConsumerWidget {
  const _TurboHomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(incomeProfileProvider);
    final productsAsync = ref.watch(loanProductsProvider);
    final accountAsync = ref.watch(loanAccountSummaryProvider);
    final policiesAsync = ref.watch(insurancePoliciesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(incomeProfileProvider);
        ref.invalidate(loanProductsProvider);
        ref.invalidate(loanAccountSummaryProvider);
        ref.invalidate(insurancePoliciesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          profileAsync.when(
            loading: () => const _LoadingCard(),
            error: (err, _) => _ErrorCard(message: '$err'),
            data: (profile) => _IncomeCertificateHero(profile: profile),
          ),
          const SizedBox(height: 20),
          accountAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (err, _) => const SizedBox.shrink(),
            data: (summary) => summary == null ? const SizedBox.shrink() : _DueReminderBanner(summary: summary),
          ),
          const Text('เลือกประเภทสินเชื่อได้เลย!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          productsAsync.when(
            loading: () => const _LoadingCard(),
            error: (err, _) => _ErrorCard(message: '$err'),
            data: (products) => _LoanProductGrid(products: products),
          ),
          const SizedBox(height: 20),
          const Text('บัญชีสินเชื่อของคุณ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          accountAsync.when(
            loading: () => const _LoadingCard(),
            error: (err, _) => _ErrorCard(message: '$err'),
            data: (summary) => summary == null ? const _NoLoanAccountCard() : _LoanAccountCard(summary: summary),
          ),
          const SizedBox(height: 20),
          const Text('ประกันของคุณ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          policiesAsync.when(
            loading: () => const _LoadingCard(),
            error: (err, _) => _ErrorCard(message: '$err'),
            data: (policies) => _InsuranceSummaryCard(activeCount: policies.where((p) => p.status == 'active').length),
          ),
          const SizedBox(height: 20),
          const Text('สาขาใกล้ฉัน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const _NearbyBranchSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text('โหลดข้อมูลไม่สำเร็จ: $message')),
  );
}

class _IncomeCertificateHero extends StatelessWidget {
  const _IncomeCertificateHero({required this.profile});
  final IncomeProfileDto profile;

  @override
  Widget build(BuildContext context) {
    final total = profile.streakDays + (profile.nextTierInDays ?? 0);
    final progress = total > 0 ? (profile.streakDays / total).clamp(0.0, 1.0) : 0.0;
    final unlocked = profile.creditTier != 'none';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/turbo/income-certificate'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        backgroundColor: Colors.grey.withAlpha(40),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFE5007D)),
                      ),
                    ),
                    Text('${profile.streakDays}/${total > 0 ? total : 30}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ใบรับรองรายได้ · ${_creditTierLabels[profile.creditTier] ?? profile.creditTier}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      '${formatBaht(profile.avgDailyRevenue)}/วัน · วงเงิน ${formatBaht(profile.creditLimit)}',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
                    ),
                    if (!unlocked) ...[
                      const SizedBox(height: 2),
                      Text('อีก ${profile.nextTierInDays} วันปลดล็อกวงเงินแรก',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFE5007D))),
                    ] else if (profile.nextTierRequirement != null) ...[
                      const SizedBox(height: 2),
                      Text(profile.nextTierRequirement!, style: const TextStyle(fontSize: 12, color: Color(0xFFE5007D))),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueReminderBanner extends StatelessWidget {
  const _DueReminderBanner({required this.summary});
  final LoanAccountSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasOverdue && (summary.dueInDays == null || summary.dueInDays! > 7)) {
      return const SizedBox.shrink();
    }
    final overdue = summary.hasOverdue;
    final color = overdue ? const Color(0xFFEF5350) : const Color(0xFFFFA726);
    final text = overdue
        ? 'ค้างชำระ ${summary.overdueCount} งวด รวม ${formatBaht(summary.overdueAmount)} (ช้าสุด ${summary.maxDaysOverdue} วัน)'
        : 'งวดถัดไปครบกำหนดอีก ${summary.dueInDays} วัน จำนวน ${formatBaht(summary.nextDueAmount!)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: color.withAlpha(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withAlpha(80))),
        child: ListTile(
          leading: Icon(Icons.notifications_active_outlined, color: color),
          title: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          trailing: TextButton(
            onPressed: () => context.push('/turbo/loans/account'),
            child: const Text('ชำระเลย'),
          ),
        ),
      ),
    );
  }
}

class _LoanProductGrid extends StatelessWidget {
  const _LoanProductGrid({required this.products});
  final List<LoanProductDto> products;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [for (final product in products) _LoanProductTile(product: product)],
    );
  }
}

class _LoanProductTile extends StatelessWidget {
  const _LoanProductTile({required this.product});
  final LoanProductDto product;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/turbo/loans/apply?product=${product.code}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_collateralIcons[product.collateralKind] ?? Icons.request_quote_rounded, color: const Color(0xFFE5007D)),
              const Spacer(),
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                'สูงสุด ${formatBaht(product.maxPrincipal)}',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoLoanAccountCard extends StatelessWidget {
  const _NoLoanAccountCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'ยังไม่มีบัญชีสินเชื่อ — เลือกประเภทสินเชื่อด้านบนเพื่อยื่นขอได้เลย',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
        ),
      ),
    );
  }
}

class _LoanAccountCard extends StatelessWidget {
  const _LoanAccountCard({required this.summary});
  final LoanAccountSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    final remaining = summary.installmentsTotal - summary.installmentsPaid;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('บัญชี ${summary.account.accountNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text('คงเหลือ ${formatBaht(summary.outstandingBalance)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5007D))),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: summary.installmentsTotal > 0 ? summary.installmentsPaid / summary.installmentsTotal : 0,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.grey.withAlpha(40),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF66BB6A)),
            ),
            const SizedBox(height: 6),
            Text(
              'ผ่อนแล้ว ${summary.installmentsPaid}/${summary.installmentsTotal} งวด (เหลือ $remaining งวด)'
              '${summary.nextDueDate != null ? ' · งวดถัดไป ${_shortDate(summary.nextDueDate!)}' : ''}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/turbo/loans/account'),
                    child: const Text('ตารางผ่อน'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push('/turbo/loans/account'),
                    child: const Text('ชำระด้วย QR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsuranceSummaryCard extends StatelessWidget {
  const _InsuranceSummaryCard({required this.activeCount});
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.health_and_safety_outlined, color: Color(0xFF66BB6A)),
        title: Text(activeCount > 0 ? 'มีกรมธรรม์ใช้งานอยู่ $activeCount ฉบับ' : 'ยังไม่มีกรมธรรม์'),
        subtitle: const Text('ชดเชยรายได้ อุบัติเหตุ สุขภาพ ทรัพย์สินร้าน'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/turbo/insurance'),
      ),
    );
  }
}

enum _NearbyBranchStatus { idle, loading, error, loaded }

class _NearbyBranchSection extends ConsumerStatefulWidget {
  const _NearbyBranchSection();

  @override
  ConsumerState<_NearbyBranchSection> createState() => _NearbyBranchSectionState();
}

class _NearbyBranchSectionState extends ConsumerState<_NearbyBranchSection> {
  _NearbyBranchStatus _status = _NearbyBranchStatus.idle;
  List<NearbyBranchDto> _branches = [];
  String? _error;

  Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('กรุณาเปิดบริการตำแหน่งของเครื่อง');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง');
    }
    return Geolocator.getCurrentPosition();
  }

  Future<void> _findNearby() async {
    setState(() {
      _status = _NearbyBranchStatus.loading;
      _error = null;
    });
    try {
      final position = await _getPosition();
      final branches = await ref
          .read(turboRepositoryProvider)
          .nearbyBranches(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _status = _NearbyBranchStatus.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _status = _NearbyBranchStatus.error;
      });
    }
  }

  Future<void> _openInMaps(NearbyBranchDto branch) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${branch.lat},${branch.lng}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _NearbyBranchStatus.idle:
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 12),
                const Expanded(child: Text('หาสาขาเงินเทอร์โบที่ใกล้คุณที่สุด')),
                FilledButton(onPressed: _findNearby, child: const Text('หาสาขาใกล้ฉัน')),
              ],
            ),
          ),
        );
      case _NearbyBranchStatus.loading:
        return const _LoadingCard();
      case _NearbyBranchStatus.error:
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error ?? 'เกิดข้อผิดพลาด', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _findNearby, child: const Text('ลองอีกครั้ง')),
              ],
            ),
          ),
        );
      case _NearbyBranchStatus.loaded:
        if (_branches.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('ไม่พบสาขาใกล้คุณ', style: TextStyle(fontSize: 13)),
            ),
          );
        }
        return Column(
          children: [
            for (final branch in _branches)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.store_mall_directory_outlined, color: Color(0xFFE5007D)),
                  title: Text(branch.name),
                  subtitle: Text('${branch.province} · ${branch.distanceKm.toStringAsFixed(1)} กม.'),
                  trailing: const Icon(Icons.directions_outlined),
                  onTap: () => _openInMaps(branch),
                ),
              ),
          ],
        );
    }
  }
}
