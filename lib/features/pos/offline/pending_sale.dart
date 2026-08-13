class PendingSaleItem {
  const PendingSaleItem({required this.productId, required this.qty, this.discount = '0'});

  final String productId;
  final int qty;
  final String discount;

  Map<String, dynamic> toJson() => {'product_id': productId, 'qty': qty, 'discount': discount};

  // '0' fallback covers sales that were already queued (and persisted to
  // shared_preferences) before this field existed — they replay with no
  // per-item discount rather than failing to parse.
  factory PendingSaleItem.fromJson(Map<String, dynamic> json) => PendingSaleItem(
    productId: json['product_id'] as String,
    qty: json['qty'] as int,
    discount: json['discount'] as String? ?? '0',
  );
}

/// A sale that failed to reach the backend because of a network error and is
/// waiting to be retried. [clientUuid] is the same id the checkout screen
/// generated for the original attempt — reusing it on retry is what makes
/// the resend idempotent on the backend instead of double-charging the sale.
class PendingSale {
  const PendingSale({
    required this.clientUuid,
    required this.items,
    required this.discount,
    required this.paymentMethod,
    required this.createdAt,
    this.customerId,
    this.redeemPoints = 0,
    this.lastError,
  });

  final String clientUuid;
  final List<PendingSaleItem> items;
  final String discount;
  final String paymentMethod;
  final DateTime createdAt;
  final String? customerId;
  final int redeemPoints;
  final String? lastError;

  PendingSale withError(String error) => PendingSale(
    clientUuid: clientUuid,
    items: items,
    discount: discount,
    paymentMethod: paymentMethod,
    createdAt: createdAt,
    customerId: customerId,
    redeemPoints: redeemPoints,
    lastError: error,
  );

  Map<String, dynamic> toJson() => {
    'client_uuid': clientUuid,
    'items': items.map((i) => i.toJson()).toList(),
    'discount': discount,
    'payment_method': paymentMethod,
    'created_at': createdAt.toIso8601String(),
    'customer_id': customerId,
    'redeem_points': redeemPoints,
    'last_error': lastError,
  };

  factory PendingSale.fromJson(Map<String, dynamic> json) => PendingSale(
    clientUuid: json['client_uuid'] as String,
    items: (json['items'] as List).map((e) => PendingSaleItem.fromJson(e as Map<String, dynamic>)).toList(),
    discount: json['discount'] as String,
    paymentMethod: json['payment_method'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    customerId: json['customer_id'] as String?,
    redeemPoints: json['redeem_points'] as int? ?? 0,
    lastError: json['last_error'] as String?,
  );
}
