import '../../core/api_client.dart';

class AuditLogEntryDto {
  AuditLogEntryDto({
    required this.id,
    required this.actorName,
    required this.action,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String actorName;
  final String action;
  final String summary;
  final DateTime createdAt;

  factory AuditLogEntryDto.fromJson(Map<String, dynamic> json) => AuditLogEntryDto(
    id: json['id'] as String,
    actorName: json['actor_name'] as String,
    action: json['action'] as String,
    summary: json['summary'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}

class AuditLogRepository {
  AuditLogRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<AuditLogEntryDto>> list({int limit = 50, int offset = 0}) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/audit-log',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (resp.data as List).map((e) => AuditLogEntryDto.fromJson(e as Map<String, dynamic>)).toList();
  }
}
