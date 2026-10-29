import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saff_app/data/dto/mappers.dart';
import 'package:saff_app/data/services/firebase_services.dart';
import 'package:saff_core/saff_core.dart';
import 'package:saff_domain/saff_domain.dart';

/// Profile, saffs and members.
abstract interface class SaffRepository {
  /// The user's profile; null until it is created.
  Stream<Profile?> watchProfile(String uid);

  /// Creates or updates the profile and contact number.
  Future<Result<void>> setProfile({
    required String displayName,
    required String whatsapp,
    int? avatarColor,
  });

  /// The saffs with [ids], live.
  Stream<List<Saff>> watchSaffs(List<String> ids);

  /// One saff, live.
  Stream<Saff?> watchSaff(String id);

  /// Members of a saff, live.
  Stream<List<Member>> watchMembers(String saffId);

  /// Creates a saff.
  Future<Result<({String saffId, String inviteCode})>> create({String? name});

  /// Looks an invite code up for the confirmation screen.
  Future<Result<InvitePreview>> preview(String code);

  /// Joins by code.
  Future<Result<String>> join(String code);

  /// Leaves a saff.
  Future<Result<void>> leave(String saffId);

  /// Removes a member (owner).
  Future<Result<void>> removeMember(String saffId, String uid);

  /// New invite code (owner).
  Future<Result<String>> regenerateInvite(String saffId);

  /// Renames a saff (owner).
  Future<Result<void>> rename(String saffId, String name);

  /// Registers this device's FCM token.
  Future<Result<void>> registerDevice(String installationId, String token);

  /// Deletes the account and everything tied to it.
  Future<Result<void>> deleteAccount();

  /// Notification category switches of the user (`settings.notifications`).
  Stream<Map<String, bool>> watchNotificationSettings(String uid);

  /// Turns a notification category on or off.
  Future<Result<void>> setNotification(
    String uid,
    String key, {
    required bool on,
  });

  /// Sends feedback with optional failure details.
  Future<Result<void>> sendFeedback(String uid, String text, {String? details});
}

/// [SaffRepository] over Firestore and callables.
final class SaffRepositoryImpl implements SaffRepository {
  /// Creates the repository.
  const SaffRepositoryImpl(this._fs, this._fn, this._mapper);

  final FirestoreService _fs;
  final FunctionsService _fn;
  final FailureMapper _mapper;

  Future<Result<T>> _g<T>(String op, Future<T> Function() f) =>
      Result.guard(f, _mapper, context: {'op': op});

  @override
  Stream<Profile?> watchProfile(String uid) {
    final user = _fs.db.doc('users/$uid').snapshots();
    final contact = _fs.db.doc('users/$uid/private/contact').snapshots();
    return _combine2(user, contact, (u, c) {
      if (!u.exists) return null;
      final m = u.data()!;
      return Profile(
        uid: uid,
        displayName: (m['displayName'] as String?) ?? '',
        avatarColor: avatarIndex(m['avatarColor']),
        saffIds: strings(m['saffIds']),
        whatsapp: (c.data()?['whatsapp'] as String?) ?? '',
      );
    });
  }

  @override
  Future<Result<void>> setProfile({
    required String displayName,
    required String whatsapp,
    int? avatarColor,
  }) => _g(
    'setProfile',
    () => _fn.call('setProfile', {
      'displayName': displayName,
      'whatsapp': whatsapp,
      if (avatarColor != null) 'avatarColor': '$avatarColor',
    }),
  );

  @override
  Stream<List<Saff>> watchSaffs(List<String> ids) {
    if (ids.isEmpty) return Stream.value(const []);
    final streams = ids.map(
      (id) => _fs.db
          .doc('saffs/$id')
          .snapshots()
          .map(
            (d) => d.exists ? saffFrom(d) : null,
          ),
    );
    return _combineAll<Saff?>(streams.toList()).map(
      (l) => l.whereType<Saff>().toList(),
    );
  }

  @override
  Stream<Saff?> watchSaff(String id) => _fs.db
      .doc('saffs/$id')
      .snapshots()
      .map((d) => d.exists ? saffFrom(d) : null);

  @override
  Stream<List<Member>> watchMembers(String saffId) => _fs.db
      .collection('saffs/$saffId/members')
      .snapshots()
      .map((s) => s.docs.map(memberFrom).toList());

  @override
  Future<Result<({String saffId, String inviteCode})>> create({
    String? name,
  }) => _g('createSaff', () async {
    final r = await _fn.call('createSaff', {'name': ?name});
    return (saffId: '${r['saffId']}', inviteCode: '${r['inviteCode']}');
  });

