import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/services/authentication_service.dart';

/// Authentication state
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final UserModel? user;
  final String? error;

  const AuthState({
    required this.isAuthenticated,
    required this.isLoading,
    this.user,
    this.error,
  });

  factory AuthState.initial() {
    return const AuthState(
      isAuthenticated: false,
      isLoading: false,
    );
  }

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
    );
  }
}

/// Authentication state notifier
class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthenticationService _authService;

  AuthStateNotifier(this._authService) : super(AuthState.initial());

  /// Sign in
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.signIn(
      username: username,
      password: password,
    );

    if (result.success) {
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        user: result.user,
        error: null,
      );
    } else {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: result.error,
      );
    }
  }

  /// Sign up
  Future<void> signUp({
    required String username,
    required String password,
    required String email,
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.signUp(
      username: username,
      password: password,
      email: email,
      displayName: displayName,
    );

    if (result.success) {
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        user: result.user,
        error: null,
      );
    } else {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: result.error,
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    state = AuthState.initial();
  }

  /// Update profile
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? email,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedUser = await _authService.updateProfile(
        userId: userId,
        displayName: displayName,
        email: email,
        avatarUrl: avatarUrl,
      );

      state = state.copyWith(
        isLoading: false,
        user: updatedUser,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.changePassword(
        userId: userId,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      state = state.copyWith(isLoading: false, error: null);
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }
}

/// Authentication state provider
final authStateProvider = StateNotifierProvider<_DemoAuthStateNotifier, AuthState>((ref) {
  // TEMPORARILY CREATE A DEMO USER WITHOUT DATABASE
  return _DemoAuthStateNotifier();
});

/// Demo auth state notifier for testing
class _DemoAuthStateNotifier extends StateNotifier<AuthState> {
  _DemoAuthStateNotifier() : super(_createDemoState());

  static AuthState _createDemoState() {
    // Create a demo user directly without database
    final demoUser = UserModel(
      id: 'demo-user-001',
      username: 'demo',
      email: 'demo@example.com',
      passwordHash: 'not-used',
      displayName: 'Demo User',
      status: UserStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Return pre-authenticated state with demo user
    return AuthState(
      isAuthenticated: true,
      isLoading: false,
      user: demoUser,
      error: null,
    );
  }

  /// Demo sign in - always successful
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    // Demo mode: Always succeed
    state = _createDemoState();
  }

  /// Demo sign up - always successful
  Future<void> signUp({
    required String username,
    required String password,
    required String email,
    String? displayName,
  }) async {
    // Demo mode: Always succeed
    state = _createDemoState();
  }

  /// Demo sign out - resets to demo state
  Future<void> signOut() async {
    // Demo mode: Just reset to initial demo state
    state = _createDemoState();
  }
}

/// Current user provider
final currentUserProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.user;
});