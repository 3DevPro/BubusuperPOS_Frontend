import 'dart:async';

/// Broadcast signal for "the refresh token is also invalid, force logout."
/// ApiClient's interceptor lives outside the widget tree and can't reach
/// authControllerProvider directly (that would be a circular provider
/// dependency, since AuthController's own repository is built on top of
/// ApiClient) — it fires this instead, and AuthController listens.
class SessionEvents {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onExpired => _controller.stream;

  void notifyExpired() => _controller.add(null);

  void dispose() => _controller.close();
}
