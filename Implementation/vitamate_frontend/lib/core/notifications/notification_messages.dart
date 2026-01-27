import 'dart:math';

class NotificationMessages {
  static final _rng = Random();

  static String _pick(List<String> list) => list[_rng.nextInt(list.length)];

  // =====================
  // Water reminders
  // =====================

  static String waterTitle() =>
      _pick(['Time to hydrate 💧', 'Drink some water', 'Hydration reminder']);

  static String waterBody() => _pick([
    'A small glass of water makes a big difference.',
    'Stay hydrated to keep your energy up.',
    'Don’t forget to drink water!',
    'Your body will thank you for this 💙',
  ]);

  // =====================
  // Sleep - Bedtime
  // =====================

  static String sleepBedTitle() =>
      _pick(['Bedtime is near 🛌', 'Time to wind down', 'Prepare for sleep']);

  static String sleepBedBody() => _pick([
    'Good sleep helps your body recover.',
    'Try to disconnect and relax before sleeping.',
    'Quality sleep = a better tomorrow.',
  ]);

  // =====================
  // Sleep - Wake up
  // =====================

  static String sleepWakeTitle() =>
      _pick(['Good morning ☀️', 'Rise and shine', 'New day, new energy']);

  static String sleepWakeBody() => _pick([
    'Start your day with positive energy.',
    'A fresh start for a healthy day.',
    'Take a deep breath and begin your day.',
  ]);

  // =====================
  // Meals
  // =====================

  static String breakfastTitle() => 'Breakfast time 🍳';
  static String breakfastBody() =>
      'Log your breakfast to stay on track with your calories.';

  static String lunchTitle() => 'Lunch time 🍲';
  static String lunchBody() =>
      'Don’t forget to log your lunch and stay balanced.';

  static String dinnerTitle() => 'Dinner time 🥗';
  static String dinnerBody() =>
      'Log your dinner to complete your daily nutrition tracking.';

  // =====================
  // Activity reminders
  // =====================

  static String activityTitle() =>
      _pick(['Time to move 🏃', 'Get active', 'Activity reminder']);

  static String activityBody() => _pick([
    'A short walk can boost your energy.',
    'Move your body and refresh your mind.',
    'Even 10 minutes of activity matters.',
    'Consistency is the key to progress.',
  ]);

  // =====================
  // Steps reminders
  // =====================
  static String stepsTitle() =>
      _pick(['Keep stepping', 'Hit your step goal', 'Quick walk time']);

  static String stepsBody() => _pick([
        'Stand up and add a few minutes of walking.',
        'Small walks add up—let\'s get those steps in.',
        'Move a bit now to stay on track.',
        'Your daily step streak is waiting for you.',
      ]);
}
