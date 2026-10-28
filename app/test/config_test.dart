import 'package:flutter_test/flutter_test.dart';
import 'package:saff_app/config/environment_config.dart';

void main() {
  test('dev keeps emulator and demo settings', () {
    final c = EnvironmentConfig.resolve(
      flavor: Flavor.dev,
      useEmulators: true,
      emulatorHost: '192.168.1.10',
      demoTiming: true,
    );
    expect(c.useEmulators, isTrue);
    expect(c.emulatorHost, '192.168.1.10');
    expect(c.demoTiming, isTrue);
    expect(c.constants.nightLockLead, const Duration(minutes: 1));
  });

  test('prod ignores emulator and demo defines', () {
    final c = EnvironmentConfig.resolve(
      flavor: Flavor.prod,
      useEmulators: true,
      emulatorHost: '192.168.1.10',
      demoTiming: true,
    );
    expect(c.useEmulators, isFalse);
    expect(c.emulatorHost, isEmpty);
    expect(c.demoTiming, isFalse);
    expect(c.constants.nightLockLead, const Duration(minutes: 60));
    expect(c.constants.revealDeadline, const Duration(minutes: 30));
  });

  test('crash reporting: dev always, prod only in release', () {
    final dev = EnvironmentConfig.resolve(
      flavor: Flavor.dev,
      useEmulators: false,
      emulatorHost: '',
      demoTiming: false,
    );
    final prod = EnvironmentConfig.resolve(
      flavor: Flavor.prod,
      useEmulators: false,
      emulatorHost: '',
      demoTiming: false,
    );
    expect(dev.reportToCrashlytics(releaseMode: false), isTrue);
    expect(prod.reportToCrashlytics(releaseMode: false), isFalse);
    expect(prod.reportToCrashlytics(releaseMode: true), isTrue);
  });
}
