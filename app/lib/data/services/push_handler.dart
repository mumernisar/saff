import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:saff_alarm/saff_alarm.dart';
import 'package:saff_app/config/environment_config.dart';
import 'package:saff_app/config/firebase_options_dev.dart' as dev;
import 'package:saff_app/config/firebase_options_prod.dart' as prod;
import 'package:saff_app/data/services/firebase_init.dart';

/// Background / terminated-state push entrypoint (`docs/BACKEND.md` §7).
///
/// - `nudge`: re-rings the alarm through the native module, no UI needed.
/// - `roundLocked`: reads the round once so Firestore's offline cache holds it
///   for the morning.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  switch (data['type']) {
    case 'nudge':
      await AlarmHostApi().ringNow(
        RingReason.nudge,
        data['occurrenceId'] as String?,
        '${data['fromName'] ?? ''} rang you again',
      );
    case 'roundLocked':
      final config = EnvironmentConfig.fromBuildFlavor();
      await initFirebase(
        config,
        config.isDev
            ? dev.DefaultFirebaseOptions.currentPlatform
            : prod.DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseFirestore.instance
          .doc('saffs/${data['saffId']}/rounds/${data['occurrenceId']}')
          .get();
  }
}

/// Whether [Firebase] was already started in this isolate (for tests).
bool get firebaseStarted => Firebase.apps.isNotEmpty;
