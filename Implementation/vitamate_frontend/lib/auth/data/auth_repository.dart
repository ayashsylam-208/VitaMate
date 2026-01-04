import '../../core/storage/secure_storage.dart';
import '../models/auth_token.dart';
import 'auth_api.dart';

class AuthRepository {
  final AuthApi _api;

  AuthRepository(this._api);

  Future<void> register({
    required String username,
    required String password,
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    await _api.register(
      username: username,
      password: password,
      email: email,
      firstName: firstName,
      lastName: lastName,
    );
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final res = await _api.login(username: username, password: password);

    final token = AuthToken.fromJson(res.data as Map<String, dynamic>);
    if (token.access.isEmpty || token.refresh.isEmpty) {
      throw Exception('Login response did not include access/refresh.');
    }

    await SecureStorage.saveTokens(access: token.access, refresh: token.refresh);
  }

  Future<Map<String, dynamic>> getMeRaw() async {
    final res = await _api.me();
    return res.data as Map<String, dynamic>;
  }

  Future<void> updateMe(Map<String, dynamic> data) async {
    await _api.updateMe(data);
  }

  Future<void> logout() async {
    await SecureStorage.clear();
  }
}
