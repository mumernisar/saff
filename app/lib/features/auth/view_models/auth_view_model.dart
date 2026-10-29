import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_core/saff_core.dart';

/// State of an action that can fail (`docs/ARCHITECTURE.md` §3.2).
class ActionState {
  /// Creates the state.
  const ActionState({this.running = false, this.failure});

  /// Whether the action is in flight.
  final bool running;

  /// The failure of the last run.
  final AppFailure? failure;
}

/// Sign-in and sign-out actions.
class AuthViewModel extends Notifier<ActionState> {
  @override
  ActionState build() => const ActionState();

  /// Signs in as a seeded dev test user.
  Future<void> signInTestUser(String name) async {
    state = const ActionState(running: true);
    final r = await ref.read(authRepositoryProvider).signInTestUser(name);
    state = ActionState(failure: r is Err<void> ? r.failure : null);
  }

  /// Signs out.
  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();

  /// Deletes the account; the server removes the Auth user, so the session ends.
  Future<void> deleteAccount() async {
    state = const ActionState(running: true);
    final r = await ref.read(saffRepositoryProvider).deleteAccount();
    state = ActionState(failure: r is Err<void> ? r.failure : null);
    if (r is Ok<void>) await ref.read(authRepositoryProvider).signOut();
  }
}

/// Provider of [AuthViewModel].
final authViewModelProvider = NotifierProvider<AuthViewModel, ActionState>(
  AuthViewModel.new,
);

/// Profile creation.
class ProfileViewModel extends Notifier<ActionState> {
  @override
  ActionState build() => const ActionState();

  /// Saves the profile.
  Future<bool> save(String name, String whatsapp, {int? avatarColor}) async {
    state = const ActionState(running: true);
    final r = await ref
        .read(saffRepositoryProvider)
        .setProfile(
          displayName: name.trim(),
          whatsapp: whatsapp.trim(),
          avatarColor: avatarColor,
        );
    state = ActionState(failure: r is Err<void> ? r.failure : null);
    return r is Ok<void>;
  }
}

/// Provider of [ProfileViewModel].
final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, ActionState>(ProfileViewModel.new);
