import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

final notificationListProvider = FutureProvider.autoDispose<List<NotificationDto>>((ref) {
  return ref.watch(notificationRepositoryProvider).list();
});

final notificationSettingsProvider = FutureProvider.autoDispose<NotificationSettingsDto>((ref) {
  return ref.watch(notificationRepositoryProvider).getSettings();
});

/// Polls every 5 minutes rather than opening a websocket — the bell badge
/// only needs to be "eventually" fresh, not real-time, and this keeps the
/// notification feature entirely request/response like the rest of the app.
/// `ref.keepAlive()` is what lets the timer survive between screens instead
/// of being torn down (and losing its poll schedule) every time the bell
/// icon's widget unmounts.
class UnreadCountNotifier extends AsyncNotifier<int> {
  static const _pollInterval = Duration(minutes: 5);
  Timer? _timer;

  @override
  Future<int> build() async {
    ref.keepAlive();
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
    ref.onDispose(() => _timer?.cancel());
    return ref.read(notificationRepositoryProvider).unreadCount();
  }

  Future<void> refresh() async {
    final count = await ref.read(notificationRepositoryProvider).unreadCount();
    state = AsyncData(count);
  }
}

final unreadCountProvider = AsyncNotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);
