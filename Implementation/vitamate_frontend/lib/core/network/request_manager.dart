import 'package:dio/dio.dart';

class RequestLease {
  const RequestLease._({
    required this.key,
    required this.revision,
    required this.cancelToken,
  });

  final String key;
  final int revision;
  final CancelToken cancelToken;
}

class RequestManager {
  final Map<String, CancelToken> _tokens = <String, CancelToken>{};
  final Map<String, int> _revisions = <String, int>{};

  RequestLease beginLatest(String key, {String reason = 'Request replaced'}) {
    _tokens.remove(key)?.cancel(reason);
    final revision = (_revisions[key] ?? 0) + 1;
    _revisions[key] = revision;
    final cancelToken = CancelToken();
    _tokens[key] = cancelToken;
    return RequestLease._(
      key: key,
      revision: revision,
      cancelToken: cancelToken,
    );
  }

  bool isCurrent(RequestLease lease) {
    return _revisions[lease.key] == lease.revision &&
        identical(_tokens[lease.key], lease.cancelToken) &&
        !lease.cancelToken.isCancelled;
  }

  void complete(RequestLease lease) {
    if (identical(_tokens[lease.key], lease.cancelToken)) {
      _tokens.remove(lease.key);
    }
  }

  void cancel(String key, {String reason = 'Request canceled'}) {
    _tokens.remove(key)?.cancel(reason);
  }

  void cancelAll({String reason = 'Request manager disposed'}) {
    for (final token in _tokens.values) {
      token.cancel(reason);
    }
    _tokens.clear();
  }
}
