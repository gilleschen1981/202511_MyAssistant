import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/domain/repositories/i_user_repository.dart';
import 'package:myassistant/core/errors/exceptions.dart';

/// Authentication result
class AuthResult {
  final bool success;
  final UserModel? user;
  final String? token;
  final String? error;

  AuthResult({
    required this.success,
    this.user,
    this.token,
    this.error,
  });
}

/// Session info
class SessionInfo {
  final String userId;
  final String username;
  final DateTime loginTime;
  final DateTime? lastActivityTime;
  final bool isActive;

  SessionInfo({
    required this.userId,
    required this.username,
    required this.loginTime,
    this.lastActivityTime,
    required this.isActive,
  });
}

/// Authentication service - handles user authentication and session management.
///
/// This service provides secure authentication, session management, and user
/// profile operations. It implements session timeouts, password validation,
/// and secure token generation.
///
/// Example usage:
/// ```dart
/// final authService = AuthenticationService(userRepository: userRepo);
/// final result = await authService.signIn(
///   username: 'john_doe',
///   password: 'SecurePass123',
/// );
/// if (result.success) {
///   print('Logged in as ${result.user?.username}');
/// }
/// ```
class AuthenticationService {
  final IUserRepository _userRepository;

  // Current session
  UserModel? _currentUser;
  String? _sessionToken;
  DateTime? _sessionStartTime;
  DateTime? _lastActivityTime;

  // Session timeout (30 minutes)
  static const Duration _sessionTimeout = Duration(minutes: 30);

  AuthenticationService({
    required IUserRepository userRepository,
  }) : _userRepository = userRepository;

  /// Gets the currently authenticated user.
  /// Returns null if no user is authenticated or session has expired.
  UserModel? get currentUser => _currentUser;

  /// Checks if a user is currently authenticated.
  /// Returns false if no user is logged in or session has expired.
  bool get isAuthenticated => _currentUser != null && !isSessionExpired;

  /// Checks if the current session has expired.
  /// Sessions expire after 30 minutes of inactivity.
  bool get isSessionExpired {
    if (_lastActivityTime == null) return true;
    return DateTime.now().difference(_lastActivityTime!) > _sessionTimeout;
  }

