import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/data/models/user_settings_model.dart';

void main() {
  group('AppThemeMode', () {
    test('toDbString should return the enum name', () {
      expect(AppThemeMode.light.toDbString(), 'light');
      expect(AppThemeMode.dark.toDbString(), 'dark');
      expect(AppThemeMode.system.toDbString(), 'system');
    });

    test('fromString should return the correct enum value', () {
      expect(AppThemeMode.fromString('light'), AppThemeMode.light);
      expect(AppThemeMode.fromString('dark'), AppThemeMode.dark);
      expect(AppThemeMode.fromString('system'), AppThemeMode.system);
    });

    test('fromString should be case-insensitive', () {
      expect(AppThemeMode.fromString('LIGHT'), AppThemeMode.light);
      expect(AppThemeMode.fromString('Dark'), AppThemeMode.dark);
      expect(AppThemeMode.fromString('SYSTEM'), AppThemeMode.system);
    });

    test('fromString should default to system for unknown values', () {
      expect(AppThemeMode.fromString('unknown'), AppThemeMode.system);
      expect(AppThemeMode.fromString(''), AppThemeMode.system);
      expect(AppThemeMode.fromString('auto'), AppThemeMode.system);
    });
  });

  group('UserSettingsModel', () {
    test('should create with required fields and defaults', () {
      const settings = UserSettingsModel(userId: 'user-123');

      expect(settings.userId, 'user-123');
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.locale, 'zh_CN');
      expect(settings.fontScale, 1.0);
      expect(settings.enableNotifications, true);
      expect(settings.enableSound, true);
      expect(settings.enableVibration, true);
      expect(settings.autoSync, true);
      expect(settings.lastSyncTime, isNull);
      expect(settings.autoRefreshTasks, true);
      expect(settings.defaultTimerMinutes, 25);
      expect(settings.enableAnalytics, false);
      expect(settings.enableCrashReporting, true);
    });

    test('should create with all fields specified', () {
      final syncTime = DateTime(2024, 6, 15, 10, 30);

      final settings = UserSettingsModel(
        userId: 'user-123',
        themeMode: AppThemeMode.dark,
        locale: 'en_US',
        fontScale: 1.2,
        enableNotifications: false,
        enableSound: false,
        enableVibration: false,
        autoSync: false,
        lastSyncTime: syncTime,
        autoRefreshTasks: false,
        defaultTimerMinutes: 45,
        enableAnalytics: true,
        enableCrashReporting: false,
      );

      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.locale, 'en_US');
      expect(settings.fontScale, 1.2);
      expect(settings.enableNotifications, false);
      expect(settings.enableSound, false);
      expect(settings.enableVibration, false);
      expect(settings.autoSync, false);
      expect(settings.lastSyncTime, syncTime);
      expect(settings.autoRefreshTasks, false);
      expect(settings.defaultTimerMinutes, 45);
      expect(settings.enableAnalytics, true);
      expect(settings.enableCrashReporting, false);
    });

    group('defaultSettings factory', () {
      test('should create settings with the given userId', () {
        final settings = UserSettingsModel.defaultSettings('user-456');

        expect(settings.userId, 'user-456');
      });

      test('should use same defaults as the constructor defaults', () {
        final factorySettings = UserSettingsModel.defaultSettings('user-123');
        const constructorSettings = UserSettingsModel(userId: 'user-123');

        expect(factorySettings, equals(constructorSettings));
      });
    });

    group('isFontScaleValid', () {
      test('should be valid at lower bound (0.8)', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          fontScale: 0.8,
        );

        expect(settings.isFontScaleValid, true);
      });

      test('should be valid at upper bound (1.3)', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          fontScale: 1.3,
        );

        expect(settings.isFontScaleValid, true);
      });

      test('should be valid at default (1.0)', () {
        const settings = UserSettingsModel(userId: 'user-123');

        expect(settings.isFontScaleValid, true);
      });

      test('should be valid at mid-range values', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          fontScale: 1.1,
        );

        expect(settings.isFontScaleValid, true);
      });

      test('should be invalid below lower bound', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          fontScale: 0.7,
        );

        expect(settings.isFontScaleValid, false);
      });

      test('should be invalid above upper bound', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          fontScale: 1.4,
        );

        expect(settings.isFontScaleValid, false);
      });

      test('should be invalid at zero', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          fontScale: 0.0,
        );

        expect(settings.isFontScaleValid, false);
      });

      test('should be invalid at negative values', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          fontScale: -1.0,
        );

        expect(settings.isFontScaleValid, false);
      });
    });

    group('isTimerMinutesValid', () {
      test('should be valid at default (25)', () {
        const settings = UserSettingsModel(userId: 'user-123');

        expect(settings.isTimerMinutesValid, true);
      });

      test('should be valid at lower bound (1)', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          defaultTimerMinutes: 1,
        );

        expect(settings.isTimerMinutesValid, true);
      });

      test('should be valid at upper bound (180)', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          defaultTimerMinutes: 180,
        );

        expect(settings.isTimerMinutesValid, true);
      });

      test('should be valid at mid-range values', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          defaultTimerMinutes: 60,
        );

        expect(settings.isTimerMinutesValid, true);
      });

      test('should be invalid at zero', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          defaultTimerMinutes: 0,
        );

        expect(settings.isTimerMinutesValid, false);
      });

      test('should be invalid at negative values', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          defaultTimerMinutes: -10,
        );

        expect(settings.isTimerMinutesValid, false);
      });

      test('should be invalid above upper bound', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          defaultTimerMinutes: 181,
        );

        expect(settings.isTimerMinutesValid, false);
      });
    });

    group('copyWith', () {
      test('should create a new instance with updated fields', () {
        const original = UserSettingsModel(userId: 'user-123');

        final updated = original.copyWith(
          themeMode: AppThemeMode.dark,
          locale: 'en_US',
          fontScale: 1.2,
        );

        expect(updated.userId, 'user-123'); // unchanged
        expect(updated.themeMode, AppThemeMode.dark);
        expect(updated.locale, 'en_US');
        expect(updated.fontScale, 1.2);
        expect(updated.enableNotifications, true); // unchanged default
        expect(identical(original, updated), false);
      });

      test('should preserve all fields when no arguments given', () {
        final syncTime = DateTime(2024, 6, 15);
        final original = UserSettingsModel(
          userId: 'user-123',
          themeMode: AppThemeMode.dark,
          locale: 'en_US',
          fontScale: 1.1,
          enableNotifications: false,
          enableSound: false,
          enableVibration: false,
          autoSync: false,
          lastSyncTime: syncTime,
          autoRefreshTasks: false,
          defaultTimerMinutes: 45,
          enableAnalytics: true,
          enableCrashReporting: false,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
      });

      test('should allow updating userId', () {
        const original = UserSettingsModel(userId: 'user-123');

        final updated = original.copyWith(userId: 'user-456');

        expect(updated.userId, 'user-456');
      });

      test('should allow updating boolean fields', () {
        const original = UserSettingsModel(userId: 'user-123');

        final updated = original.copyWith(
          enableNotifications: false,
          enableSound: false,
          enableVibration: false,
          autoSync: false,
          autoRefreshTasks: false,
          enableAnalytics: true,
          enableCrashReporting: false,
        );

        expect(updated.enableNotifications, false);
        expect(updated.enableSound, false);
        expect(updated.enableVibration, false);
        expect(updated.autoSync, false);
        expect(updated.autoRefreshTasks, false);
        expect(updated.enableAnalytics, true);
        expect(updated.enableCrashReporting, false);
      });

      test('should allow updating lastSyncTime', () {
        const original = UserSettingsModel(userId: 'user-123');
        final newSyncTime = DateTime(2024, 7, 1, 12, 0);

        final updated = original.copyWith(lastSyncTime: newSyncTime);

        expect(updated.lastSyncTime, newSyncTime);
      });
    });

    group('JSON serialization', () {
      test('should serialize to JSON correctly', () {
        const settings = UserSettingsModel(
          userId: 'user-123',
          themeMode: AppThemeMode.dark,
          locale: 'en_US',
          fontScale: 1.2,
          enableNotifications: false,
          defaultTimerMinutes: 45,
        );

        final json = settings.toJson();

        expect(json['userId'], 'user-123');
        expect(json['themeMode'], 'dark');
        expect(json['locale'], 'en_US');
        expect(json['fontScale'], 1.2);
        expect(json['enableNotifications'], false);
        expect(json['defaultTimerMinutes'], 45);
        expect(json['lastSyncTime'], isNull);
      });

      test('should serialize lastSyncTime as ISO 8601 string', () {
        final syncTime = DateTime(2024, 6, 15, 10, 30);
        final settings = UserSettingsModel(
          userId: 'user-123',
          lastSyncTime: syncTime,
        );

        final json = settings.toJson();

        expect(json['lastSyncTime'], syncTime.toIso8601String());
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'userId': 'user-123',
          'themeMode': 'dark',
          'locale': 'en_US',
          'fontScale': 1.2,
          'enableNotifications': false,
          'enableSound': true,
          'enableVibration': true,
          'autoSync': true,
          'autoRefreshTasks': true,
          'defaultTimerMinutes': 45,
          'enableAnalytics': false,
          'enableCrashReporting': true,
        };

        final settings = UserSettingsModel.fromJson(json);

        expect(settings.userId, 'user-123');
        expect(settings.themeMode, AppThemeMode.dark);
        expect(settings.locale, 'en_US');
        expect(settings.fontScale, 1.2);
        expect(settings.enableNotifications, false);
        expect(settings.defaultTimerMinutes, 45);
        expect(settings.lastSyncTime, isNull);
      });

      test('should deserialize with lastSyncTime', () {
        final syncTime = DateTime(2024, 6, 15, 10, 30);
        final json = {
          'userId': 'user-123',
          'lastSyncTime': syncTime.toIso8601String(),
        };

        final settings = UserSettingsModel.fromJson(json);

        expect(settings.lastSyncTime, syncTime);
      });

      test('should use defaults for missing optional JSON fields', () {
        final json = {
          'userId': 'user-123',
        };

        final settings = UserSettingsModel.fromJson(json);

        expect(settings.themeMode, AppThemeMode.system);
        expect(settings.locale, 'zh_CN');
        expect(settings.fontScale, 1.0);
        expect(settings.enableNotifications, true);
        expect(settings.enableSound, true);
        expect(settings.enableVibration, true);
        expect(settings.autoSync, true);
        expect(settings.autoRefreshTasks, true);
        expect(settings.defaultTimerMinutes, 25);
        expect(settings.enableAnalytics, false);
        expect(settings.enableCrashReporting, true);
      });

      test('should survive round-trip serialization', () {
        final syncTime = DateTime(2024, 6, 15, 10, 30);
        final original = UserSettingsModel(
          userId: 'user-123',
          themeMode: AppThemeMode.light,
          locale: 'en_US',
          fontScale: 0.9,
          enableNotifications: false,
          enableSound: false,
          enableVibration: false,
          autoSync: false,
          lastSyncTime: syncTime,
          autoRefreshTasks: false,
          defaultTimerMinutes: 50,
          enableAnalytics: true,
          enableCrashReporting: false,
        );

        final json = original.toJson();
        final restored = UserSettingsModel.fromJson(json);

        expect(restored, equals(original));
      });
    });

    group('Equatable', () {
      test('should be equal when all fields are the same', () {
        const settings1 = UserSettingsModel(
          userId: 'user-123',
          themeMode: AppThemeMode.dark,
          fontScale: 1.1,
        );

        const settings2 = UserSettingsModel(
          userId: 'user-123',
          themeMode: AppThemeMode.dark,
          fontScale: 1.1,
        );

        expect(settings1, equals(settings2));
      });

      test('should not be equal when userId differs', () {
        const settings1 = UserSettingsModel(userId: 'user-123');
        const settings2 = UserSettingsModel(userId: 'user-456');

        expect(settings1, isNot(equals(settings2)));
      });

      test('should not be equal when themeMode differs', () {
        const settings1 = UserSettingsModel(
          userId: 'user-123',
          themeMode: AppThemeMode.dark,
        );

        const settings2 = UserSettingsModel(
          userId: 'user-123',
          themeMode: AppThemeMode.light,
        );

        expect(settings1, isNot(equals(settings2)));
      });

      test('should not be equal when fontScale differs', () {
        const settings1 = UserSettingsModel(
          userId: 'user-123',
          fontScale: 1.0,
        );

        const settings2 = UserSettingsModel(
          userId: 'user-123',
          fontScale: 1.2,
        );

        expect(settings1, isNot(equals(settings2)));
      });

      test('should not be equal when lastSyncTime differs', () {
        final settings1 = UserSettingsModel(
          userId: 'user-123',
          lastSyncTime: DateTime(2024, 6, 15),
        );

        final settings2 = UserSettingsModel(
          userId: 'user-123',
          lastSyncTime: DateTime(2024, 7, 1),
        );

        expect(settings1, isNot(equals(settings2)));
      });
    });
  });
}
