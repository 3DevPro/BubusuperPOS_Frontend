import 'package:decimal/decimal.dart';

import '../../core/api_client.dart';

class SaleItemResultDto {
  SaleItemResultDto({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    required this.discount,
    required this.lineTotal,
    required this.refundedQty,
  });

  final String id;
  final String productId;
  final String name;
  final Decimal price;
  final int qty;
  final Decimal discount;
  final Decimal lineTotal;
  final int refundedQty;

  int get remainingQty => qty - refundedQty;

  factory SaleItemResultDto.fromJson(Map<String, dynamic> json) => SaleItemResultDto(
    id: json['id'] as String,
    productId: json['product_id'] as String,
    name: json['name'] as String,
    price: Decimal.parse(json['price'] as String),
    qty: json['qty'] as int,
    discount: Decimal.parse(json['discount'] as String),
    lineTotal: Decimal.parse(json['line_total'] as String),
    refundedQty: json['refunded_qty'] as int,
  );
}

class RefundSummaryDto {
  RefundSummaryDto({
    required this.id,
    required this.refundAmount,
    required this.refundTax,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final Decimal refundAmount;
  final Decimal refundTax;
  final String? reason;
  final DateTime createdAt;

  factory RefundSummaryDto.fromJson(Map<String, dynamic> json) => RefundSummaryDto(
    id: json['id'] as String,
    refundAmount: Decimal.parse(json['refund_amount'] as String),
    refundTax: Decimal.parse(json['refund_tax'] as String),
    reason: json['reason'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class SaleResultDto {
  SaleResultDto({
    required this.id,
    required this.receiptNo,
    required this.customerId,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.priceIncludesTax,
    required this.total,
    required this.pointsEarned,
    required this.pointsRedeemed,
    required this.pointsDiscount,
    required this.paymentMethod,
    required this.status,
    required this.refundedTotal,
    required this.createdAt,
    required this.items,
    required this.refunds,
    required this.warnings,
  });

  final String id;
  final String receiptNo;
  final String? customerId;
  final Decimal subtotal;
  final Decimal discount;
  final Decimal tax;
  final bool priceIncludesTax;
  final Decimal total;
  final int pointsEarned;
  final int pointsRedeemed;
  final Decimal pointsDiscount;
  final String paymentMethod;
  final String status;
  final Decimal refundedTotal;
  final DateTime createdAt;
  final List<SaleItemResultDto> items;
  final List<RefundSummaryDto> refunds;
  final List<String> warnings;

  bool get canRefund => status == 'completed' || status == 'partially_refunded';

  factory SaleResultDto.fromJson(Map<String, dynamic> json) => SaleResultDto(
    id: json['id'] as String,
    receiptNo: json['receipt_no'] as String,
    customerId: json['customer_id'] as String?,
    subtotal: Decimal.parse(json['subtotal'] as String),
    discount: Decimal.parse(json['discount'] as String),
    tax: Decimal.parse(json['tax'] as String),
    priceIncludesTax: json['price_includes_tax'] as bool,
    total: Decimal.parse(json['total'] as String),
    pointsEarned: json['points_earned'] as int,
    pointsRedeemed: json['points_redeemed'] as int,
    pointsDiscount: Decimal.parse(json['points_discount'] as String),
    paymentMethod: json['payment_method'] as String,
    status: json['status'] as String,
    refundedTotal: Decimal.parse(json['refunded_total'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    items: (json['items'] as List).map((e) => SaleItemResultDto.fromJson(e as Map<String, dynamic>)).toList(),
    refunds: (json['refunds'] as List).map((e) => RefundSummaryDto.fromJson(e as Map<String, dynamic>)).toList(),
    warnings: (json['warnings'] as List).cast<String>(),
  );
}

class SaleListItemDto {
  SaleListItemDto({
    required this.id,
    required this.receiptNo,
    required this.total,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String receiptNo;
  final Decimal total;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;

  factory SaleListItemDto.fromJson(Map<String, dynamic> json) => SaleListItemDto(
    id: json['id'] as String,
    receiptNo: json['receipt_no'] as String,
    total: Decimal.parse(json['total'] as String),
    paymentMethod: json['payment_method'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class CheckoutItem {
  CheckoutItem({required this.productId, required this.qty, Decimal? discount}) : discount = discount ?? Decimal.zero;
  final String productId;
  final int qty;
  final Decimal discount;
}

class RefundItemRequest {
  const RefundItemRequest({required this.saleItemId, required this.qty});
  final String saleItemId;
  final int qty;
}

class RefundItemResultDto {
  RefundItemResultDto({required this.saleItemId, required this.qty, required this.amount});
  final String saleItemId;
  final int qty;
  final Decimal amount;

  factory RefundItemResultDto.fromJson(Map<String, dynamic> json) => RefundItemResultDto(
    saleItemId: json['sale_item_id'] as String,
    qty: json['qty'] as int,
    amount: Decimal.parse(json['amount'] as String),
  );
}

class RefundResultDto {
  RefundResultDto({
    required this.id,
    required this.saleId,
    required this.refundAmount,
    required this.refundTax,
    required this.reason,
    required this.createdAt,
    required this.items,
    required this.saleStatus,
  });

  final String id;
  final String saleId;
  final Decimal refundAmount;
  final Decimal refundTax;
  final String? reason;
  final DateTime createdAt;
  final List<RefundItemResultDto> items;
  final String saleStatus;

  factory RefundResultDto.fromJson(Map<String, dynamic> json) => RefundResultDto(
    id: json['id'] as String,
    saleId: json['sale_id'] as String,
    refundAmount: Decimal.parse(json['refund_amount'] as String),
    refundTax: Decimal.parse(json['refund_tax'] as String),
    reason: json['reason'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    items: (json['items'] as List).map((e) => RefundItemResultDto.fromJson(e as Map<String, dynamic>)).toList(),
    saleStatus: json['sale_status'] as String,
  );
}

class SalesRepository {
  SalesRepository(this._apiClient);
  final ApiClient _apiClient;

  /// [clientUuid] must be generated once per checkout attempt and reused
  /// across retries — that's what lets the backend dedupe a resubmission
  /// after a flaky network response instead of double-charging the sale.
  Future<SaleResultDto> checkout({
    required String clientUuid,
    required List<CheckoutItem> items,
    required Decimal discount,
    required String paymentMethod,
    String? customerId,
    int redeemPoints = 0,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/sales',
      data: {
        'client_uuid': clientUuid,
        'items': [
          for (final i in items) {'product_id': i.productId, 'qty': i.qty, 'discount': i.discount.toString()},
        ],
        'discount': discount.toString(),
        'payment_method': paymentMethod,
        if (customerId != null) 'customer_id': customerId,
        if (redeemPoints > 0) 'redeem_points': redeemPoints,
      },
    );
    return SaleResultDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<SaleListItemDto>> list({DateTime? startDate, DateTime? endDate}) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/sales',
      queryParameters: {
        if (startDate != null) 'start_date': _isoDate(startDate),
        if (endDate != null) 'end_date': _isoDate(endDate),
      },
    );
    return (resp.data as List).map((e) => SaleListItemDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<SaleResultDto> get(String id) async {
    final resp = await _apiClient.dio.get('/api/v1/sales/$id');
    return SaleResultDto.fromJson(resp.data as Map<String, dynamic>);
  }

  /// [items] omitted/empty refunds every unit still remaining on the sale.
  Future<RefundResultDto> refund({
    required String saleId,
    required String clientUuid,
    List<RefundItemRequest>? items,
    String? reason,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/sales/$saleId/refunds',
      data: {
        'client_uuid': clientUuid,
        if (items != null)
          'items': [
            for (final i in items) {'sale_item_id': i.saleItemId, 'qty': i.qty},
          ],
        'reason': reason,
      },
    );
    return RefundResultDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
