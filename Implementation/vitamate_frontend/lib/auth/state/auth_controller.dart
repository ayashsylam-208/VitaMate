import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/config/api_endpoints.dart';
import '../../features/chronic_conditions/data/chronic_conditions_api.dart';
import '../../core/network/network_error_mapper.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../models/user.dart';

class AuthController extends ChangeNotifier {
  AuthController({AuthRepository? repo})
    : _repo = repo ?? AuthRepository(AuthApi());

  final AuthRepository _repo;

  bool isLoading = false;
  String? error;
  AuthUser? me;

  Future<bool> login(String username, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        debugPrint('AuthController.login: start username=$username');
      }
      ChronicConditionsApi.invalidateOverviewCache();
      await _repo
          .login(username: username, password: password)
          .timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        debugPrint('AuthController.login: token exchange complete');
      }
      me = await _repo.getMe().timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        debugPrint('AuthController.login: profile loaded');
      }
      return true;
    } on TimeoutException {
      error = 'Sign in took too long. ${ApiEndpoints.connectionHint()}';
      return false;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Login failed. Please check your credentials.',
        statusMessages: const {401: 'Invalid username or password.'},
      );
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
      await _repo
          .register(
            username: username,
            password: password,
            email: email,
            firstName: firstName,
            lastName: lastName,
          )
          .timeout(const Duration(seconds: 15));
      return true;
    } on TimeoutException {
      error = 'Sign up took too long. ${ApiEndpoints.connectionHint()}';
      return false;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Registration failed. Please try again.',
      );
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    ChronicConditionsApi.invalidateOverviewCache();
    me = null;
    notifyListeners();
  }

  Future<void> updateMe(Map<String, dynamic> data) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      me = await _repo.updateMe(data);
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Profile update failed. Please try again.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMe() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      me = await _repo.getMe();
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load your profile.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
