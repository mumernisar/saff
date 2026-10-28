import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/config/environment_config.dart';
import 'package:saff_app/data/errors/failure_mapper_factory.dart';
import 'package:saff_app/data/repositories/alarm_repository.dart';
import 'package:saff_app/data/repositories/emulator_status_repository.dart';
import 'package:saff_app/data/services/alarm_service.dart';
import 'package:saff_app/data/services/crash_reporter.dart';
import 'package:saff_app/data/services/emulator_probe_service.dart';
import 'package:saff_core/saff_core.dart';

/// The build configuration; overridden at startup.
final environmentConfigProvider = Provider<EnvironmentConfig>(
  (ref) => throw UnimplementedError('Override environmentConfigProvider.'),
);

/// Crash reporting; overridden at startup.
final crashReporterProvider = Provider<CrashReporter>(
  (ref) => throw UnimplementedError('Override crashReporterProvider.'),
);

/// The shared exception-to-failure mapper chain.
final failureMapperProvider = Provider<FailureMapper>(
  (ref) => buildFailureMapper(),
);

/// The native alarm module.
final alarmServiceProvider = Provider<AlarmService>((ref) => AlarmService());

/// Native alarm state.
final alarmRepositoryProvider = Provider<AlarmRepository>(
  (ref) => AlarmRepositoryImpl(
    ref.watch(alarmServiceProvider),
    ref.watch(failureMapperProvider),
  ),
);

/// Probes emulator ports.
final emulatorProbeServiceProvider = Provider<EmulatorProbeService>(
  (ref) => const SocketEmulatorProbeService(),
);

/// Emulator reachability.
final emulatorStatusRepositoryProvider = Provider<EmulatorStatusRepository>(
  (ref) => EmulatorStatusRepositoryImpl(
    ref.watch(emulatorProbeServiceProvider),
    ref.watch(environmentConfigProvider),
    ref.watch(failureMapperProvider),
  ),
);

/// Retry rule for providers: only retryable failures, with the policy of
/// `docs/ERRORS.md` §6. Returning null stops retrying.
Duration? providerRetry(int retryCount, Object error) {
  if (error is! AppFailure || !error.retryable) return null;
  const policy = RetryPolicy.userRead;
  if (retryCount + 1 >= policy.maxAttempts) return null;
  return policy.ceiling(retryCount + 1);
}
