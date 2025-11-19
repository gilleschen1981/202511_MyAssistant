import 'package:sqflite/sqflite.dart';
import 'package:myassistant/data/data_sources/local/database/app_database.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/user_settings_model.dart';
import 'package:myassistant/data/models/enums/status.dart';

/// User Data Access Object
class UserDao {
  static const String _tableUsers = 'users';
  static const String _tableUserSettings = 'user_settings';

  final AppDatabase _database = AppDatabase.instance;

  /// Insert user
  Future<UserModel> insertUser(UserModel user) async {
    final db = await _database.database;
    final userMap = user.toJson();

    // Convert DateTime to timestamp
    userMap['created_at'] = AppDatabase.dateTimeToTimestamp(user.createdAt);
    userMap['updated_at'] = AppDatabase.dateTimeToTimestamp(user.updatedAt);
    userMap['status'] = user.status.toDbString();

    await db.insert(
      _tableUsers,
      userMap,
      conflictAlgorithm: ConflictAlgorithm.fail,
    );

    return user;
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableUsers,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [userId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return _mapToUser(maps.first);
  }

  /// Get user by username
  Future<UserModel?> getUserByUsername(String username) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableUsers,
      where: 'username = ? AND deleted_at IS NULL',
      whereArgs: [username],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return _mapToUser(maps.first);
  }

