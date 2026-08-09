import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import 'chat_providers.dart';
import 'chat_repository.dart';

/// Pushed on top of ChatScreen; pops with the tapped conversation's id, or
/// null if the user backs out without picking one.
class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติแชท')),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดประวัติไม่สำเร็จ: $err')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(child: Text('ยังไม่มีประวัติแชท'));
          }
          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(formatThaiDateTime(conversation.updatedAt)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'ลบแชทนี้',
                  onPressed: () => _confirmDelete(context, ref, conversation),
                ),
                onTap: () => Navigator.of(context).pop(conversation.id),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ConversationDto conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบแชทนี้?'),
        content: Text('"${conversation.title}" จะถูกลบและกู้คืนไม่ได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(chatRepositoryProvider).deleteConversation(conversation.id);
    ref.invalidate(conversationListProvider);
  }
}
