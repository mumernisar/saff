import 'package:saff_core/src/failure/app_failure.dart';
import 'package:saff_core/src/failure/exception_mapper.dart';

/// Either a value or an [AppFailure]; repositories return this instead of
/// throwing across the boundary (`docs/ERRORS.md` §3).
sealed class Result<T> {
  const Result();

  /// A success carrying [value].
  const factory Result.ok(T value) = Ok<T>;

  /// A failure carrying [failure].
  const factory Result.err(AppFailure failure) = Err<T>;

  /// Runs [action] and converts any thrown [Exception] with [mapper].
  ///
  /// Only [Exception]s are caught. An [Error] is a bug and propagates to the
  /// global handlers.
  static Future<Result<T>> guard<T>(
    Future<T> Function() action,
    FailureMapper mapper, {
    Map<String, Object?> context = const {},
  }) async {
    try {
      return Result.ok(await action());
    } on Exception catch (e, st) {
      return Result.err(mapper.map(e, st, context: context));
    }
  }

  /// Transforms a success value.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Result.ok(transform(value)),
    Err<T>(:final failure) => Result.err(failure),
  };

  /// Chains another fallible step after a success.
  Result<R> flatMap<R>(Result<R> Function(T value) next) => switch (this) {
    Ok<T>(:final value) => next(value),
    Err<T>(:final failure) => Result.err(failure),
  };

  /// Collapses both cases into one value.
  R fold<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final failure) => err(failure),
  };

  /// The value, or null on failure.
  T? getOrNull() => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };
}

/// A successful [Result].
final class Ok<T> extends Result<T> {
  /// Creates a success.
  const Ok(this.value);

  /// The value.
  final T value;
}

/// A failed [Result].
final class Err<T> extends Result<T> {
  /// Creates a failure.
  const Err(this.failure);

  /// The failure.
  final AppFailure failure;
}
