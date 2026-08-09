import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/barcode_scanner_screen.dart';
import 'chat_providers.dart';
import 'conversation_list_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _inputController.clear();
    ref.read(chatProvider.notifier).send(text);
    _scrollToBottom();
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()));
    // Prefill the input rather than sending immediately — lets the user add
    // context (e.g. "เพิ่มสินค้าบาร์โค้ด ... ราคา 20 บาท") or correct a
    // misread before it goes to the bot.
    if (code != null && mounted) {
      _inputController.text = 'เพิ่มสินค้าบาร์โค้ด $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ผู้ช่วย AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'แชทใหม่',
            onPressed: () => ref.read(chatProvider.notifier).startNewConversation(),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'ประวัติแชท',
            onPressed: () async {
              final id = await Navigator.of(
                context,
              ).push<String>(MaterialPageRoute(builder: (context) => const ConversationListScreen()));
              if (id != null) {
                await ref.read(chatProvider.notifier).loadConversation(id);
                _scrollToBottom();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyState(onPick: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) => _MessageBubble(message: state.messages[index], index: index),
                  ),
          ),
          if (state.messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final chip in ref.read(chatProvider.notifier).suggestionChips)
                    ActionChip(label: Text(chip), onPressed: state.sending ? null : () => _send(chip)),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !state.sending,
                      decoration: const InputDecoration(
                        hintText: 'ถามเกี่ยวกับยอดขายหรือสต็อกสินค้า...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'สแกนบาร์โค้ดสินค้า',
                    onPressed: state.sending ? null : _scanBarcode,
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: state.sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                    onPressed: state.sending ? null : () => _send(_inputController.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onPick});
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('ถามอะไรก็ได้เกี่ยวกับร้านของคุณ', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final chip in ref.read(chatProvider.notifier).suggestionChips)
                  ActionChip(label: Text(chip), onPressed: () => onPick(chip)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message, required this.index});
  final ChatUiMessage message;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == 'user';
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.toolStatus != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isUser ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      message.toolStatus!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isUser ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.text,
              style: TextStyle(color: isUser ? colorScheme.onPrimary : colorScheme.onSurfaceVariant),
            ),
            if (message.pendingAction != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => ref.read(chatProvider.notifier).cancelAction(index),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => ref.read(chatProvider.notifier).confirmAction(index),
                      child: const Text('ยืนยัน'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
