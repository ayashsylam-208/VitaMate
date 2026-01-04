class OnboardingState {
  // Backend expects: 'M' or 'F'
  String gender = 'F';

  int age = 18;
  double heightCm = 170;
  double weightKg = 70;

  // Backend expects ONE of: 1.2, 1.375, 1.55, 1.725, 1.9
  double activityLevel = 1.2;

  // Backend expects: lose / maintain / gain / muscle
  String goal = 'maintain';
}