  /// Signs up a new user account.
  ///
  /// Creates a new user with the provided credentials and profile information.
  /// Automatically logs in the user upon successful registration.
  ///
  /// Parameters:
  /// - [username]: Unique username (3-20 chars, alphanumeric + underscore)
  /// - [password]: Secure password (min 8 chars, must include uppercase, lowercase, number)
  /// - [email]: Valid email address
  /// - [displayName]: Optional display name for the user profile
  ///
  /// Returns [AuthResult] containing:
  /// - success: true if registration successful
  /// - user: The created UserModel
  /// - token: Session token for authentication
  /// - error: Error message if registration failed
  ///
  /// Throws:
  /// - [ValidationException] if input validation fails
  Future<AuthResult> signUp({
    required String username,
    required String password,
    required String email,
    String? displayName,
  }) async {
    try {
      // 1. Validate input
      _validateSignUpInput(username, password, email);

      // 2. Check if username exists
      final existingUser = await _userRepository.getUserByUsername(username);
      if (existingUser != null) {
        return AuthResult(
          success: false,
          error: 'Username already exists',
        );
      }

      // 3. Check if email exists
      final emailUser = await _userRepository.getUserByEmail(email);
      if (emailUser != null) {
        return AuthResult(
          success: false,
          error: 'Email already registered',
        );
      }

      // 4. Create user (password will be hashed in repository)
      final user = await _userRepository.createUser(
        username: username,
        password: password,
        email: email,
        displayName: displayName,
      );

      // 5. Create default settings
      await _userRepository.createDefaultSettings(user.id);

      // 6. Set session
      _setSession(user);

      return AuthResult(
        success: true,
        user: user,
        token: _sessionToken,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Signs in an existing user.
  ///
  /// Authenticates user credentials and creates a new session.
  /// Sessions expire after 30 minutes of inactivity.
  ///
  /// Parameters:
  /// - [username]: The user's username
  /// - [password]: The user's password
  ///
  /// Returns [AuthResult] containing:
  /// - success: true if login successful
  /// - user: The authenticated UserModel
  /// - token: New session token
  /// - error: Error message if login failed
  ///
  /// Common error cases:
  /// - Invalid username or password
  /// - Account is deactivated
  /// - Empty credentials
  Future<AuthResult> signIn({
    required String username,
    required String password,
  }) async {
    try {
      // 1. Validate input
      if (username.isEmpty || password.isEmpty) {
        return AuthResult(
          success: false,
          error: 'Username and password are required',
        );
      }

      // 2. Use authenticate method from repository
      final user = await _userRepository.authenticate(username, password);

      if (user == null) {
        return AuthResult(
          success: false,
          error: 'Invalid username or password',
        );
      }

      // 3. Check if user is active
      if (!user.isActive) {
        return AuthResult(
          success: false,
          error: 'Account is deactivated',
        );
      }

      // 4. Update user with login timestamp
      final updatedUser = user.copyWith(
        updatedAt: DateTime.now(),
      );
      await _userRepository.updateUser(updatedUser);

      // 5. Set session
      _setSession(user);

      return AuthResult(
        success: true,
        user: user,
        token: _sessionToken,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    _currentUser = null;
    _sessionToken = null;
    _sessionStartTime = null;
    _lastActivityTime = null;
  }

  /// Refresh session
  void refreshSession() {
    if (isAuthenticated) {
      _lastActivityTime = DateTime.now();
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    // 1. Validate user
    if (_currentUser == null || _currentUser!.id != userId) {
      throw const PermissionException('Not authorized to change password');
    }

    // 2. Validate new password
    if (!_isPasswordValid(newPassword)) {
      throw const ValidationException('New password does not meet requirements');
    }

    // 3. Update password using repository method
    final result = await _userRepository.updatePassword(
      userId,
      currentPassword,
      newPassword,
    );

    if (!result) {
      throw const AuthenticationException('Failed to update password - current password may be incorrect');
    }

    return true;
  }

  /// Update profile
  Future<UserModel> updateProfile({
    required String userId,
    String? displayName,
    String? email,
    String? avatarUrl,
  }) async {
    // 1. Validate user
    if (_currentUser == null || _currentUser!.id != userId) {
      throw const PermissionException('Not authorized to update profile');
    }

    // 2. Get user
    final user = await _userRepository.getUserById(userId);
    if (user == null) {
      throw const NotFoundException('User not found');
    }

    // 3. Validate email if changed
    if (email != null && email != user.email) {
      if (!_isEmailValid(email)) {
        throw const ValidationException('Invalid email format');
      }

      // Check if email already exists
      final existingUser = await _userRepository.getUserByEmail(email);
      if (existingUser != null && existingUser.id != userId) {
        throw const ValidationException('Email already registered');
      }
    }

    // 4. Update user
    final updatedUser = user.copyWith(
      displayName: displayName ?? user.displayName,
      email: email ?? user.email,
      avatarUrl: avatarUrl ?? user.avatarUrl,
      updatedAt: DateTime.now(),
    );

    final result = await _userRepository.updateUser(updatedUser);

    // 5. Update current user
    if (_currentUser?.id == userId) {
      _currentUser = result;
    }

    return result;
  }

  /// Deactivate account
  Future<bool> deactivateAccount({
    required String userId,
    required String password,
  }) async {
    // 1. Validate user
    if (_currentUser == null || _currentUser!.id != userId) {
      throw const PermissionException('Not authorized to deactivate account');
    }

    // 2. Verify password using authenticate
    final authenticatedUser = await _userRepository.authenticate(_currentUser!.username, password);
    if (authenticatedUser == null) {
      throw const AuthenticationException('Password is incorrect');
    }

    // 3. Delete user (soft delete)
    final result = await _userRepository.deleteUser(userId);

    // 4. Sign out
    if (result) {
      await signOut();
    }

    return result;
  }

  /// Get session info
  SessionInfo? getSessionInfo() {
    if (!isAuthenticated || _currentUser == null) {
      return null;
    }

    return SessionInfo(
      userId: _currentUser!.id,
      username: _currentUser!.username,
      loginTime: _sessionStartTime!,
      lastActivityTime: _lastActivityTime,
      isActive: !isSessionExpired,
    );
  }

  /// Validate sign up input
  void _validateSignUpInput(String username, String password, String email) {
    // Username validation
    if (username.length < 3) {
      throw const ValidationException('Username must be at least 3 characters');
    }
    if (username.length > 20) {
      throw const ValidationException('Username must be less than 20 characters');
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      throw const ValidationException('Username can only contain letters, numbers, and underscore');
    }

    // Password validation
    if (!_isPasswordValid(password)) {
      throw const ValidationException('Password must be at least 8 characters and contain uppercase, lowercase, and number');
    }

    // Email validation
    if (!_isEmailValid(email)) {
      throw const ValidationException('Invalid email format');
    }
  }

  /// Check if password is valid
  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  /// Check if email is valid
  bool _isEmailValid(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  /// Generate session token
  String _generateToken(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = '$userId:$timestamp';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Set session
  void _setSession(UserModel user) {
    _currentUser = user;
    _sessionToken = _generateToken(user.id);
    _sessionStartTime = DateTime.now();
    _lastActivityTime = DateTime.now();
  }
}