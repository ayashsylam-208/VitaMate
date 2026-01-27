class AuthToken {
  final String access;
  final String? refresh;

  const AuthToken({
    required this.access,
    this.refresh,
  });

  /// True if access token exists and not empty.
  bool get hasAccess => access.trim().isNotEmpty;

  /// True if refresh token exists and not empty.
  bool get hasRefresh => (refresh?.trim().isNotEmpty ?? false);

  /// Returns refresh token if present, otherwise throws a clear exception.
  String get requireRefresh {
    final r = refresh?.trim();
    if (r == null || r.isEmpty) {
      throw const FormatException('Refresh token is missing from response.');
    }
    return r;
  }

  AuthToken copyWith({
    String? access,
    String? refresh,
  }) {
    return AuthToken(
      access: access ?? this.access,
      refresh: refresh ?? this.refresh,
    );
  }

  Map<String, dynamic> toJson() => {
        'access': access,
        if (refresh != null) 'refresh': refresh,
      };

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    // Supports:
    // 1) { "access": "...", "refresh": "..." }
    // 2) { "token": "..." }   // fallback token-only APIs
    final access = _asString(json['access']) ?? _asString(json['token']) ?? '';
    final refresh = _asString(json['refresh']);

    return AuthToken(
      access: access,
      refresh: (refresh != null && refresh.trim().isNotEmpty) ? refresh : null,
    );
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }
}