  @override
  Future<Result<InvitePreview>> preview(String code) => _g(
    'previewInvite',
    () async {
      final r = await _fn.call('previewInvite', {'code': code});
      return InvitePreview(
        saffId: '${r['saffId']}',
        name: '${r['name']}',
        ownerName: '${r['ownerName']}',
        memberCount: (r['memberCount']! as num).toInt(),
        memberLimit: (r['memberLimit']! as num).toInt(),
        members: [
          for (final m in (r['members']! as List).cast<Map<String, Object?>>())
            (name: '${m['name']}', avatarColor: avatarIndex(m['avatarColor'])),
        ],
      );
    },
  );

  @override
  Future<Result<String>> join(String code) => _g('joinSaff', () async {
    final r = await _fn.call('joinSaff', {'code': code});
    return '${r['saffId']}';
  });

  @override
  Future<Result<void>> leave(String saffId) =>
      _g('leaveSaff', () => _fn.call('leaveSaff', {'saffId': saffId}));

  @override
  Future<Result<void>> removeMember(String saffId, String uid) => _g(
    'removeMember',
    () => _fn.call('removeMember', {'saffId': saffId, 'uid': uid}),
  );

  @override
  Future<Result<String>> regenerateInvite(String saffId) =>
      _g('regenerateInvite', () async {
        final r = await _fn.call('regenerateInvite', {'saffId': saffId});
        return '${r['inviteCode']}';
      });

  @override
  Future<Result<void>> rename(String saffId, String name) => _g(
    'renameSaff',
    () => _fn.call('renameSaff', {'saffId': saffId, 'name': name}),
  );

  @override
  Stream<Map<String, bool>> watchNotificationSettings(String uid) =>
      _fs.db.doc('users/$uid').snapshots().map((d) {
        final n =
            ((d.data()?['settings'] as Map?)?['notifications'] as Map?) ??
            const {};
        return {for (final e in n.entries) '${e.key}': e.value == true};
      });

  @override
  Future<Result<void>> setNotification(
    String uid,
    String key, {
    required bool on,
  }) => _g(
    'setNotification',
    () => _fs.db.doc('users/$uid').update({'settings.notifications.$key': on}),
  );

  @override
  Future<Result<void>> sendFeedback(
    String uid,
    String text, {
    String? details,
  }) => _g(
    'sendFeedback',
    () => _fs.db.collection('feedback').add({
      'uid': uid,
      'text': text,
      if (details != null) 'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<Result<void>> deleteAccount() =>
      _g('deleteAccount', () => _fn.call('deleteAccount'));

  @override
  Future<Result<void>> registerDevice(String installationId, String token) =>
      _g(
        'registerDevice',
        () => _fn.call('registerDevice', {
          'installationId': installationId,
          'fcmToken': token,
        }),
      );
}

/// Combines two streams, emitting when both have a value.
Stream<R> _combine2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) f,
) {
  late StreamController<R> c;
  StreamSubscription<A>? sa;
  StreamSubscription<B>? sb;
  A? la;
  B? lb;
  var ha = false;
  var hb = false;
  void emit() {
    if (ha && hb) c.add(f(la as A, lb as B));
  }

  c = StreamController<R>(
    onListen: () {
      sa = a.listen((v) {
        la = v;
        ha = true;
        emit();
      }, onError: c.addError);
      sb = b.listen((v) {
        lb = v;
        hb = true;
        emit();
      }, onError: c.addError);
    },
    onCancel: () async {
      await sa?.cancel();
      await sb?.cancel();
    },
  );
  return c.stream;
}

/// Combines many streams into the list of their latest values.
Stream<List<T>> _combineAll<T>(List<Stream<T>> streams) {
  late StreamController<List<T>> c;
  final subs = <StreamSubscription<T>>[];
  final latest = List<T?>.filled(streams.length, null);
  final has = List<bool>.filled(streams.length, false);
  c = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subs.add(
          streams[i].listen((v) {
            latest[i] = v;
            has[i] = true;
            if (has.every((h) => h)) c.add([for (final x in latest) x as T]);
          }, onError: c.addError),
        );
      }
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return c.stream;
}

/// Public helper for other repositories.
Stream<List<T>> combineLatestAll<T>(List<Stream<T>> streams) =>
    streams.isEmpty ? Stream.value(const []) : _combineAll(streams);
