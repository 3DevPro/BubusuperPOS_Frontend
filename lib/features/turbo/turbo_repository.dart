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
    required this.onTimePayments,
    required this.nextTierRequirement,
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
  final int onTimePayments;
  final String? nextTierRequirement;

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
    onTimePayments: json['on_time_payments'] as int,
    nextTierRequirement: json['next_tier_requirement'] as String?,
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

class LoanProductDto {
  LoanProductDto({
    required this.id,
    required this.code,
    required this.collateralKind,
    required this.name,
    required this.description,
    required this.maxPrincipal,
    required this.monthlyInterestRate,
    required this.minTermMonths,
    required this.maxTermMonths,
  });

  final String id;
  final String code;
  final String collateralKind;
  final String name;
  final String description;
  final Decimal maxPrincipal;
  final Decimal monthlyInterestRate;
  final int minTermMonths;
  final int maxTermMonths;

  factory LoanProductDto.fromJson(Map<String, dynamic> json) => LoanProductDto(
    id: json['id'] as String,
    code: json['code'] as String,
    collateralKind: json['collateral_kind'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    maxPrincipal: Decimal.parse(json['max_principal'] as String),
    monthlyInterestRate: Decimal.parse(json['monthly_interest_rate'] as String),
    minTermMonths: json['min_term_months'] as int,
    maxTermMonths: json['max_term_months'] as int,
  );
}

class LoanQuoteDto {
  LoanQuoteDto({
    required this.productCode,
    required this.approvedAmount,
    required this.termMonths,
    required this.monthlyInterestRate,
    required this.monthlyInstallment,
    required this.totalInterest,
    required this.totalRepayment,
    required this.capReasons,
  });

  final String productCode;
  final Decimal approvedAmount;
  final int termMonths;
  final Decimal monthlyInterestRate;
  final Decimal monthlyInstallment;
  final Decimal totalInterest;
  final Decimal totalRepayment;
  final List<String> capReasons;

