import '../../core/api_client.dart';

class NotificationDto {
  NotificationDto({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.payload,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory NotificationDto.fromJson(Map<String, dynamic> json) => NotificationDto(
    id: json['id'] as String,
    kind: json['kind'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
    createdAt: DateTime.parse(json['created_at'] as String),
    readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
  );
}

class NotificationSettingsDto {
  NotificationSettingsDto({
    required this.lowStockEnabled,
    required this.lowStockTime,
    required this.lowStockRepeatDays,
    required this.dailySummaryEnabled,
    required this.dailySummaryTime,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.lineEnabled,
  });

  final bool lowStockEnabled;
  final String lowStockTime; // "HH:MM:SS"
  final int lowStockRepeatDays;
  final bool dailySummaryEnabled;
  final String dailySummaryTime;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final bool lineEnabled;

  factory NotificationSettingsDto.fromJson(Map<String, dynamic> json) => NotificationSettingsDto(
    lowStockEnabled: json['low_stock_enabled'] as bool,
    lowStockTime: json['low_stock_time'] as String,
    lowStockRepeatDays: json['low_stock_repeat_days'] as int,
    dailySummaryEnabled: json['daily_summary_enabled'] as bool,
    dailySummaryTime: json['daily_summary_time'] as String,
    quietHoursStart: json['quiet_hours_start'] as String?,
    quietHoursEnd: json['quiet_hours_end'] as String?,
    lineEnabled: json['line_enabled'] as bool,
  );
}

class NotificationRepository {
  NotificationRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<NotificationDto>> list({bool unreadOnly = false, int limit = 50}) async {
    final resp = await _apiClient.dio.get(
      '/api/v1/notifications',
      queryParameters: {'unread_only': unreadOnly, 'limit': limit},
    );
    return (resp.data as List).map((e) => NotificationDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> unreadCount() async {
    final resp = await _apiClient.dio.get('/api/v1/notifications/unread-count');
    return (resp.data as Map<String, dynamic>)['unread_count'] as int;
  }

  Future<void> markRead(String id) => _apiClient.dio.post('/api/v1/notifications/$id/read');

  Future<void> markAllRead() => _apiClient.dio.post('/api/v1/notifications/read-all');

  Future<NotificationSettingsDto> getSettings() async {
    final resp = await _apiClient.dio.get('/api/v1/notifications/settings');
    return NotificationSettingsDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<NotificationSettingsDto> updateSettings(Map<String, dynamic> patch) async {
    final resp = await _apiClient.dio.patch('/api/v1/notifications/settings', data: patch);
    return NotificationSettingsDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
