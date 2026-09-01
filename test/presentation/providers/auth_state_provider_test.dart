import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/services/authentication_service.dart';

import 'auth_state_provider_test.mocks.dart';

@GenerateMocks([AuthenticationService])
void main() {
  late MockAuthenticationService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthenticationService();
  });

  /// Helper to create a test user
  UserModel createTestUser({String id = 'test-user-123'}) {
    final now = DateTime.now();
    return UserModel(
      id: id,
      username: 'testuser',
      email: 'test@example.com',
      passwordHash: 'test-hash',
      displayName: 'Test User',
      status: UserStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('AuthState', () {
    test('initial state should be unauthenticated and not loading', () {
      final state = AuthState.initial();

      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.user, isNull);
      expect(state.error, isNull);
    });

    test('copyWith should create a new state with updated values', () {
      final initial = AuthState.initial();
      final user = createTestUser();

      final updated = initial.copyWith(
        isAuthenticated: true,
        isLoading: false,
        user: user,
      );

      expect(updated.isAuthenticated, isTrue);
      expect(updated.isLoading, isFalse);
      expect(updated.user, equals(user));
      expect(updated.error, isNull);
    });

    test('copyWith with error should clear error when null passed', () {
      final stateWithError = const AuthState(
        isAuthenticated: false,
        isLoading: false,
        error: 'Some error',
      );

      // error parameter defaults to null in copyWith, which clears it
      final cleared = stateWithError.copyWith(isLoading: true);

      expect(cleared.error, isNull);
    });
  });

  group('AuthStateNotifier - signIn', () {
    test('should set loading state before sign in attempt', () async {
      final testUser = createTestUser();
      when(mockAuthService.signIn(
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => AuthResult(
            success: true,
            user: testUser,
          ));

      final notifier = AuthStateNotifier(mockAuthService);

      // Capture state transitions (addListener fires immediately with current state)
      final states = <AuthState>[];
      notifier.addListener((state) {
        states.add(state);
      });

      await notifier.signIn(username: 'testuser', password: 'password');

      // states[0] = initial state (fireImmediately), states[1] = loading
      expect(states[1].isLoading, isTrue);
      expect(states[1].error, isNull);
    });

    test('should set authenticated state on successful sign in', () async {
      final testUser = createTestUser();
      when(mockAuthService.signIn(
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => AuthResult(
            success: true,
            user: testUser,
          ));

      final notifier = AuthStateNotifier(mockAuthService);

      await notifier.signIn(username: 'testuser', password: 'password');

      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.user, equals(testUser));
      expect(notifier.state.error, isNull);
    });

    test('should set error state on failed sign in', () async {
      when(mockAuthService.signIn(
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => AuthResult(
            success: false,
            error: 'Invalid username or password',
          ));

      final notifier = AuthStateNotifier(mockAuthService);

      await notifier.signIn(username: 'wrong', password: 'wrong');

      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.user, isNull);
      expect(notifier.state.error, equals('Invalid username or password'));
    });
  });

  group('AuthStateNotifier - signUp', () {
    test('should set authenticated state on successful sign up', () async {
      final testUser = createTestUser();
      when(mockAuthService.signUp(
        username: anyNamed('username'),
        password: anyNamed('password'),
        email: anyNamed('email'),
        displayName: anyNamed('displayName'),
      )).thenAnswer((_) async => AuthResult(
            success: true,
            user: testUser,
          ));

      final notifier = AuthStateNotifier(mockAuthService);

      await notifier.signUp(
        username: 'testuser',
        password: 'Password1',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.user, equals(testUser));
      expect(notifier.state.error, isNull);
    });

    test('should set error state on failed sign up', () async {
      when(mockAuthService.signUp(
        username: anyNamed('username'),
        password: anyNamed('password'),
        email: anyNamed('email'),
        displayName: anyNamed('displayName'),
      )).thenAnswer((_) async => AuthResult(
            success: false,
            error: 'Username already exists',
          ));

      final notifier = AuthStateNotifier(mockAuthService);

      await notifier.signUp(
        username: 'existing',
        password: 'Password1',
        email: 'test@example.com',
      );

      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, equals('Username already exists'));
    });

    test('should set loading state before sign up attempt', () async {
      when(mockAuthService.signUp(
        username: anyNamed('username'),
        password: anyNamed('password'),
        email: anyNamed('email'),
        displayName: anyNamed('displayName'),
      )).thenAnswer((_) async => AuthResult(
            success: true,
            user: createTestUser(),
          ));

      final notifier = AuthStateNotifier(mockAuthService);

      final states = <AuthState>[];
      notifier.addListener((state) {
        states.add(state);
      });

      await notifier.signUp(
        username: 'testuser',
        password: 'Password1',
        email: 'test@example.com',
      );

      // states[0] = initial state (fireImmediately), states[1] = loading
      expect(states[1].isLoading, isTrue);
      expect(states[1].error, isNull);
    });
  });

  group('AuthStateNotifier - signOut', () {
    test('should reset to initial state on sign out', () async {
      final testUser = createTestUser();
      when(mockAuthService.signIn(
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => AuthResult(
            success: true,
            user: testUser,
          ));
      when(mockAuthService.signOut()).thenAnswer((_) async {});

      final notifier = AuthStateNotifier(mockAuthService);

      // First sign in
      await notifier.signIn(username: 'testuser', password: 'password');
      expect(notifier.state.isAuthenticated, isTrue);

      // Then sign out
      await notifier.signOut();

      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.user, isNull);
      expect(notifier.state.error, isNull);
    });

    test('should call authService.signOut', () async {
      when(mockAuthService.signOut()).thenAnswer((_) async {});

      final notifier = AuthStateNotifier(mockAuthService);
      await notifier.signOut();

      verify(mockAuthService.signOut()).called(1);
    });
  });

  group('AuthStateNotifier - updateProfile', () {
    test('should update user on successful profile update', () async {
      final testUser = createTestUser();
      final updatedUser = testUser.copyWith(displayName: 'Updated Name');

      when(mockAuthService.updateProfile(
        userId: anyNamed('userId'),
        displayName: anyNamed('displayName'),
        email: anyNamed('email'),
        avatarUrl: anyNamed('avatarUrl'),
      )).thenAnswer((_) async => updatedUser);

      final notifier = AuthStateNotifier(mockAuthService);

      await notifier.updateProfile(
        userId: 'test-user-123',
        displayName: 'Updated Name',
      );

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.user?.displayName, equals('Updated Name'));
      expect(notifier.state.error, isNull);
    });

    test('should set error state on profile update failure', () async {
      when(mockAuthService.updateProfile(
        userId: anyNamed('userId'),
        displayName: anyNamed('displayName'),
        email: anyNamed('email'),
        avatarUrl: anyNamed('avatarUrl'),
      )).thenThrow(Exception('Not authorized'));

      final notifier = AuthStateNotifier(mockAuthService);

      await notifier.updateProfile(
        userId: 'test-user-123',
        displayName: 'Updated Name',
      );

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, contains('Not authorized'));
    });

    test('should set loading state before profile update', () async {
      when(mockAuthService.updateProfile(
        userId: anyNamed('userId'),
        displayName: anyNamed('displayName'),
        email: anyNamed('email'),
        avatarUrl: anyNamed('avatarUrl'),
      )).thenAnswer((_) async => createTestUser());

      final notifier = AuthStateNotifier(mockAuthService);

      final states = <AuthState>[];
      notifier.addListener((state) {
        states.add(state);
      });

      await notifier.updateProfile(
        userId: 'test-user-123',
        displayName: 'Updated Name',
      );

      // states[0] = initial state (fireImmediately), states[1] = loading
      expect(states[1].isLoading, isTrue);
    });
  });

  group('AuthStateNotifier - changePassword', () {
    test('should return true on successful password change', () async {
      when(mockAuthService.changePassword(
        userId: anyNamed('userId'),
        currentPassword: anyNamed('currentPassword'),
        newPassword: anyNamed('newPassword'),
      )).thenAnswer((_) async => true);

      final notifier = AuthStateNotifier(mockAuthService);

      final result = await notifier.changePassword(
        userId: 'test-user-123',
        currentPassword: 'OldPass1',
        newPassword: 'NewPass1',
      );

      expect(result, isTrue);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('should return false and set error on password change failure', () async {
      when(mockAuthService.changePassword(
        userId: anyNamed('userId'),
        currentPassword: anyNamed('currentPassword'),
        newPassword: anyNamed('newPassword'),
      )).thenThrow(Exception('Current password is incorrect'));

      final notifier = AuthStateNotifier(mockAuthService);

      final result = await notifier.changePassword(
        userId: 'test-user-123',
        currentPassword: 'wrong',
        newPassword: 'NewPass1',
      );

      expect(result, isFalse);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, contains('Current password is incorrect'));
    });
  });

  group('Demo AuthState Provider', () {
    test('authStateProvider should start as authenticated demo user', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(authStateProvider);

      expect(state.isAuthenticated, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.user, isNotNull);
      expect(state.user!.username, equals('demo'));
      expect(state.user!.email, equals('demo@example.com'));
      expect(state.user!.displayName, equals('Demo User'));
      expect(state.error, isNull);
    });

    test('currentUserProvider should return demo user', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final user = container.read(currentUserProvider);

      expect(user, isNotNull);
      expect(user!.username, equals('demo'));
      expect(user.id, equals('demo-user-001'));
    });
  });

  group('AuthStateNotifier - State Transitions', () {
    test('error should be cleared when starting new sign in', () async {
      // First, create an error state
      when(mockAuthService.signIn(
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => AuthResult(
            success: false,
            error: 'First error',
          ));

      final notifier = AuthStateNotifier(mockAuthService);
      await notifier.signIn(username: 'wrong', password: 'wrong');
      expect(notifier.state.error, equals('First error'));

      // Then sign in again - error should be cleared during loading
      when(mockAuthService.signIn(
        username: anyNamed('username'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => AuthResult(
            success: true,
            user: createTestUser(),
          ));

      final states = <AuthState>[];
      notifier.addListener((state) {
        states.add(state);
      });

      await notifier.signIn(username: 'testuser', password: 'password');

      // states[0] = current state with error (fireImmediately), states[1] = loading
      expect(states[1].isLoading, isTrue);
      expect(states[1].error, isNull);
    });

    test('error should be cleared when starting new sign up', () async {
      // First, create an error state
      when(mockAuthService.signUp(
        username: anyNamed('username'),
        password: anyNamed('password'),
        email: anyNamed('email'),
        displayName: anyNamed('displayName'),
      )).thenAnswer((_) async => AuthResult(
            success: false,
            error: 'Sign up error',
          ));

      final notifier = AuthStateNotifier(mockAuthService);
      await notifier.signUp(
        username: 'existing',
        password: 'Password1',
        email: 'test@example.com',
      );
      expect(notifier.state.error, equals('Sign up error'));

      // Sign up again
      when(mockAuthService.signUp(
        username: anyNamed('username'),
        password: anyNamed('password'),
        email: anyNamed('email'),
        displayName: anyNamed('displayName'),
      )).thenAnswer((_) async => AuthResult(
            success: true,
            user: createTestUser(),
          ));

      final states = <AuthState>[];
      notifier.addListener((state) {
        states.add(state);
      });

      await notifier.signUp(
        username: 'newuser',
        password: 'Password1',
        email: 'new@example.com',
      );

      // states[0] = current state with error (fireImmediately), states[1] = loading
      expect(states[1].isLoading, isTrue);
      expect(states[1].error, isNull);
    });
  });
}
