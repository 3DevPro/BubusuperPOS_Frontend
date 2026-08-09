import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import '../auth/auth_provider.dart';
import '../reports/reports_providers.dart';
import '../reports/reports_repository.dart';
import '../turbo/claim_banner.dart';
import '../turbo/daily_close_card.dart';

/// Today's summary — a separate provider so it doesn't interfere with the
/// period-based one in the full reports screen.
final _todaySummaryProvider = FutureProvider.autoDispose<ReportSummaryDto>((ref) {
  return ref.watch(reportsRepositoryProvider).summary('today');
});

final _weeklySeriesProvider = FutureProvider.autoDispose<List<DailyPointDto>>((ref) {
  return ref.watch(reportsRepositoryProvider).daily(days: 7);
});

final _bestSellersProvider = FutureProvider.autoDispose<List<BestSellerDto>>((ref) {
  return ref.watch(reportsRepositoryProvider).bestSellers('today');
});

class DailyDashboardScreen extends ConsumerWidget {
  const DailyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_todaySummaryProvider);
    final dailyAsync = ref.watch(_weeklySeriesProvider);
    final bestAsync = ref.watch(_bestSellersProvider);
    final cs = Theme.of(context).colorScheme;
    final role = ref.watch(authControllerProvider).me?['role'] as String?;
    // Matches Permission.manage_insurance server-side — a cashier's calls
    // would just 403, so skip even asking rather than show-then-fail.
    final canManageInsurance = role == 'owner' || role == 'manager';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFFFF2D95)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.speed, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Turbo POS', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_todaySummaryProvider);
          ref.invalidate(_weeklySeriesProvider);
          ref.invalidate(_bestSellersProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Greeting ──
            Text(_greeting(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(
              _formatThaiDate(DateTime.now()),
              style: TextStyle(color: cs.outline, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // ── Today Summary ──
            summaryAsync.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('โหลดสรุปไม่สำเร็จ: $err'),
                ),
              ),
              data: (s) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _SummaryCard(
                        icon: Icons.trending_up_rounded,
                        label: 'ยอดขายวันนี้',
                        value: formatBaht(s.revenue),
                        color: const Color(0xFF00BFA5),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'กำไรวันนี้',
                        value: formatBaht(s.profit),
                        color: const Color(0xFF66BB6A),
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _SummaryCard(
                        icon: Icons.receipt_long_rounded,
                        label: 'จำนวนบิล',
                        value: '${s.saleCount}',
                        color: const Color(0xFF42A5F5),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard(
                        icon: Icons.inventory_2_rounded,
                        label: 'จำนวนชิ้น',
                        value: '${s.itemCount}',
                        color: const Color(0xFFFF2D95),
                      )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Detected Insurance Claims ──
            if (canManageInsurance) ...[
              const ClaimBanner(),
              const SizedBox(height: 16),
            ],

            // ── Daily Close ──
            const DailyCloseCard(),
            const SizedBox(height: 32),

            // ── 7-Day Chart ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ยอดขาย 7 วันล่าสุด',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => context.push('/reports'),
                  child: const Text('ดูรายงานเต็ม →', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: dailyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('โหลดกราฟไม่สำเร็จ: $err')),
                data: (points) => _GradientBarChart(points: points),
              ),
            ),
            const SizedBox(height: 32),

            // ── Best Sellers ──
            const Text('สินค้าขายดีวันนี้',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            bestAsync.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text('โหลดไม่สำเร็จ: $err'),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('ยังไม่มียอดขายวันนี้',
                        style: TextStyle(color: cs.outline)),
                    )
                  : Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFF2D95).withAlpha(30),
                                foregroundColor: const Color(0xFFFF2D95),
                                child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('ขายได้ ${items[i].qty} ชิ้น'),
                              trailing: Text(formatBaht(items[i].revenue),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'สวัสดีตอนเช้า';
    if (h < 17) return 'สวัสดีตอนบ่าย';
    return 'สวัสดีตอนเย็น';
  }

  String _formatThaiDate(DateTime d) {
    const months = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
    return '${d.day} ${months[d.month]} ${d.year + 543}';
  }
}

// ── Summary Card with subtle gradient border ──

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon, required this.label,
    required this.value, required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: color.withAlpha(200), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: color,
          )),
        ],
      ),
    );
  }
}

// ── Gradient Bar Chart ──

class _GradientBarChart extends StatelessWidget {
  const _GradientBarChart({required this.points});
  final List<DailyPointDto> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: Text('ยังไม่มีข้อมูล'));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                    final d = points[idx].date;
                    return SideTitleWidget(
                      meta: meta,
                      child: Text('${d.day}/${d.month}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                  formatBaht(points[group.x].revenue),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: points[i].revenue.toDouble(),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xFF1A237E), Color(0xFFFF2D95)],
                      ),
                      width: 22,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
