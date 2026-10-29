import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';

/// Registers this device's FCM token once signed in and keeps it fresh.
/// Watched from the app shell.
final deviceRegistrationProvider = Provider<void>((ref) {
  final uid = ref.watch(uidProvider).value;
  if (uid == null) return;
  final repo = ref.read(saffRepositoryProvider);
  final messaging = FirebaseMessaging.instance;

  Future<void> register(String? token) async {
    if (token == null) return;
    await repo.registerDevice(uid, token);
  }

  unawaited(() async {
    await messaging.requestPermission();
    await register(await messaging.getToken());
  }());
  final sub = messaging.onTokenRefresh.listen((t) => unawaited(register(t)));
  ref.onDispose(sub.cancel);
});
