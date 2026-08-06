import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../core/network/network_error_mapper.dart';
import '../../../core/network/request_manager.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../data/motivation_repository.dart';
import '../models/motivation_models.dart';

class MotivationExperienceController extends ChangeNotifier
    with WidgetsBindingObserver {
  MotivationExperienceController({
    MotivationRepository? repository,
    RequestManager? requestManager,
  }) : _repository = repository ?? MotivationRepository(),
       _requestManager = requestManager ?? RequestManager();

  static final MotivationExperienceController instance =
      MotivationExperienceController();

  final MotivationRepository _repository;
  final RequestManager _requestManager;

  MotivationFeed feed = MotivationFeed.empty();
  MotivationCelebration? _activeCelebration;
  final List<MotivationCelebration> _queuedCelebrations =
      <MotivationCelebration>[];
  final Set<int> _knownCelebrationIds = <int>{};

  bool loading = false;
  bool _started = false;
  bool _foreground = true;
  bool presentationEnabled = false;
  String? error;

  MotivationCelebration? get activeCelebration => _activeCelebration;

  int get unreadCelebrationCount =>
      (_activeCelebration == null ? 0 : 1) + _queuedCelebrations.length;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    HealthSyncBus.instance.addListener(_handleHealthSync);
    unawaited(load(silent: true));
  }

  void activatePresentation() {
    final changed = !presentationEnabled;
    presentationEnabled = true;
    start();
    if (changed) {
      _notifyListenersSafely();
    }
  }

  void resetPresentation() {
    _requestManager.cancelAll();
    feed = MotivationFeed.empty();
    _activeCelebration = null;
    _queuedCelebrations.clear();
    _knownCelebrationIds.clear();
    loading = false;
    error = null;
    presentationEnabled = false;
    notifyListeners();
  }

  void _notifyListenersSafely() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hasListeners) {
        return;
      }
      notifyListeners();
    });
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  Future<void> load({bool silent = false}) async {
    final lease = _requestManager.beginLatest('motivation.feed');
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    error = null;
    try {
      final nextFeed = await _repository.getFeed(
        cancelToken: lease.cancelToken,
      );
      if (!_requestManager.isCurrent(lease)) {
        return;
      }
      feed = nextFeed;
      _mergeCelebrations(nextFeed.celebrations);
      if (_foreground) {
        _promoteNextCelebration();
      }
    } catch (e) {
      if (NetworkErrorMapper.isCanceled(e)) {
        return;
      }
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load motivation feed',
      );
    } finally {
      _requestManager.complete(lease);
      loading = false;
      notifyListeners();
    }
  }

  Future<void> dismissActiveCelebration() async {
    final current = _activeCelebration;
    if (current == null) {
      return;
    }
    _activeCelebration = null;
    notifyListeners();
    try {
      await _repository.acknowledgeCelebrations(ids: <int>[current.id]);
    } catch (_) {
      // Keep the local dismissal even if the ack request fails.
    }
    _promoteNextCelebration();
  }

  void _handleHealthSync() {
    if (!HealthSyncBus.instance.affects(const {HealthSyncScope.homeOverview})) {
      return;
    }
    unawaited(load(silent: true));
  }

  void _mergeCelebrations(List<MotivationCelebration> incoming) {
    for (final item in incoming) {
      // Major achievements are owned by Notification Hub so they cannot render
      // simultaneously with the lightweight points burst.
      if (item.type != 'points_awarded') {
        continue;
      }
      if (!_knownCelebrationIds.add(item.id)) {
        continue;
      }
      _queuedCelebrations.add(item);
    }
    _queuedCelebrations.sort(
      (a, b) => (a.createdAt ?? DateTime(2000)).compareTo(
        b.createdAt ?? DateTime(2000),
      ),
    );
  }

  void _promoteNextCelebration() {
    if (_activeCelebration != null ||
        _queuedCelebrations.isEmpty ||
        !_foreground) {
      return;
    }
    _activeCelebration = _queuedCelebrations.removeAt(0);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _promoteNextCelebration();
      unawaited(load(silent: true));
    }
  }

  @override
  void dispose() {
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      HealthSyncBus.instance.removeListener(_handleHealthSync);
    }
    _requestManager.cancelAll();
    super.dispose();
  }
}
