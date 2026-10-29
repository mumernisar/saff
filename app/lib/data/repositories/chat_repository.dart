import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saff_app/data/dto/mappers.dart';
import 'package:saff_app/data/services/firebase_services.dart';
import 'package:saff_core/saff_core.dart';
import 'package:saff_domain/saff_domain.dart';

/// Chat of one saff.
abstract interface class ChatRepository {
  /// Latest [limit] messages, newest first.
  Stream<List<ChatMessage>> watch(String saffId, {int limit = 50});

  /// Sends a text message.
  Future<Result<void>> send(
    String saffId,
    String uid,
    String text, {
    String? replyToId,
  });

  /// Marks [ids] as seen by [uid].
  Future<Result<void>> markSeen(String saffId, String uid, List<String> ids);

  /// Soft-deletes an own message (within one hour).
  Future<Result<void>> delete(String saffId, String messageId);

  /// Updates the own presence field of the member doc.
  Future<Result<void>> setPresence(
    String saffId,
    String uid, {
    required bool online,
  });
}

/// [ChatRepository] over Firestore.
final class ChatRepositoryImpl implements ChatRepository {
  /// Creates the repository.
  const ChatRepositoryImpl(this._fs, this._mapper);

  final FirestoreService _fs;
  final FailureMapper _mapper;

  @override
  Stream<List<ChatMessage>> watch(String saffId, {int limit = 50}) => _fs.db
      .collection('saffs/$saffId/messages')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.docs.map(messageFrom).toList());

  @override
  Future<Result<void>> send(
    String saffId,
    String uid,
    String text, {
    String? replyToId,
  }) =>
      Result.guard(
        () async {
          // Not awaited to completion offline: the write queues and the
          // snapshot shows it as pending.
          await _fs.db
              .collection('saffs/$saffId/messages')
              .add({
                'type': 'text',
                'authorId': uid,
                'text': text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
                'seenBy': <String, Object?>{},
                'replyToId': ?replyToId,
              })
              .timeout(
                const Duration(seconds: 3),
                onTimeout: () => throw _Queued(),
              );
        },
        _mapper,
        context: const {'op': 'sendMessage'},
      ).then(
        (r) => r.fold(
          ok: (_) => r,
          err: (f) => f.cause is _Queued ? const Result.ok(null) : r,
        ),
      );

  @override
  Future<Result<void>> markSeen(
    String saffId,
    String uid,
    List<String> ids,
  ) => Result.guard(
    () async {
      final batch = _fs.db.batch();
      for (final id in ids) {
        batch.update(_fs.db.doc('saffs/$saffId/messages/$id'), {
          'seenBy.$uid': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    },
    _mapper,
    context: const {'op': 'markSeen'},
  );

  @override
  Future<Result<void>> delete(String saffId, String messageId) => Result.guard(
    () => _fs.db.doc('saffs/$saffId/messages/$messageId').update({
      'deletedAt': FieldValue.serverTimestamp(),
    }),
    _mapper,
    context: const {'op': 'deleteMessage'},
  );

  @override
  Future<Result<void>> setPresence(
    String saffId,
    String uid, {
    required bool online,
  }) => Result.guard(
    () => _fs.db.doc('saffs/$saffId/members/$uid').update({
      'presence': {
        'online': online,
        'lastSeenAt': FieldValue.serverTimestamp(),
      },
    }),
    _mapper,
    context: const {'op': 'setPresence'},
  );
}

class _Queued implements Exception {}
