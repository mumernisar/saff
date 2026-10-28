import 'dart:async';
import 'dart:io';

import 'package:saff_core/src/failure/app_failure.dart';
import 'package:saff_core/src/failure/exception_mapper.dart';
import 'package:saff_core/src/failure/failure_code.g.dart';

/// Passes through an [AppFailure] thrown deliberately inside a service.
final class AppFailureMapper implements ExceptionMapper {
  /// Creates the mapper.
  const AppFailureMapper();

  @override
  AppFailure? tryMap(Object e, StackTrace st, Map<String, Object?> context) =>
      e is AppFailure ? e : null;
}

/// Maps `dart:io` and `dart:async` connectivity exceptions.
final class NetworkExceptionMapper implements ExceptionMapper {
  /// Creates the mapper.
  const NetworkExceptionMapper();

  @override
  AppFailure? tryMap(Object e, StackTrace st, Map<String, Object?> context) {
    final code = switch (e) {
      TimeoutException() => FailureCode.networkTimeout,
      SocketException() ||
      HandshakeException() ||
      HttpException() => FailureCode.networkOffline,
      _ => null,
    };
    if (code == null) return null;
    return NetworkFailure(
      code: code,
      cause: e,
      stackTrace: st,
      context: context,
    );
  }
}

/// An HTTP response with a non-success status from our gateway client.
class HttpStatusException implements Exception {
  /// Creates the exception for a response with [status] and [body].
  const HttpStatusException(this.status, [this.body]);

  /// The HTTP status code.
  final int status;

  /// The response body, if any. Never shown to users.
  final String? body;

  @override
  String toString() => 'HttpStatusException($status)';
}

/// Maps [HttpStatusException]: 4xx to client-side codes, 5xx to a retryable
/// backend failure.
final class HttpStatusMapper implements ExceptionMapper {
  /// Creates the mapper.
  const HttpStatusMapper();

  @override
  AppFailure? tryMap(Object e, StackTrace st, Map<String, Object?> context) {
    if (e is! HttpStatusException) return null;
    final code = switch (e.status) {
      401 => FailureCode.unauthenticated,
      403 => FailureCode.permissionDenied,
      404 => FailureCode.notFound,
      429 => FailureCode.rateLimited,
      >= 500 => FailureCode.serverUnavailable,
      _ => FailureCode.dataMalformed,
    };
    return AppFailure.fromCode(
      code,
      cause: e,
      stackTrace: st,
      context: {...context, 'httpStatus': e.status},
    );
  }
}

/// Maps a [FormatException] to a malformed-data failure.
final class FormatExceptionMapper implements ExceptionMapper {
  /// Creates the mapper.
  const FormatExceptionMapper();

  @override
  AppFailure? tryMap(Object e, StackTrace st, Map<String, Object?> context) =>
      e is FormatException
      ? DataFailure(
          code: FailureCode.dataMalformed,
          cause: e,
          stackTrace: st,
          context: context,
        )
      : null;
}
