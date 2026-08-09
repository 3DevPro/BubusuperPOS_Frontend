import 'package:decimal/decimal.dart';

import '../../core/api_client.dart';

class ProspectDto {
  ProspectDto({
    required this.id,
    required this.name,
    required this.businessType,
    required this.address,
    required this.phone,
    required this.status,
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
    required this.leadsContacted,
    required this.score,
  });

  final String branchId;
  final String branchName;
  final int prospectsVisited;
  final int leadsContacted;
  final int score;

  factory LeaderboardEntryDto.fromJson(Map<String, dynamic> json) => LeaderboardEntryDto(
    branchId: json['branch_id'] as String,
    branchName: json['branch_name'] as String,
    prospectsVisited: json['prospects_visited'] as int,
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

class BranchRepository {
  BranchRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<ProspectDto>> listProspects() async {
    final resp = await _apiClient.dio.get('/api/v1/turbo/branch/prospects');
    return (resp.data as List).map((e) => ProspectDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ProspectDto> createProspect({
    required String name,
    String? businessType,
    String? address,
    String? phone,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/turbo/branch/prospects',
      data: {
        'name': name,
        if (businessType != null && businessType.isNotEmpty) 'business_type': businessType,
        if (address != null && address.isNotEmpty) 'address': address,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
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
}
