import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/auth/view_models/auth_view_model.dart';
import 'package:saff_core/saff_core.dart';
import 'package:saff_domain/saff_domain.dart';

/// State of the create / join flows.
class SaffFlowState {
  /// Creates the state.
  const SaffFlowState({
    this.running = false,
    this.failure,
    this.preview,
    this.createdSaffId,
    this.inviteCode,
    this.joinedSaffId,
  });

  /// Whether a call is in flight.
  final bool running;

  /// Last failure.
  final AppFailure? failure;

  /// The invite being confirmed.
  final InvitePreview? preview;

  /// The saff just created.
  final String? createdSaffId;

  /// Its invite code.
  final String? inviteCode;

  /// The saff just joined.
  final String? joinedSaffId;
}

/// Create, preview and join.
class SaffFlowViewModel extends Notifier<SaffFlowState> {
  @override
  SaffFlowState build() => const SaffFlowState();

  /// Creates a saff.
  Future<void> create({String? name}) async {
    state = const SaffFlowState(running: true);
    final r = await ref.read(saffRepositoryProvider).create(name: name);
    state = switch (r) {
      Ok(:final value) => SaffFlowState(
        createdSaffId: value.saffId,
        inviteCode: value.inviteCode,
      ),
      Err(:final failure) => SaffFlowState(failure: failure),
    };
  }

  /// Looks [code] up for the confirmation screen.
  Future<void> preview(String code) async {
    state = const SaffFlowState(running: true);
    final r = await ref
        .read(saffRepositoryProvider)
        .preview(code.trim().toUpperCase());
    state = switch (r) {
      Ok(:final value) => SaffFlowState(preview: value),
      Err(:final failure) => SaffFlowState(failure: failure),
    };
  }

  /// Joins the previewed saff.
  Future<void> join(String code) async {
    final preview = state.preview;
    state = SaffFlowState(running: true, preview: preview);
    final r = await ref
        .read(saffRepositoryProvider)
        .join(code.trim().toUpperCase());
    state = switch (r) {
      Ok(:final value) => SaffFlowState(joinedSaffId: value),
      Err(:final failure) => SaffFlowState(failure: failure, preview: preview),
    };
  }

  /// Clears the state.
  void reset() => state = const SaffFlowState();
}

/// Provider of [SaffFlowViewModel].
final NotifierProvider<SaffFlowViewModel, SaffFlowState> saffFlowProvider =
    NotifierProvider.autoDispose<SaffFlowViewModel, SaffFlowState>(
      SaffFlowViewModel.new,
    );

/// Owner and member actions on one saff.
class SaffManageViewModel extends Notifier<ActionState> {
  @override
  ActionState build() => const ActionState();

  Future<bool> _run(Future<Result<Object?>> Function() f) async {
    state = const ActionState(running: true);
    final r = await f();
    state = ActionState(failure: r is Err<Object?> ? r.failure : null);
    return r is Ok<Object?>;
  }

  /// Leaves the saff.
  Future<bool> leave(String saffId) =>
      _run(() => ref.read(saffRepositoryProvider).leave(saffId));

  /// Removes a member.
  Future<bool> remove(String saffId, String uid) =>
      _run(() => ref.read(saffRepositoryProvider).removeMember(saffId, uid));

  /// New invite code.
  Future<bool> regenerate(String saffId) =>
      _run(() => ref.read(saffRepositoryProvider).regenerateInvite(saffId));

  /// Rename.
  Future<bool> rename(String saffId, String name) =>
      _run(() => ref.read(saffRepositoryProvider).rename(saffId, name));
}

/// Provider of [SaffManageViewModel].
final saffManageProvider = NotifierProvider<SaffManageViewModel, ActionState>(
  SaffManageViewModel.new,
);
