class OnboardingState {
  String? gender; // 'M' or 'F'
  int? age;
  double? heightCm;
  double? weightKg;
  double? activityLevel; // 1.2, 1.375, 1.55, 1.725, 1.9
  String? goal; // lose / maintain / gain / muscle

  bool get hasBasicInfo =>
      gender != null &&
      gender!.isNotEmpty &&
      age != null &&
      age! > 0 &&
      heightCm != null &&
      heightCm! > 0 &&
      weightKg != null &&
      weightKg! > 0;

  bool get hasActivityLevel => activityLevel != null;

  bool get hasGoal => goal != null && goal!.isNotEmpty;
}
