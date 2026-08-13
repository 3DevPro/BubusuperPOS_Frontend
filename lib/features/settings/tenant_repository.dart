import 'package:decimal/decimal.dart';

import '../../core/api_client.dart';

class TenantSettingsDto {
  TenantSettingsDto({
    required this.name,
    required this.businessType,
    required this.currency,
    required this.timezone,
    required this.promptpayId,
    required this.vatEnabled,
    required this.vatRate,
    required this.priceIncludesTax,
    required this.loyaltyEnabled,
    required this.bahtPerPoint,
    required this.pointValueBaht,
    required this.taxId,
    required this.address,
    required this.branchCode,
    required this.receiptFooter,
  });

  final String name;
  final String? businessType;
  final String currency;
  final String timezone;
  final String? promptpayId;
  final bool vatEnabled;
  final Decimal vatRate;
  final bool priceIncludesTax;
  final bool loyaltyEnabled;
  final Decimal bahtPerPoint;
  final Decimal pointValueBaht;
  final String? taxId;
  final String? address;
  final String? branchCode;
  final String? receiptFooter;

  factory TenantSettingsDto.fromJson(Map<String, dynamic> json) => TenantSettingsDto(
    name: json['name'] as String,
    businessType: json['business_type'] as String?,
    currency: json['currency'] as String,
    timezone: json['timezone'] as String,
    promptpayId: json['promptpay_id'] as String?,
    vatEnabled: json['vat_enabled'] as bool,
    vatRate: Decimal.parse(json['vat_rate'] as String),
    priceIncludesTax: json['price_includes_tax'] as bool,
    loyaltyEnabled: json['loyalty_enabled'] as bool,
    bahtPerPoint: Decimal.parse(json['baht_per_point'] as String),
    pointValueBaht: Decimal.parse(json['point_value_baht'] as String),
    taxId: json['tax_id'] as String?,
    address: json['address'] as String?,
    branchCode: json['branch_code'] as String?,
    receiptFooter: json['receipt_footer'] as String?,
  );
}

class TenantRepository {
  TenantRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<TenantSettingsDto> getSettings() async {
    final resp = await _apiClient.dio.get('/api/v1/tenant/settings');
    return TenantSettingsDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<TenantSettingsDto> updatePromptPayId(String? promptpayId) async {
    final resp = await _apiClient.dio.patch(
      '/api/v1/tenant/settings',
      data: {'promptpay_id': promptpayId},
    );
    return TenantSettingsDto.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Only sends the VAT fields — never touches promptpay_id — so this can't
  /// clobber a setting the owner isn't editing right now (the backend also
  /// only applies whatever fields are present in the request body).
  Future<TenantSettingsDto> updateVatSettings({
    required bool vatEnabled,
    required Decimal vatRate,
    required bool priceIncludesTax,
  }) async {
    final resp = await _apiClient.dio.patch(
      '/api/v1/tenant/settings',
      data: {
        'vat_enabled': vatEnabled,
        'vat_rate': vatRate.toString(),
        'price_includes_tax': priceIncludesTax,
      },
    );
    return TenantSettingsDto.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Only sends the loyalty fields — same isolation rationale as
  /// updateVatSettings above.
  Future<TenantSettingsDto> updateLoyaltySettings({
    required bool loyaltyEnabled,
    required Decimal bahtPerPoint,
    required Decimal pointValueBaht,
  }) async {
    final resp = await _apiClient.dio.patch(
      '/api/v1/tenant/settings',
      data: {
        'loyalty_enabled': loyaltyEnabled,
        'baht_per_point': bahtPerPoint.toString(),
        'point_value_baht': pointValueBaht.toString(),
      },
    );
    return TenantSettingsDto.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Only sends the tax-invoice fields — same isolation rationale as
  /// updateVatSettings above.
  Future<TenantSettingsDto> updateTaxInvoiceSettings({
    required String? taxId,
    required String? address,
    required String? branchCode,
    required String? receiptFooter,
  }) async {
    final resp = await _apiClient.dio.patch(
      '/api/v1/tenant/settings',
      data: {
        'tax_id': taxId,
        'address': address,
        'branch_code': branchCode,
        'receipt_footer': receiptFooter,
      },
    );
    return TenantSettingsDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
