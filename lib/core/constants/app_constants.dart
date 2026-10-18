class AppConstants {
  static const demoUserId = 'demo-user';
  static const currencySymbol = r'$';
}

const bool enablePersonalMode = bool.fromEnvironment(
  'ENABLE_PERSONAL_MODE',
  defaultValue: false,
);
