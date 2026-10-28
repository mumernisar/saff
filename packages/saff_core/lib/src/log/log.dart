import 'package:saff_core/src/failure/app_failure.dart';

/// Keys whose values never leave the device (`docs/ERRORS.md` §9).
const redactedKeys = <String>{
  'message',
  'text',
  'answer',
  'answers',
  'name',
  'displayName',
  'phone',
  'email',
  'token',
  'idToken',
  'fcmToken',
  'password',
};

/// Replaces the value of every key in [redactedKeys] with `[redacted]`.
Map<String, Object?> redact(Map<String, Object?> context) => {
  for (final entry in context.entries)
    entry.key: redactedKeys.contains(entry.key) ? '[redacted]' : entry.value,
};

/// Structured logging. Implementations must call [redact] on the context
/// before anything leaves the device.
abstract interface class Log {
  /// Developer detail, dropped in release builds.
  void debug(String event, {String? area, Map<String, Object?> context});

  /// Something noteworthy that went right.
  void info(String event, {String? area, Map<String, Object?> context});

  /// Something unexpected that was handled.
  void warn(String event, {String? area, Map<String, Object?> context});

  /// A failure; implementations report it according to its kind.
  void error(AppFailure failure, {String? area});
}

/// A [Log] that drops everything.
final class NoopLog implements Log {
  /// Creates the log.
  const NoopLog();

  @override
  void debug(
    String event, {
    String? area,
    Map<String, Object?> context = const {},
  }) {}

  @override
  void info(
    String event, {
    String? area,
    Map<String, Object?> context = const {},
  }) {}

  @override
  void warn(
    String event, {
    String? area,
    Map<String, Object?> context = const {},
  }) {}

  @override
  void error(AppFailure failure, {String? area}) {}
}
