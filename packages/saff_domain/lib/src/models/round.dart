/// A playable card inside a locked round.
final class RoundCard {
  /// Creates a card.
  const RoundCard({
    required this.id,
    required this.type,
    required this.category,
    required this.question,
    required this.answer,
    this.options = const [],
    this.explanation,
    this.talk,
    this.source,
    this.difficulty = 'medium',
    this.fromName,
    this.authorId,
  });

  /// Card id.
  final String id;

  /// `choice`, `typed` or `self`.
  final String type;

  /// quran, story, hadith, deen, general.
  final String category;

  /// Question text (placeholders stripped or resolved).
  final String question;

  /// The correct answer (revealed in review).
  final String answer;

  /// Options for choice cards.
  final List<String> options;

  /// Explanation shown after the round.
  final String? explanation;

  /// A talk question for the chat.
  final String? talk;

  /// Source citation.
  final String? source;

  /// easy / medium / hard.
  final String difficulty;

  /// Who planted this card (bonus cards only).
  final String? fromName;

  /// uid of who planted this card.
  final String? authorId;

  /// Whether this is a planted bonus card (never scored).
  bool get isBonus => id.startsWith('plant_');
}

/// A locked round.
final class Round {
  /// Creates a round.
  const Round({
    required this.id,
    required this.saffId,
    required this.mode,
    required this.seed,
    required this.cards,
    required this.bonusCards,
    required this.status,
    required this.requiredIds,
    required this.alarmName,
    required this.ringAt,
    required this.deadlineAt,
  });

  /// Occurrence id.
  final String id;

  /// Saff id.
  final String saffId;

  /// Mode id, e.g. `cardDuel`.
  final String mode;

  /// Seed for seeded modes.
  final int seed;

  /// Scored cards.
  final List<RoundCard> cards;

  /// Planted cards, played after the scored ones; never scored.
  final List<RoundCard> bonusCards;

  /// `locked` or `revealed`.
  final String status;

  /// Members who must play.
  final List<String> requiredIds;

  /// Alarm name.
  final String alarmName;

  /// When the alarm rings.
  final DateTime ringAt;

  /// Reveal deadline.
  final DateTime deadlineAt;
}

/// One answer in a result.
final class CardAnswer {
  /// Creates an answer.
  const CardAnswer({
    required this.cardId,
    required this.msToAnswer,
    this.answer,
    this.choiceIndex,
    this.selfGrade,
  });

  /// The card answered.
  final String cardId;

  /// Time taken.
  final int msToAnswer;

  /// Typed answer.
  final String? answer;

  /// Chosen option.
  final int? choiceIndex;

  /// Self-grade for self cards.
  final bool? selfGrade;

  /// Firestore map.
  Map<String, Object?> toMap() => {
    'cardId': cardId,
    'msToAnswer': msToAnswer,
    if (answer != null) 'answer': answer,
    if (choiceIndex != null) 'choiceIndex': choiceIndex,
    if (selfGrade != null) 'selfGrade': selfGrade,
  };
}

/// A row of the reveal.
final class RevealRow {
  /// Creates a row.
  const RevealRow({
    required this.uid,
    required this.name,
    required this.avatarColor,
    required this.played,
    required this.points,
    required this.correct,
    required this.total,
    required this.rank,
    required this.ranked,
    this.wakeMs,
    this.offlineFallback = false,
  });

  /// Member uid.
  final String uid;

  /// Display name.
  final String name;

  /// Avatar index.
  final int avatarColor;

  /// Whether the member played.
  final bool played;

  /// Points.
  final int points;

  /// Correct cards.
  final int correct;

  /// Cards in the round.
  final int total;

  /// Rank, 0 when unranked.
  final int rank;

  /// Whether the result counts for ranking.
  final bool ranked;

  /// Wake time in ms.
  final int? wakeMs;

  /// Whether the member played the offline fallback.
  final bool offlineFallback;
}

/// One member's answer to one card, for review.
final class ReviewAnswer {
  /// Creates an answer.
  const ReviewAnswer({
    required this.uid,
    required this.correct,
    required this.answered,
    this.answer,
    this.choiceIndex,
  });

  /// Member.
  final String uid;

  /// Whether correct.
  final bool correct;

  /// Whether answered at all.
  final bool answered;

  /// Typed answer.
  final String? answer;

  /// Chosen option index.
  final int? choiceIndex;
}

/// The reveal summary.
final class Reveal {
  /// Creates a reveal.
  const Reveal({
    required this.rows,
    required this.firstWaker,
    required this.streak,
    required this.solo,
    required this.perCard,
    required this.mode,
    this.bonusCards = const [],
  });

  /// Ranked rows (unplayed members last).
  final List<RevealRow> rows;

  /// uid of the first member to wake.
  final String? firstWaker;

  /// Saff streak after this morning.
  final int streak;

  /// Whether only one member played.
  final bool solo;

  /// Review data keyed by card id.
  final Map<String, List<ReviewAnswer>> perCard;

  /// Mode id.
  final String mode;

  /// Planted cards of the round, for the review.
  final List<RoundCard> bonusCards;
}

/// A member's live status.
enum LiveStatus {
  /// Not started.
  asleep,

  /// Snoozed.
  snoozed,

  /// Playing.
  playing,

  /// Finished.
  done,

  /// Phone never reported.
  offline,

  /// Deadline passed.
  missed;

  /// Parses a stored name; unknown values mean asleep.
  static LiveStatus parse(String? s) => LiveStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => LiveStatus.asleep,
  );
}
