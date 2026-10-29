import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saff_domain/saff_domain.dart';

/// Reads a timestamp field as UTC, or [fallback].
DateTime ts(Object? v, [DateTime? fallback]) =>
    v is Timestamp ? v.toDate().toUtc() : (fallback ?? DateTime.now().toUtc());

List<String> strings(Object? v) =>
    v is List ? v.map((e) => '$e').toList() : const [];

int avatarIndex(Object? v) => int.tryParse('${v ?? 0}') ?? 0;

/// Document → [Saff].
Saff saffFrom(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? const {};
  return Saff(
    id: d.id,
    name: (m['name'] as String?) ?? '',
    ownerId: (m['ownerId'] as String?) ?? '',
    memberIds: strings(m['memberIds']),
    memberLimit: (m['memberLimit'] as int?) ?? 4,
    inviteCode: (m['inviteCode'] as String?) ?? '',
    streak: ((m['streak'] as Map?)?['current'] as int?) ?? 0,
    whatsappGroupLink: m['whatsappGroupLink'] as String?,
    ended: m['endedAt'] != null,
    overLimit: (m['overLimit'] as bool?) ?? false,
  );
}

/// Document → [Member].
Member memberFrom(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? const {};
  final presence = (m['presence'] as Map?) ?? const {};
  return Member(
    uid: d.id,
    displayName: (m['displayName'] as String?) ?? '',
    avatarColor: avatarIndex(m['avatarColor']),
    isOwner: m['role'] == 'owner',
    whatsapp: (m['whatsapp'] as String?) ?? '',
    online: (presence['online'] as bool?) ?? false,
    lastSeen: presence['lastSeenAt'] is Timestamp
        ? ts(presence['lastSeenAt'])
        : null,
  );
}

/// Document → [Alarm].
Alarm alarmFrom(String saffId, DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? const {};
  return Alarm(
    id: d.id,
    saffId: saffId,
    name: (m['name'] as String?) ?? '',
    time: (m['time'] as String?) ?? '00:00',
    days: (m['days'] as List?)?.map((e) => e as int).toList() ?? const [],
    timezone: (m['timezone'] as String?) ?? 'UTC',
    status: (m['status'] as String?) ?? 'active',
    participantIds: strings(m['participantIds']),
    createdBy: (m['createdBy'] as String?) ?? '',
  );
}

/// Document → [Proposal].
Proposal proposalFrom(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? const {};
  return Proposal(
    id: d.id,
    type: ProposalType.values.firstWhere(
      (t) => t.name == m['type'],
      orElse: () => ProposalType.alarmCreate,
    ),
    status: (m['status'] as String?) ?? 'pending',
    proposerId: (m['proposerId'] as String?) ?? '',
    payload: ((m['payload'] as Map?) ?? const {}).cast<String, Object?>(),
    requiredIds: strings(m['requiredIds']),
    acceptedIds: strings(m['acceptedIds']),
    targetId: m['targetId'] as String?,
  );
}

/// Document → [Occurrence].
Occurrence occurrenceFrom(
  String saffId,
  DocumentSnapshot<Map<String, dynamic>> d,
) {
  final m = d.data() ?? const {};
  return Occurrence(
    id: d.id,
    saffId: saffId,
    alarmId: (m['alarmId'] as String?) ?? '',
    alarmName: (m['alarmName'] as String?) ?? '',
    ringAt: ts(m['ringAt']),
    lockAt: ts(m['lockAt']),
    deadlineAt: ts(m['deadlineAt']),
    status: (m['status'] as String?) ?? 'planned',
    participantIds: strings(m['participantIds']),
    skippedIds: strings(m['skippedIds']),
    date: (m['date'] as String?) ?? '',
  );
}

/// Document → [ChatMessage].
ChatMessage messageFrom(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? const {};
  return ChatMessage(
    id: d.id,
    type: (m['type'] as String?) ?? 'text',
    authorId: (m['authorId'] as String?) ?? 'system',
    createdAt: ts(m['createdAt']),
    seenBy: ((m['seenBy'] as Map?) ?? const {}).keys.map((k) => '$k').toSet(),
    text: m['text'] as String?,
    replyToId: m['replyToId'] as String?,
    payload: ((m['systemPayload'] as Map?) ?? const {}).cast<String, Object?>(),
    deleted: m['deletedAt'] != null,
    pending: d.metadata.hasPendingWrites,
  );
}

