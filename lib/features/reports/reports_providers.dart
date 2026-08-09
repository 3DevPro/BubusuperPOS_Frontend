import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'reports_repository.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(apiClientProvider));
});

final reportPeriodProvider = StateProvider<String>((ref) => 'today');

// Only meaningful when reportPeriodProvider == 'custom' — set together by the
// date-range picker in reports_screen.dart.
final customDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

final reportSummaryProvider = FutureProvider.autoDispose<ReportSummaryDto>((ref) {
  final period = ref.watch(reportPeriodProvider);
  final range = ref.watch(customDateRangeProvider);
  return ref
      .watch(reportsRepositoryProvider)
      .summary(period, startDate: range?.start, endDate: range?.end);
});

final dailySeriesProvider = FutureProvider.autoDispose<List<DailyPointDto>>((ref) {
  final period = ref.watch(reportPeriodProvider);
  // today/yesterday/7d still show a 7-day trailing chart for context — only
  // 30d actually needs a wider window, since a 1-day trend has no shape.
  // Custom ranges have no matching /reports/daily equivalent (it's always
  // "N days ending today") — the UI simply hides this chart in that mode,
  // so this provider is never watched for period == 'custom'.
  final days = switch (period) { '30d' => 30, _ => 7 };
  return ref.watch(reportsRepositoryProvider).daily(days: days);
});

final bestSellersProvider = FutureProvider.autoDispose<List<BestSellerDto>>((ref) {
  final period = ref.watch(reportPeriodProvider);
  final range = ref.watch(customDateRangeProvider);
  return ref
      .watch(reportsRepositoryProvider)
      .bestSellers(period, startDate: range?.start, endDate: range?.end);
});
