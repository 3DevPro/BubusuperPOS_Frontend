import 'package:decimal/decimal.dart';

import '../../core/api_client.dart';

class DailyCloseDto {
  DailyCloseDto({
    required this.id,
    required this.businessDate,
    required this.closedReason,
    required this.extraExpense,
    required this.note,
    required this.closedAt,
  });

  final String id;
  final DateTime businessDate;
  final String closedReason;
  final Decimal extraExpense;
  final String? note;
  final DateTime closedAt;

  factory DailyCloseDto.fromJson(Map<String, dynamic> json) => DailyCloseDto(
    id: json['id'] as String,
    businessDate: DateTime.parse(json['business_date'] as String),
    closedReason: json['closed_reason'] as String,
    extraExpense: Decimal.parse(json['extra_expense'] as String),
    note: json['note'] as String?,
    closedAt: DateTime.parse(json['closed_at'] as String),
  );
}

class IncomeProfileDto {
  IncomeProfileDto({
    required this.windowDays,
    required this.daysRecorded,
    required this.streakDays,
    required this.avgDailyRevenue,
    required this.verifiedAvgDailyRevenue,
    required this.cashAvgDailyRevenue,
    required this.verifiedRatio,
    required this.creditWeightedAvgDailyRevenue,
    required this.volatility,
    required this.zeroDays,
    required this.creditTier,
    required this.creditLimit,
    required this.nextTierInDays,
  });

  final int windowDays;
  final int daysRecorded;
  final int streakDays;
  final Decimal avgDailyRevenue;
  final Decimal verifiedAvgDailyRevenue;
  final Decimal cashAvgDailyRevenue;
  final Decimal verifiedRatio;
  final Decimal creditWeightedAvgDailyRevenue;
  final Decimal volatility;
  final List<DateTime> zeroDays;
  final String creditTier;
  final Decimal creditLimit;
  final int? nextTierInDays;

  factory IncomeProfileDto.fromJson(Map<String, dynamic> json) => IncomeProfileDto(
    windowDays: json['window_days'] as int,
    daysRecorded: json['days_recorded'] as int,
    streakDays: json['streak_days'] as int,
    avgDailyRevenue: Decimal.parse(json['avg_daily_revenue'] as String),
    verifiedAvgDailyRevenue: Decimal.parse(json['verified_avg_daily_revenue'] as String),
    cashAvgDailyRevenue: Decimal.parse(json['cash_avg_daily_revenue'] as String),
    verifiedRatio: Decimal.parse(json['verified_ratio'] as String),
    creditWeightedAvgDailyRevenue: Decimal.parse(json['credit_weighted_avg_daily_revenue'] as String),
    volatility: Decimal.parse(json['volatility'] as String),
    zeroDays: (json['zero_days'] as List).map((d) => DateTime.parse(d as String)).toList(),
    creditTier: json['credit_tier'] as String,
    creditLimit: Decimal.parse(json['credit_limit'] as String),
    nextTierInDays: json['next_tier_in_days'] as int?,
  );
}

class InsuranceProductDto {
  InsuranceProductDto({
    required this.id,
    required this.code,
    required this.kind,
    required this.name,
    required this.description,
    required this.flatMonthlyPremium,
  });

  final String id;
  final String code;
  final String kind;
  final String name;
  final String description;
  final Decimal flatMonthlyPremium;

  factory InsuranceProductDto.fromJson(Map<String, dynamic> json) => InsuranceProductDto(
    id: json['id'] as String,
    code: json['code'] as String,
    kind: json['kind'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    flatMonthlyPremium: Decimal.parse(json['flat_monthly_premium'] as String),
  );
}

class InsuranceQuoteDto {
  InsuranceQuoteDto({
    required this.productCode,
    required this.dailyBenefit,
    required this.premiumAmount,
    required this.premiumCycle,
  });

  final String productCode;
  final Decimal dailyBenefit;
  final Decimal premiumAmount;
  final String premiumCycle;

