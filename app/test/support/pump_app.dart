import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/app.dart';
import 'package:saff_app/config/environment_config.dart';
import 'package:saff_app/data/services/crash_reporter.dart';
import 'package:saff_app/data/services/emulator_probe_service.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/router.dart';

/// A probe whose answers are set by the test.
class FakeProbe implements EmulatorProbeService {
  FakeProbe(this.reachablePorts);

  final Set<int> reachablePorts;

  @override
  Future<bool> isReachable(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 2),
  }) async => reachablePorts.contains(port);
}

EnvironmentConfig devConfig({bool emulators = false}) =>
    EnvironmentConfig.resolve(
      flavor: Flavor.dev,
      useEmulators: emulators,
      emulatorHost: '10.0.0.5',
      demoTiming: false,
    );

EnvironmentConfig prodConfig() => EnvironmentConfig.resolve(
  flavor: Flavor.prod,
  useEmulators: true,
  emulatorHost: '10.0.0.5',
  demoTiming: true,
);

Future<GoRouter> pumpApp(
  WidgetTester tester, {
  required EnvironmentConfig config,
  EmulatorProbeService? probe,
}) async {
  final router = buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        environmentConfigProvider.overrideWithValue(config),
        crashReporterProvider.overrideWithValue(MemoryCrashReporter()),
        if (probe != null)
          emulatorProbeServiceProvider.overrideWithValue(probe),
      ],
      child: SaffApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