final _placeholder = RegExp(r'\s*\{\{[^}]*\}\}\s*');

/// Strips content placeholders that no gateway resolved (offline fallback).
String stripPlaceholders(String s) =>
    s.replaceAll(_placeholder, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Map → [RoundCard].
RoundCard roundCardFrom(Map<String, dynamic> m) => RoundCard(
  id: '${m['id']}',
  type: (m['type'] as String?) ?? 'choice',
  category: (m['category'] as String?) ?? '',
  question: stripPlaceholders((m['question'] as String?) ?? ''),
  answer: (m['answer'] as String?) ?? '',
  options: strings(m['options']),
  explanation: m['explanation'] == null
      ? null
      : stripPlaceholders('${m['explanation']}'),
  talk: m['talk'] as String?,
  source: m['source'] as String?,
  difficulty: (m['difficulty'] as String?) ?? 'medium',
  fromName: m['fromName'] as String?,
);

/// Document → [Round].
Round roundFrom(String saffId, DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? const {};
  return Round(
    id: d.id,
    saffId: saffId,
    mode: (m['mode'] as String?) ?? 'cardDuel',
    seed: (m['seed'] as int?) ?? 0,
    cards: ((m['cards'] as List?) ?? const [])
        .map((c) => roundCardFrom((c as Map).cast<String, dynamic>()))
        .toList(),
    bonusCards: ((m['bonusCards'] as List?) ?? const [])
        .map((c) => roundCardFrom((c as Map).cast<String, dynamic>()))
        .toList(),
    status: (m['status'] as String?) ?? 'locked',
    requiredIds: strings(m['requiredIds']),
    alarmName: (m['alarmName'] as String?) ?? '',
    ringAt: ts(m['ringAt']),
    deadlineAt: ts(m['deadlineAt']),
  );
}

/// Document → [Reveal].
Reveal revealFrom(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? const {};
  final rows = ((m['rows'] as List?) ?? const []).map((r) {
    final x = (r as Map).cast<String, dynamic>();
    return RevealRow(
      uid: '${x['uid']}',
      name: (x['name'] as String?) ?? '',
      avatarColor: avatarIndex(x['avatarColor']),
      played: (x['played'] as bool?) ?? false,
      points: (x['points'] as num?)?.toInt() ?? 0,
      correct: (x['correct'] as num?)?.toInt() ?? 0,
      total: (x['total'] as num?)?.toInt() ?? 0,
      rank: (x['rank'] as num?)?.toInt() ?? 0,
      ranked: (x['ranked'] as bool?) ?? false,
      wakeMs: (x['wakeMs'] as num?)?.toInt(),
      offlineFallback: (x['offlineFallback'] as bool?) ?? false,
    );
  }).toList();
  rows.sort((a, b) {
    if (a.played != b.played) return a.played ? -1 : 1;
    if (a.rank != b.rank) {
      if (a.rank == 0) return 1;
      if (b.rank == 0) return -1;
      return a.rank.compareTo(b.rank);
    }
    return b.points.compareTo(a.points);
  });
  final perCard = <String, List<ReviewAnswer>>{};
  for (final c in (m['perCard'] as List?) ?? const []) {
    final x = (c as Map).cast<String, dynamic>();
    perCard['${x['cardId']}'] = ((x['answers'] as List?) ?? const []).map((a) {
      final y = (a as Map).cast<String, dynamic>();
      return ReviewAnswer(
        uid: '${y['uid']}',
        correct: (y['correct'] as bool?) ?? false,
        answered: (y['answered'] as bool?) ?? false,
        answer: y['answer'] as String?,
        choiceIndex: (y['choiceIndex'] as num?)?.toInt(),
      );
    }).toList();
  }
  return Reveal(
    rows: rows,
    firstWaker: m['firstWaker'] as String?,
    streak: (m['streak'] as num?)?.toInt() ?? 0,
    solo: (m['solo'] as bool?) ?? false,
    perCard: perCard,
    mode: (m['mode'] as String?) ?? 'cardDuel',
    bonusCards: ((m['bonusCards'] as List?) ?? const [])
        .map((c) => roundCardFrom((c as Map).cast<String, dynamic>()))
        .toList(),
  );
}
