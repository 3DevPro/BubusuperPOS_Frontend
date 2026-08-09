import 'package:decimal/decimal.dart';

import '../../core/api_client.dart';

class PurchaseOrderItemResultDto {
  PurchaseOrderItemResultDto({
    required this.id,
    required this.productId,
    required this.name,
    required this.qtyOrdered,
    required this.qtyReceived,
    required this.unitCost,
  });

  final String id;
  final String productId;
  final String name;
  final int qtyOrdered;
  final int qtyReceived;
  final Decimal unitCost;

  int get remainingQty => qtyOrdered - qtyReceived;

  factory PurchaseOrderItemResultDto.fromJson(Map<String, dynamic> json) => PurchaseOrderItemResultDto(
    id: json['id'] as String,
    productId: json['product_id'] as String,
    name: json['name'] as String,
    qtyOrdered: json['qty_ordered'] as int,
    qtyReceived: json['qty_received'] as int,
    unitCost: Decimal.parse(json['unit_cost'] as String),
  );
}

class PurchaseOrderResultDto {
  PurchaseOrderResultDto({
    required this.id,
    required this.orderNo,
    required this.supplierId,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String orderNo;
  final String supplierId;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final List<PurchaseOrderItemResultDto> items;

  bool get canReceive => status == 'ordered' || status == 'partially_received';
  bool get canCancel => status == 'ordered';

  factory PurchaseOrderResultDto.fromJson(Map<String, dynamic> json) => PurchaseOrderResultDto(
    id: json['id'] as String,
    orderNo: json['order_no'] as String,
    supplierId: json['supplier_id'] as String,
    status: json['status'] as String,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    items: (json['items'] as List)
        .map((e) => PurchaseOrderItemResultDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PurchaseOrderListItemDto {
  PurchaseOrderListItemDto({
    required this.id,
    required this.orderNo,
    required this.supplierId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String orderNo;
  final String supplierId;
  final String status;
  final DateTime createdAt;

  factory PurchaseOrderListItemDto.fromJson(Map<String, dynamic> json) => PurchaseOrderListItemDto(
    id: json['id'] as String,
    orderNo: json['order_no'] as String,
    supplierId: json['supplier_id'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class PurchaseOrderItemRequest {
  const PurchaseOrderItemRequest({required this.productId, required this.qty, required this.unitCost});
  final String productId;
  final int qty;
  final Decimal unitCost;
}

class PurchaseOrderReceiveItemRequest {
  const PurchaseOrderReceiveItemRequest({required this.purchaseOrderItemId, required this.qty});
  final String purchaseOrderItemId;
  final int qty;
}

class PurchaseOrderRepository {
  PurchaseOrderRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<PurchaseOrderListItemDto>> list({String? status}) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/purchase-orders',
      queryParameters: {if (status != null) 'status': status},
    );
    return (resp.data as List).map((e) => PurchaseOrderListItemDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PurchaseOrderResultDto> get(String id) async {
    final resp = await _apiClient.dio.get('/api/v1/purchase-orders/$id');
    return PurchaseOrderResultDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<PurchaseOrderResultDto> create({
    required String supplierId,
    required List<PurchaseOrderItemRequest> items,
    String? notes,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/purchase-orders',
      data: {
        'supplier_id': supplierId,
        'items': [
          for (final i in items) {'product_id': i.productId, 'qty': i.qty, 'unit_cost': i.unitCost.toString()},
        ],
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return PurchaseOrderResultDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<PurchaseOrderResultDto> receive(String id, List<PurchaseOrderReceiveItemRequest> items) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/purchase-orders/$id/receive',
      data: {
        'items': [
          for (final i in items) {'purchase_order_item_id': i.purchaseOrderItemId, 'qty': i.qty},
        ],
      },
    );
    return PurchaseOrderResultDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<PurchaseOrderResultDto> cancel(String id) async {
    final resp = await _apiClient.dio.post('/api/v1/purchase-orders/$id/cancel');
    return PurchaseOrderResultDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
