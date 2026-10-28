import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:saff_app/data/services/crash_reporter.dart';
import 'package:saff_core/saff_core.dart';

/// The app's [Log]: console in debug, breadcrumbs and non-fatals via
/// [CrashReporter] (`docs/ERRORS.md` §9).
final class AppLog implements Log {
  /// Creates the log. [console] turns on developer-console output.
  AppLog(this._reporter, {bool? console}) : console = console ?? !kReleaseMode;

  final CrashReporter _reporter;

  /// Whether entries are also written to the developer console.
  final bool console;

  @override
  void debug(
    String event, {
    String? area,
    Map<String, Object?> context = const {},
  }) => _write('DEBUG', event, area, context);

  @override
  void info(
    String event, {
    String? area,
    Map<String, Object?> context = const {},
  }) {
    _write('INFO', event, area, context);
    _reporter.breadcrumb(_format(event, area, context));
  }

  @override
  void warn(
    String event, {
    String? area,
    Map<String, Object?> context = const {},
  }) {
    _write('WARN', event, area, context);
    _reporter.breadcrumb(_format(event, area, context));
  }

  @override
  void error(AppFailure failure, {String? area}) {
    _write('ERROR', failure.code.wire, area, failure.context);
    _reporter.breadcrumb(_format(failure.code.wire, area, failure.context));
    if (_reportable(failure)) {
      _reporter.nonFatal(
        failure.cause ?? failure,
        failure.stackTrace,
        reason: failure.code.wire,
      );
    }
  }

  // Unknown and data failures, and backend `internal`, are reported; domain,
  // network and device failures are only counted (docs/ERRORS.md §9).
  bool _reportable(AppFailure failure) =>
      failure is UnknownFailure ||
      failure is DataFailure ||
      failure.code == FailureCode.serverInternal;

  String _format(String event, String? area, Map<String, Object?> context) {
    final safe = redact(context);
    final prefix = area == null ? '' : '$area: ';
    return safe.isEmpty ? '$prefix$event' : '$prefix$event $safe';
  }

  void _write(
    String level,
    String event,
    String? area,
    Map<String, Object?> context,
  ) {
    if (!console) return;
    developer.log(
      _format(event, area, context),
      name: 'saff',
      level: level == 'ERROR' ? 1000 : 800,
    );
  }
}
