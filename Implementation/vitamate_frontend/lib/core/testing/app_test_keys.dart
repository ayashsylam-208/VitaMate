class AppTestKeys {
  AppTestKeys._();

  static const loginUsernameField = 'login.usernameField';
  static const loginPasswordField = 'login.passwordField';
  static const loginSubmitButton = 'login.submitButton';

  static const homeConditionsCenterAddButton =
      'home.conditionsCenter.addButton';
  static const homeConditionsCenterOpenButton =
      'home.conditionsCenter.openButton';

  static const chronicScreenHeader = 'chronic.screen.header';
  static const chronicCreateSaveButton = 'chronic.create.saveButton';
  static const chronicDetailAddReadingButton =
      'chronic.detail.addReadingButton';
  static const chronicDetailSummaryCard = 'chronic.detail.summaryCard';
  static const chronicDetailReadingsList = 'chronic.detail.readingsList';
  static const chronicReadingSaveButton = 'chronic.reading.saveButton';
  static const chronicDetailBackButton = 'chronic.detail.backButton';

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
