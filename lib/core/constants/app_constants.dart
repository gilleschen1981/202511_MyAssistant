/// Application-wide constants
class AppConstants {
  // App Info
  static const String appName = 'MyAssistant';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'myassistant.db';
  static const int databaseVersion = 1;

  // Preferences Keys
  static const String prefKeyUserId = 'user_id';
  static const String prefKeyToken = 'auth_token';
  static const String prefKeyTheme = 'theme_mode';
  static const String prefKeyLocale = 'locale';
  static const String prefKeyFirstLaunch = 'first_launch';

  // Default Values
  static const int defaultTimerMinutes = 25;
  static const double minFontScale = 0.8;
  static const double maxFontScale = 1.3;

  // Time Window (hours)
  static const int taskWindowHours = 24;

  // Pagination
  static const int pageSize = 20;

  // Session
  static const int sessionTimeoutDays = 7;

  // Supported Locales
  static const List<String> supportedLocales = ['zh_CN', 'en_US'];
  static const String defaultLocale = 'zh_CN';
}