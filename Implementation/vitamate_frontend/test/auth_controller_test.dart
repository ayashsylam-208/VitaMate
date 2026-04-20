import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/auth/data/auth_api.dart';
import 'package:vitamate/auth/data/auth_repository.dart';
import 'package:vitamate/auth/models/auth_token.dart';
import 'package:vitamate/auth/models/user.dart';
import 'package:vitamate/auth/models/user_profile.dart';
import 'package:vitamate/auth/state/auth_controller.dart';
import 'package:vitamate/core/network/http_client.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.loginError, this.user}) : super(AuthApi());

  final Object? loginError;
  final AuthUser? user;

  @override
  Future<AuthToken> login({
    required String username,
    required String password,
  }) async {
    if (loginError != null) {
      throw loginError!;
    }
    return const AuthToken(access: 'access-token', refresh: 'refresh-token');
  }

  @override
  Future<AuthUser> getMe() async {
    return user!;
  }
}

AuthUser _sampleUser() {
  return AuthUser(
    username: 'salam',
    firstName: 'Salam',
    lastName: 'Ayash',
    email: 'salam@example.com',
    profile: UserProfileSettings.fromJson(const {
      'weight': 82,
      'height': 178,
      'activity_level': 1.55,
      'goal': 'maintain',
      'daily_step_goal': 9000,
      'gender': 'male',
      'birth_date': '2000-01-01',
      'recommended_sleep_hours': 8,
      'target_wake_time': '07:00:00',
      'target_bed_time': '23:00:00',
      'enable_sleep_improvement': true,
      'preferred_activity_type': 'walking',
      'enable_activity_reminders': true,
      'activity_reminder_interval_hours': 2,
      'enable_water_reminders': true,
      'water_reminder_interval_minutes': 60,
    }),
  );
}

void main() {
  setUpAll(() {
    HttpClient.initForTesting();
  });

  test('login populates typed me state', () async {
    final controller = AuthController(
      repo: _FakeAuthRepository(user: _sampleUser()),
    );

    final success = await controller.login('salam', 'Secret123');

    expect(success, isTrue);
    expect(controller.error, isNull);
    expect(controller.isLoading, isFalse);
    expect(controller.me, isNotNull);
    expect(controller.me!.fullName, 'Salam Ayash');
    expect(controller.me!.profile.dailyStepGoal, 9000);
  });

  test('login maps dio auth errors to a user-facing message', () async {
    final request = RequestOptions(path: '/api/auth/login/');
    final controller = AuthController(
      repo: _FakeAuthRepository(
        loginError: DioException(
          requestOptions: request,
          response: Response(requestOptions: request, statusCode: 401),
          type: DioExceptionType.badResponse,
        ),
      ),
    );

    final success = await controller.login('salam', 'wrong-password');

    expect(success, isFalse);
    expect(controller.isLoading, isFalse);
    expect(controller.me, isNull);
    expect(controller.error, 'Invalid username or password.');
  });
}
