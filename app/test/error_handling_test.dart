import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saff_app/data/services/app_log.dart';
import 'package:saff_app/data/services/crash_reporter.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/error_handling.dart';
import 'package:saff_core/saff_core.dart';

void main() {
  late MemoryCrashReporter reporter;
  late void Function(FlutterErrorDetails)? savedOnError;
  late bool Function(Object, StackTrace)? savedPlatformOnError;
  late ErrorWidgetBuilder savedBuilder;

  setUp(() {
    reporter = MemoryCrashReporter();
    savedOnError = FlutterError.onError;
    savedPlatformOnError = PlatformDispatcher.instance.onError;
    savedBuilder = ErrorWidget.builder;
  });

  tearDown(() {
    FlutterError.onError = savedOnError;
    PlatformDispatcher.instance.onError = savedPlatformOnError;
    ErrorWidget.builder = savedBuilder;
  });

  test('a StateError reaching FlutterError.onError is reported as fatal', () {
    installGlobalErrorHandlers(reporter);
    final error = StateError('boom');
    FlutterError.onError!(FlutterErrorDetails(exception: error));
    expect(reporter.fatals, [error]);
  });

  test('an async error reaching PlatformDispatcher is fatal and handled', () {
    installGlobalErrorHandlers(reporter);
    final error = StateError('async boom');
    final handled = PlatformDispatcher.instance.onError!(
      error,
      StackTrace.current,
    );
    expect(handled, isTrue);
    expect(reporter.fatals, [error]);
  });

  test('release swaps in the calm error widget', () {
    installGlobalErrorHandlers(reporter, releaseWidgets: true);
    final widget = ErrorWidget.builder(
      const FlutterErrorDetails(exception: 'x'),
    );
    expect(widget, isA<BrokenScreen>());
  });

  group('AppLog', () {
    test('reports unknown, data and internal failures as non-fatal', () {
      final log = AppLog(reporter, console: false)
        ..error(const UnknownFailure(code: FailureCode.unknown))
        ..error(const DataFailure(code: FailureCode.dataMalformed))
        ..error(const BackendFailure(code: FailureCode.serverInternal));
      expect(reporter.nonFatals, hasLength(3));
      expect(log.console, isFalse);
    });

    test('only counts domain, network and device failures', () {
      AppLog(reporter, console: false)
        ..error(const DomainFailure(code: FailureCode.skipTooLate))
        ..error(const NetworkFailure(code: FailureCode.networkOffline))
        ..error(
          const DeviceFailure(
            code: FailureCode.batteryOptimised,
            fix: DeviceFix.batteryOptimisation,
          ),
        );
      expect(reporter.nonFatals, isEmpty);
      expect(reporter.breadcrumbs, hasLength(3));
    });

    test('redacts personal keys in breadcrumbs', () {
      AppLog(reporter, console: false).info(
        'sent',
        area: 'chat',
        context: {'email': 'a@b.c', 'saffId': 's1'},
      );
      expect(reporter.breadcrumbs.single, isNot(contains('a@b.c')));
      expect(reporter.breadcrumbs.single, contains('s1'));
    });
  });

  group('providerRetry', () {
    test('retries only retryable failures, with growing ceilings', () {
      const offline = NetworkFailure(code: FailureCode.networkOffline);
      expect(providerRetry(0, offline), const Duration(milliseconds: 500));
      expect(providerRetry(1, offline), const Duration(seconds: 1));
      expect(providerRetry(3, offline), isNull);
    });

    test('never retries a domain failure or a bug', () {
      expect(
        providerRetry(0, const DomainFailure(code: FailureCode.saffFull)),
        isNull,
      );
      expect(providerRetry(0, StateError('bug')), isNull);
    });
  });
}
