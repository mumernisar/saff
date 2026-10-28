import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Sends errors to crash reporting.
abstract interface class CrashReporter {
  /// Reports an unhandled error that ends a task or the app.
  void fatal(Object error, StackTrace? stack);

  /// Reports a handled problem worth a look.
  void nonFatal(Object error, StackTrace? stack, {String? reason});

  /// Records a breadcrumb that is attached to later reports.
  void breadcrumb(String message);
}

/// Crashlytics-backed reporter.
final class CrashlyticsReporter implements CrashReporter {
  /// Creates the reporter around the Crashlytics instance.
  CrashlyticsReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  void fatal(Object error, StackTrace? stack) {
    unawaited(_crashlytics.recordError(error, stack, fatal: true));
  }

  @override
  void nonFatal(Object error, StackTrace? stack, {String? reason}) {
    unawaited(_crashlytics.recordError(error, stack, reason: reason));
  }

  @override
  void breadcrumb(String message) => unawaited(_crashlytics.log(message));
}

/// A reporter that keeps everything in memory; used when reporting is off and
/// in tests.
final class MemoryCrashReporter implements CrashReporter {
  /// Fatal errors seen.
  final List<Object> fatals = [];

  /// Non-fatal errors seen.
  final List<Object> nonFatals = [];

  /// Breadcrumbs seen.
  final List<String> breadcrumbs = [];

  @override
  void fatal(Object error, StackTrace? stack) => fatals.add(error);

  @override
  void nonFatal(Object error, StackTrace? stack, {String? reason}) =>
      nonFatals.add(error);

  @override
  void breadcrumb(String message) => breadcrumbs.add(message);
}
