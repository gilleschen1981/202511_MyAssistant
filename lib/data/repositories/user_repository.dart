import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:myassistant/data/data_sources/local/dao/user_dao.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/user_settings_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/domain/repositories/i_user_repository.dart';

/// User repository implementation
class UserRepository implements IUserRepository {
  final UserDao _userDao;
  final _uuid = const Uuid();

  UserRepository({UserDao? userDao}) : _userDao = userDao ?? UserDao();

  /// Hash password using SHA256 (in production, use bcrypt or similar)
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Future<UserModel> createUser({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    // Check if username or email already exists
    if (await _userDao.isUsernameExists(username)) {
      throw Exception('Username already exists');
    }
    if (await _userDao.isEmailExists(email)) {
      throw Exception('Email already exists');
    }

    final now = DateTime.now();
    final user = UserModel(
      id: _uuid.v4(),
      username: username,
      email: email,
      passwordHash: _hashPassword(password),
      displayName: displayName,
      status: UserStatus.active,
      createdAt: now,
      updatedAt: now,
    );

    final createdUser = await _userDao.insertUser(user);

    // Create default settings for the new user
    await createDefaultSettings(createdUser.id);

    return createdUser;
  }

  @override
  Future<UserModel?> getUserById(String userId) async {
    final user = await _userDao.getUserById(userId);
    if (user == null) return null;

    // Get statistics and return enriched user
    final stats = await getUserStatistics(userId);
    return user.copyWith(
      totalGoals: stats['totalGoals'] as int,
      completedGoals: stats['completedGoals'] as int,
      activePlans: stats['activePlans'] as int,
      completedTasks: stats['completedTasks'] as int,
    );
  }

  @override
  Future<UserModel?> getUserByUsername(String username) async {
    final user = await _userDao.getUserByUsername(username);
    if (user == null) return null;

    // Get statistics and return enriched user
    final stats = await getUserStatistics(user.id);
    return user.copyWith(
      totalGoals: stats['totalGoals'] as int,
      completedGoals: stats['completedGoals'] as int,
      activePlans: stats['activePlans'] as int,
      completedTasks: stats['completedTasks'] as int,
    );
  }

  @override
  Future<UserModel?> getUserByEmail(String email) async {
    final user = await _userDao.getUserByEmail(email);
    if (user == null) return null;

    // Get statistics and return enriched user
    final stats = await getUserStatistics(user.id);
    return user.copyWith(
      totalGoals: stats['totalGoals'] as int,
      completedGoals: stats['completedGoals'] as int,
      activePlans: stats['activePlans'] as int,
      completedTasks: stats['completedTasks'] as int,
    );
  }

  @override
  Future<UserModel?> authenticate(String username, String password) async {
    final passwordHash = _hashPassword(password);
    final user = await _userDao.authenticate(username, passwordHash);
    if (user == null) return null;

    // Get statistics and return enriched user
    final stats = await getUserStatistics(user.id);
    return user.copyWith(
      totalGoals: stats['totalGoals'] as int,
      completedGoals: stats['completedGoals'] as int,
      activePlans: stats['activePlans'] as int,
      completedTasks: stats['completedTasks'] as int,
    );
  }

  @override
  Future<UserModel> updateUser(UserModel user) async {
    final updatedUser = user.copyWith(
      updatedAt: DateTime.now(),
    );

    final result = await _userDao.updateUser(updatedUser);
    if (result == 0) {
      throw Exception('Failed to update user');
    }

    return updatedUser;
  }

  @override
  Future<bool> updatePassword(String userId, String oldPassword, String newPassword) async {
    // Verify old password first
    final user = await _userDao.getUserById(userId);
    if (user == null) return false;

    final oldPasswordHash = _hashPassword(oldPassword);
    if (user.passwordHash != oldPasswordHash) {
      return false; // Old password doesn't match
    }

    // Update to new password
    final newPasswordHash = _hashPassword(newPassword);
    final result = await _userDao.updatePassword(userId, newPasswordHash);
    return result > 0;
  }

  @override
  Future<UserSettingsModel?> getUserSettings(String userId) async {
    return await _userDao.getUserSettings(userId);
  }

  @override
  Future<UserSettingsModel> updateUserSettings(UserSettingsModel settings) async {
    // Validate settings
    if (!settings.isFontScaleValid) {
      throw Exception('Invalid font scale: ${settings.fontScale}');
    }
    if (!settings.isTimerMinutesValid) {
      throw Exception('Invalid timer minutes: ${settings.defaultTimerMinutes}');
    }

    final result = await _userDao.updateUserSettings(settings);
    if (result == 0) {
      // If update failed, it might be because settings don't exist yet
      await _userDao.insertUserSettings(settings);
    }

    return settings;
  }

  @override
  Future<UserSettingsModel> createDefaultSettings(String userId) async {
    final settings = UserSettingsModel.defaultSettings(userId);
    await _userDao.insertUserSettings(settings);
    return settings;
  }

  @override
  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    return await _userDao.getUserStatistics(userId);
  }

  @override
  Future<bool> deleteUser(String userId) async {
    final result = await _userDao.deleteUser(userId);
    return result > 0;
  }

  @override
  Future<bool> isUsernameExists(String username) async {
    return await _userDao.isUsernameExists(username);
  }

  @override
  Future<bool> isEmailExists(String email) async {
    return await _userDao.isEmailExists(email);
  }
}