  factory InsuranceQuoteDto.fromJson(Map<String, dynamic> json) => InsuranceQuoteDto(
    productCode: json['product_code'] as String,
    dailyBenefit: Decimal.parse(json['daily_benefit'] as String),
    premiumAmount: Decimal.parse(json['premium_amount'] as String),
    premiumCycle: json['premium_cycle'] as String,
  );
}

class InsurancePolicyDto {
  InsurancePolicyDto({
    required this.id,
    required this.productId,
    required this.dailyBenefit,
    required this.premiumAmount,
    required this.premiumCycle,
    required this.status,
    required this.startsAt,
  });

  final String id;
  final String productId;
  final Decimal dailyBenefit;
  final Decimal premiumAmount;
  final String premiumCycle;
  final String status;
  final DateTime startsAt;

  factory InsurancePolicyDto.fromJson(Map<String, dynamic> json) => InsurancePolicyDto(
    id: json['id'] as String,
    productId: json['product_id'] as String,
    dailyBenefit: Decimal.parse(json['daily_benefit'] as String),
    premiumAmount: Decimal.parse(json['premium_amount'] as String),
    premiumCycle: json['premium_cycle'] as String,
    status: json['status'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String),
  );
}

class DetectedClaimDto {
  DetectedClaimDto({
    required this.policyId,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.benefitAmount,
    required this.reasons,
  });

  final String policyId;
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final Decimal benefitAmount;
  final Map<String, String> reasons;

  factory DetectedClaimDto.fromJson(Map<String, dynamic> json) => DetectedClaimDto(
    policyId: json['policy_id'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    days: json['days'] as int,
    benefitAmount: Decimal.parse(json['benefit_amount'] as String),
    reasons: Map<String, String>.from(json['reasons'] as Map),
  );
}

class InsuranceClaimDto {
  InsuranceClaimDto({
    required this.id,
    required this.policyId,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.benefitAmount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String policyId;
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final Decimal benefitAmount;
  final String status;
  final DateTime createdAt;

  factory InsuranceClaimDto.fromJson(Map<String, dynamic> json) => InsuranceClaimDto(
    id: json['id'] as String,
    policyId: json['policy_id'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    days: json['days'] as int,
    benefitAmount: Decimal.parse(json['benefit_amount'] as String),
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class TurboRepository {
  TurboRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<IncomeProfileDto> incomeProfile({int days = 30}) async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/income-profile', queryParameters: {'days': days});
    return IncomeProfileDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<DailyCloseDto> closeDay({
    required DateTime businessDate,
    String closedReason = 'open',
    Decimal? extraExpense,
    String? note,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/daily-close',
      data: {
        'business_date': _isoDate(businessDate),
        'closed_reason': closedReason,
        if (extraExpense != null) 'extra_expense': extraExpense.toString(),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return DailyCloseDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<DailyCloseDto>> listCloses({int days = 30}) async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/daily-close', queryParameters: {'days': days});
    return (resp.data as List).map((e) => DailyCloseDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<InsuranceProductDto>> insuranceProducts() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/insurance/products');
    return (resp.data as List).map((e) => InsuranceProductDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<InsuranceQuoteDto> insuranceQuote(String productCode) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/turbo/insurance/quote',
      queryParameters: {'product_code': productCode},
    );
    return InsuranceQuoteDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<InsurancePolicyDto> purchaseInsurance(String productCode) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/insurance/policies',
      data: {'product_code': productCode},
    );
    return InsurancePolicyDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<InsurancePolicyDto>> insurancePolicies() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/insurance/policies');
    return (resp.data as List).map((e) => InsurancePolicyDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DetectedClaimDto>> detectedClaims(String policyId) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/turbo/insurance/claims/detected',
      queryParameters: {'policy_id': policyId},
    );
    return (resp.data as List).map((e) => DetectedClaimDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<InsuranceClaimDto> createClaim({
    required String policyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/insurance/claims',
      data: {'policy_id': policyId, 'start_date': _isoDate(startDate), 'end_date': _isoDate(endDate)},
    );
    return InsuranceClaimDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<InsuranceClaimDto>> insuranceClaims() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/insurance/claims');
    return (resp.data as List).map((e) => InsuranceClaimDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
