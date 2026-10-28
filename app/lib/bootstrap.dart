import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/app.dart';
import 'package:saff_app/config/environment_config.dart';
import 'package:saff_app/data/services/app_log.dart';
import 'package:saff_app/data/services/crash_reporter.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/error_handling.dart';
import 'package:saff_core/saff_core.dart';

/// Logs provider failures (with the provider name) as non-fatals.
base class LoggingProviderObserver extends ProviderObserver {
  /// Creates the observer.
  const LoggingProviderObserver(this._log);

  final Log _log;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final name =
        context.provider.name ?? context.provider.runtimeType.toString();
    if (error is AppFailure) {
      _log.error(error, area: name);
    } else {
      _log.error(
        UnknownFailure(
          code: FailureCode.unknown,
          cause: error,
          stackTrace: stackTrace,
          context: {'provider': name},
        ),
        area: name,
      );
    }
  }
}

/// Shared startup for every flavor: Firebase, emulators, App Check,
/// Crashlytics, global error handlers, then `runApp`.
Future<void> bootstrap({
  required EnvironmentConfig config,
  required FirebaseOptions firebaseOptions,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);

  if (config.useEmulators) await _connectEmulators(config.emulatorHost);

  await FirebaseAppCheck.instance.activate(
    providerAndroid: config.isDev
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );

  final report = config.reportToCrashlytics(releaseMode: kReleaseMode);
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(report);
  final reporter = _reporterFor(report: report);
  final log = AppLog(reporter);

  installGlobalErrorHandlers(reporter);

  runApp(
    ProviderScope(
      retry: providerRetry,
      observers: [LoggingProviderObserver(log)],
      overrides: [
        environmentConfigProvider.overrideWithValue(config),
        crashReporterProvider.overrideWithValue(reporter),
      ],
      child: const SaffApp(),
    ),
  );
}

CrashReporter _reporterFor({required bool report}) => report
    ? CrashlyticsReporter(FirebaseCrashlytics.instance)
    : MemoryCrashReporter();

Future<void> _connectEmulators(String host) async {
  await FirebaseAuth.instance.useAuthEmulator(host, EmulatorPorts.auth);
  FirebaseFirestore.instance.useFirestoreEmulator(
    host,
    EmulatorPorts.firestore,
  );
  FirebaseFunctions.instance.useFunctionsEmulator(
    host,
    EmulatorPorts.functions,
  );
  await FirebaseStorage.instance.useStorageEmulator(
    host,
    EmulatorPorts.storage,
  );
}
