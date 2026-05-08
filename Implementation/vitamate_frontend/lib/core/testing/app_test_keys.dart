class AppTestKeys {
  AppTestKeys._();

  static const loginUsernameField = 'login.usernameField';
  static const loginPasswordField = 'login.passwordField';
  static const loginSubmitButton = 'login.submitButton';
  static const onboardingScreen = 'onboarding.screen';
  static const onboardingBackButton = 'onboarding.backButton';
  static const onboardingContinueButton = 'onboarding.continueButton';

  static const homeScreen = 'home.screen';
  static const homeConditionsCenterAddButton =
      'home.conditionsCenter.addButton';
  static const homeConditionsCenterOpenButton =
      'home.conditionsCenter.openButton';

  static const chronicCreateSheet = 'chronic.create.sheet';
  static const chronicScreenHeader = 'chronic.screen.header';
  static const chronicCreateSaveButton = 'chronic.create.saveButton';
  static const chronicDetailAddReadingButton =
      'chronic.detail.addReadingButton';
  static const chronicDetailSummaryCard = 'chronic.detail.summaryCard';
  static const chronicDetailReadingsList = 'chronic.detail.readingsList';
  static const chronicReadingSaveButton = 'chronic.reading.saveButton';
  static const chronicDetailBackButton = 'chronic.detail.backButton';

  static const nutritionScreen = 'nutrition.screen';
  static const nutritionLogMealButton = 'nutrition.logMeal.button';
  static const nutritionCreateFoodButton = 'nutrition.createFood.button';
  static const nutritionLogMealSheet = 'nutrition.logMeal.sheet';
  static const nutritionCreateFoodSheet = 'nutrition.createFood.sheet';
  static const nutritionSearchField = 'nutrition.search.field';
  static const nutritionCategoryField = 'nutrition.category.field';
  static const nutritionAmountField = 'nutrition.amount.field';
  static const nutritionSaveMealButton = 'nutrition.saveMeal.button';
  static const nutritionSaveFoodButton = 'nutrition.saveFood.button';

  static const waterScreen = 'water.screen';
  static const waterAddBeverageButton = 'water.addBeverage.button';
  static const waterAddBeverageSheet = 'water.addBeverage.sheet';
  static const waterSearchField = 'water.search.field';
  static const waterCatalogSaveButton = 'water.catalog.saveButton';
  static const waterCustomSaveButton = 'water.custom.saveButton';

  static const activityScreen = 'activity.screen';
  static const sleepScreen = 'sleep.screen';
  static const statsScreen = 'stats.screen';
  static const stepsScreen = 'steps.screen';

  static const medicationsScreen = 'medications.screen';
  static const medicationsAddScreen = 'medications.add.screen';
  static const medicationsTodayScreen = 'medications.today.screen';
  static const medicationsAddButton = 'medications.add.button';
  static const medicationsTodayPlanButton = 'medications.todayPlan.button';
  static const medicationsSaveButton = 'medications.save.button';

  static String homeConditionCard(String slug) =>
      'home.conditionsCenter.card.$slug';

  static String chronicSupportedAddButton(String slug) =>
      'chronic.supported.$slug.addButton';

  static String chronicSupportedOpenButton(String slug) =>
      'chronic.supported.$slug.openButton';

  static String chronicCreateField({
    required String slug,
    required String field,
  }) => 'chronic.create.$slug.$field';

  static String chronicReadingField({
    required String slug,
    required String field,
  }) => 'chronic.reading.$slug.$field';
}
