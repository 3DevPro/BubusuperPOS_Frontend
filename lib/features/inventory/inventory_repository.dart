import '../../core/api_client.dart';

class LowStockItemDto {
  LowStockItemDto({
    required this.id,
    required this.name,
    required this.stockQty,
    required this.lowStockThreshold,
  });

  final String id;
  final String name;
  final int stockQty;
  final int lowStockThreshold;

  factory LowStockItemDto.fromJson(Map<String, dynamic> json) => LowStockItemDto(
    id: json['id'] as String,
    name: json['name'] as String,
    stockQty: json['stock_qty'] as int,
    lowStockThreshold: json['low_stock_threshold'] as int,
  );
}

class ExpiringSoonItemDto {
  ExpiringSoonItemDto({
    required this.id,
    required this.name,
    required this.stockQty,
    required this.expiryDate,
  });

  final String id;
  final String name;
  final int stockQty;
  final DateTime expiryDate;

  bool get isExpired => expiryDate.isBefore(DateTime.now());

  factory ExpiringSoonItemDto.fromJson(Map<String, dynamic> json) => ExpiringSoonItemDto(
    id: json['id'] as String,
    name: json['name'] as String,
    stockQty: json['stock_qty'] as int,
    expiryDate: DateTime.parse(json['expiry_date'] as String),
  );
}

class InventoryRepository {
  InventoryRepository(this._apiClient);
  final ApiClient _apiClient;

  /// [qtyDelta] positive to add stock (purchase/restock), negative to remove
  /// (waste/loss/correction). [type] must be one of purchase/adjust/waste/return —
  /// "sale" movements are only ever created by checkout.
  Future<int> adjustStock({
    required String productId,
    required int qtyDelta,
    String type = 'adjust',
    String? note,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/inventory/adjust',
      data: {
        'product_id': productId,
        'qty_delta': qtyDelta,
        'type': type,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return resp.data['stock_qty'] as int;
  }

  Future<List<LowStockItemDto>> lowStock() async {
    final resp = await _apiClient.dio.get('/api/v1/inventory/low-stock');
    return (resp.data as List).map((e) => LowStockItemDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ExpiringSoonItemDto>> expiringSoon({int days = 7}) async {
    final resp = await _apiClient.dio.get('/api/v1/inventory/expiring-soon', queryParameters: {'days': days});
    return (resp.data as List).map((e) => ExpiringSoonItemDto.fromJson(e as Map<String, dynamic>)).toList();
  }
}
