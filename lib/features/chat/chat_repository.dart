import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/api_client.dart';

sealed class ChatEvent {}

class ChatToolEvent extends ChatEvent {
  ChatToolEvent(this.name);
  final String name;
}

class ChatTokenEvent extends ChatEvent {
  ChatTokenEvent(this.text);
  final String text;
}

class ChatActionProposedEvent extends ChatEvent {
  ChatActionProposedEvent(this.actionId, this.actionType, this.summary);
  final String actionId;
  final String actionType;
  final String summary;
}

class ChatDoneEvent extends ChatEvent {
  ChatDoneEvent(this.messageId, this.conversationId);
  final String messageId;
  final String conversationId;
}

class ChatErrorEvent extends ChatEvent {
  ChatErrorEvent(this.detail);
  final String detail;
}

class ChatMessageDto {
  ChatMessageDto({
    required this.id,
    required this.role,
    required this.content,
    required this.intent,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String content;
  final String? intent;
  final DateTime createdAt;

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) => ChatMessageDto(
    id: json['id'] as String,
    role: json['role'] as String,
    content: json['content'] as String,
    intent: json['intent'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class ConversationDto {
  ConversationDto({required this.id, required this.title, required this.updatedAt});

  final String id;
  final String title;
  final DateTime updatedAt;

  factory ConversationDto.fromJson(Map<String, dynamic> json) => ConversationDto(
    id: json['id'] as String,
    title: json['title'] as String,
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}

class ConversationDetailDto {
  ConversationDetailDto({required this.id, required this.title, required this.messages});

  final String id;
  final String title;
  final List<ChatMessageDto> messages;

  factory ConversationDetailDto.fromJson(Map<String, dynamic> json) => ConversationDetailDto(
    id: json['id'] as String,
    title: json['title'] as String,
    messages: (json['messages'] as List)
        .map((e) => ChatMessageDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

ChatEvent _decodeSseEvent(Map<String, dynamic> json) {
  switch (json['type'] as String?) {
    case 'tool':
      return ChatToolEvent(json['name'] as String);
    case 'token':
      return ChatTokenEvent(json['text'] as String);
    case 'action_proposed':
      return ChatActionProposedEvent(
        json['action_id'] as String,
        json['action_type'] as String,
        json['summary'] as String,
      );
    case 'done':
      return ChatDoneEvent(json['message_id'] as String, json['conversation_id'] as String);
    case 'error':
      return ChatErrorEvent(json['detail'] as String);
    default:
      throw FormatException('unknown chat SSE event: $json');
  }
}

/// Decodes a raw SSE byte stream into [ChatEvent]s. Split out from
/// [ChatRepository.streamChat] so it can be unit-tested against a
/// hand-built byte stream — including chunks that split mid multi-byte
/// UTF-8 character or mid JSON line, which real HTTP chunking does in
/// practice and which naive per-chunk decoding gets wrong.
///
/// `utf8.decoder` buffers partial multi-byte sequences across chunks on its
/// own; `LineSplitter` buffers partial lines the same way, so together they
/// reassemble frames correctly regardless of where the transport happens to
/// cut a chunk.
///
/// Uses `utf8.decoder.bind(...)` rather than `byteStream.transform(utf8.decoder)`
/// — on the web (DDC), `Stream<Uint8List>.transform()` does a runtime check
/// against `StreamTransformer<Uint8List, String>` that `Utf8Decoder` (a
/// `Converter<List<int>, String>`) fails, even though `.bind()` accepts the
/// exact same stream just fine.
Stream<ChatEvent> parseSseEvents(Stream<List<int>> byteStream) async* {
  final lines = utf8.decoder.bind(byteStream).transform(const LineSplitter());
  await for (final line in lines) {
    if (!line.startsWith('data: ')) continue;
    final jsonStr = line.substring('data: '.length);
    if (jsonStr.isEmpty) continue;
    yield _decodeSseEvent(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}

class ChatRepository {
  ChatRepository(this._apiClient);
  final ApiClient _apiClient;

  Stream<ChatEvent> streamChat({String? conversationId, required String message}) async* {
    // The browser's EventSource can't attach an Authorization header, so
    // this uses a plain dio POST with a streamed response body instead —
    // ApiClient's interceptor still attaches the bearer token normally.
    // chatDio (not dio) — chat now lives in its own service, see
    // BubusuperPOS_chatbot; the /api/v1/chat/* path is unchanged, only the
    // host it resolves against differs (see AppConfig.chatbotBaseUrl).
    final response = await _apiClient.chatDio.post<ResponseBody>(
      '/api/v1/chat/stream',
      data: {'conversation_id': ?conversationId, 'message': message},
      options: Options(responseType: ResponseType.stream),
    );
    yield* parseSseEvents(response.data!.stream);
  }

  Future<List<ConversationDto>> listConversations() async {
    final resp = await _apiClient.chatDio.get('/api/v1/chat/conversations');
    return (resp.data as List).map((e) => ConversationDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ConversationDetailDto> getConversation(String id) async {
    final resp = await _apiClient.chatDio.get('/api/v1/chat/conversations/$id');
    return ConversationDetailDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteConversation(String id) async {
    await _apiClient.chatDio.delete('/api/v1/chat/conversations/$id');
  }

  Future<String> confirmAction(String actionId) async {
    final resp = await _apiClient.chatDio.post('/api/v1/chat/actions/$actionId/confirm');
    return (resp.data as Map<String, dynamic>)['summary'] as String;
  }
}
