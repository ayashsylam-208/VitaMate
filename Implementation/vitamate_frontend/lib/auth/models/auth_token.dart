class AuthToken {
  final String access;
  final String? refresh;

  AuthToken({required this.access, this.refresh});

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    // يدعم: access/refresh أو token
    final access = (json['access'] ?? json['token'] ?? '') as String;
    final refresh = json['refresh'] as String?;
    return AuthToken(access: access, refresh: refresh);
  }
}
