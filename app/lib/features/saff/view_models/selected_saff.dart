import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_domain/saff_domain.dart';

/// The saff the Chat and Stats tabs show (`docs/ARCHITECTURE.md` §5a).
class SelectedSaff extends Notifier<String?> {
  @override
  String? build() => null;

  /// Switches to [id].
  void select(String id) => state = id;
}

/// Provider of the explicitly selected saff id.
final selectedSaffIdProvider = NotifierProvider<SelectedSaff, String?>(
  SelectedSaff.new,
);

/// The selected saff, falling back to the first one.
final selectedSaffProvider = Provider<Saff?>((ref) {
  final saffs = ref.watch(mySaffsProvider).value ?? const <Saff>[];
  if (saffs.isEmpty) return null;
  final id = ref.watch(selectedSaffIdProvider);
  return saffs.firstWhere((s) => s.id == id, orElse: () => saffs.first);
});
