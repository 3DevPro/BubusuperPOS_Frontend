import '../../core/api_client.dart';
import '../../core/token_storage.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<void> login({required String email, required String password}) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    await _saveTokens(resp.data);
  }

  Future<void> signup({
    required String businessName,
    required String ownerName,
    required String email,
    required String password,
  }) async {
    final resp = await _apiClient.dio.post(
      '/api/v1/auth/signup',
      data: {
        'business_name': businessName,
        'owner_name': ownerName,
        'email': email,
        'password': password,
      },
    );
    await _saveTokens(resp.data);
  }

  Future<Map<String, dynamic>> me() async {
    final resp = await _apiClient.dio.get('/api/v1/auth/me');
    return resp.data as Map<String, dynamic>;
  }

  Future<bool> hasSession() async {
    return await _tokenStorage.readAccessToken() != null;
  }

  Future<void> logout() => _tokenStorage.clear();

  Future<void> _saveTokens(Map<String, dynamic> data) {
    return _tokenStorage.save(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }
}
