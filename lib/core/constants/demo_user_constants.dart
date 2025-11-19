/// Demo user constants for testing and development
/// This demo user is automatically created when the database is initialized
class DemoUserConstants {
  // Demo User Info
  static const String userId = 'demo-user-001';
  static const String username = 'demo';
  static const String email = 'demo@myassistant.com';
  static const String passwordHash = 'demo-password-hash';
  static const String displayName = 'Demo User';
  static const String status = 'active';

  // Demo User Settings
  static const String themeMode = 'system';
  static const String locale = 'zh_CN';
  static const double fontScale = 1.0;
  static const int enableNotifications = 1;
  static const int enableSound = 1;
  static const int enableVibration = 1;
  static const int autoSync = 0;
  static const int autoRefreshTasks = 1;
  static const int defaultTimerMinutes = 25;
  static const int enableAnalytics = 0;
  static const int enableCrashReporting = 1;

  /// Get demo user data as Map for database insertion
  static Map<String, dynamic> getUserData(int timestamp) {
    return {
      'id': userId,
      'username': username,
      'email': email,
      'password_hash': passwordHash,
      'display_name': displayName,
      'avatar_url': null,
      'status': status,
      'created_at': timestamp,
      'updated_at': timestamp,
      'deleted_at': null,
    };
  }

  /// Get demo user settings data as Map for database insertion
  static Map<String, dynamic> getUserSettingsData() {
    return {
      'user_id': userId,
      'theme_mode': themeMode,
      'locale': locale,
      'font_scale': fontScale,
      'enable_notifications': enableNotifications,
      'enable_sound': enableSound,
      'enable_vibration': enableVibration,
      'auto_sync': autoSync,
      'last_sync_time': null,
      'auto_refresh_tasks': autoRefreshTasks,
      'default_timer_minutes': defaultTimerMinutes,
      'enable_analytics': enableAnalytics,
      'enable_crash_reporting': enableCrashReporting,
    };
  }
}
