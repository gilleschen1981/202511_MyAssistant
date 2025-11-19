// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserSettingsModel _$UserSettingsModelFromJson(Map<String, dynamic> json) =>
    UserSettingsModel(
      userId: json['userId'] as String,
      themeMode:
          $enumDecodeNullable(_$AppThemeModeEnumMap, json['themeMode']) ??
          AppThemeMode.system,
      locale: json['locale'] as String? ?? 'zh_CN',
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      enableNotifications: json['enableNotifications'] as bool? ?? true,
      enableSound: json['enableSound'] as bool? ?? true,
      enableVibration: json['enableVibration'] as bool? ?? true,
      autoSync: json['autoSync'] as bool? ?? true,
      lastSyncTime: json['lastSyncTime'] == null
          ? null
          : DateTime.parse(json['lastSyncTime'] as String),
      autoRefreshTasks: json['autoRefreshTasks'] as bool? ?? true,
      defaultTimerMinutes: (json['defaultTimerMinutes'] as num?)?.toInt() ?? 25,
      enableAnalytics: json['enableAnalytics'] as bool? ?? false,
      enableCrashReporting: json['enableCrashReporting'] as bool? ?? true,
    );

Map<String, dynamic> _$UserSettingsModelToJson(UserSettingsModel instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'themeMode': _$AppThemeModeEnumMap[instance.themeMode]!,
      'locale': instance.locale,
      'fontScale': instance.fontScale,
      'enableNotifications': instance.enableNotifications,
      'enableSound': instance.enableSound,
      'enableVibration': instance.enableVibration,
      'autoSync': instance.autoSync,
      'lastSyncTime': instance.lastSyncTime?.toIso8601String(),
      'autoRefreshTasks': instance.autoRefreshTasks,
      'defaultTimerMinutes': instance.defaultTimerMinutes,
      'enableAnalytics': instance.enableAnalytics,
      'enableCrashReporting': instance.enableCrashReporting,
    };

const _$AppThemeModeEnumMap = {
  AppThemeMode.light: 'light',
  AppThemeMode.dark: 'dark',
  AppThemeMode.system: 'system',
};
