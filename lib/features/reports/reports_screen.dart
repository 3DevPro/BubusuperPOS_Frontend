import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/formatters.dart';
import 'export_csv.dart';
import 'reports_providers.dart';
import 'reports_repository.dart';

const _periodLabels = {'today': 'วันนี้', 'yesterday': 'เมื่อวาน', '7d': '7 วัน', '30d': '30 วัน'};

final _rangeDateFormat = DateFormat('d MMM', 'th');

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _exporting = false;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: ref.read(customDateRangeProvider) ?? DateTimeRange(start: now, end: now),
    );
    if (picked == null) return;
    ref.read(customDateRangeProvider.notifier).state = picked;
    ref.read(reportPeriodProvider.notifier).state = 'custom';
  }

  Future<void> _exportCsv(String period, DateTimeRange? range) async {
    setState(() => _exporting = true);
    try {
      await exportSalesCsv(ref: ref, period: period, range: range);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ส่งออก CSV ไม่สำเร็จ')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(reportPeriodProvider);
    final range = ref.watch(customDateRangeProvider);
    final summaryAsync = ref.watch(reportSummaryProvider);
    final dailyAsync = ref.watch(dailySeriesProvider);
    final bestSellersAsync = ref.watch(bestSellersProvider);
    final isCustom = period == 'custom';

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงาน'),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download_outlined),
            tooltip: 'ส่งออก CSV',
            onPressed: _exporting ? null : () => _exportCsv(period, range),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: [
                  for (final entry in _periodLabels.entries)
                    ButtonSegment(value: entry.key, label: Text(entry.value)),
                ],
                selected: isCustom ? const <String>{} : {period},
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                onSelectionChanged: (s) => ref.read(reportPeriodProvider.notifier).state = s.first,
              ),
              OutlinedButton.icon(
                onPressed: _pickCustomRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  isCustom && range != null
                      ? '${_rangeDateFormat.format(range.start)} - ${_rangeDateFormat.format(range.end)}'
                      : 'กำหนดช่วงวันที่เอง',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          summaryAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            error: (err, _) => Center(child: Text('โหลดรายงานไม่สำเร็จ: $err')),
            data: (summary) => _SummaryGrid(summary: summary),
          ),
          if (!isCustom) ...[
            const SizedBox(height: 24),
            Text(
              period == '30d' ? 'ยอดขาย 30 วันล่าสุด' : 'ยอดขาย 7 วันล่าสุด',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: dailyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('โหลดกราฟไม่สำเร็จ: $err')),
                data: (points) => _RevenueBarChart(points: points),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('สินค้าขายดี', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          bestSellersAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (err, _) => Center(child: Text('โหลดสินค้าขายดีไม่สำเร็จ: $err')),
            data: (best) => _BestSellersList(items: best),
          ),
        ],
      ),
    );
  }
}

class _BestSellersList extends StatelessWidget {
  const _BestSellersList({required this.items});
  final List<BestSellerDto> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('ยังไม่มีข้อมูลการขาย');
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(items[i].name),
              subtitle: Text('ขายได้ ${items[i].qty} ชิ้น'),
              trailing: Text(formatBaht(items[i].revenue), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final ReportSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('ยอดขาย', formatBaht(summary.revenue), Colors.teal),
      ('กำไร', formatBaht(summary.profit), Colors.green),
      ('จำนวนบิล', '${summary.saleCount}', Colors.blue),
      ('จำนวนชิ้น', '${summary.itemCount}', Colors.orange),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.8,
      children: [
        for (final (label, value, color) in cards)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  const _RevenueBarChart({required this.points});
  final List<DailyPointDto> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('ยังไม่มีข้อมูล'));
    }

    return BarChart(
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
                final index = value.toInt();
                if (index < 0 || index >= points.length) return const SizedBox.shrink();
                final day = points[index].date;
                return SideTitleWidget(
                  meta: meta,
                  child: Text('${day.day}/${day.month}', style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(formatBaht(points[group.x].revenue), const TextStyle(color: Colors.white));
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].revenue.toDouble(),
                  color: Theme.of(context).colorScheme.primary,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