  factory LoanQuoteDto.fromJson(Map<String, dynamic> json) => LoanQuoteDto(
    productCode: json['product_code'] as String,
    approvedAmount: Decimal.parse(json['approved_amount'] as String),
    termMonths: json['term_months'] as int,
    monthlyInterestRate: Decimal.parse(json['monthly_interest_rate'] as String),
    monthlyInstallment: Decimal.parse(json['monthly_installment'] as String),
    totalInterest: Decimal.parse(json['total_interest'] as String),
    totalRepayment: Decimal.parse(json['total_repayment'] as String),
    capReasons: (json['cap_reasons'] as List).map((e) => e as String).toList(),
  );
}

class LoanApplicationDto {
  LoanApplicationDto({
    required this.id,
    required this.productId,
    required this.requestedAmount,
    required this.collateralValue,
    required this.termMonths,
    required this.approvedAmount,
    required this.monthlyInstallment,
    required this.creditTierSnapshot,
    required this.capReasons,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final Decimal requestedAmount;
  final Decimal collateralValue;
  final int termMonths;
  final Decimal approvedAmount;
  final Decimal monthlyInstallment;
  final String creditTierSnapshot;
  final List<String> capReasons;
  final String status;
  final DateTime createdAt;

  factory LoanApplicationDto.fromJson(Map<String, dynamic> json) => LoanApplicationDto(
    id: json['id'] as String,
    productId: json['product_id'] as String,
    requestedAmount: Decimal.parse(json['requested_amount'] as String),
    collateralValue: Decimal.parse(json['collateral_value'] as String),
    termMonths: json['term_months'] as int,
    approvedAmount: Decimal.parse(json['approved_amount'] as String),
    monthlyInstallment: Decimal.parse(json['monthly_installment'] as String),
    creditTierSnapshot: json['credit_tier_snapshot'] as String,
    capReasons: (json['cap_reasons'] as List).map((e) => e as String).toList(),
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class LoanCollateralDetailDto {
  const LoanCollateralDetailDto({this.registrationNo, this.brandModel, this.year, this.note});

  final String? registrationNo;
  final String? brandModel;
  final String? year;
  final String? note;

  Map<String, dynamic> toJson() => {
    if (registrationNo != null && registrationNo!.isNotEmpty) 'registration_no': registrationNo,
    if (brandModel != null && brandModel!.isNotEmpty) 'brand_model': brandModel,
    if (year != null && year!.isNotEmpty) 'year': year,
    if (note != null && note!.isNotEmpty) 'note': note,
  };

  factory LoanCollateralDetailDto.fromJson(Map<String, dynamic> json) => LoanCollateralDetailDto(
    registrationNo: json['registration_no'] as String?,
    brandModel: json['brand_model'] as String?,
    year: json['year'] as String?,
    note: json['note'] as String?,
  );
}

class LoanApplicationEventDto {
  LoanApplicationEventDto({
    required this.id,
    required this.fromStatus,
    required this.toStatus,
    required this.actorName,
    required this.actorKind,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String? fromStatus;
  final String toStatus;
  final String actorName;
  final String actorKind;
  final String? note;
  final DateTime createdAt;

  factory LoanApplicationEventDto.fromJson(Map<String, dynamic> json) => LoanApplicationEventDto(
    id: json['id'] as String,
    fromStatus: json['from_status'] as String?,
    toStatus: json['to_status'] as String,
    actorName: json['actor_name'] as String,
    actorKind: json['actor_kind'] as String,
    note: json['note'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class LoanApplicationDetailDto {
  LoanApplicationDetailDto({
    required this.id,
    required this.productId,
    required this.requestedAmount,
    required this.collateralValue,
    required this.collateralDetail,
    required this.termMonths,
    required this.approvedAmount,
    required this.monthlyInstallment,
    required this.creditTierSnapshot,
    required this.capReasons,
    required this.status,
    required this.rejectionReason,
    required this.stageStartedAt,
    required this.createdAt,
    required this.decidedAt,
    required this.nextStageEtaSeconds,
    required this.canReapplyAt,
    required this.events,
  });

  final String id;
  final String productId;
  final Decimal requestedAmount;
  final Decimal collateralValue;
  final LoanCollateralDetailDto collateralDetail;
  final int termMonths;
  final Decimal approvedAmount;
  final Decimal monthlyInstallment;
  final String creditTierSnapshot;
  final List<String> capReasons;
  final String status;
  final String? rejectionReason;
  final DateTime stageStartedAt;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final int? nextStageEtaSeconds;
  final DateTime? canReapplyAt;
  final List<LoanApplicationEventDto> events;

  factory LoanApplicationDetailDto.fromJson(Map<String, dynamic> json) => LoanApplicationDetailDto(
    id: json['id'] as String,
    productId: json['product_id'] as String,
    requestedAmount: Decimal.parse(json['requested_amount'] as String),
    collateralValue: Decimal.parse(json['collateral_value'] as String),
    collateralDetail: LoanCollateralDetailDto.fromJson(json['collateral_detail'] as Map<String, dynamic>),
    termMonths: json['term_months'] as int,
    approvedAmount: Decimal.parse(json['approved_amount'] as String),
    monthlyInstallment: Decimal.parse(json['monthly_installment'] as String),
    creditTierSnapshot: json['credit_tier_snapshot'] as String,
    capReasons: (json['cap_reasons'] as List).map((e) => e as String).toList(),
    status: json['status'] as String,
    rejectionReason: json['rejection_reason'] as String?,
    stageStartedAt: DateTime.parse(json['stage_started_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    decidedAt: json['decided_at'] == null ? null : DateTime.parse(json['decided_at'] as String),
    nextStageEtaSeconds: json['next_stage_eta_seconds'] as int?,
    canReapplyAt: json['can_reapply_at'] == null ? null : DateTime.parse(json['can_reapply_at'] as String),
    events: (json['events'] as List).map((e) => LoanApplicationEventDto.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class LoanEligibilityDto {
  LoanEligibilityDto({
    required this.canApply,
    required this.reason,
    required this.cooldownUntil,
    required this.inFlightApplicationId,
  });

  final bool canApply;
  final String? reason;
  final DateTime? cooldownUntil;
  final String? inFlightApplicationId;

  factory LoanEligibilityDto.fromJson(Map<String, dynamic> json) => LoanEligibilityDto(
    canApply: json['can_apply'] as bool,
    reason: json['reason'] as String?,
    cooldownUntil: json['cooldown_until'] == null ? null : DateTime.parse(json['cooldown_until'] as String),
    inFlightApplicationId: json['in_flight_application_id'] as String?,
  );
}

// Terminal = the poller (loanApplicationDetailProvider) should stop — none
// of these three can change server-side on their own: approved only moves
// via the tenant's own disburse() tap (not the review clock), and
// rejected/disbursed are dead ends. Every other status can still be moved
// along by the auto-advance clock or a Champion, so polling must continue.
bool isTerminalLoanStatus(String status) =>
    status == 'approved' || status == 'rejected' || status == 'disbursed';

class LoanAccountDto {
  LoanAccountDto({
    required this.id,
    required this.accountNumber,
    required this.principal,
    required this.monthlyInterestRate,
    required this.termMonths,
    required this.monthlyInstallment,
    required this.status,
    required this.disbursedAt,
    required this.firstDueDate,
  });

  final String id;
  final String accountNumber;
  final Decimal principal;
  final Decimal monthlyInterestRate;
  final int termMonths;
  final Decimal monthlyInstallment;
  final String status;
  final DateTime disbursedAt;
  final DateTime firstDueDate;

  factory LoanAccountDto.fromJson(Map<String, dynamic> json) => LoanAccountDto(
    id: json['id'] as String,
    accountNumber: json['account_number'] as String,
    principal: Decimal.parse(json['principal'] as String),
    monthlyInterestRate: Decimal.parse(json['monthly_interest_rate'] as String),
    termMonths: json['term_months'] as int,
    monthlyInstallment: Decimal.parse(json['monthly_installment'] as String),
    status: json['status'] as String,
    disbursedAt: DateTime.parse(json['disbursed_at'] as String),
    firstDueDate: DateTime.parse(json['first_due_date'] as String),
  );
}

class LoanInstallmentDto {
  LoanInstallmentDto({
    required this.id,
    required this.accountId,
    required this.sequence,
    required this.dueDate,
    required this.amountDue,
    required this.status,
    required this.paidAt,
    required this.isOverdue,
    required this.daysOverdue,
  });

  final String id;
  final String accountId;
  final int sequence;
  final DateTime dueDate;
  final Decimal amountDue;
  final String status;
  final DateTime? paidAt;
  final bool isOverdue;
  final int? daysOverdue;

  factory LoanInstallmentDto.fromJson(Map<String, dynamic> json) => LoanInstallmentDto(
    id: json['id'] as String,
    accountId: json['account_id'] as String,
    sequence: json['sequence'] as int,
    dueDate: DateTime.parse(json['due_date'] as String),
    amountDue: Decimal.parse(json['amount_due'] as String),
    status: json['status'] as String,
    paidAt: json['paid_at'] == null ? null : DateTime.parse(json['paid_at'] as String),
    isOverdue: json['is_overdue'] as bool,
    daysOverdue: json['days_overdue'] as int?,
  );
}

class LoanAccountSummaryDto {
  LoanAccountSummaryDto({
    required this.account,
    required this.outstandingBalance,
    required this.installmentsTotal,
    required this.installmentsPaid,
    required this.onTimePayments,
    required this.nextDueDate,
    required this.nextDueAmount,
    required this.dueInDays,
    required this.hasOverdue,
    required this.overdueCount,
    required this.overdueAmount,
    required this.maxDaysOverdue,
  });

  final LoanAccountDto account;
  final Decimal outstandingBalance;
  final int installmentsTotal;
  final int installmentsPaid;
  final int onTimePayments;
  final DateTime? nextDueDate;
  final Decimal? nextDueAmount;
  final int? dueInDays;
  final bool hasOverdue;
  final int overdueCount;
  final Decimal overdueAmount;
  final int? maxDaysOverdue;

  factory LoanAccountSummaryDto.fromJson(Map<String, dynamic> json) => LoanAccountSummaryDto(
    account: LoanAccountDto.fromJson(json['account'] as Map<String, dynamic>),
    outstandingBalance: Decimal.parse(json['outstanding_balance'] as String),
    installmentsTotal: json['installments_total'] as int,
    installmentsPaid: json['installments_paid'] as int,
    onTimePayments: json['on_time_payments'] as int,
    nextDueDate: json['next_due_date'] == null ? null : DateTime.parse(json['next_due_date'] as String),
    nextDueAmount: json['next_due_amount'] == null ? null : Decimal.parse(json['next_due_amount'] as String),
    dueInDays: json['due_in_days'] as int?,
    hasOverdue: json['has_overdue'] as bool,
    overdueCount: json['overdue_count'] as int,
    overdueAmount: Decimal.parse(json['overdue_amount'] as String),
    maxDaysOverdue: json['max_days_overdue'] as int?,
  );
}

class CreditStandingDto {
  CreditStandingDto({
    required this.creditTier,
    required this.creditLimit,
    required this.streakDays,
    required this.onTimePayments,
    required this.nextTierInDays,
    required this.nextTierRequirement,
  });

  final String creditTier;
  final Decimal creditLimit;
  final int streakDays;
  final int onTimePayments;
  final int? nextTierInDays;
  final String? nextTierRequirement;

  factory CreditStandingDto.fromJson(Map<String, dynamic> json) => CreditStandingDto(
    creditTier: json['credit_tier'] as String,
    creditLimit: Decimal.parse(json['credit_limit'] as String),
    streakDays: json['streak_days'] as int,
    onTimePayments: json['on_time_payments'] as int,
    nextTierInDays: json['next_tier_in_days'] as int?,
    nextTierRequirement: json['next_tier_requirement'] as String?,
  );
}

class NearbyBranchDto {
  NearbyBranchDto({
    required this.id,
    required this.code,
    required this.name,
    required this.province,
    required this.lat,
    required this.lng,
    required this.distanceKm,
  });

  final String id;
  final String code;
  final String name;
  final String province;
  final Decimal lat;
  final Decimal lng;
  final double distanceKm;

  factory NearbyBranchDto.fromJson(Map<String, dynamic> json) => NearbyBranchDto(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    province: json['province'] as String,
    lat: Decimal.parse(json['lat'] as String),
    lng: Decimal.parse(json['lng'] as String),
    distanceKm: (json['distance_km'] as num).toDouble(),
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

  Future<void> reopenDay(DateTime businessDate) async {
    await _apiClient.dio.delete('/api/v1/turbo/daily-close/${_isoDate(businessDate)}');
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

  Future<List<LoanProductDto>> loanProducts() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/loans/products');
    return (resp.data as List).map((e) => LoanProductDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LoanQuoteDto> loanQuote({
    required String productCode,
    required Decimal requestedAmount,
    required Decimal collateralValue,
    required int termMonths,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/loans/quote',
      data: {
        'product_code': productCode,
        'requested_amount': requestedAmount.toString(),
        'collateral_value': collateralValue.toString(),
        'term_months': termMonths,
      },
    );
    return LoanQuoteDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<LoanApplicationDto> applyForLoan({
    required String productCode,
    required Decimal requestedAmount,
    required Decimal collateralValue,
    required int termMonths,
    LoanCollateralDetailDto collateralDetail = const LoanCollateralDetailDto(),
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/loans/applications',
      data: {
        'product_code': productCode,
        'requested_amount': requestedAmount.toString(),
        'collateral_value': collateralValue.toString(),
        'term_months': termMonths,
        'collateral_detail': collateralDetail.toJson(),
      },
    );
    return LoanApplicationDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<LoanApplicationDto>> loanApplications() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/loans/applications');
    return (resp.data as List).map((e) => LoanApplicationDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LoanApplicationDetailDto> loanApplication(String applicationId) async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/loans/applications/$applicationId');
    return LoanApplicationDetailDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<LoanEligibilityDto> loanEligibility() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/loans/eligibility');
    return LoanEligibilityDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<LoanApplicationDetailDto> fastForwardLoanApplication(String applicationId) async {
    final resp = await _apiClient.dio.post('/api/v1/turbo/loans/applications/$applicationId/demo/fast-forward');
    return LoanApplicationDetailDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<LoanAccountDto> disburseLoan(String applicationId) async {
    final resp = await _apiClient.dio.post('/api/v1/turbo/loans/applications/$applicationId/disburse');
    return LoanAccountDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<LoanAccountSummaryDto?> loanAccountSummary() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/loans/account');
    if (resp.data == null) return null;
    return LoanAccountSummaryDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<LoanInstallmentDto>> loanInstallments(String accountId) async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/loans/account/$accountId/installments');
    return (resp.data as List).map((e) => LoanInstallmentDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LoanInstallmentDto> payInstallment({
    required String installmentId,
    required Decimal amount,
    String? reference,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/loans/installments/$installmentId/payment',
      data: {'amount': amount.toString(), if (reference != null) 'reference': reference},
    );
    return LoanInstallmentDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<CreditStandingDto> creditStanding() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/credit-standing');
    return CreditStandingDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<NearbyBranchDto>> nearbyBranches(double lat, double lng) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/turbo/branch/nearby',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return (resp.data as List).map((e) => NearbyBranchDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
