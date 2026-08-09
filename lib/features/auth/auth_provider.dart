import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/session_events.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider));
});

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.error, this.me});

  final AuthStatus status;
  final String? error;
  final Map<String, dynamic>? me;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, SessionEvents sessionEvents) : super(const AuthState()) {
    _restore();
    // ApiClient's interceptor fires this when the refresh token is also
    // invalid/expired — the only way back at that point is a fresh login.
    _sessionExpiredSub = sessionEvents.onExpired.listen((_) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
      );
    });
  }

  final AuthRepository _repo;
  late final StreamSubscription<void> _sessionExpiredSub;

  @override
  void dispose() {
    _sessionExpiredSub.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    if (await _repo.hasSession()) {
      try {
        final me = await _repo.me();
        state = AuthState(status: AuthStatus.authenticated, me: me);
        return;
      } catch (_) {
        await _repo.logout();
      }
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> login(String email, String password) async {
    try {
      await _repo.login(email: email, password: password);
      final me = await _repo.me();
      state = AuthState(status: AuthStatus.authenticated, me: me);
    } on DioException catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: _errorMessage(e));
    }
  }

  Future<void> signup({
    required String businessName,
    required String ownerName,
    required String email,
    required String password,
  }) async {
    try {
      await _repo.signup(
        businessName: businessName,
        ownerName: ownerName,
        email: email,
        password: password,
      );
      final me = await _repo.me();
      state = AuthState(status: AuthStatus.authenticated, me: me);
    } on DioException catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: _errorMessage(e));
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่อีกครั้ง';
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider), ref.watch(sessionEventsProvider));
});
