import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';

/// Dev-only crash trigger (`docs/DEV_RELAXATIONS.md` R-10).
class CrashTestViewModel {
  /// Creates the view model.
  const CrashTestViewModel({required bool enabled}) : available = enabled;

  /// Whether the trigger exists in this build.
  final bool available;

  /// Throws a [StateError] on purpose so it reaches the global handlers.
  void triggerTestCrash() {
    if (!available) return;
    throw StateError('Test crash from Settings (dev flavor)');
  }
}

/// Provider of [CrashTestViewModel]; enabled only in the dev flavor.
final crashTestProvider = Provider<CrashTestViewModel>(
  (ref) =>
      CrashTestViewModel(enabled: ref.watch(environmentConfigProvider).isDev),
);
