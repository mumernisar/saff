import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:saff_app/data/services/firebase_services.dart';
import 'package:saff_core/saff_core.dart';

/// State of one import as the server reports it.
class ImportStatus {
  /// Creates the status.
  const ImportStatus({
    required this.status,
    this.errorCode,
    this.cards = 0,
    this.warnings = const [],
    this.sample = const [],
  });

  /// `uploaded`, `parsing`, `done` or `failed`.
  final String status;

  /// Catalog code on failure.
  final String? errorCode;

  /// Cards found.
  final int cards;

  /// Warning codes.
  final List<String> warnings;

  /// First few cards.
  final List<({String question, String answer})> sample;
}

/// An imported pack of a saff.
class ImportedPack {
  /// Creates the pack.
  const ImportedPack({
    required this.id,
    required this.title,
    required this.cardCount,
    required this.createdBy,
  });

  /// Pack id.
  final String id;

  /// Title.
  final String title;

  /// Cards.
  final int cardCount;

  /// Importer uid.
  final String createdBy;
}

/// Anki imports and the saff's card mix.
abstract interface class ImportRepository {
  /// Uploads [path] and returns the import id.
  Future<Result<String>> upload({
    required String uid,
    required String saffId,
    required String fileName,
    required String path,
  });

  /// Live status of an import.
  Stream<ImportStatus?> watchStatus(String importId);

  /// Imported packs of a saff, live.
  Stream<List<ImportedPack>> watchPacks(String saffId);

  /// Deletes a pack.
  Future<Result<void>> deletePack(String saffId, String packId);

  /// Turns the custom card mix on or off.
  Future<Result<void>> setCustomMix(String saffId, {required bool on});
}

/// [ImportRepository] over Storage, Firestore and callables.
final class ImportRepositoryImpl implements ImportRepository {
  /// Creates the repository.
  const ImportRepositoryImpl(this._fs, this._fn, this._mapper);

  final FirestoreService _fs;
  final FunctionsService _fn;
  final FailureMapper _mapper;

  @override
  Future<Result<String>> upload({
    required String uid,
    required String saffId,
    required String fileName,
    required String path,
  }) => Result.guard(
    () async {
      final ref = _fs.db.collection('imports').doc();
      await ref.set({
        'uid': uid,
        'saffId': saffId,
        'fileName': fileName,
        'status': 'uploaded',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseStorage.instance
          .ref('imports/$uid/${ref.id}')
          .putFile(File(path));
      return ref.id;
    },
    _mapper,
    context: const {'op': 'uploadImport'},
  );

  @override
  Stream<ImportStatus?> watchStatus(String importId) =>
      _fs.db.doc('imports/$importId').snapshots().map((d) {
        if (!d.exists) return null;
        final m = d.data()!;
        return ImportStatus(
          status: (m['status'] as String?) ?? 'uploaded',
          errorCode: m['errorCode'] as String?,
          cards: (((m['counts'] as Map?)?['cards']) as num?)?.toInt() ?? 0,
          warnings: ((m['warnings'] as List?) ?? const [])
              .map((e) => '$e')
              .toList(),
          sample: [
            for (final s in (m['sample'] as List?) ?? const [])
              (
                question: '${(s as Map)['question']}',
                answer: '${s['answer']}',
              ),
          ],
        );
      });

  @override
  Stream<List<ImportedPack>> watchPacks(String saffId) => _fs.db
      .collection('saffs/$saffId/packs')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            ImportedPack(
              id: d.id,
              title: (d.data()['title'] as String?) ?? '',
              cardCount: (d.data()['cardCount'] as num?)?.toInt() ?? 0,
              createdBy: (d.data()['createdBy'] as String?) ?? '',
            ),
        ],
      );

  @override
  Future<Result<void>> deletePack(String saffId, String packId) => Result.guard(
    () => _fn.call('deletePack', {'saffId': saffId, 'packId': packId}),
    _mapper,
    context: const {'op': 'deletePack'},
  );

  @override
  Future<Result<void>> setCustomMix(String saffId, {required bool on}) =>
      Result.guard(
        () => _fn.call('updateSaffSettings', {
          'saffId': saffId,
          'cardMix': {'custom': on},
        }),
        _mapper,
        context: const {'op': 'setCustomMix'},
      );
}
