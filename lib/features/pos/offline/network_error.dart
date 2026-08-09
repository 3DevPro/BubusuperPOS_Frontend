import 'package:dio/dio.dart';

/// True when [e] means the request never reached the server (offline, DNS
/// failure, timeout) — as opposed to a real response the server sent back
/// (4xx/5xx), which should surface as an error rather than get queued.
bool isNetworkError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return true;
    default:
      return false;
  }
}
