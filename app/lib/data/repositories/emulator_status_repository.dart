import 'package:saff_app/config/environment_config.dart';
import 'package:saff_app/data/services/emulator_probe_service.dart';
import 'package:saff_core/saff_core.dart';

/// Reachability of one emulator.
typedef EmulatorReach = ({String name, int port, bool reachable});

/// Reports whether the Firebase emulators answer (dev builds only).
// ignore: one_member_abstracts
abstract interface class EmulatorStatusRepository {
  /// Probes every emulator.
  Future<Result<List<EmulatorReach>>> check();
}

/// [EmulatorStatusRepository] backed by an emulator probe service.
final class EmulatorStatusRepositoryImpl implements EmulatorStatusRepository {
  /// Creates the repository for the config.
  const EmulatorStatusRepositoryImpl(this._probe, this._config, this._mapper);

  final EmulatorProbeService _probe;
  final EnvironmentConfig _config;
  final FailureMapper _mapper;

  static const _targets = <(String, int)>[
    ('Auth', EmulatorPorts.auth),
    ('Firestore', EmulatorPorts.firestore),
    ('Functions', EmulatorPorts.functions),
    ('Storage', EmulatorPorts.storage),
  ];

  @override
  Future<Result<List<EmulatorReach>>> check() => Result.guard(
    () async => [
      for (final (name, port) in _targets)
        (
          name: name,
          port: port,
          reachable: await _probe.isReachable(_config.emulatorHost, port),
        ),
    ],
    _mapper,
    context: const {'op': 'checkEmulators'},
  );
}
