import 'package:saff_app/data/services/firebase_services.dart';
import 'package:saff_core/saff_core.dart';

/// Who is signed in.
abstract interface class AuthRepository {
  /// The signed-in uid; null when signed out.
  Stream<String?> uid();

  /// The current uid, if any.
  String? get currentUid;

  /// Dev test-user sign-in (`docs/DEV_RELAXATIONS.md` R-2).
  Future<Result<void>> signInTestUser(String name);

  /// Signs out.
  Future<Result<void>> signOut();
}

/// [AuthRepository] over [AuthService].
final class AuthRepositoryImpl implements AuthRepository {
  /// Creates the repository.
  const AuthRepositoryImpl(this._auth, this._mapper);

  final AuthService _auth;
  final FailureMapper _mapper;

  @override
  Stream<String?> uid() => _auth.uidChanges();

  @override
  String? get currentUid => _auth.uid;

  @override
  Future<Result<void>> signInTestUser(String name) => Result.guard(
    () => _auth.signInWithPassword(
      '${name.toLowerCase()}@test.saff',
      'password1',
    ),
    _mapper,
    context: const {'op': 'signInTestUser'},
  );

  @override
  Future<Result<void>> signOut() =>
      Result.guard(_auth.signOut, _mapper, context: const {'op': 'signOut'});
}
