import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../../core/api_client.dart';

// Date-only (no time component) so it round-trips cleanly through the
// backend's `date` field, regardless of the picker's local timezone.
String formatDateForApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ProductDto {
  ProductDto({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.categoryId,
    this.imageUrl,
    required this.sellPrice,
    required this.costPrice,
    required this.trackStock,
    required this.stockQty,
    required this.lowStockThreshold,
    this.expiryDate,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? categoryId;
  final String? imageUrl;
  final Decimal sellPrice;
  final Decimal costPrice;
  final bool trackStock;
  final int stockQty;
  final int lowStockThreshold;
  final DateTime? expiryDate;
  final bool isActive;

  bool get isLowStock => trackStock && stockQty <= lowStockThreshold;

  // Same 7-day horizon as the backend's default for GET /inventory/expiring-soon.
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final cutoff = DateTime.now().add(const Duration(days: 7));
    return !expiryDate!.isAfter(cutoff);
  }

  factory ProductDto.fromJson(Map<String, dynamic> json) => ProductDto(
    id: json['id'] as String,
    name: json['name'] as String,
    sku: json['sku'] as String?,
    barcode: json['barcode'] as String?,
    categoryId: json['category_id'] as String?,
    imageUrl: json['image_url'] as String?,
    sellPrice: Decimal.parse(json['sell_price'] as String),
    costPrice: Decimal.parse(json['cost_price'] as String),
    trackStock: json['track_stock'] as bool,
    stockQty: json['stock_qty'] as int,
    lowStockThreshold: json['low_stock_threshold'] as int,
    expiryDate: json['expiry_date'] == null ? null : DateTime.parse(json['expiry_date'] as String),
    isActive: json['is_active'] as bool,
  );
}

class ProductLookupDto {
  ProductLookupDto({
    required this.found,
    this.name,
    this.imageUrl,
    this.price,
    this.currency,
    this.brand,
    this.source,
    required this.cached,
  });

  final bool found;
  final String? name;
  final String? imageUrl;
  final Decimal? price;
  final String? currency;
  final String? brand;
  final String? source;
  final bool cached;

  factory ProductLookupDto.fromJson(Map<String, dynamic> json) => ProductLookupDto(
    found: json['found'] as bool,
    name: json['name'] as String?,
    imageUrl: json['image_url'] as String?,
    price: json['price'] == null ? null : Decimal.parse(json['price'].toString()),
    currency: json['currency'] as String?,
    brand: json['brand'] as String?,
    source: json['source'] as String?,
    cached: json['cached'] as bool,
  );
}

class ProductRepository {
  ProductRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<ProductLookupDto> lookupBarcode(String barcode) async {
    final resp = await _apiClient.dio.get('/api/v1/products/lookup/$barcode');
    return ProductLookupDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<ProductDto>> list({String? search}) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/products',
      queryParameters: {if (search != null && search.isNotEmpty) 'q': search},
    );
    return (resp.data as List).map((e) => ProductDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ProductDto> create({
    required String name,
    required Decimal sellPrice,
    Decimal? costPrice,
    String? sku,
    String? barcode,
    String? categoryId,
    String? imageUrl,
    bool trackStock = true,
    int stockQty = 0,
    int lowStockThreshold = 5,
    DateTime? expiryDate,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/products',
      data: {
        'name': name,
        'sell_price': sellPrice.toString(),
        'cost_price': (costPrice ?? Decimal.zero).toString(),
        if (sku != null && sku.isNotEmpty) 'sku': sku,
        if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
        'category_id': ?categoryId,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        'track_stock': trackStock,
        'stock_qty': stockQty,
        'low_stock_threshold': lowStockThreshold,
        if (expiryDate != null) 'expiry_date': formatDateForApi(expiryDate),
      },
    );
    return ProductDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ProductDto> update(String id, Map<String, dynamic> patch) async {
    final resp = await _apiClient.dio.patch('/api/v1/products/$id', data: patch);
    return ProductDto.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Bytes rather than a file path — the only representation that works
  /// uniformly across web (no filesystem) and native, both of which
  /// image_picker's XFile supports via readAsBytes().
  Future<String> uploadImage(List<int> bytes, {required String filename, required String contentType}) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/products/upload-image',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType.parse(contentType)),
      }),
    );
    return (resp.data as Map<String, dynamic>)['image_url'] as String;
  }

  Future<void> delete(String id) => _apiClient.dio.delete('/api/v1/products/$id');
}

class CategoryDto {
  CategoryDto({required this.id, required this.name});

  final String id;
  final String name;

  factory CategoryDto.fromJson(Map<String, dynamic> json) =>
      CategoryDto(id: json['id'] as String, name: json['name'] as String);
}

class CategoryRepository {
  CategoryRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<CategoryDto>> list() async {
    final resp = await _apiClient.dio.get('/api/v1/categories');
    return (resp.data as List).map((e) => CategoryDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CategoryDto> create(String name) async {
    final resp = await _apiClient.dio.post('/api/v1/categories', data: {'name': name});
    return CategoryDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<CategoryDto> update(String id, String name) async {
    final resp = await _apiClient.dio.patch('/api/v1/categories/$id', data: {'name': name});
    return CategoryDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _apiClient.dio.delete('/api/v1/categories/$id');
}
