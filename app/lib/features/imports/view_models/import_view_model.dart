import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/data/repositories/import_repository.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/auth/view_models/auth_view_model.dart';
import 'package:saff_core/saff_core.dart';

/// Imported packs of a saff.
final packsProvider = StreamProvider.autoDispose
    .family<List<ImportedPack>, String>(
      (ref, saffId) => ref.watch(importRepositoryProvider).watchPacks(saffId),
    );

/// State of the import flow.
class ImportFlowState extends ActionState {
  /// Creates the state.
  const ImportFlowState({super.running, super.failure, this.importId});

  /// The import being tracked.
  final String? importId;
}

/// Pick a file, upload it, follow the server's parsing.
class ImportViewModel extends Notifier<ImportFlowState> {
  @override
  ImportFlowState build() => const ImportFlowState();

  /// Picks and uploads a deck for [saffId].
  Future<void> pickAndUpload(String saffId) async {
    final uid = ref.read(uidProvider).value;
    if (uid == null) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['apkg', 'txt', 'csv', 'tsv', 'colpkg'],
    );
    final file = picked?.files.firstOrNull;
    if (file?.path == null) return;
    state = const ImportFlowState(running: true);
    final r = await ref
        .read(importRepositoryProvider)
        .upload(
          uid: uid,
          saffId: saffId,
          fileName: file!.name,
          path: file.path!,
        );
    state = switch (r) {
      Ok(:final value) => ImportFlowState(importId: value),
      Err(:final failure) => ImportFlowState(failure: failure),
    };
  }

  /// Switches the custom mix.
  Future<void> setCustomMix(String saffId, {required bool on}) async {
    final r = await ref
        .read(importRepositoryProvider)
        .setCustomMix(saffId, on: on);
    state = ImportFlowState(
      importId: state.importId,
      failure: r is Err<void> ? r.failure : null,
    );
  }

  /// Deletes a pack.
  Future<void> delete(String saffId, String packId) =>
      ref.read(importRepositoryProvider).deletePack(saffId, packId);
}

/// Provider of [ImportViewModel].
final importViewModelProvider =
    NotifierProvider<ImportViewModel, ImportFlowState>(ImportViewModel.new);

/// Live status of the current import.
final importStatusProvider = StreamProvider.autoDispose<ImportStatus?>((ref) {
  final id = ref.watch(importViewModelProvider).importId;
  if (id == null) return Stream.value(null);
  return ref.watch(importRepositoryProvider).watchStatus(id);
});
