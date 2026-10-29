import 'package:saff_app/data/dto/mappers.dart';
import 'package:saff_app/data/services/firebase_services.dart';
import 'package:saff_core/saff_core.dart';
import 'package:saff_domain/saff_domain.dart';

/// The values of an alarm proposal.
typedef AlarmDraft = ({
  String name,
  String time,
  List<int> days,
  String timezone,
});

/// Alarms, proposals and occurrences of a saff.
abstract interface class AlarmPlanRepository {
  /// Alarms, live.
  Stream<List<Alarm>> watchAlarms(String saffId);

  /// Proposals, live.
  Stream<List<Proposal>> watchProposals(String saffId);

  /// Upcoming occurrences (not yet revealed), live.
  Stream<List<Occurrence>> watchUpcoming(String saffId);

  /// Proposes a new alarm.
  Future<Result<void>> proposeCreate(
    String saffId,
    AlarmDraft draft, {
    String? supersedes,
  });

  /// Proposes a change to [alarmId].
  Future<Result<void>> proposeChange(
    String saffId,
    String alarmId,
    AlarmDraft draft, {
    String? supersedes,
  });

  /// Proposes deleting [alarmId].
  Future<Result<void>> proposeDelete(String saffId, String alarmId);

  /// Votes on a proposal.
  Future<Result<void>> vote(
    String saffId,
    String proposalId, {
    required bool accept,
  });

  /// Joins a group alarm.
  Future<Result<void>> joinAlarm(String saffId, String alarmId);

  /// Leaves a group alarm.
  Future<Result<void>> leaveAlarm(String saffId, String alarmId);

  /// Skips an occurrence.
  Future<Result<void>> skip(String saffId, String occurrenceId);
}

/// [AlarmPlanRepository] over Firestore and callables.
final class AlarmPlanRepositoryImpl implements AlarmPlanRepository {
  /// Creates the repository.
  const AlarmPlanRepositoryImpl(this._fs, this._fn, this._mapper);

  final FirestoreService _fs;
  final FunctionsService _fn;
  final FailureMapper _mapper;

  Future<Result<void>> _call(String op, Map<String, Object?> data) =>
      Result.guard(() => _fn.call(op, data), _mapper, context: {'op': op});

  Map<String, Object?> _payload(AlarmDraft d) => {
    'name': d.name,
    'time': d.time,
    'days': d.days,
    'timezone': d.timezone,
  };

  @override
  Stream<List<Alarm>> watchAlarms(String saffId) => _fs.db
      .collection('saffs/$saffId/alarms')
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => alarmFrom(saffId, d))
            .where((a) => a.status != 'deleted')
            .toList(),
      );

  @override
  Stream<List<Proposal>> watchProposals(String saffId) => _fs.db
      .collection('saffs/$saffId/proposals')
      .snapshots()
      .map((s) => s.docs.map(proposalFrom).toList());

  @override
  Stream<List<Occurrence>> watchUpcoming(String saffId) => _fs.db
      .collection('saffs/$saffId/occurrences')
      .where('status', whereIn: ['planned', 'locked'])
      .snapshots()
      .map((s) {
        final list = s.docs.map((d) => occurrenceFrom(saffId, d)).toList()
          ..sort((a, b) => a.ringAt.compareTo(b.ringAt));
        return list;
      });

  @override
  Future<Result<void>> proposeCreate(
    String saffId,
    AlarmDraft draft, {
    String? supersedes,
  }) => _call('createProposal', {
    'saffId': saffId,
    'type': 'alarmCreate',
    'payload': _payload(draft),
    'supersedes': ?supersedes,
  });

  @override
  Future<Result<void>> proposeChange(
    String saffId,
    String alarmId,
    AlarmDraft draft, {
    String? supersedes,
  }) => _call('createProposal', {
    'saffId': saffId,
    'type': 'alarmChange',
    'targetId': alarmId,
    'payload': _payload(draft),
    'supersedes': ?supersedes,
  });

  @override
  Future<Result<void>> proposeDelete(String saffId, String alarmId) => _call(
    'createProposal',
    {'saffId': saffId, 'type': 'alarmDelete', 'targetId': alarmId},
  );

  @override
  Future<Result<void>> vote(
    String saffId,
    String proposalId, {
    required bool accept,
  }) => _call('voteProposal', {
    'saffId': saffId,
    'proposalId': proposalId,
    'vote': accept ? 'accept' : 'decline',
  });

  @override
  Future<Result<void>> joinAlarm(String saffId, String alarmId) =>
      _call('joinAlarm', {'saffId': saffId, 'alarmId': alarmId});

  @override
  Future<Result<void>> leaveAlarm(String saffId, String alarmId) =>
      _call('leaveAlarm', {'saffId': saffId, 'alarmId': alarmId});

  @override
  Future<Result<void>> skip(String saffId, String occurrenceId) =>
      _call('skipOccurrence', {'saffId': saffId, 'occurrenceId': occurrenceId});
}
