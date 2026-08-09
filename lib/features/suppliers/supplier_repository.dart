import '../../core/api_client.dart';

class SupplierDto {
  SupplierDto({required this.id, required this.name, this.phone, this.email, this.address, this.notes});

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;

  factory SupplierDto.fromJson(Map<String, dynamic> json) => SupplierDto(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    address: json['address'] as String?,
    notes: json['notes'] as String?,
  );
}

class SupplierRepository {
  SupplierRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<SupplierDto>> list({String? search}) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/suppliers',
      queryParameters: {if (search != null && search.isNotEmpty) 'q': search},
    );
    return (resp.data as List).map((e) => SupplierDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SupplierDto> get(String id) async {
    final resp = await _apiClient.dio.get('/api/v1/suppliers/$id');
    return SupplierDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<SupplierDto> create({required String name, String? phone, String? email, String? address, String? notes}) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/suppliers',
      data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (address != null && address.isNotEmpty) 'address': address,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return SupplierDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<SupplierDto> update(String id, Map<String, dynamic> patch) async {
    final resp = await _apiClient.dio.patch('/api/v1/suppliers/$id', data: patch);
    return SupplierDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
