import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/data/repositories/alarm_plan_repository.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/auth/view_models/auth_view_model.dart';
import 'package:saff_core/saff_core.dart';

/// Alarm proposals and votes.
class ProposalViewModel extends Notifier<ActionState> {
  @override
  ActionState build() => const ActionState();

  Future<bool> _run(Future<Result<void>> Function() f) async {
    state = const ActionState(running: true);
    final r = await f();
    state = ActionState(failure: r is Err<void> ? r.failure : null);
    return r is Ok<void>;
  }

  /// Proposes a new alarm.
  Future<bool> create(
    String saffId,
    AlarmDraft draft, {
    String? supersedes,
  }) => _run(
    () => ref
        .read(alarmPlanRepositoryProvider)
        .proposeCreate(saffId, draft, supersedes: supersedes),
  );

  /// Proposes a change.
  Future<bool> change(
    String saffId,
    String alarmId,
    AlarmDraft draft, {
    String? supersedes,
  }) => _run(
    () => ref
        .read(alarmPlanRepositoryProvider)
        .proposeChange(saffId, alarmId, draft, supersedes: supersedes),
  );

  /// Proposes deleting an alarm.
  Future<bool> delete(String saffId, String alarmId) => _run(
    () => ref.read(alarmPlanRepositoryProvider).proposeDelete(saffId, alarmId),
  );

  /// Accepts or declines.
  Future<bool> vote(
    String saffId,
    String proposalId, {
    required bool accept,
  }) => _run(
    () => ref
        .read(alarmPlanRepositoryProvider)
        .vote(saffId, proposalId, accept: accept),
  );

  /// Joins a group alarm.
  Future<bool> join(String saffId, String alarmId) => _run(
    () => ref.read(alarmPlanRepositoryProvider).joinAlarm(saffId, alarmId),
  );

  /// Leaves a group alarm.
  Future<bool> leave(String saffId, String alarmId) => _run(
    () => ref.read(alarmPlanRepositoryProvider).leaveAlarm(saffId, alarmId),
  );

  /// Skips an occurrence.
  Future<bool> skip(String saffId, String occurrenceId) => _run(
    () => ref.read(alarmPlanRepositoryProvider).skip(saffId, occurrenceId),
  );
}

/// Provider of [ProposalViewModel].
final proposalViewModelProvider =
    NotifierProvider<ProposalViewModel, ActionState>(ProposalViewModel.new);

/// The device timezone from the alarm module.
final deviceTimezoneProvider = FutureProvider<String>((ref) async {
  final r = await ref.read(alarmRepositoryProvider).timezone();
  return r.getOrNull() ?? 'UTC';
});
