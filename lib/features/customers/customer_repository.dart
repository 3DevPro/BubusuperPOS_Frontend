import '../../core/api_client.dart';

class CustomerDto {
  CustomerDto({required this.id, required this.name, this.phone, required this.pointsBalance});

  final String id;
  final String name;
  final String? phone;
  final int pointsBalance;

  factory CustomerDto.fromJson(Map<String, dynamic> json) => CustomerDto(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    pointsBalance: json['points_balance'] as int,
  );
}

class CustomerRepository {
  CustomerRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<CustomerDto>> list({String? search}) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/customers',
      queryParameters: {if (search != null && search.isNotEmpty) 'q': search},
    );
    return (resp.data as List).map((e) => CustomerDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CustomerDto> get(String id) async {
    final resp = await _apiClient.dio.get('/api/v1/customers/$id');
    return CustomerDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<CustomerDto> create({required String name, String? phone}) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/customers',
      data: {'name': name, if (phone != null && phone.isNotEmpty) 'phone': phone},
    );
    return CustomerDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<CustomerDto> update(String id, Map<String, dynamic> patch) async {
    final resp = await _apiClient.dio.patch('/api/v1/customers/$id', data: patch);
    return CustomerDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
