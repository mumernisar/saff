import 'package:saff_core/src/failure/failure_code.g.dart';
import 'package:saff_core/src/failure/failure_kind.dart';

/// Which device setting fixes a [DeviceFailure].
enum DeviceFix {
  /// Exact-alarm permission ("Alarms & reminders").
  alarmPermission,

  /// App notifications.
  notifications,

  /// Full-screen intent permission.
  fullScreenIntent,

  /// Battery optimisation for the app.
  batteryOptimisation,

  /// Camera permission.
  camera,

  /// Free up device storage.
  storage,

  /// The app's general settings page.
  appSettings,
}

/// Base of every expected failure in the app (`docs/ERRORS.md` §3).
///
/// Implements [Exception] so a service may throw one deliberately and the
/// mapper chain passes it through unchanged.
sealed class AppFailure implements Exception {
  const AppFailure({
    required this.code,
    this.cause,
    this.stackTrace,
    this.context = const {},
  });

  /// Builds the failure subtype that matches `code.kind`.
  factory AppFailure.fromCode(
    FailureCode code, {
    Object? cause,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
    DeviceFix? fix,
  }) => switch (code.kind) {
    FailureKind.domain => DomainFailure(
      code: code,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
    ),
    FailureKind.network => NetworkFailure(
      code: code,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
    ),
    FailureKind.backend => BackendFailure(
      code: code,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
    ),
    FailureKind.device => DeviceFailure(
      code: code,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
      fix: fix ?? DeviceFix.appSettings,
    ),
    FailureKind.data => DataFailure(
      code: code,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
    ),
    FailureKind.unknown => UnknownFailure(
      code: code,
      cause: cause,
      stackTrace: stackTrace,
      context: context,
    ),
  };

  /// The catalog code (generated from `contracts/errors.json`).
  final FailureCode code;

  /// The original exception. Never shown to users.
  final Object? cause;

  /// Where the original exception was thrown.
  final StackTrace? stackTrace;

  /// Redacted diagnostic data (ids, never personal data).
  final Map<String, Object?> context;

  /// Whether retrying can succeed.
  bool get retryable => code.retryable;

  /// How serious the failure is.
  FailureSeverity get severity => code.severity;

  /// ARB key of the user-facing message.
  String get messageKey => code.messageKey;

  @override
  String toString() => 'AppFailure(${code.wire})';
}

/// A business rule said no; the user changes something.
final class DomainFailure extends AppFailure {
  /// Creates a domain failure.
  const DomainFailure({
    required super.code,
    super.cause,
    super.stackTrace,
    super.context,
  });
}

/// No connection, timeout, DNS or TLS problem.
final class NetworkFailure extends AppFailure {
  /// Creates a network failure.
  const NetworkFailure({
    required super.code,
    super.cause,
    super.stackTrace,
    super.context,
  });
}

/// The backend answered with an error.
final class BackendFailure extends AppFailure {
  /// Creates a backend failure.
  const BackendFailure({
    required super.code,
    super.cause,
    super.stackTrace,
    super.context,
  });
}

/// A device setting or permission blocks the action.
final class DeviceFailure extends AppFailure {
  /// Creates a device failure that [fix] can resolve.
  const DeviceFailure({
    required super.code,
    required this.fix,
    super.cause,
    super.stackTrace,
    super.context,
  });

  /// The setting to open so the user can fix this.
  final DeviceFix fix;
}

/// Malformed or unsupported data.
final class DataFailure extends AppFailure {
  /// Creates a data failure.
  const DataFailure({
    required super.code,
    super.cause,
    super.stackTrace,
    super.context,
  });
}

/// Anything no mapper recognised. Always reported.
final class UnknownFailure extends AppFailure {
  /// Creates an unknown failure.
  const UnknownFailure({
    required super.code,
    super.cause,
    super.stackTrace,
    super.context,
  });
}
