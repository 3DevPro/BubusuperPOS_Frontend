import 'package:dio/dio.dart';

import 'config.dart';
import 'session_events.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient(this._tokenStorage, this._sessionEvents)
    : dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)),
      // The chatbot runs as its own service (see BubusuperPOS_chatbot) — its
      // own Dio instance, but it shares the *same* token/refresh interceptor
      // below via _attachAuthInterceptor, so a 401 on a chat request goes
      // through the identical refresh-and-retry flow as everything else.
      chatDio = Dio(BaseOptions(baseUrl: AppConfig.chatbotBaseUrl)),
      // A plain client for the refresh call itself — it must not carry a
      // (possibly expired) Authorization header, and must not go through
      // this same interceptor or a failed refresh would try to refresh itself.
      _refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)) {
    _attachAuthInterceptor(dio);
    _attachAuthInterceptor(chatDio);
  }

  void _attachAuthInterceptor(Dio client) {
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isAuthEndpoint = error.requestOptions.path.startsWith('/api/v1/auth/');
          final alreadyRetried = error.requestOptions.extra['retriedAfterRefresh'] == true;
          if (error.response?.statusCode != 401 || isAuthEndpoint || alreadyRetried) {
            handler.next(error);
            return;
          }

          try {
            final newAccessToken = await _refreshAccessToken();
            final retryOptions = error.requestOptions
              ..headers['Authorization'] = 'Bearer $newAccessToken'
              ..extra['retriedAfterRefresh'] = true;
            // `client.fetch` (not `dio.fetch`) — retryOptions already carries
            // whichever baseUrl the failed request originated from (dio's or
            // chatDio's), but fetch() must be called through a Dio instance
            // that has this same interceptor attached, or a *second* 401
            // wouldn't retry again. Using the same client the request came
            // from keeps that symmetric for both dio and chatDio.
            handler.resolve(await client.fetch(retryOptions));
          } catch (_) {
            // Refresh token is also invalid/expired — there's no way back
            // without the user logging in again.
            await _tokenStorage.clear();
            _sessionEvents.notifyExpired();
            handler.next(error);
          }
        },
      ),
    );
  }

  final Dio dio;
  final Dio chatDio;
  final Dio _refreshDio;
  final TokenStorage _tokenStorage;
  final SessionEvents _sessionEvents;

  // Several requests can 401 around the same moment (e.g. the app was idle
  // past the access token's lifetime and multiple screens refetch at once)
  // — share one in-flight refresh instead of racing the backend with several.
  Future<String>? _refreshInFlight;

  Future<String> _refreshAccessToken() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<String> _doRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      throw StateError('no refresh token available');
    }
    final resp = await _refreshDio.post('/api/v1/auth/refresh', data: {'refresh_token': refreshToken});
    final data = resp.data as Map<String, dynamic>;
    final newAccessToken = data['access_token'] as String;
    await _tokenStorage.save(accessToken: newAccessToken, refreshToken: data['refresh_token'] as String);
    return newAccessToken;
  }
}
