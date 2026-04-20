import 'user_profile.dart';

class AuthUser {
  const AuthUser({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.profile,
  });

  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final UserProfileSettings profile;

  String get fullName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? username : value;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      username: json['username']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      profile: UserProfileSettings.fromJson(json),
    );
  }
}
