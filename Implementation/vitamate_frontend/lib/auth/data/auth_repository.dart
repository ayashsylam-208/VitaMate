import 'dart:convert';

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

    final data = _asMap(res.data);
    final token = AuthToken.fromJson(data);

    final access = token.access.trim();
    final refresh = token.refresh?.trim();

    if (access.isEmpty) {
      throw Exception('Login response did not include a valid access token.');
    }
    if (refresh == null || refresh.isEmpty) {
      throw Exception('Login response did not include a valid refresh token.');
    }

    await SecureStorage.saveTokens(
      access: access,
      refresh: refresh,
    );
  }

  Future<Map<String, dynamic>> getMeRaw() async {
    final res = await _api.me();
    return _asMap(res.data);
  }

  Future<void> updateMe(Map<String, dynamic> data) async {
    await _api.updateMe(data);
  }

  Future<void> logout() async {
    await SecureStorage.clear();
  }

  /// Accepts:
  /// - Map<String, dynamic>
  /// - Map (dynamic keys)
  /// - String (JSON text)
  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();

    if (v is String) {
      final decoded = jsonDecode(v);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      throw Exception('Login response JSON is not an object.');
    }

    throw Exception('Unexpected response format: ${v.runtimeType}');
  }
}
