import 'package:flutter/foundation.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository(AuthApi());

  bool isLoading = false;
  String? error;
  Map<String, dynamic>? me;

  Future<bool> login(String username, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _repo.login(username: username, password: password);
      me = await _repo.getMeRaw();
      return true;
    } catch (e) {
      error =
          'Login failed. Please check your credentials and network connection.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String password,
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _repo.register(
        username: username,
        password: password,
        email: email,
        firstName: firstName,
        lastName: lastName,
      );
      return true;
    } catch (e) {
      error =
          'Registration failed. The username or email may already be in use.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    me = null;
    notifyListeners();
  }

  Future<void> updateMe(Map<String, dynamic> data) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _repo.updateMe(data);
      me = await _repo.getMeRaw();
    } catch (e) {
      error = 'Profile update failed. Please try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
