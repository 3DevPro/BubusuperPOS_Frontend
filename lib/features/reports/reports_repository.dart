import 'package:decimal/decimal.dart';

import '../../core/api_client.dart';

class ReportSummaryDto {
  ReportSummaryDto({
    required this.period,
    required this.saleCount,
    required this.revenue,
    required this.profit,
    required this.itemCount,
  });

  final String period;
  final int saleCount;
  final Decimal revenue;
  final Decimal profit;
  final int itemCount;

  factory ReportSummaryDto.fromJson(Map<String, dynamic> json) => ReportSummaryDto(
    period: json['period'] as String,
    saleCount: json['sale_count'] as int,
    revenue: Decimal.parse(json['revenue'] as String),
    profit: Decimal.parse(json['profit'] as String),
    itemCount: json['item_count'] as int,
  );
}

class DailyPointDto {
  DailyPointDto({required this.date, required this.saleCount, required this.revenue});

  final DateTime date;
  final int saleCount;
  final Decimal revenue;

  factory DailyPointDto.fromJson(Map<String, dynamic> json) => DailyPointDto(
    date: DateTime.parse(json['date'] as String),
    saleCount: json['sale_count'] as int,
    revenue: Decimal.parse(json['revenue'] as String),
  );
}

class BestSellerDto {
  BestSellerDto({required this.productId, required this.name, required this.qty, required this.revenue});

  final String productId;
  final String name;
  final int qty;
  final Decimal revenue;

  factory BestSellerDto.fromJson(Map<String, dynamic> json) => BestSellerDto(
    productId: json['product_id'] as String,
    name: json['name'] as String,
    qty: json['qty'] as int,
    revenue: Decimal.parse(json['revenue'] as String),
  );
}

class ReportsRepository {
  ReportsRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<ReportSummaryDto> summary(String period, {DateTime? startDate, DateTime? endDate}) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/reports/summary',
      queryParameters: {
        'period': period,
        if (startDate != null) 'start_date': _isoDate(startDate),
        if (endDate != null) 'end_date': _isoDate(endDate),
      },
    );
    return ReportSummaryDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<DailyPointDto>> daily({int days = 7}) async {
    final resp = await _apiClient.dio.get('/api/v1/reports/daily', queryParameters: {'days': days});
    return (resp.data as List).map((e) => DailyPointDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BestSellerDto>> bestSellers(
    String period, {
    int limit = 5,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/reports/best-sellers',
      queryParameters: {
        'period': period,
        'limit': limit,
        if (startDate != null) 'start_date': _isoDate(startDate),
        if (endDate != null) 'end_date': _isoDate(endDate),
      },
    );
    return (resp.data as List).map((e) => BestSellerDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
