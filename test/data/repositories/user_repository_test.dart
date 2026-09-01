import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/repositories/user_repository.dart';
import 'package:myassistant/data/data_sources/local/dao/user_dao.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/user_settings_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'user_repository_test.mocks.dart';

@GenerateMocks([UserDao])
void main() {
  // Initialize sqflite ffi for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late UserRepository repository;
  late MockUserDao mockUserDao;

  setUp(() {
    mockUserDao = MockUserDao();
    repository = UserRepository(userDao: mockUserDao);
  });

  /// Helper to compute the expected SHA256 hash of a password
  String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Helper function to create a test user
  UserModel createTestUser({
    String id = 'user-123',
    String username = 'testuser',
    String email = 'test@example.com',
    String passwordHash = 'hashed_password',
    String? displayName,
    UserStatus status = UserStatus.active,
  }) {
    final now = DateTime.now();
    return UserModel(
      id: id,
      username: username,
      email: email,
      passwordHash: passwordHash,
      displayName: displayName,
      status: status,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
    );
  }

  // Helper function to create default statistics
  Map<String, dynamic> createDefaultStats({
    int totalGoals = 5,
    int completedGoals = 2,
    int activePlans = 3,
    int completedTasks = 10,
  }) {
    return {
      'totalGoals': totalGoals,
      'completedGoals': completedGoals,
      'activePlans': activePlans,
      'completedTasks': completedTasks,
    };
  }

  group('UserRepository - createUser', () {
    test('should create a user with SHA256 hashed password', () async {
      // Arrange
      const username = 'newuser';
      const email = 'new@example.com';
      const password = 'securePassword123';
      final expectedHash = hashPassword(password);

      when(mockUserDao.isUsernameExists(username))
          .thenAnswer((_) async => false);
      when(mockUserDao.isEmailExists(email))
          .thenAnswer((_) async => false);
      when(mockUserDao.insertUser(any)).thenAnswer((invocation) async {
        return invocation.positionalArguments[0] as UserModel;
      });
      when(mockUserDao.insertUserSettings(any)).thenAnswer((invocation) async {
        return invocation.positionalArguments[0] as UserSettingsModel;
      });

      // Act
      final result = await repository.createUser(
        username: username,
        email: email,
        password: password,
      );

      // Assert
      expect(result.username, username);
      expect(result.email, email);
      expect(result.passwordHash, expectedHash);
      expect(result.status, UserStatus.active);
      expect(result.id, isNotEmpty);
      verify(mockUserDao.insertUser(any)).called(1);
    });

    test('should create default settings for new user', () async {
      // Arrange
      when(mockUserDao.isUsernameExists(any))
          .thenAnswer((_) async => false);
      when(mockUserDao.isEmailExists(any))
          .thenAnswer((_) async => false);
      when(mockUserDao.insertUser(any)).thenAnswer((invocation) async {
        return invocation.positionalArguments[0] as UserModel;
      });
      when(mockUserDao.insertUserSettings(any)).thenAnswer((invocation) async {
        return invocation.positionalArguments[0] as UserSettingsModel;
      });

      // Act
      await repository.createUser(
        username: 'newuser',
        email: 'new@example.com',
        password: 'password',
      );

      // Assert
      verify(mockUserDao.insertUserSettings(any)).called(1);
    });

    test('should throw exception when username already exists', () async {
      // Arrange
      when(mockUserDao.isUsernameExists('existing'))
          .thenAnswer((_) async => true);

      // Act & Assert
      expect(
        () => repository.createUser(
          username: 'existing',
          email: 'new@example.com',
          password: 'password',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Username already exists'),
        )),
      );
    });

    test('should throw exception when email already exists', () async {
      // Arrange
      when(mockUserDao.isUsernameExists(any))
          .thenAnswer((_) async => false);
      when(mockUserDao.isEmailExists('existing@example.com'))
          .thenAnswer((_) async => true);

      // Act & Assert
      expect(
        () => repository.createUser(
          username: 'newuser',
          email: 'existing@example.com',
          password: 'password',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Email already exists'),
        )),
      );
    });

    test('should create user with displayName', () async {
      // Arrange
      when(mockUserDao.isUsernameExists(any))
          .thenAnswer((_) async => false);
      when(mockUserDao.isEmailExists(any))
          .thenAnswer((_) async => false);
      when(mockUserDao.insertUser(any)).thenAnswer((invocation) async {
        return invocation.positionalArguments[0] as UserModel;
      });
      when(mockUserDao.insertUserSettings(any)).thenAnswer((invocation) async {
        return invocation.positionalArguments[0] as UserSettingsModel;
      });

      // Act
      final result = await repository.createUser(
        username: 'newuser',
        email: 'new@example.com',
        password: 'password',
        displayName: 'New User',
      );

      // Assert
      expect(result.displayName, 'New User');
    });
  });

  group('UserRepository - getUserById', () {
    test('should return enriched user with statistics when found', () async {
      // Arrange
      final user = createTestUser();
      final stats = createDefaultStats();
      when(mockUserDao.getUserById('user-123'))
          .thenAnswer((_) async => user);
      when(mockUserDao.getUserStatistics('user-123'))
          .thenAnswer((_) async => stats);

      // Act
      final result = await repository.getUserById('user-123');

      // Assert
      expect(result, isNotNull);
      expect(result!.totalGoals, 5);
      expect(result.completedGoals, 2);
      expect(result.activePlans, 3);
      expect(result.completedTasks, 10);
      verify(mockUserDao.getUserStatistics('user-123')).called(1);
    });

    test('should return null when user not found', () async {
      // Arrange
      when(mockUserDao.getUserById('nonexistent'))
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.getUserById('nonexistent');

      // Assert
      expect(result, isNull);
      verifyNever(mockUserDao.getUserStatistics(any));
    });
  });

  group('UserRepository - getUserByUsername', () {
    test('should return enriched user with statistics when found', () async {
      // Arrange
      final user = createTestUser();
      final stats = createDefaultStats();
      when(mockUserDao.getUserByUsername('testuser'))
          .thenAnswer((_) async => user);
      when(mockUserDao.getUserStatistics('user-123'))
          .thenAnswer((_) async => stats);

      // Act
      final result = await repository.getUserByUsername('testuser');

      // Assert
      expect(result, isNotNull);
      expect(result!.totalGoals, 5);
      expect(result.completedGoals, 2);
    });

    test('should return null when username not found', () async {
      // Arrange
      when(mockUserDao.getUserByUsername('nonexistent'))
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.getUserByUsername('nonexistent');

      // Assert
      expect(result, isNull);
    });
  });

  group('UserRepository - getUserByEmail', () {
    test('should return enriched user with statistics when found', () async {
      // Arrange
      final user = createTestUser();
      final stats = createDefaultStats();
      when(mockUserDao.getUserByEmail('test@example.com'))
          .thenAnswer((_) async => user);
      when(mockUserDao.getUserStatistics('user-123'))
          .thenAnswer((_) async => stats);

      // Act
      final result = await repository.getUserByEmail('test@example.com');

      // Assert
      expect(result, isNotNull);
      expect(result!.activePlans, 3);
      expect(result.completedTasks, 10);
    });

    test('should return null when email not found', () async {
      // Arrange
      when(mockUserDao.getUserByEmail('nonexistent@example.com'))
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.getUserByEmail('nonexistent@example.com');

      // Assert
      expect(result, isNull);
    });
  });

  group('UserRepository - authenticate', () {
    test('should authenticate with correct credentials and return enriched user', () async {
      // Arrange
      const password = 'correctPassword';
      final expectedHash = hashPassword(password);
      final user = createTestUser(passwordHash: expectedHash);
      final stats = createDefaultStats();

      when(mockUserDao.authenticate('testuser', expectedHash))
          .thenAnswer((_) async => user);
      when(mockUserDao.getUserStatistics('user-123'))
          .thenAnswer((_) async => stats);

      // Act
      final result = await repository.authenticate('testuser', password);

      // Assert
      expect(result, isNotNull);
      expect(result!.username, 'testuser');
      expect(result.totalGoals, 5);
      verify(mockUserDao.authenticate('testuser', expectedHash)).called(1);
    });

    test('should return null for wrong password', () async {
      // Arrange
      const wrongPassword = 'wrongPassword';
      final wrongHash = hashPassword(wrongPassword);

      when(mockUserDao.authenticate('testuser', wrongHash))
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.authenticate('testuser', wrongPassword);

      // Assert
      expect(result, isNull);
    });

    test('should hash password with SHA256 before passing to DAO', () async {
      // Arrange
      const password = 'myPassword';
      final expectedHash = hashPassword(password);

      when(mockUserDao.authenticate(any, any))
          .thenAnswer((_) async => null);

      // Act
      await repository.authenticate('testuser', password);

      // Assert
      verify(mockUserDao.authenticate('testuser', expectedHash)).called(1);
    });
  });

  group('UserRepository - updateUser', () {
    test('should update user and set new updatedAt timestamp', () async {
      // Arrange
      final user = createTestUser();
      when(mockUserDao.updateUser(any)).thenAnswer((_) async => 1);

      // Act
      final result = await repository.updateUser(user);

      // Assert
      expect(result.username, user.username);
      expect(result.updatedAt.isAfter(user.updatedAt) ||
          result.updatedAt.isAtSameMomentAs(user.updatedAt), isTrue);
      verify(mockUserDao.updateUser(any)).called(1);
    });

    test('should throw exception when DAO update returns 0', () async {
      // Arrange
      final user = createTestUser();
      when(mockUserDao.updateUser(any)).thenAnswer((_) async => 0);

      // Act & Assert
      expect(
        () => repository.updateUser(user),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update user'),
        )),
      );
    });
  });

  group('UserRepository - updatePassword', () {
    test('should update password when old password matches', () async {
      // Arrange
      const oldPassword = 'oldPassword';
      const newPassword = 'newPassword';
      final oldHash = hashPassword(oldPassword);
      final newHash = hashPassword(newPassword);
      final user = createTestUser(passwordHash: oldHash);

      when(mockUserDao.getUserById('user-123'))
          .thenAnswer((_) async => user);
      when(mockUserDao.updatePassword('user-123', newHash))
          .thenAnswer((_) async => 1);

      // Act
      final result = await repository.updatePassword('user-123', oldPassword, newPassword);

      // Assert
      expect(result, true);
      verify(mockUserDao.updatePassword('user-123', newHash)).called(1);
    });

    test('should return false when old password does not match', () async {
      // Arrange
      const correctOldPassword = 'correctOld';
      const wrongOldPassword = 'wrongOld';
      final correctHash = hashPassword(correctOldPassword);
      final user = createTestUser(passwordHash: correctHash);

      when(mockUserDao.getUserById('user-123'))
          .thenAnswer((_) async => user);

      // Act
      final result = await repository.updatePassword('user-123', wrongOldPassword, 'newPassword');

      // Assert
      expect(result, false);
      verifyNever(mockUserDao.updatePassword(any, any));
    });

    test('should return false when user not found', () async {
      // Arrange
      when(mockUserDao.getUserById('nonexistent'))
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.updatePassword('nonexistent', 'old', 'new');

      // Assert
      expect(result, false);
      verifyNever(mockUserDao.updatePassword(any, any));
    });

    test('should return false when DAO updatePassword returns 0', () async {
      // Arrange
      const oldPassword = 'oldPassword';
      const newPassword = 'newPassword';
      final oldHash = hashPassword(oldPassword);
      final newHash = hashPassword(newPassword);
      final user = createTestUser(passwordHash: oldHash);

      when(mockUserDao.getUserById('user-123'))
          .thenAnswer((_) async => user);
      when(mockUserDao.updatePassword('user-123', newHash))
          .thenAnswer((_) async => 0);

      // Act
      final result = await repository.updatePassword('user-123', oldPassword, newPassword);

      // Assert
      expect(result, false);
    });

    test('should hash new password with SHA256', () async {
      // Arrange
      const oldPassword = 'oldPassword';
      const newPassword = 'newPassword';
      final oldHash = hashPassword(oldPassword);
      final expectedNewHash = hashPassword(newPassword);
      final user = createTestUser(passwordHash: oldHash);

      when(mockUserDao.getUserById('user-123'))
          .thenAnswer((_) async => user);
      when(mockUserDao.updatePassword(any, any))
          .thenAnswer((_) async => 1);

      // Act
      await repository.updatePassword('user-123', oldPassword, newPassword);

      // Assert
      verify(mockUserDao.updatePassword('user-123', expectedNewHash)).called(1);
    });
  });

  group('UserRepository - updateUserSettings', () {
    test('should update settings when valid', () async {
      // Arrange
      final settings = UserSettingsModel.defaultSettings('user-123');
      when(mockUserDao.updateUserSettings(any)).thenAnswer((_) async => 1);

      // Act
      final result = await repository.updateUserSettings(settings);

      // Assert
      expect(result, settings);
      verify(mockUserDao.updateUserSettings(any)).called(1);
    });

    test('should throw exception for invalid font scale (too low)', () async {
      // Arrange
      final settings = UserSettingsModel(
        userId: 'user-123',
        fontScale: 0.5, // below 0.8 minimum
      );

      // Act & Assert
      expect(
        () => repository.updateUserSettings(settings),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid font scale'),
        )),
      );
    });

    test('should throw exception for invalid font scale (too high)', () async {
      // Arrange
      final settings = UserSettingsModel(
        userId: 'user-123',
        fontScale: 1.5, // above 1.3 maximum
      );

      // Act & Assert
      expect(
        () => repository.updateUserSettings(settings),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid font scale'),
        )),
      );
    });

    test('should throw exception for invalid timer minutes (zero)', () async {
      // Arrange
      final settings = UserSettingsModel(
        userId: 'user-123',
        defaultTimerMinutes: 0,
      );

      // Act & Assert
      expect(
        () => repository.updateUserSettings(settings),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid timer minutes'),
        )),
      );
    });

    test('should throw exception for invalid timer minutes (too high)', () async {
      // Arrange
      final settings = UserSettingsModel(
        userId: 'user-123',
        defaultTimerMinutes: 200, // above 180 maximum
      );

      // Act & Assert
      expect(
        () => repository.updateUserSettings(settings),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid timer minutes'),
        )),
      );
    });

    test('should fall back to insert when update returns 0', () async {
      // Arrange
      final settings = UserSettingsModel.defaultSettings('user-123');
      when(mockUserDao.updateUserSettings(any)).thenAnswer((_) async => 0);
      when(mockUserDao.insertUserSettings(any)).thenAnswer((invocation) async {
        return invocation.positionalArguments[0] as UserSettingsModel;
      });

      // Act
      final result = await repository.updateUserSettings(settings);

      // Assert
      expect(result, settings);
      verify(mockUserDao.updateUserSettings(any)).called(1);
      verify(mockUserDao.insertUserSettings(any)).called(1);
    });

    test('should not insert when update succeeds', () async {
      // Arrange
      final settings = UserSettingsModel.defaultSettings('user-123');
      when(mockUserDao.updateUserSettings(any)).thenAnswer((_) async => 1);

      // Act
      await repository.updateUserSettings(settings);

      // Assert
      verify(mockUserDao.updateUserSettings(any)).called(1);
      verifyNever(mockUserDao.insertUserSettings(any));
    });

    test('should accept valid boundary font scale values', () async {
      // Arrange - test lower boundary
      final settingsLow = UserSettingsModel(
        userId: 'user-123',
        fontScale: 0.8,
      );
      when(mockUserDao.updateUserSettings(any)).thenAnswer((_) async => 1);

      // Act
      final resultLow = await repository.updateUserSettings(settingsLow);

      // Assert
      expect(resultLow.fontScale, 0.8);

      // Arrange - test upper boundary
      final settingsHigh = UserSettingsModel(
        userId: 'user-123',
        fontScale: 1.3,
      );

      // Act
      final resultHigh = await repository.updateUserSettings(settingsHigh);

      // Assert
      expect(resultHigh.fontScale, 1.3);
    });

    test('should accept valid boundary timer minutes', () async {
      // Arrange - test lower boundary
      final settingsMin = UserSettingsModel(
        userId: 'user-123',
        defaultTimerMinutes: 1,
      );
      when(mockUserDao.updateUserSettings(any)).thenAnswer((_) async => 1);

      // Act
      final resultMin = await repository.updateUserSettings(settingsMin);

      // Assert
      expect(resultMin.defaultTimerMinutes, 1);

      // Arrange - test upper boundary
      final settingsMax = UserSettingsModel(
        userId: 'user-123',
        defaultTimerMinutes: 180,
      );

      // Act
      final resultMax = await repository.updateUserSettings(settingsMax);

      // Assert
      expect(resultMax.defaultTimerMinutes, 180);
    });
  });

  group('UserRepository - createDefaultSettings', () {
    test('should create default settings for user', () async {
      // Arrange
      when(mockUserDao.insertUserSettings(any)).thenAnswer((invocation) async {
        return invocation.positionalArguments[0] as UserSettingsModel;
      });

      // Act
      final result = await repository.createDefaultSettings('user-123');

      // Assert
      expect(result.userId, 'user-123');
      expect(result.themeMode, AppThemeMode.system);
      expect(result.locale, 'zh_CN');
      expect(result.fontScale, 1.0);
      expect(result.enableNotifications, true);
      expect(result.defaultTimerMinutes, 25);
      verify(mockUserDao.insertUserSettings(any)).called(1);
    });
  });

  group('UserRepository - deleteUser', () {
    test('should return true when soft delete succeeds', () async {
      // Arrange
      when(mockUserDao.deleteUser('user-123')).thenAnswer((_) async => 1);

      // Act
      final result = await repository.deleteUser('user-123');

      // Assert
      expect(result, true);
      verify(mockUserDao.deleteUser('user-123')).called(1);
    });

    test('should return false when soft delete affects no rows', () async {
      // Arrange
      when(mockUserDao.deleteUser('nonexistent')).thenAnswer((_) async => 0);

      // Act
      final result = await repository.deleteUser('nonexistent');

      // Assert
      expect(result, false);
    });
  });

  group('UserRepository - delegate methods', () {
    test('getUserSettings should delegate to DAO', () async {
      // Arrange
      final settings = UserSettingsModel.defaultSettings('user-123');
      when(mockUserDao.getUserSettings('user-123'))
          .thenAnswer((_) async => settings);

      // Act
      final result = await repository.getUserSettings('user-123');

      // Assert
      expect(result, settings);
    });

    test('getUserStatistics should delegate to DAO', () async {
      // Arrange
      final stats = createDefaultStats();
      when(mockUserDao.getUserStatistics('user-123'))
          .thenAnswer((_) async => stats);

      // Act
      final result = await repository.getUserStatistics('user-123');

      // Assert
      expect(result, stats);
    });

    test('isUsernameExists should delegate to DAO', () async {
      // Arrange
      when(mockUserDao.isUsernameExists('existing'))
          .thenAnswer((_) async => true);
      when(mockUserDao.isUsernameExists('new'))
          .thenAnswer((_) async => false);

      // Act & Assert
      expect(await repository.isUsernameExists('existing'), true);
      expect(await repository.isUsernameExists('new'), false);
    });

    test('isEmailExists should delegate to DAO', () async {
      // Arrange
      when(mockUserDao.isEmailExists('existing@example.com'))
          .thenAnswer((_) async => true);
      when(mockUserDao.isEmailExists('new@example.com'))
          .thenAnswer((_) async => false);

      // Act & Assert
      expect(await repository.isEmailExists('existing@example.com'), true);
      expect(await repository.isEmailExists('new@example.com'), false);
    });
  });
}
