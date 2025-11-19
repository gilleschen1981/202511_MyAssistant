import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_settings_model.g.dart';

/// App-specific ThemeMode to avoid conflict with Flutter's ThemeMode
enum AppThemeMode {
  light,
  dark,
  system;

  /// Convert to string for database storage
  String toDbString() => name;

  /// Create from string
  static AppThemeMode fromString(String str) {
    return AppThemeMode.values.firstWhere(
      (t) => t.name == str.toLowerCase(),
      orElse: () => AppThemeMode.system,
    );
  }
}

@JsonSerializable()
class UserSettingsModel extends Equatable {
  // Associated user
  final String userId; // Primary key

  // Display settings
  final AppThemeMode themeMode;
  final String locale; // zh_CN or en_US
  final double fontScale; // 0.8 - 1.3

  // Notification settings
  final bool enableNotifications;
  final bool enableSound;
  final bool enableVibration;

  // Data sync settings
  final bool autoSync;
  final DateTime? lastSyncTime;

  // Task settings
  final bool autoRefreshTasks;
  final int defaultTimerMinutes;

  // Privacy settings
  final bool enableAnalytics;
  final bool enableCrashReporting;

  const UserSettingsModel({
    required this.userId,
    this.themeMode = AppThemeMode.system,
    this.locale = 'zh_CN',
    this.fontScale = 1.0,
    this.enableNotifications = true,
    this.enableSound = true,
    this.enableVibration = true,
    this.autoSync = true,
    this.lastSyncTime,
    this.autoRefreshTasks = true,
    this.defaultTimerMinutes = 25,
    this.enableAnalytics = false,
    this.enableCrashReporting = true,
  });

  /// Validate font scale
  bool get isFontScaleValid =>
      fontScale >= 0.8 && fontScale <= 1.3;

  /// Validate timer minutes
  bool get isTimerMinutesValid =>
      defaultTimerMinutes > 0 && defaultTimerMinutes <= 180;

  /// Factory constructor for creating from JSON
  factory UserSettingsModel.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$UserSettingsModelToJson(this);

  /// Copy with method for immutable updates
  UserSettingsModel copyWith({
    String? userId,
    AppThemeMode? themeMode,
    String? locale,
    double? fontScale,
    bool? enableNotifications,
    bool? enableSound,
    bool? enableVibration,
    bool? autoSync,
    DateTime? lastSyncTime,
    bool? autoRefreshTasks,
    int? defaultTimerMinutes,
    bool? enableAnalytics,
    bool? enableCrashReporting,
  }) {
    return UserSettingsModel(
      userId: userId ?? this.userId,
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      fontScale: fontScale ?? this.fontScale,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
      autoSync: autoSync ?? this.autoSync,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      autoRefreshTasks: autoRefreshTasks ?? this.autoRefreshTasks,
      defaultTimerMinutes: defaultTimerMinutes ?? this.defaultTimerMinutes,
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
      enableCrashReporting: enableCrashReporting ?? this.enableCrashReporting,
    );
  }

  /// Factory for default settings for a new user
  factory UserSettingsModel.defaultSettings(String userId) {
    return UserSettingsModel(userId: userId);
  }

  @override
  List<Object?> get props => [
        userId,
        themeMode,
        locale,
        fontScale,
        enableNotifications,
        enableSound,
        enableVibration,
        autoSync,
        lastSyncTime,
        autoRefreshTasks,
        defaultTimerMinutes,
        enableAnalytics,
        enableCrashReporting,
      ];
}