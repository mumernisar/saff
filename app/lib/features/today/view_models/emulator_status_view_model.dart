import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/data/repositories/emulator_status_repository.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_core/saff_core.dart';

/// Emulator reachability for the Today placeholder; null when the build does
/// not use emulators.
class EmulatorStatusViewModel extends AsyncNotifier<List<EmulatorReach>?> {
  @override
  Future<List<EmulatorReach>?> build() async {
    final config = ref.watch(environmentConfigProvider);
    if (!config.useEmulators) return null;
    final result = await ref.watch(emulatorStatusRepositoryProvider).check();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }

  /// Probes again.
  Future<void> recheck() async {
    state = const AsyncLoading();
    ref.invalidateSelf();
    await future;
  }
}

/// Provider of [EmulatorStatusViewModel].
final emulatorStatusProvider =
    AsyncNotifierProvider<EmulatorStatusViewModel, List<EmulatorReach>?>(
      EmulatorStatusViewModel.new,
    );
