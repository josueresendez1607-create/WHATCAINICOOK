sealed class AppResult<T> {
  const AppResult();

  bool get isSuccess => this is AppSuccess<T>;
  T? get valueOrNull => switch (this) {
    AppSuccess<T>(:final T value) => value,
    AppFailure<T>() => null,
  };

  String? get errorOrNull => switch (this) {
    AppSuccess<T>() => null,
    AppFailure<T>(:final String message) => message,
  };
}

final class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);
  final T value;
}

final class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.message, {this.exception});
  final String message;
  final Object? exception;
}
