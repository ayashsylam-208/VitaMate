import 'package:flutter/material.dart';

final VitaMateRouteObserver vitaMateRouteObserver = VitaMateRouteObserver();

class VitaMateRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final ValueNotifier<String?> currentRouteName = ValueNotifier<String?>(null);
  String? _pendingRouteName;
  bool _routeUpdateScheduled = false;

  void _setCurrent(Route<dynamic>? route) {
    final nextRouteName = route?.settings.name;
    if (currentRouteName.value == nextRouteName &&
        _pendingRouteName == nextRouteName) {
      return;
    }
    _pendingRouteName = nextRouteName;
    if (_routeUpdateScheduled) {
      return;
    }
    _routeUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeUpdateScheduled = false;
      final routeName = _pendingRouteName;
      _pendingRouteName = null;
      if (currentRouteName.value != routeName) {
        currentRouteName.value = routeName;
      }
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _setCurrent(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _setCurrent(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _setCurrent(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _setCurrent(previousRoute);
  }
}
