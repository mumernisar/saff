import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:saff_app/data/dto/mappers.dart';
import 'package:saff_app/data/services/firebase_services.dart';
import 'package:saff_core/saff_core.dart';
import 'package:saff_domain/saff_domain.dart';

/// Rounds, results, live status and the reveal.
abstract interface class RoundRepository {
  /// A locked round (from cache when offline); null if absent.
  Future<Result<Round?>> getRound(String saffId, String occurrenceId);

  /// Live round document (status flips to revealed).
  Stream<Round?> watchRound(String saffId, String occurrenceId);

  /// Live statuses of every member.
  Stream<Map<String, LiveStatus>> watchPresence(
    String saffId,
    String occurrenceId,
  );

  /// Writes the own status.
  Future<Result<void>> setStatus(
    String saffId,
    String occurrenceId,
    String uid,
    LiveStatus status,
  );

  /// Writes the result once; Firestore queues it offline.
  Future<Result<void>> submitResult(
    String saffId,
    String occurrenceId,
    String uid, {
    required List<CardAnswer> answers,
    required int wakeMs,
    required bool snoozed,
    required bool offlineFallback,
    int? arcadeScore,
  });

  /// The planter's grade for an ask-me card.
  Future<Result<void>> gradeAskMe(
    String saffId,
    String occurrenceId,
    String cardId, {
    required bool correct,
  });

  /// Live ask-me grades: card id → correct.
  Stream<Map<String, bool>> watchAskMeGrades(
    String saffId,
    String occurrenceId,
  );

  /// Compresses and uploads the selfie, then records it.
  Future<Result<void>> uploadSelfie(
    String saffId,
    String occurrenceId,
    String uid,
    String path, {
    required int msFromRing,
  });

  /// Downloads a selfie's bytes (members, after the reveal).
  Future<Result<Uint8List?>> selfieBytes(String storagePath);

  /// Live reveal; null until revealed.
  Stream<Reveal?> watchReveal(String saffId, String occurrenceId);

  /// Rings [targetUid] again; returns the nudges left.
  Future<Result<int>> nudge(
    String saffId,
    String occurrenceId,
    String targetUid,
  );

  /// Live nudges the caller sent, per target.
  Stream<Map<String, ({int count, DateTime? last})>> watchSentNudges(
    String saffId,
    String occurrenceId,
    String uid,
  );
}

/// [RoundRepository] over Firestore and callables.
final class RoundRepositoryImpl implements RoundRepository {
  /// Creates the repository.
  const RoundRepositoryImpl(this._fs, this._fn, this._mapper);

  final FirestoreService _fs;
  final FunctionsService _fn;
  final FailureMapper _mapper;

  DocumentReference<Map<String, dynamic>> _round(String s, String o) =>
      _fs.db.doc('saffs/$s/rounds/$o');

  @override
  Future<Result<Round?>> getRound(String saffId, String occurrenceId) =>
      Result.guard(
        () async {
          final d = await _round(saffId, occurrenceId).get();
          return d.exists ? roundFrom(saffId, d) : null;
        },
        _mapper,
        context: const {'op': 'getRound'},
      );

  @override
  Stream<Round?> watchRound(String saffId, String occurrenceId) =>
      _round(saffId, occurrenceId).snapshots().map(
        (d) => d.exists ? roundFrom(saffId, d) : null,
      );

  @override
  Stream<Map<String, LiveStatus>> watchPresence(
    String saffId,
    String occurrenceId,
  ) => _round(saffId, occurrenceId)
      .collection('presence')
      .snapshots()
      .map(
        (s) => {
          for (final d in s.docs)
            d.id: LiveStatus.parse(d.data()['status'] as String?),
        },
      );

