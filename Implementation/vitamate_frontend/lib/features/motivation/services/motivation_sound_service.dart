import 'package:flutter/services.dart';

import '../models/motivation_models.dart';

class MotivationSoundService {
  const MotivationSoundService();

  static const MethodChannel _channel = MethodChannel(
    'vitamate/motivation_audio',
  );

  Future<void> playFor(MotivationCelebration celebration) async {
    switch (celebration.type) {
      case 'points_awarded':
        await playPointAwarded();
      case 'mission_completed':
        await playMissionCompleted();
    }
  }

  Future<void> playPointAwarded() async {
    try {
      await _channel.invokeMethod<void>('play', <String, String>{
        'type': 'points_awarded',
      });
      await HapticFeedback.selectionClick();
    } catch (_) {
      await _fallbackClick();
    }
  }

  Future<void> playMissionCompleted() async {
    try {
      await _channel.invokeMethod<void>('play', <String, String>{
        'type': 'mission_completed',
      });
      await HapticFeedback.mediumImpact();
    } catch (_) {
      await _fallbackAlert();
    }
  }

  Future<void> _fallbackClick() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.selectionClick();
    } catch (_) {
      // Audio feedback is best-effort; celebrations must never fail on sound.
    }
  }

  Future<void> _fallbackAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Audio feedback is best-effort; celebrations must never fail on sound.
    }
  }
}
