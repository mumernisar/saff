import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Wraps Firebase Auth. May throw; repositories map.
class AuthService {
  /// Creates the service.
  AuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// The signed-in uid, emitted on every auth change.
  Stream<String?> uidChanges() => _auth.authStateChanges().map((u) => u?.uid);

  /// The current uid, if signed in.
  String? get uid => _auth.currentUser?.uid;

  /// The current user's email, if any.
  String? get email => _auth.currentUser?.email;

  /// Signs in with email and password, creating the account when missing
  /// (dev test users only, `docs/DEV_RELAXATIONS.md` R-2).
  Future<void> signInWithPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found' &&
          e.code != 'invalid-credential' &&
          e.code != 'invalid-login-credentials') {
        rethrow;
      }
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  /// Signs out.
  Future<void> signOut() => _auth.signOut();
}

/// Wraps callable Cloud Functions.
class FunctionsService {
  /// Creates the service.
  FunctionsService([FirebaseFunctions? functions])
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Calls [name] with [data] and returns the response map.
  Future<Map<String, Object?>> call(
    String name, [
    Map<String, Object?> data = const {},
  ]) async {
    final result = await _functions.httpsCallable(name).call<Object?>(data);
    final out = result.data;
    return out is Map ? out.cast<String, Object?>() : const {};
  }
}

/// Gives repositories the Firestore instance.
class FirestoreService {
  /// Creates the service.
  FirestoreService([FirebaseFirestore? db])
    : db = db ?? FirebaseFirestore.instance;

  /// The Firestore instance.
  final FirebaseFirestore db;
}
