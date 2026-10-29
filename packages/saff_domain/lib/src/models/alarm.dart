/// An alarm of a saff.
final class Alarm {
  /// Creates an alarm.
  const Alarm({
    required this.id,
    required this.saffId,
    required this.name,
    required this.time,
    required this.days,
    required this.timezone,
    required this.status,
    required this.participantIds,
    required this.createdBy,
  });

  /// Document id.
  final String id;

  /// The saff it belongs to.
  final String saffId;

  /// Name, e.g. Fajr.
  final String name;

  /// Wall-clock `HH:mm` in [timezone].
  final String time;

  /// ISO weekdays 1-7.
  final List<int> days;

  /// IANA timezone of the creator.
  final String timezone;

  /// `active`, `waiting` or `deleted`.
  final String status;

  /// Members the alarm rings for.
  final List<String> participantIds;

  /// The creator's uid.
  final String createdBy;

  /// Whether the alarm is ringing in the future.
  bool get isActive => status == 'active';
}

/// The kinds of alarm proposal.
enum ProposalType {
  /// A new alarm.
  alarmCreate,

  /// A change to an alarm.
  alarmChange,

  /// Deleting an alarm.
  alarmDelete,
}

/// A proposal living in chat.
final class Proposal {
  /// Creates a proposal.
  const Proposal({
    required this.id,
    required this.type,
    required this.status,
    required this.proposerId,
    required this.payload,
    required this.requiredIds,
    required this.acceptedIds,
    this.targetId,
  });

  /// Document id.
  final String id;

  /// What kind of change.
  final ProposalType type;

  /// `pending`, `accepted`, `declined`, `superseded`, `expired`.
  final String status;

  /// Who proposed it.
  final String proposerId;

  /// Proposed values: name, time, days, timezone.
  final Map<String, Object?> payload;

  /// Members that must accept (empty for opt-in group alarms).
  final List<String> requiredIds;

  /// Members that accepted.
  final List<String> acceptedIds;

  /// The alarm it targets.
  final String? targetId;

  /// Whether it still awaits votes.
  bool get isPending => status == 'pending';
}

/// One planned ring moment.
final class Occurrence {
  /// Creates an occurrence.
  const Occurrence({
    required this.id,
    required this.saffId,
    required this.alarmId,
    required this.alarmName,
    required this.ringAt,
    required this.lockAt,
    required this.deadlineAt,
    required this.status,
    required this.participantIds,
    required this.skippedIds,
    required this.date,
  });

  /// `{alarmId}_{yyyyMMdd}`.
  final String id;

  /// Saff id.
  final String saffId;

  /// Alarm id.
  final String alarmId;

  /// Alarm name.
  final String alarmName;

  /// When it rings (UTC).
  final DateTime ringAt;

  /// When the round locks.
  final DateTime lockAt;

  /// When the reveal happens regardless.
  final DateTime deadlineAt;

  /// `planned`, `locked`, `revealed`, `cancelled`.
  final String status;

  /// Participants at planning time.
  final List<String> participantIds;

  /// Members skipping this morning.
  final List<String> skippedIds;

  /// `yyyyMMdd` in the alarm's timezone.
  final String date;

  /// Whether [uid] is expected to play.
  bool requires(String uid) =>
      participantIds.contains(uid) && !skippedIds.contains(uid);
}