  @override
  Future<Result<void>> setStatus(
    String saffId,
    String occurrenceId,
    String uid,
    LiveStatus status,
  ) => Result.guard(
    () => _round(saffId, occurrenceId).collection('presence').doc(uid).set({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
    _mapper,
    context: const {'op': 'setStatus'},
  );

  @override
  Future<Result<void>> submitResult(
    String saffId,
    String occurrenceId,
    String uid, {
    required List<CardAnswer> answers,
    required int wakeMs,
    required bool snoozed,
    required bool offlineFallback,
    int? arcadeScore,
  }) => Result.guard(
    () {
      // Deterministic id (uid): a retry overwrites instead of duplicating.
      // Not awaited: offline it queues in Firestore and syncs later.
      final write = _round(saffId, occurrenceId)
          .collection('results')
          .doc(uid)
          .set({
            'answers': answers.map((a) => a.toMap()).toList(),
            'wakeMs': wakeMs,
            'snoozed': snoozed,
            'offlineFallback': offlineFallback,
            if (arcadeScore != null) 'arcadeScore': arcadeScore,
            'finishedAt': FieldValue.serverTimestamp(),
            'clientVersion': 1,
          });
      return write.timeout(const Duration(seconds: 4), onTimeout: () {});
    },
    _mapper,
    context: const {'op': 'submitResult'},
  );

  @override
  Future<Result<void>> gradeAskMe(
    String saffId,
    String occurrenceId,
    String cardId, {
    required bool correct,
  }) => Result.guard(
    () => _fn.call('gradeAskMe', {
      'saffId': saffId,
      'occurrenceId': occurrenceId,
      'cardId': cardId,
      'correct': correct,
    }),
    _mapper,
    context: const {'op': 'gradeAskMe'},
  );

  @override
  Stream<Map<String, bool>> watchAskMeGrades(
    String saffId,
    String occurrenceId,
  ) => _round(saffId, occurrenceId)
      .collection('askMeGrades')
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: d.data()['correct'] == true});

  @override
  Future<Result<void>> uploadSelfie(
    String saffId,
    String occurrenceId,
    String uid,
    String path, {
    required int msFromRing,
  }) => Result.guard(
    () async {
      final decoded = img.decodeImage(await File(path).readAsBytes());
      if (decoded == null) throw const FormatException('selfie');
      final long = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      final scaled = long > 1080
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? 1080 : null,
              height: decoded.height > decoded.width ? 1080 : null,
            )
          : decoded;
      final bytes = Uint8List.fromList(img.encodeJpg(scaled, quality: 80));
      final storagePath = 'saffs/$saffId/rounds/$occurrenceId/$uid.jpg';
      await FirebaseStorage.instance
          .ref(storagePath)
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      await _round(saffId, occurrenceId).collection('selfies').doc(uid).set({
        'storagePath': storagePath,
        'takenAt': FieldValue.serverTimestamp(),
        'msFromRing': msFromRing,
        'width': scaled.width,
        'height': scaled.height,
      });
    },
    _mapper,
    context: const {'op': 'uploadSelfie'},
  );

  @override
  Future<Result<Uint8List?>> selfieBytes(String storagePath) => Result.guard(
    () => FirebaseStorage.instance.ref(storagePath).getData(1024 * 1024),
    _mapper,
    context: const {'op': 'selfieBytes'},
  );

  @override
  Stream<Reveal?> watchReveal(String saffId, String occurrenceId) =>
      _round(saffId, occurrenceId)
          .collection('reveal')
          .doc('summary')
          .snapshots()
          .map((d) => d.exists ? revealFrom(d) : null);

  @override
  Future<Result<int>> nudge(
    String saffId,
    String occurrenceId,
    String targetUid,
  ) => Result.guard(
    () async {
      final r = await _fn.call('nudge', {
        'saffId': saffId,
        'occurrenceId': occurrenceId,
        'targetUid': targetUid,
      });
      return (r['left'] as num?)?.toInt() ?? 0;
    },
    _mapper,
    context: const {'op': 'nudge'},
  );

  @override
  Stream<Map<String, ({int count, DateTime? last})>> watchSentNudges(
    String saffId,
    String occurrenceId,
    String uid,
  ) => _round(saffId, occurrenceId)
      .collection('nudges')
      .where('fromId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final out = <String, ({int count, DateTime? last})>{};
        for (final d in s.docs) {
          final to = '${d.data()['toId']}';
          final at = d.data()['at'];
          final prev = out[to];
          final when = at is Timestamp ? at.toDate() : null;
          out[to] = (
            count: (prev?.count ?? 0) + 1,
            last:
                (prev?.last != null &&
                    when != null &&
                    prev!.last!.isAfter(when))
                ? prev.last
                : when ?? prev?.last,
          );
        }
        return out;
      });
}
