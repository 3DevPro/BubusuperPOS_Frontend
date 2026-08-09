import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});

final conversationListProvider = FutureProvider.autoDispose<List<ConversationDto>>((ref) {
  return ref.watch(chatRepositoryProvider).listConversations();
});

class PendingActionUi {
  const PendingActionUi({required this.id, required this.summary});
  final String id;
  final String summary;
}

class ChatUiMessage {
  const ChatUiMessage({required this.role, required this.text, this.toolStatus, this.pendingAction});

  final String role; // 'user' | 'assistant'
  final String text;
  final String? toolStatus;
  final PendingActionUi? pendingAction;

  ChatUiMessage copyWith({
    String? text,
    String? toolStatus,
    bool clearToolStatus = false,
    PendingActionUi? pendingAction,
    bool clearPendingAction = false,
  }) {
    return ChatUiMessage(
      role: role,
      text: text ?? this.text,
      toolStatus: clearToolStatus ? null : (toolStatus ?? this.toolStatus),
      pendingAction: clearPendingAction ? null : (pendingAction ?? this.pendingAction),
    );
  }
}

class ChatState {
  const ChatState({this.conversationId, this.messages = const [], this.sending = false, this.error});

  final String? conversationId;
  final List<ChatUiMessage> messages;
  final bool sending;
  final String? error;
}

const _suggestionChips = ['ยอดขายวันนี้', 'ของใกล้หมด', 'ขายดีสุด'];

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._repository) : super(const ChatState());
  final ChatRepository _repository;

  List<String> get suggestionChips => _suggestionChips;

  Future<void> send(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || state.sending) return;

    state = ChatState(
      conversationId: state.conversationId,
      messages: [
        ...state.messages,
        ChatUiMessage(role: 'user', text: trimmed),
        const ChatUiMessage(role: 'assistant', text: ''),
      ],
      sending: true,
    );

    try {
      await for (final event in _repository.streamChat(
        conversationId: state.conversationId,
        message: trimmed,
      )) {
        switch (event) {
          case ChatToolEvent(:final name):
            _replaceLastAssistant((m) => m.copyWith(toolStatus: _toolStatusLabel(name)));
          case ChatTokenEvent(:final text):
            _replaceLastAssistant((m) => m.copyWith(text: m.text + text, clearToolStatus: true));
          case ChatActionProposedEvent(:final actionId, :final summary):
            _replaceLastAssistant(
              (m) => m.copyWith(
                text: summary,
                clearToolStatus: true,
                pendingAction: PendingActionUi(id: actionId, summary: summary),
              ),
            );
          case ChatDoneEvent(:final conversationId):
            state = ChatState(conversationId: conversationId, messages: state.messages, sending: false);
          case ChatErrorEvent(:final detail):
            _replaceLastAssistant((m) => m.copyWith(text: detail, clearToolStatus: true));
            state = ChatState(
              conversationId: state.conversationId,
              messages: state.messages,
              sending: false,
              error: detail,
            );
        }
      }
    } catch (_) {
      _replaceLastAssistant(
        (m) => m.copyWith(text: 'เชื่อมต่อผู้ช่วย AI ไม่ได้ ลองใหม่อีกครั้ง', clearToolStatus: true),
      );
      state = ChatState(
        conversationId: state.conversationId,
        messages: state.messages,
        sending: false,
        error: 'connection_failed',
      );
    }
  }

  void _replaceLastAssistant(ChatUiMessage Function(ChatUiMessage) update) {
    _updateMessageAt(state.messages.length - 1, update);
  }

  void _updateMessageAt(int index, ChatUiMessage Function(ChatUiMessage) update) {
    final messages = [...state.messages];
    messages[index] = update(messages[index]);
    state = ChatState(
      conversationId: state.conversationId,
      messages: messages,
      sending: state.sending,
      error: state.error,
    );
  }

  /// Executes a pending action the user tapped "ยืนยัน" on. The confirmation
  /// text shown on success/failure comes straight from the backend (or its
  /// error detail) — never guessed client-side — since only the server knows
  /// whether the mutation actually happened.
  Future<void> confirmAction(int index) async {
    final action = state.messages[index].pendingAction;
    if (action == null) return;
    try {
      final resultSummary = await _repository.confirmAction(action.id);
      _updateMessageAt(index, (m) => m.copyWith(text: 'เรียบร้อยแล้ว: $resultSummary', clearPendingAction: true));
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = (data is Map && data['detail'] != null)
          ? data['detail'].toString()
          : 'ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง';
      _updateMessageAt(index, (m) => m.copyWith(text: detail, clearPendingAction: true));
    }
  }

  /// Purely a client-side dismissal — the pending row on the server just
  /// expires on its own (see `ChatPendingAction.expires_at`), no cancel call.
  void cancelAction(int index) {
    _updateMessageAt(index, (m) => m.copyWith(text: '${m.text} (ยกเลิกแล้ว)', clearPendingAction: true));
  }

  Future<void> loadConversation(String id) async {
    final detail = await _repository.getConversation(id);
    state = ChatState(
      conversationId: detail.id,
      messages: [for (final m in detail.messages) ChatUiMessage(role: m.role, text: m.content)],
    );
  }

  void startNewConversation() {
    state = const ChatState();
  }

  String _toolStatusLabel(String toolName) {
    switch (toolName) {
      case 'get_sales_summary':
        return 'กำลังดูยอดขาย...';
      case 'get_daily_sales':
        return 'กำลังดูยอดขายรายวัน...';
      case 'list_low_stock':
        return 'กำลังตรวจสต็อก...';
      case 'search_products':
        return 'กำลังค้นหาสินค้า...';
      case 'get_best_sellers':
        return 'กำลังดูสินค้าขายดี...';
      case 'get_worst_sellers':
        return 'กำลังดูสินค้าขายไม่ดี...';
      case 'get_sales_by_staff':
        return 'กำลังดูยอดขายแยกตามพนักงาน...';
      case 'get_sales_by_payment_method':
        return 'กำลังดูยอดขายแยกตามช่องทางชำระ...';
      case 'compare_periods':
        return 'กำลังเปรียบเทียบยอดขาย...';
      case 'propose_stock_adjust':
        return 'กำลังเตรียมปรับสต็อก...';
      case 'propose_product_create':
        return 'กำลังเตรียมเพิ่มสินค้า...';
      case 'propose_product_price_update':
        return 'กำลังเตรียมแก้ราคา...';
      case 'propose_product_deactivate':
        return 'กำลังเตรียมปิดการขายสินค้า...';
      case 'find_sale':
        return 'กำลังค้นหาใบเสร็จ...';
      case 'propose_refund':
        return 'กำลังเตรียมคืนเงิน...';
      default:
        return 'กำลังค้นข้อมูล...';
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(chatRepositoryProvider));
});
