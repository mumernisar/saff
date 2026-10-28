import 'package:flutter/services.dart' show appFlavor;
import 'package:saff_domain/saff_domain.dart';

/// Which build the app is (`docs/REPOSITORY.md` §1, `docs/DEV_RELAXATIONS.md`).
enum Flavor {
  /// Development: emulators, demo timing and test hooks may be on.
  dev,

  /// Production: none of the dev relaxations exist.
  prod,
}

/// Ports of the Firebase emulators (`firebase/firebase.json`).
abstract final class EmulatorPorts {
  /// Authentication emulator.
  static const auth = 9099;

  /// Firestore emulator.
  static const firestore = 8080;

  /// Functions emulator.
  static const functions = 5001;

  /// Storage emulator.
  static const storage = 9199;
}

/// Build-time configuration, resolved once at startup.
final class EnvironmentConfig {
  const EnvironmentConfig._({
    required this.flavor,
    required this.useEmulators,
    required this.emulatorHost,
    required this.demoTiming,
  });

  /// Reads the `--dart-define` values for [flavor].
  ///
  /// The prod flavor ignores every emulator and demo define, so a prod build
  /// can never talk to emulators or use demo timing.
  factory EnvironmentConfig.fromDefines(Flavor flavor) =>
      EnvironmentConfig.resolve(
        flavor: flavor,
        useEmulators: const bool.fromEnvironment('USE_EMULATORS'),
        emulatorHost: const String.fromEnvironment(
          'EMULATOR_HOST',
          defaultValue: '127.0.0.1',
        ),
        demoTiming: const bool.fromEnvironment('DEMO_TIMING'),
      );

  /// Reads the flavor Flutter was built with (`--flavor`), for entrypoints
  /// that don't know it statically, such as the wake engine.
  factory EnvironmentConfig.fromBuildFlavor() => EnvironmentConfig.fromDefines(
    appFlavor == 'prod' ? Flavor.prod : Flavor.dev,
  );

  /// Applies the flavor rules to raw values.
  factory EnvironmentConfig.resolve({
    required Flavor flavor,
    required bool useEmulators,
    required String emulatorHost,
    required bool demoTiming,
  }) {
    final dev = flavor == Flavor.dev;
    return EnvironmentConfig._(
      flavor: flavor,
      useEmulators: dev && useEmulators,
      emulatorHost: dev ? emulatorHost : '',
      demoTiming: dev && demoTiming,
    );
  }

  /// The build flavor.
  final Flavor flavor;

  /// Whether Firebase talks to the local emulators (dev only).
  final bool useEmulators;

  /// Host of the emulators: the laptop's address, or `127.0.0.1` over USB.
  final String emulatorHost;

  /// Whether the demo timing overlay is on (dev only).
  final bool demoTiming;

  /// Whether this is the dev flavor.
  bool get isDev => flavor == Flavor.dev;

  /// The product constants for this build.
  SaffConstants get constants =>
      SaffConstants.resolve(allowDemo: isDev, demoRequested: demoTiming);

  /// Whether crashes and errors go to Crashlytics in a build of [releaseMode].
  ///
  /// Dev reports in every build mode (`DEV_RELAXATIONS.md` R-10); prod only
  /// in release.
  bool reportToCrashlytics({required bool releaseMode}) => isDev || releaseMode;
}
