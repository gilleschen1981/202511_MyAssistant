/// Base exception class for the application
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Business logic exception
class BusinessException extends AppException {
  const BusinessException(super.message, {super.code, super.details});

  @override
  String toString() => 'BusinessException: $message';
}

/// Validation exception
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException(
    super.message, {
    this.fieldErrors,
    super.code,
    super.details,
  });

  @override
  String toString() => 'ValidationException: $message';
}

/// Resource not found exception
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code, super.details});

  @override
  String toString() => 'NotFoundException: $message';
}

/// Permission denied exception
class PermissionException extends AppException {
  const PermissionException(super.message, {super.code, super.details});

  @override
  String toString() => 'PermissionException: $message';
}

/// Concurrency conflict exception
class ConcurrencyException extends AppException {
  const ConcurrencyException(super.message, {super.code, super.details});

  @override
  String toString() => 'ConcurrencyException: $message';
}

/// Network exception
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.details});

  @override
  String toString() => 'NetworkException: $message';
}

/// Database exception
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code, super.details});

  @override
  String toString() => 'DatabaseException: $message';
}

/// Authentication exception
class AuthenticationException extends AppException {
  const AuthenticationException(super.message, {super.code, super.details});

  @override
  String toString() => 'AuthenticationException: $message';
}

/// Timeout exception
class TimeoutException extends AppException {
  const TimeoutException(super.message, {super.code, super.details});

  @override
  String toString() => 'TimeoutException: $message';
}