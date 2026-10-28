import 'package:saff_core/src/failure/app_failure.dart';
import 'package:saff_core/src/failure/failure_code.g.dart';

/// Recognises one family of exceptions (`docs/ERRORS.md` §4).
// An interface with one method is the point: mappers are registered in a list.
// ignore: one_member_abstracts
abstract interface class ExceptionMapper {
  /// Returns a failure if this mapper recognises [e], otherwise null.
  AppFailure? tryMap(Object e, StackTrace st, Map<String, Object?> context);
}

/// Tries each [ExceptionMapper] in order; the first match wins.
final class FailureMapper {
  /// Creates a chain of [mappers], tried in the given order.
  const FailureMapper(this.mappers);

  /// The chain, in order.
  final List<ExceptionMapper> mappers;

  /// Converts [e] to a failure, or an [UnknownFailure] if nothing matches.
  AppFailure map(
    Object e,
    StackTrace st, {
    Map<String, Object?> context = const {},
  }) {
    for (final mapper in mappers) {
      final failure = mapper.tryMap(e, st, context);
      if (failure != null) return failure;
    }
    return UnknownFailure(
      code: FailureCode.unknown,
      cause: e,
      stackTrace: st,
      context: context,
    );
  }
}
