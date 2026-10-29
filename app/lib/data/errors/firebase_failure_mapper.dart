import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saff_core/saff_core.dart';

/// Maps FlutterFire exceptions to catalog failures (`docs/ERRORS.md` §4).
///
/// Callable errors carry the catalog code in `details['code']`
/// (`functions/src/core/errors.ts`).
final class FirebaseFailureMapper implements ExceptionMapper {
  /// Creates the mapper.
  const FirebaseFailureMapper();

  @override
  AppFailure? tryMap(Object e, StackTrace st, Map<String, Object?> context) {
    FailureCode? code;
    var ctx = context;
    switch (e) {
      case FirebaseFunctionsException():
        final details = e.details;
        if (details is Map) {
          final wire = details['code'];
          if (wire is String) code = FailureCode.fromWire(wire);
          ctx = {
            ...context,
            for (final entry in details.entries)
              if (entry.key != 'code') '${entry.key}': entry.value,
          };
        }
        code ??= switch (e.code) {
          'unavailable' => FailureCode.serverUnavailable,
          'deadline-exceeded' => FailureCode.networkTimeout,
          'unauthenticated' => FailureCode.unauthenticated,
          'permission-denied' => FailureCode.permissionDenied,
          'not-found' => FailureCode.notFound,
          'invalid-argument' => FailureCode.invalidArgument,
          'resource-exhausted' => FailureCode.rateLimited,
          _ => FailureCode.serverInternal,
        };
      case FirebaseException(plugin: 'cloud_firestore'):
        code = switch (e.code) {
          'permission-denied' => FailureCode.permissionDenied,
          'unavailable' => FailureCode.networkOffline,
          'not-found' => FailureCode.notFound,
          'deadline-exceeded' => FailureCode.networkTimeout,
          _ => FailureCode.serverInternal,
        };
      case FirebaseAuthException():
        code = switch (e.code) {
          'user-disabled' => FailureCode.authAccountDisabled,
          'expired-action-code' => FailureCode.authLinkExpired,
          'invalid-action-code' => FailureCode.authLinkInvalid,
          'network-request-failed' => FailureCode.networkOffline,
          'web-context-canceled' ||
          'canceled' ||
          'popup-closed-by-user' => FailureCode.authCancelled,
          _ => FailureCode.unauthenticated,
        };
      default:
        return null;
    }
    return AppFailure.fromCode(code, cause: e, stackTrace: st, context: ctx);
  }
}
