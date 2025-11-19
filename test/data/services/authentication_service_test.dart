import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/services/authentication_service.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/user_settings_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/domain/repositories/i_user_repository.dart';
import 'package:myassistant/core/errors/exceptions.dart';

import 'authentication_service_test.mocks.dart';

@GenerateMocks([IUserRepository])
void main() {
  late AuthenticationService authService;
  late MockIUserRepository mockUserRepository;

  setUp(() {
    mockUserRepository = MockIUserRepository();
    authService = AuthenticationService(
      userRepository: mockUserRepository,
    );
  });

  final testUser = UserModel(
    id: 'user-123',
    username: 'testuser',
    email: 'test@example.com',
    passwordHash: 'hashed_password',
    displayName: 'Test User',
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    status: UserStatus.active,
  );

  group('AuthenticationService', () {
    group('signUp', () {
      test('should successfully create a new user', () async {
        // Arrange
        when(mockUserRepository.getUserByUsername('testuser'))
            .thenAnswer((_) async => null);
        when(mockUserRepository.getUserByEmail('test@example.com'))
            .thenAnswer((_) async => null);
        when(mockUserRepository.createUser(
          username: anyNamed('username'),
          password: anyNamed('password'),
          email: anyNamed('email'),
          displayName: anyNamed('displayName'),
        )).thenAnswer((_) async => testUser);
        when(mockUserRepository.createDefaultSettings(any))
            .thenAnswer((_) async => UserSettingsModel(userId: testUser.id));

        // Act
        final result = await authService.signUp(
          username: 'testuser',
          password: 'Password123',
          email: 'test@example.com',
          displayName: 'Test User',
        );

        // Assert
        expect(result.success, true);
        expect(result.user, testUser);
        expect(result.token, isNotNull);
        expect(authService.isAuthenticated, true);
        expect(authService.currentUser, testUser);
      });

      test('should fail if username already exists', () async {
        // Arrange
        when(mockUserRepository.getUserByUsername('testuser'))
            .thenAnswer((_) async => testUser);

        // Act
        final result = await authService.signUp(
          username: 'testuser',
          password: 'Password123',
          email: 'new@example.com',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, 'Username already exists');
        expect(authService.isAuthenticated, false);
      });

      test('should fail if email already exists', () async {
        // Arrange
        when(mockUserRepository.getUserByUsername('newuser'))
            .thenAnswer((_) async => null);
        when(mockUserRepository.getUserByEmail('test@example.com'))
            .thenAnswer((_) async => testUser);

        // Act
        final result = await authService.signUp(
          username: 'newuser',
          password: 'Password123',
          email: 'test@example.com',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, 'Email already registered');
      });

      test('should validate username format', () async {
        // Test short username
        final shortResult = await authService.signUp(
          username: 'ab',
          password: 'Password123',
          email: 'test@example.com',
        );
        expect(shortResult.success, false);
        expect(shortResult.error, contains('at least 3 characters'));

        // Test long username
        final longResult = await authService.signUp(
          username: 'a' * 21,
          password: 'Password123',
          email: 'test@example.com',
        );
        expect(longResult.success, false);
        expect(longResult.error, contains('less than 20 characters'));

        // Test invalid characters
        final invalidResult = await authService.signUp(
          username: 'test user',
          password: 'Password123',
          email: 'test@example.com',
        );
        expect(invalidResult.success, false);
        expect(invalidResult.error, contains('letters, numbers, and underscore'));
      });

      test('should validate password requirements', () async {
        // Test short password
        final shortResult = await authService.signUp(
          username: 'testuser',
          password: 'Pass1',
          email: 'test@example.com',
        );
        expect(shortResult.success, false);
        expect(shortResult.error, contains('at least 8 characters'));

        // Test missing uppercase
        final noUpperResult = await authService.signUp(
          username: 'testuser',
          password: 'password123',
          email: 'test@example.com',
        );
        expect(noUpperResult.success, false);

        // Test missing lowercase
        final noLowerResult = await authService.signUp(
          username: 'testuser',
          password: 'PASSWORD123',
          email: 'test@example.com',
        );
        expect(noLowerResult.success, false);

        // Test missing number
        final noNumberResult = await authService.signUp(
          username: 'testuser',
          password: 'Password',
          email: 'test@example.com',
        );
        expect(noNumberResult.success, false);
      });

      test('should validate email format', () async {
        final invalidEmails = [
          'notanemail',
          '@example.com',
          'test@',
          'test@.com',
          'test..test@example.com',
        ];

        for (final email in invalidEmails) {
          final result = await authService.signUp(
            username: 'testuser',
            password: 'Password123',
            email: email,
          );
          expect(result.success, false);
          expect(result.error, contains('Invalid email'));
        }
      });
    });

    group('signIn', () {
      test('should successfully sign in with valid credentials', () async {
        // Arrange
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((_) async => testUser);

        // Act
        final result = await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Assert
        expect(result.success, true);
        expect(result.user, testUser);
        expect(result.token, isNotNull);
        expect(authService.isAuthenticated, true);
        expect(authService.currentUser, testUser);
      });

      test('should fail with invalid credentials', () async {
        // Arrange
        when(mockUserRepository.authenticate('testuser', 'WrongPassword'))
            .thenAnswer((_) async => null);

        // Act
        final result = await authService.signIn(
          username: 'testuser',
          password: 'WrongPassword',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, 'Invalid username or password');
        expect(authService.isAuthenticated, false);
      });

      test('should fail if user is deactivated', () async {
        // Arrange
        final deactivatedUser = testUser.copyWith(
          status: UserStatus.deactivated,
        );
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => deactivatedUser);

        // Act
        final result = await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, 'Account is deactivated');
        expect(authService.isAuthenticated, false);
      });

      test('should require username and password', () async {
        // Test empty username
        final emptyUsernameResult = await authService.signIn(
          username: '',
          password: 'Password123',
        );
        expect(emptyUsernameResult.success, false);
        expect(emptyUsernameResult.error, 'Username and password are required');

        // Test empty password
        final emptyPasswordResult = await authService.signIn(
          username: 'testuser',
          password: '',
        );
        expect(emptyPasswordResult.success, false);
        expect(emptyPasswordResult.error, 'Username and password are required');
      });
    });

    group('signOut', () {
      test('should clear session on sign out', () async {
        // Arrange - sign in first
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((_) async => testUser);

        await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );
        expect(authService.isAuthenticated, true);

        // Act
        await authService.signOut();

        // Assert
        expect(authService.isAuthenticated, false);
        expect(authService.currentUser, null);
      });
    });

    group('session management', () {
      test('should refresh session activity', () async {
        // Arrange - sign in first
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((_) async => testUser);

        await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Act
        authService.refreshSession();

        // Assert
        expect(authService.isAuthenticated, true);
        expect(authService.isSessionExpired, false);
      });

      test('should get session info for authenticated user', () async {
        // Arrange
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((_) async => testUser);

        await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Act
        final sessionInfo = authService.getSessionInfo();

        // Assert
        expect(sessionInfo, isNotNull);
        expect(sessionInfo!.userId, testUser.id);
        expect(sessionInfo.username, testUser.username);
        expect(sessionInfo.isActive, true);
        expect(sessionInfo.loginTime, isNotNull);
      });

      test('should return null session info when not authenticated', () {
        // Act
        final sessionInfo = authService.getSessionInfo();

        // Assert
        expect(sessionInfo, null);
      });
    });

    group('changePassword', () {
      test('should successfully change password', () async {
        // Arrange
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updatePassword(
          testUser.id,
          'Password123',
          'NewPassword123',
        )).thenAnswer((_) async => true);

        await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Act
        final result = await authService.changePassword(
          userId: testUser.id,
          currentPassword: 'Password123',
          newPassword: 'NewPassword123',
        );

        // Assert
        expect(result, true);
      });

      test('should fail if not authenticated', () async {
        // Act & Assert
        expect(
          () => authService.changePassword(
            userId: 'user-123',
            currentPassword: 'Password123',
            newPassword: 'NewPassword123',
          ),
          throwsA(isA<PermissionException>()),
        );
      });

      test('should validate new password requirements', () async {
        // Arrange
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((_) async => testUser);

        await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Act & Assert
        expect(
          () => authService.changePassword(
            userId: testUser.id,
            currentPassword: 'Password123',
            newPassword: 'weak',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should fail with incorrect current password', () async {
        // Arrange
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updatePassword(
          testUser.id,
          'WrongPassword',
          'NewPassword123',
        )).thenAnswer((_) async => false);

        await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Act & Assert
        expect(
          () => authService.changePassword(
            userId: testUser.id,
            currentPassword: 'WrongPassword',
            newPassword: 'NewPassword123',
          ),
          throwsA(isA<AuthenticationException>()),
        );
      });
    });

    group('updateProfile', () {
      test('should successfully update profile', () async {
        // Arrange
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((invocation) async {
          final user = invocation.positionalArguments[0] as UserModel;
          return user;
        });
        when(mockUserRepository.getUserById(testUser.id))
            .thenAnswer((_) async => testUser);

        await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Act
        final updatedUser = await authService.updateProfile(
          userId: testUser.id,
          displayName: 'New Display Name',
          avatarUrl: 'https://example.com/avatar.jpg',
        );

        // Assert
        expect(updatedUser.displayName, 'New Display Name');
        expect(updatedUser.avatarUrl, 'https://example.com/avatar.jpg');
      });

      test('should validate email when updating', () async {
        // Arrange
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((invocation) async => testUser);
        when(mockUserRepository.getUserById(testUser.id))
            .thenAnswer((_) async => testUser);

        await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Act & Assert
        expect(
          () => authService.updateProfile(
            userId: testUser.id,
            email: 'invalid-email',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should check for duplicate email', () async {
        // Arrange
        final otherUser = testUser.copyWith(
          id: 'other-user',
          email: 'taken@example.com',
        );
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((invocation) async => testUser);
        when(mockUserRepository.getUserById(testUser.id))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.getUserByEmail('taken@example.com'))
            .thenAnswer((_) async => otherUser);

        await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Act & Assert
        expect(
          () => authService.updateProfile(
            userId: testUser.id,
            email: 'taken@example.com',
          ),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('deactivateAccount', () {
      test('should successfully deactivate account', () async {
        // Arrange
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.deleteUser(testUser.id))
            .thenAnswer((_) async => true);

        await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Act
        final result = await authService.deactivateAccount(
          userId: testUser.id,
          password: 'Password123',
        );

        // Assert
        expect(result, true);
        expect(authService.isAuthenticated, false);
      });

      test('should require correct password to deactivate', () async {
        // Arrange
        when(mockUserRepository.authenticate('testuser', 'Password123'))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.updateUser(any))
            .thenAnswer((_) async => testUser);
        when(mockUserRepository.authenticate('testuser', 'WrongPassword'))
            .thenAnswer((_) async => null);

        await authService.signIn(
          username: 'testuser',
          password: 'Password123',
        );

        // Act & Assert
        expect(
          () => authService.deactivateAccount(
            userId: testUser.id,
            password: 'WrongPassword',
          ),
          throwsA(isA<AuthenticationException>()),
        );
      });
    });
  });
}