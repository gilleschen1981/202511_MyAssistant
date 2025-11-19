/// Base class for all use cases
/// Follows Clean Architecture principles
abstract class BaseUseCase<Type, Params> {
  Future<Type> call(Params params);
}

/// Base class for use cases that don't need parameters
abstract class NoParamsUseCase<Type> {
  Future<Type> call();
}

/// Base class for synchronous use cases
abstract class SyncUseCase<Type, Params> {
  Type call(Params params);
}

/// Result wrapper for use cases
class UseCaseResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  const UseCaseResult.success(this.data)
      : error = null,
        isSuccess = true;

  const UseCaseResult.failure(this.error)
      : data = null,
        isSuccess = false;

  bool get isFailure => !isSuccess;
}