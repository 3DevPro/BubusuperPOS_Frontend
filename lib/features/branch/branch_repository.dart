import 'package:decimal/decimal.dart';

import '../../core/api_client.dart';
// Reused rather than redeclared — both /turbo/loans/applications/{id} and
// /turbo/branch/loan-applications/{id} return the exact same event-log and
// collateral-detail shapes (see the backend's LoanApplicationEventResponse,
// shared by both response models), so one Dart DTO each covers both sides.
import '../turbo/turbo_repository.dart' show LoanApplicationEventDto, LoanCollateralDetailDto;

class ProspectDto {
  ProspectDto({
    required this.id,
    required this.name,
    required this.businessType,
    required this.address,
    required this.phone,
    required this.status,
    required this.applicationInterest,
    required this.contactStatus,
    required this.contactStatusUpdatedAt,
    required this.calledAt,
    required this.metAt,
    required this.note,
    required this.lastVisitedAt,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? businessType;
  final String? address;
  final String? phone;
  final String status;
  final String applicationInterest;
  final String contactStatus;
  final DateTime? contactStatusUpdatedAt;
  final DateTime? calledAt;
  final DateTime? metAt;
  final String? note;
  final DateTime? lastVisitedAt;
  final DateTime createdAt;

  factory ProspectDto.fromJson(Map<String, dynamic> json) => ProspectDto(
    id: json['id'] as String,
    name: json['name'] as String,
    businessType: json['business_type'] as String?,
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    status: json['status'] as String,
    applicationInterest: json['application_interest'] as String,
    contactStatus: json['contact_status'] as String,
    contactStatusUpdatedAt: json['contact_status_updated_at'] == null
        ? null
        : DateTime.parse(json['contact_status_updated_at'] as String),
    calledAt: json['called_at'] == null ? null : DateTime.parse(json['called_at'] as String),
    metAt: json['met_at'] == null ? null : DateTime.parse(json['met_at'] as String),
    note: json['note'] as String?,
    lastVisitedAt: json['last_visited_at'] == null ? null : DateTime.parse(json['last_visited_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class LeadDto {
  LeadDto({
    required this.id,
    required this.prospectId,
    required this.source,
    required this.name,
    required this.phone,
    required this.occupation,
    required this.age,
    required this.quotedDailyBenefit,
    required this.quotedPremium,
    required this.quotedLoanAmount,
    required this.quotedMonthlyInstallment,
    required this.collateralKind,
    required this.status,
    required this.firstResponseAt,
    required this.createdAt,
  });

  final String id;
  final String? prospectId;
  final String source;
  final String name;
  final String? phone;
  final String? occupation;
  final int? age;
  final Decimal? quotedDailyBenefit;
  final Decimal? quotedPremium;
  final Decimal? quotedLoanAmount;
  final Decimal? quotedMonthlyInstallment;
  final String? collateralKind;
  final String status;
  final DateTime? firstResponseAt;
  final DateTime createdAt;

  factory LeadDto.fromJson(Map<String, dynamic> json) => LeadDto(
    id: json['id'] as String,
    prospectId: json['prospect_id'] as String?,
    source: json['source'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    occupation: json['occupation'] as String?,
    age: json['age'] as int?,
    quotedDailyBenefit: json['quoted_daily_benefit'] == null
        ? null
        : Decimal.parse(json['quoted_daily_benefit'] as String),
    quotedPremium: json['quoted_premium'] == null ? null : Decimal.parse(json['quoted_premium'] as String),
    quotedLoanAmount: json['quoted_loan_amount'] == null
        ? null
        : Decimal.parse(json['quoted_loan_amount'] as String),
    quotedMonthlyInstallment: json['quoted_monthly_installment'] == null
        ? null
        : Decimal.parse(json['quoted_monthly_installment'] as String),
    collateralKind: json['collateral_kind'] as String?,
    status: json['status'] as String,
    firstResponseAt: json['first_response_at'] == null ? null : DateTime.parse(json['first_response_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class LeaderboardEntryDto {
  LeaderboardEntryDto({
    required this.branchId,
    required this.branchName,
    required this.prospectsVisited,
    required this.prospectsContacted,
    required this.leadsContacted,
    required this.score,
  });

  final String branchId;
  final String branchName;
  final int prospectsVisited;
  final int prospectsContacted;
  final int leadsContacted;
  final int score;

  factory LeaderboardEntryDto.fromJson(Map<String, dynamic> json) => LeaderboardEntryDto(
    branchId: json['branch_id'] as String,
    branchName: json['branch_name'] as String,
    prospectsVisited: json['prospects_visited'] as int,
    prospectsContacted: json['prospects_contacted'] as int,
    leadsContacted: json['leads_contacted'] as int,
    score: json['score'] as int,
  );
}

class PublicQuoteDto {
  PublicQuoteDto({required this.dailyBenefit, required this.premiumAmount, required this.premiumCycle});

  final Decimal dailyBenefit;
  final Decimal premiumAmount;
  final String premiumCycle;

  factory PublicQuoteDto.fromJson(Map<String, dynamic> json) => PublicQuoteDto(
    dailyBenefit: Decimal.parse(json['daily_benefit'] as String),
    premiumAmount: Decimal.parse(json['premium_amount'] as String),
    premiumCycle: json['premium_cycle'] as String,
  );
}

class PublicLoanQuoteDto {
  PublicLoanQuoteDto({
    required this.approvedAmount,
    required this.termMonths,
    required this.monthlyInterestRate,
    required this.monthlyInstallment,
    required this.totalInterest,
    required this.totalRepayment,
  });

  final Decimal approvedAmount;
  final int termMonths;
  final Decimal monthlyInterestRate;
  final Decimal monthlyInstallment;
  final Decimal totalInterest;
  final Decimal totalRepayment;

  factory PublicLoanQuoteDto.fromJson(Map<String, dynamic> json) => PublicLoanQuoteDto(
    approvedAmount: Decimal.parse(json['approved_amount'] as String),
    termMonths: json['term_months'] as int,
    monthlyInterestRate: Decimal.parse(json['monthly_interest_rate'] as String),
    monthlyInstallment: Decimal.parse(json['monthly_installment'] as String),
    totalInterest: Decimal.parse(json['total_interest'] as String),
    totalRepayment: Decimal.parse(json['total_repayment'] as String),
  );
}

class LoanTermBoundsDto {
  LoanTermBoundsDto({required this.collateralKind, required this.minTermMonths, required this.maxTermMonths});

  final String collateralKind;
  final int minTermMonths;
  final int maxTermMonths;

  factory LoanTermBoundsDto.fromJson(Map<String, dynamic> json) => LoanTermBoundsDto(
    collateralKind: json['collateral_kind'] as String,
    minTermMonths: json['min_term_months'] as int,
    maxTermMonths: json['max_term_months'] as int,
  );
}

class LoanReviewItemDto {
  LoanReviewItemDto({
    required this.id,
    required this.tenantName,
    required this.tenantPhone,
    required this.productId,
    required this.approvedAmount,
    required this.monthlyInstallment,
    required this.termMonths,
    required this.collateralKind,
    required this.collateralValue,
    required this.collateralDetail,
    required this.creditTierSnapshot,
    required this.status,
    required this.stageStartedAt,
    required this.createdAt,
  });

  final String id;
  final String tenantName;
  final String? tenantPhone;
  final String productId;
  final Decimal approvedAmount;
  final Decimal monthlyInstallment;
  final int termMonths;
  final String collateralKind;
  final Decimal collateralValue;
  final LoanCollateralDetailDto collateralDetail;
  final String creditTierSnapshot;
  final String status;
  final DateTime stageStartedAt;
  final DateTime createdAt;

  factory LoanReviewItemDto.fromJson(Map<String, dynamic> json) => LoanReviewItemDto(
    id: json['id'] as String,
    tenantName: json['tenant_name'] as String,
    tenantPhone: json['tenant_phone'] as String?,
    productId: json['product_id'] as String,
    approvedAmount: Decimal.parse(json['approved_amount'] as String),
    monthlyInstallment: Decimal.parse(json['monthly_installment'] as String),
    termMonths: json['term_months'] as int,
    collateralKind: json['collateral_kind'] as String,
    collateralValue: Decimal.parse(json['collateral_value'] as String),
    collateralDetail: LoanCollateralDetailDto.fromJson(json['collateral_detail'] as Map<String, dynamic>),
    creditTierSnapshot: json['credit_tier_snapshot'] as String,
    status: json['status'] as String,
    stageStartedAt: DateTime.parse(json['stage_started_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class LoanReviewDetailDto extends LoanReviewItemDto {
  LoanReviewDetailDto({
    required super.id,
    required super.tenantName,
    required super.tenantPhone,
    required super.productId,
    required super.approvedAmount,
    required super.monthlyInstallment,
    required super.termMonths,
    required super.collateralKind,
    required super.collateralValue,
    required super.collateralDetail,
    required super.creditTierSnapshot,
    required super.status,
    required super.stageStartedAt,
    required super.createdAt,
    required this.events,
  });

  final List<LoanApplicationEventDto> events;

  factory LoanReviewDetailDto.fromJson(Map<String, dynamic> json) {
    final item = LoanReviewItemDto.fromJson(json);
    return LoanReviewDetailDto(
      id: item.id,
      tenantName: item.tenantName,
      tenantPhone: item.tenantPhone,
      productId: item.productId,
      approvedAmount: item.approvedAmount,
      monthlyInstallment: item.monthlyInstallment,
      termMonths: item.termMonths,
      collateralKind: item.collateralKind,
      collateralValue: item.collateralValue,
      collateralDetail: item.collateralDetail,
      creditTierSnapshot: item.creditTierSnapshot,
      status: item.status,
      stageStartedAt: item.stageStartedAt,
      createdAt: item.createdAt,
      events: (json['events'] as List).map((e) => LoanApplicationEventDto.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class BranchRepository {
  BranchRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<ProspectDto>> listProspects() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/branch/prospects');
    return (resp.data as List).map((e) => ProspectDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  // No contactStatus param — a prospect always starts not_scheduled server
  // side (see ProspectCreateRequest's comment) so the leaderboard can't be
  // gamed by backdating a call/visit at creation time.
  Future<ProspectDto> createProspect({
    required String name,
    String? businessType,
    String? address,
    String? phone,
    String applicationInterest = 'not_applied',
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/branch/prospects',
      data: {
        'name': name,
        if (businessType != null && businessType.isNotEmpty) 'business_type': businessType,
        if (address != null && address.isNotEmpty) 'address': address,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'application_interest': applicationInterest,
      },
    );
    return ProspectDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ProspectDto> visitProspect(String prospectId, {required String status, String? note}) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/branch/prospects/$prospectId/visit',
      data: {'status': status, if (note != null && note.isNotEmpty) 'note': note},
    );
    return ProspectDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ProspectDto> updateProspectContactStatus(String prospectId, {required String contactStatus}) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/branch/prospects/$prospectId/contact-status',
      data: {'contact_status': contactStatus},
    );
    return ProspectDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ProspectDto> updateProspectApplicationInterest(
    String prospectId, {
    required String applicationInterest,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/branch/prospects/$prospectId/application-interest',
      data: {'application_interest': applicationInterest},
    );
    return ProspectDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteProspect(String prospectId) async {
    await _apiClient.dio.delete('/api/v1/turbo/branch/prospects/$prospectId');
  }

  Future<List<LeadDto>> listLeads() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/branch/leads');
    return (resp.data as List).map((e) => LeadDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LeadDto> respondLead(String leadId, {required String status}) async {
    final resp = await _apiClient.dio.post('/api/v1/turbo/branch/leads/$leadId/respond', data: {'status': status});
    return LeadDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<LeaderboardEntryDto>> leaderboard() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/branch/leaderboard');
    return (resp.data as List).map((e) => LeaderboardEntryDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Unauthenticated — safe to call whether or not the caller is logged in;
  /// ApiClient's interceptor only *adds* a bearer token when one exists, it
  /// never requires one.
  Future<PublicQuoteDto> publicQuote({
    required String name,
    String? phone,
    required String occupation,
    required int age,
    required Decimal monthlyBudget,
    String? province,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/public/quote',
      data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'occupation': occupation,
        'age': age,
        'monthly_budget': monthlyBudget.toString(),
        if (province != null && province.isNotEmpty) 'province': province,
      },
    );
    return PublicQuoteDto.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Unauthenticated, same rationale as publicQuote above.
  Future<PublicLoanQuoteDto> publicLoanQuote({
    required String name,
    String? phone,
    required String occupation,
    required int age,
    required String collateralKind,
    required Decimal collateralValue,
    required Decimal requestedAmount,
    required int termMonths,
    String? province,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/public/loan-quote',
      data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'occupation': occupation,
        'age': age,
        'collateral_kind': collateralKind,
        'collateral_value': collateralValue.toString(),
        'requested_amount': requestedAmount.toString(),
        'term_months': termMonths,
        if (province != null && province.isNotEmpty) 'province': province,
      },
    );
    return PublicLoanQuoteDto.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Unauthenticated, same rationale as publicQuote/publicLoanQuote above.
  Future<List<LoanTermBoundsDto>> publicLoanTermBounds() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/public/loan-term-bounds');
    return (resp.data as List).map((e) => LoanTermBoundsDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LoanReviewItemDto>> listLoanApplications({bool includeDecided = false}) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/turbo/branch/loan-applications',
      queryParameters: {'include_decided': includeDecided},
    );
    return (resp.data as List).map((e) => LoanReviewItemDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LoanReviewDetailDto> getLoanApplication(String applicationId) async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/branch/loan-applications/$applicationId');
    return LoanReviewDetailDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<LoanReviewDetailDto> advanceLoanApplication(
    String applicationId, {
    required String toStatus,
    String? note,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/branch/loan-applications/$applicationId/advance',
      data: {'to_status': toStatus, if (note != null && note.isNotEmpty) 'note': note},
    );
    return LoanReviewDetailDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<LoanReviewDetailDto> rejectLoanApplication(String applicationId, {required String reason}) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/branch/loan-applications/$applicationId/reject',
      data: {'reason': reason},
    );
    return LoanReviewDetailDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
