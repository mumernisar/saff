import 'package:flutter_test/flutter_test.dart';
import 'package:saff_app/config/environment_config.dart';
import 'package:saff_app/data/errors/failure_mapper_factory.dart';
import 'package:saff_app/data/repositories/emulator_status_repository.dart';
import 'package:saff_app/data/services/emulator_probe_service.dart';
import 'package:saff_core/saff_core.dart';

import 'support/pump_app.dart';

class ThrowingProbe implements EmulatorProbeService {
  @override
  Future<bool> isReachable(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 2),
  }) => throw const FormatException('bad');
}

void main() {
  final config = devConfig(emulators: true);

  test('reports each emulator as reachable or not', () async {
    final repo = EmulatorStatusRepositoryImpl(
      FakeProbe({EmulatorPorts.auth, EmulatorPorts.firestore}),
      config,
      buildFailureMapper(),
    );
    final reaches = (await repo.check()).getOrNull()!;
    expect(
      {for (final r in reaches) r.name: r.reachable},
      {'Auth': true, 'Firestore': true, 'Functions': false, 'Storage': false},
    );
  });

  test('turns an exception into a failure instead of throwing', () async {
    final repo = EmulatorStatusRepositoryImpl(
      ThrowingProbe(),
      config,
      buildFailureMapper(),
    );
    final result = await repo.check();
    expect((result as Err).failure.code, FailureCode.dataMalformed);
  });
}
