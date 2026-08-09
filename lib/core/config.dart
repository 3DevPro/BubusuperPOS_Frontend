import 'package:flutter/foundation.dart';

class AppConfig {
  /// Set at build time with `--dart-define=API_BASE_URL=https://example.com`
  /// for a release build (e.g. a native app) that must point at a real
  /// domain instead of localhost.
  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Android emulator can't reach the host machine via `localhost` — it needs
  /// the special `10.0.2.2` alias. Web and other platforms hit localhost directly.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    // Release web builds are served by Caddy from the same origin as the
    // API (see infra/Caddyfile), so a relative base URL avoids hardcoding a
    // domain and sidesteps CORS entirely — only dev/debug needs localhost.
    if (kIsWeb && kReleaseMode) return '';
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Set at build time with `--dart-define=CHATBOT_BASE_URL=https://example.com`.
  /// The chatbot runs as its own service (see BubusuperPOS_chatbot), on its
  /// own port in dev; in release web it collapses to the same empty/relative
  /// base URL as [apiBaseUrl] — Caddy alone decides which container handles
  /// `/api/v1/chat/*` vs the rest of `/api/*` (see infra/Caddyfile), so this
  /// only actually differs from apiBaseUrl in local dev.
  static const _chatbotBaseUrlOverride = String.fromEnvironment('CHATBOT_BASE_URL');

  static String get chatbotBaseUrl {
    if (_chatbotBaseUrlOverride.isNotEmpty) return _chatbotBaseUrlOverride;
    if (kIsWeb && kReleaseMode) return '';
    if (kIsWeb) return 'http://localhost:8001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }
}
