import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:saff_app/config/environment_config.dart';

/// Initialises Firebase for the current isolate (main app, wake engine or the
/// background push handler) and points it at the emulators when configured.
///
/// Safe to call more than once: the native Firebase app is process-wide, so
/// a second engine finds it already started.
Future<void> initFirebase(
  EnvironmentConfig config,
  FirebaseOptions options,
) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
  if (!config.useEmulators) return;
  final host = config.emulatorHost;
  // Each call throws if the SDK was already used in this process (another
  // engine got there first); that means the emulator is already wired.
  try {
    await FirebaseAuth.instance.useAuthEmulator(host, EmulatorPorts.auth);
  } on Object catch (_) {}
  try {
    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      EmulatorPorts.firestore,
    );
  } on Object catch (_) {}
  try {
    FirebaseFunctions.instance.useFunctionsEmulator(
      host,
      EmulatorPorts.functions,
    );
  } on Object catch (_) {}
  try {
    await FirebaseStorage.instance.useStorageEmulator(
      host,
      EmulatorPorts.storage,
    );
  } on Object catch (_) {}
}
