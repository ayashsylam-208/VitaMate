class LocalTimezone {
  LocalTimezone._();

  static const String _configured = String.fromEnvironment(
    'VITAMATE_TIMEZONE',
    defaultValue: '',
  );

  static String get ianaName {
    final configured = _configured.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    final name = DateTime.now().timeZoneName.trim();
    if (_looksLikeIana(name)) {
      return name;
    }
    return _fromOffset(DateTime.now().timeZoneOffset);
  }

  static bool _looksLikeIana(String value) {
    return value.contains('/') && !value.contains(' ');
  }

  static String _fromOffset(Duration offset) {
    if (offset == const Duration(hours: 3)) {
      return 'Asia/Damascus';
    }
    if (offset == const Duration(hours: 2)) {
      return 'Europe/Athens';
    }
    if (offset == Duration.zero) {
      return 'UTC';
    }
    return 'UTC';
  }
}
