import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/stream_provider.dart';
import 'package:saff_app/config/environment_config.dart';
import 'package:saff_app/data/errors/failure_mapper_factory.dart';
import 'package:saff_app/data/repositories/alarm_plan_repository.dart';
import 'package:saff_app/data/repositories/alarm_repository.dart';
import 'package:saff_app/data/repositories/auth_repository.dart';
import 'package:saff_app/data/repositories/chat_repository.dart';
import 'package:saff_app/data/repositories/emulator_status_repository.dart';
import 'package:saff_app/data/repositories/plant_repository.dart';
import 'package:saff_app/data/repositories/round_repository.dart';
import 'package:saff_app/data/repositories/saff_repository.dart';
import 'package:saff_app/data/repositories/stats_repository.dart';
import 'package:saff_app/data/services/alarm_service.dart';
import 'package:saff_app/data/services/crash_reporter.dart';
import 'package:saff_app/data/services/emulator_probe_service.dart';
import 'package:saff_app/data/services/firebase_services.dart';
import 'package:saff_core/saff_core.dart';
import 'package:saff_domain/saff_domain.dart';

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

/// Firebase Auth.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Callable functions.
final functionsServiceProvider = Provider<FunctionsService>(
  (ref) => FunctionsService(),
);

/// Firestore.
final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

/// Sign-in state.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(authServiceProvider),
    ref.watch(failureMapperProvider),
  ),
);

/// Profile, saffs and members.
final saffRepositoryProvider = Provider<SaffRepository>(
  (ref) => SaffRepositoryImpl(
    ref.watch(firestoreServiceProvider),
    ref.watch(functionsServiceProvider),
    ref.watch(failureMapperProvider),
  ),
);

/// Chat.
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(
    ref.watch(firestoreServiceProvider),
    ref.watch(failureMapperProvider),
  ),
);

/// Alarms, proposals, occurrences.
final alarmPlanRepositoryProvider = Provider<AlarmPlanRepository>(
  (ref) => AlarmPlanRepositoryImpl(
    ref.watch(firestoreServiceProvider),
    ref.watch(functionsServiceProvider),
    ref.watch(failureMapperProvider),
  ),
);

/// Rounds and reveals.
final roundRepositoryProvider = Provider<RoundRepository>(
  (ref) => RoundRepositoryImpl(
    ref.watch(firestoreServiceProvider),
    ref.watch(functionsServiceProvider),
    ref.watch(failureMapperProvider),
  ),
);

/// The signed-in uid; null when signed out.
final uidProvider = StreamProvider<String?>(
  (ref) => ref.watch(authRepositoryProvider).uid(),
);

/// The signed-in user's profile; null until created.
final profileProvider = StreamProvider<Profile?>((ref) {
  final uid = ref.watch(uidProvider).value;
  if (uid == null) return Stream.value(null);
  return ref.watch(saffRepositoryProvider).watchProfile(uid);
});

/// Saffs of the user.
final mySaffsProvider = StreamProvider<List<Saff>>((ref) {
  final ids = ref.watch(profileProvider).value?.saffIds ?? const <String>[];
  return ref.watch(saffRepositoryProvider).watchSaffs(ids);
});

/// Members of a saff.
final StreamProviderFamily<List<Member>, String> membersProvider =
    StreamProvider.family<List<Member>, String>(
      (ref, saffId) => ref.watch(saffRepositoryProvider).watchMembers(saffId),
    );

/// Alarms of a saff.
final StreamProviderFamily<List<Alarm>, String> alarmsProvider =
    StreamProvider.family<List<Alarm>, String>(
      (ref, saffId) =>
          ref.watch(alarmPlanRepositoryProvider).watchAlarms(saffId),
    );

/// Proposals of a saff.
final StreamProviderFamily<List<Proposal>, String> proposalsProvider =
    StreamProvider.family<List<Proposal>, String>(
      (ref, saffId) =>
          ref.watch(alarmPlanRepositoryProvider).watchProposals(saffId),
    );

/// Upcoming occurrences of a saff.
final StreamProviderFamily<List<Occurrence>, String> upcomingProvider =
    StreamProvider.family<List<Occurrence>, String>(
      (ref, saffId) =>
          ref.watch(alarmPlanRepositoryProvider).watchUpcoming(saffId),
    );

/// Upcoming occurrences of every saff the user is in, for the user.
final myUpcomingProvider = Provider<List<Occurrence>>((ref) {
  final uid = ref.watch(uidProvider).value;
  final saffs = ref.watch(mySaffsProvider).value ?? const <Saff>[];
  final out = <Occurrence>[];
  for (final s in saffs) {
    final list = ref.watch(upcomingProvider(s.id)).value ?? const [];
    out.addAll(list.where((o) => uid != null && o.requires(uid)));
  }
  out.sort((a, b) => a.ringAt.compareTo(b.ringAt));
  return out;
});

/// Stats.
final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepositoryImpl(ref.watch(firestoreServiceProvider)),
);

/// Stats of one saff for the current and previous month.
final saffStatsProvider = StreamProvider.autoDispose.family<SaffStats, String>((
  ref,
  saffId,
) {
  final now = DateTime.now();
  final prev = DateTime(now.year, now.month - 1);
  String key(DateTime d) => '${d.year}${d.month.toString().padLeft(2, '0')}';
  return ref.watch(statsRepositoryProvider).watchSaff(saffId, [
    key(prev),
    key(now),
  ]);
});

/// The user's counters and badges.
final personalStatsProvider = StreamProvider<PersonalStats>((ref) {
  final uid = ref.watch(uidProvider).value;
  if (uid == null) return Stream.value(const PersonalStats());
  return ref.watch(statsRepositoryProvider).watchPersonal(uid);
});

/// Planting.
final plantRepositoryProvider = Provider<PlantRepository>(
  (ref) => PlantRepositoryImpl(
    ref.watch(functionsServiceProvider),
    ref.watch(failureMapperProvider),
  ),
);
