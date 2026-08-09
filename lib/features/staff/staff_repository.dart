import '../../core/api_client.dart';

class StaffDto {
  StaffDto({required this.id, required this.name, required this.role, required this.isActive});

  final String id;
  final String name;
  final String role;
  final bool isActive;

  factory StaffDto.fromJson(Map<String, dynamic> json) => StaffDto(
    id: json['id'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    isActive: json['is_active'] as bool,
  );
}

class StaffRepository {
  StaffRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<StaffDto>> list() async {
    final resp = await _apiClient.dio.get('/api/v1/staff');
    return (resp.data as List).map((e) => StaffDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<StaffDto> create({required String name, required String role, String? pin}) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/staff',
      data: {'name': name, 'role': role, 'pin': ?pin},
    );
    return StaffDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<StaffDto> update(String id, {String? role, bool? isActive, String? pin}) async {
    final resp = await _apiClient.dio.patch(
      '/api/v1/staff/$id',
      data: {'role': ?role, 'is_active': ?isActive, 'pin': ?pin},
    );
    return StaffDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
