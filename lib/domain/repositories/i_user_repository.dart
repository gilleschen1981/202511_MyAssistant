import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/user_settings_model.dart';

/// User repository interface
abstract class IUserRepository {
  /// Create a new user
  Future<UserModel> createUser({
    required String username,
    required String email,
    required String password,
    String? displayName,
  });

  /// Get user by ID
  Future<UserModel?> getUserById(String userId);

  /// Get user by username
  Future<UserModel?> getUserByUsername(String username);

  /// Get user by email
  Future<UserModel?> getUserByEmail(String email);

  /// Authenticate user
  Future<UserModel?> authenticate(String username, String password);

  /// Update user profile
  Future<UserModel> updateUser(UserModel user);

  /// Update password
  Future<bool> updatePassword(String userId, String oldPassword, String newPassword);

  /// Get user settings
  Future<UserSettingsModel?> getUserSettings(String userId);

  /// Update user settings
  Future<UserSettingsModel> updateUserSettings(UserSettingsModel settings);

  /// Create default settings for new user
  Future<UserSettingsModel> createDefaultSettings(String userId);

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStatistics(String userId);

  /// Delete user (soft delete)
  Future<bool> deleteUser(String userId);

  /// Check if username exists
  Future<bool> isUsernameExists(String username);

  /// Check if email exists
  Future<bool> isEmailExists(String email);
}