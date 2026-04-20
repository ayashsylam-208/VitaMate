import 'package:flutter/foundation.dart';

class HealthSyncBus extends ChangeNotifier {
  HealthSyncBus._();

  static final HealthSyncBus instance = HealthSyncBus._();

  void notifyTrackerDataChanged() {
    notifyListeners();
  }
}