  /// Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableUsers,
      where: 'email = ? AND deleted_at IS NULL',
      whereArgs: [email],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return _mapToUser(maps.first);
  }

  /// Authenticate user
  Future<UserModel?> authenticate(String username, String passwordHash) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableUsers,
      where: '(username = ? OR email = ?) AND password_hash = ? AND deleted_at IS NULL',
      whereArgs: [username, username, passwordHash],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return _mapToUser(maps.first);
  }

  /// Update user
  Future<int> updateUser(UserModel user) async {
    final db = await _database.database;
    final userMap = user.toJson();

    userMap['updated_at'] = AppDatabase.getCurrentTimestamp();
    userMap['status'] = user.status.toDbString();

    // Remove computed fields
    userMap.remove('totalGoals');
    userMap.remove('completedGoals');
    userMap.remove('activePlans');
    userMap.remove('completedTasks');

    return await db.update(
      _tableUsers,
      userMap,
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// Update password
  Future<int> updatePassword(String userId, String newPasswordHash) async {
    final db = await _database.database;
    return await db.update(
      _tableUsers,
      {
        'password_hash': newPasswordHash,
        'updated_at': AppDatabase.getCurrentTimestamp(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Soft delete user
  Future<int> deleteUser(String userId) async {
    final db = await _database.database;
    return await db.update(
      _tableUsers,
      {
        'deleted_at': AppDatabase.getCurrentTimestamp(),
        'updated_at': AppDatabase.getCurrentTimestamp(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Check if username exists
  Future<bool> isUsernameExists(String username) async {
    final db = await _database.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $_tableUsers WHERE username = ? AND deleted_at IS NULL',
      [username],
    ));
    return count != null && count > 0;
  }

  /// Check if email exists
  Future<bool> isEmailExists(String email) async {
    final db = await _database.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $_tableUsers WHERE email = ? AND deleted_at IS NULL',
      [email],
    ));
    return count != null && count > 0;
  }

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    final db = await _database.database;

    // Get goal statistics
    final goalStats = await db.rawQuery('''
      SELECT
        COUNT(*) as total_goals,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_goals
      FROM goals
      WHERE user_id = ? AND deleted_at IS NULL
    ''', [userId]);

    // Get plan statistics
    final planStats = await db.rawQuery('''
      SELECT
        COUNT(*) as active_plans
      FROM plans
      WHERE user_id = ?
        AND deleted_at IS NULL
        AND datetime('now') BETWEEN datetime(start_date, 'unixepoch')
                                 AND datetime(end_date, 'unixepoch')
    ''', [userId]);

    // Get task statistics
    final taskStats = await db.rawQuery('''
      SELECT
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_tasks
      FROM tasks
      WHERE user_id = ?
    ''', [userId]);

    return {
      'totalGoals': goalStats.first['total_goals'] ?? 0,
      'completedGoals': goalStats.first['completed_goals'] ?? 0,
      'activePlans': planStats.first['active_plans'] ?? 0,
      'completedTasks': taskStats.first['completed_tasks'] ?? 0,
    };
  }

  // User Settings Methods

  /// Insert user settings
  Future<UserSettingsModel> insertUserSettings(UserSettingsModel settings) async {
    final db = await _database.database;
    final settingsMap = settings.toJson();

    // Convert enums
    settingsMap['theme_mode'] = settings.themeMode.toDbString();

    // Convert DateTime to timestamp
    if (settings.lastSyncTime != null) {
      settingsMap['last_sync_time'] = AppDatabase.dateTimeToTimestamp(settings.lastSyncTime!);
    }

    // Convert booleans to integers
    settingsMap['enable_notifications'] = settings.enableNotifications ? 1 : 0;
    settingsMap['enable_sound'] = settings.enableSound ? 1 : 0;
    settingsMap['enable_vibration'] = settings.enableVibration ? 1 : 0;
    settingsMap['auto_sync'] = settings.autoSync ? 1 : 0;
    settingsMap['auto_refresh_tasks'] = settings.autoRefreshTasks ? 1 : 0;
    settingsMap['enable_analytics'] = settings.enableAnalytics ? 1 : 0;
    settingsMap['enable_crash_reporting'] = settings.enableCrashReporting ? 1 : 0;

    await db.insert(
      _tableUserSettings,
      settingsMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return settings;
  }

  /// Get user settings
  Future<UserSettingsModel?> getUserSettings(String userId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableUserSettings,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return _mapToUserSettings(maps.first);
  }

  /// Update user settings
  Future<int> updateUserSettings(UserSettingsModel settings) async {
    final db = await _database.database;
    final settingsMap = settings.toJson();

    // Convert enums
    settingsMap['theme_mode'] = settings.themeMode.toDbString();

    // Convert DateTime to timestamp
    if (settings.lastSyncTime != null) {
      settingsMap['last_sync_time'] = AppDatabase.dateTimeToTimestamp(settings.lastSyncTime!);
    }

    // Convert booleans to integers
    settingsMap['enable_notifications'] = settings.enableNotifications ? 1 : 0;
    settingsMap['enable_sound'] = settings.enableSound ? 1 : 0;
    settingsMap['enable_vibration'] = settings.enableVibration ? 1 : 0;
    settingsMap['auto_sync'] = settings.autoSync ? 1 : 0;
    settingsMap['auto_refresh_tasks'] = settings.autoRefreshTasks ? 1 : 0;
    settingsMap['enable_analytics'] = settings.enableAnalytics ? 1 : 0;
    settingsMap['enable_crash_reporting'] = settings.enableCrashReporting ? 1 : 0;

    return await db.update(
      _tableUserSettings,
      settingsMap,
      where: 'user_id = ?',
      whereArgs: [settings.userId],
    );
  }

  /// Convert map to UserModel
  UserModel _mapToUser(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      status: UserStatus.fromString(map['status'] as String),
      createdAt: AppDatabase.timestampToDateTime(map['created_at'] as int),
      updatedAt: AppDatabase.timestampToDateTime(map['updated_at'] as int),
    );
  }

  /// Convert map to UserSettingsModel
  UserSettingsModel _mapToUserSettings(Map<String, dynamic> map) {
    return UserSettingsModel(
      userId: map['user_id'] as String,
      themeMode: AppThemeMode.fromString(map['theme_mode'] as String),
      locale: map['locale'] as String,
      fontScale: map['font_scale'] as double,
      enableNotifications: map['enable_notifications'] == 1,
      enableSound: map['enable_sound'] == 1,
      enableVibration: map['enable_vibration'] == 1,
      autoSync: map['auto_sync'] == 1,
      lastSyncTime: map['last_sync_time'] != null
          ? AppDatabase.timestampToDateTime(map['last_sync_time'] as int)
          : null,
      autoRefreshTasks: map['auto_refresh_tasks'] == 1,
      defaultTimerMinutes: map['default_timer_minutes'] as int,
      enableAnalytics: (map['enable_analytics'] ?? 0) == 1,
      enableCrashReporting: (map['enable_crash_reporting'] ?? 1) == 1,
    );
  }
}