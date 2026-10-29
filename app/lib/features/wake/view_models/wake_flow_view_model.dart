import 'dart:async';
import 'dart:convert';

import 'package:riverpod/src/providers/notifier.dart';
import 'package:saff_alarm/saff_alarm.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/wake/view_models/ringing_view_model.dart';
import 'package:saff_core/saff_core.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the member is in the morning.
enum WakePhase {
  /// Reading the round.
  loading,

  /// No cached round: the offline arcade fallback.
  fallback,

  /// Playing.
  play,

  /// Result sent, others still playing.
  waiting,

  /// Everyone is in (or the deadline passed).
  reveal,

  /// Card review.
  review,

  /// A test ring was started; nothing to play.
  testDone,
}

/// Immutable state of the wake flow.
class WakeFlowState {
  /// Creates the state.
  const WakeFlowState({
    this.phase = WakePhase.loading,
    this.round,
    this.answers = const [],
    this.presence = const {},
    this.reveal,
    this.nudges = const {},
    this.idle = false,
    this.failure,
    this.members = const [],
  });

  /// Current phase.
  final WakePhase phase;

  /// The locked round.
  final Round? round;

  /// Answers given so far.
  final List<CardAnswer> answers;

  /// Live statuses.
  final Map<String, LiveStatus> presence;

  /// The reveal once available.
  final Reveal? reveal;

  /// Nudges sent by the user, per target.
  final Map<String, ({int count, DateTime? last})> nudges;

  /// Whether the idle-guard overlay is showing.
  final bool idle;

  /// Last failure to show.
  final AppFailure? failure;

  /// Members of the saff.
  final List<Member> members;

  /// A copy with changes.
  WakeFlowState copyWith({
    WakePhase? phase,
    Round? round,
    List<CardAnswer>? answers,
    Map<String, LiveStatus>? presence,
    Reveal? reveal,
    Map<String, ({int count, DateTime? last})>? nudges,
    bool? idle,
    AppFailure? failure,
    bool clearFailure = false,
    List<Member>? members,
  }) => WakeFlowState(
    phase: phase ?? this.phase,
    round: round ?? this.round,
    answers: answers ?? this.answers,
    presence: presence ?? this.presence,
    reveal: reveal ?? this.reveal,
    nudges: nudges ?? this.nudges,
    idle: idle ?? this.idle,
    failure: clearFailure ? null : (failure ?? this.failure),
    members: members ?? this.members,
  );
}

/// Identifies one morning.
typedef MorningKey = ({String saffId, String occurrenceId});

/// Drives the wake flow after the alarm is stopped
/// (`docs/PRODUCT.md` §6): play, wait, reveal, review.
class WakeFlowViewModel extends Notifier<WakeFlowState> {
  WakeFlowViewModel(this._key);

  final MorningKey _key;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _idle;
  final Stopwatch _sincePlay = Stopwatch();
  int? _wakeMs;
  late final int _ringAgeMs;
  late final bool _snoozed;

  // The wake engine has no listeners on uidProvider, so read it synchronously.
  String get _uid => ref.read(authRepositoryProvider).currentUid ?? '';

  String get _pendingKey => 'pending_${_key.occurrenceId}';

  @override
  WakeFlowState build() {
    final ctx = ref.read(wakeContextProvider);
    _ringAgeMs = ctx.ringAgeMs ?? 0;
    _snoozed = ctx.snoozed;
    ref.onDispose(() {
      _idle?.cancel();
      for (final s in _subs) {
        unawaited(s.cancel());
      }
    });
    unawaited(_init());
    return const WakeFlowState();
  }

  Future<void> _init() async {
    final rounds = ref.read(roundRepositoryProvider);
    final r = await rounds.getRound(_key.saffId, _key.occurrenceId);
    final round = r.getOrNull();
    final pending = await _loadPending();
    _subs
      ..add(
        ref
            .read(saffRepositoryProvider)
            .watchMembers(_key.saffId)
            .listen((m) => state = state.copyWith(members: m)),
      )
      ..add(
        rounds
            .watchPresence(_key.saffId, _key.occurrenceId)
            .listen((p) => state = state.copyWith(presence: p)),
      )
      ..add(
        rounds
            .watchSentNudges(_key.saffId, _key.occurrenceId, _uid)
            .listen((n) => state = state.copyWith(nudges: n)),
      )
      ..add(
        rounds.watchReveal(_key.saffId, _key.occurrenceId).listen((rev) {
          if (rev != null) {
            state = state.copyWith(
              reveal: rev,
              phase: state.phase == WakePhase.review
                  ? WakePhase.review
                  : WakePhase.reveal,
            );
          }
        }),
      );
    if (round == null) {
      state = state.copyWith(phase: WakePhase.fallback);
      _wakeMs ??= _ringAgeMs;
      return;
    }
    final alreadyDone = pending?.submitted ?? false;
    state = state.copyWith(
      round: round,
      answers: pending?.answers ?? const [],
      phase: alreadyDone || round.status == 'revealed'
          ? (round.status == 'revealed' ? WakePhase.reveal : WakePhase.waiting)
          : WakePhase.play,
    );
    _wakeMs = pending?.wakeMs;
    if (state.phase == WakePhase.play) {
      _sincePlay.start();
      unawaited(_setStatus(LiveStatus.playing));
      _armIdle();
    }
  }

  Future<void> _setStatus(LiveStatus s) async {
    await ref
        .read(roundRepositoryProvider)
        .setStatus(_key.saffId, _key.occurrenceId, _uid, s);
  }

  // ----- play -----

  /// Records one answer and saves it locally.
  void onAnswer(CardAnswer a) {
    _wakeMs ??= _ringAgeMs + _sincePlay.elapsedMilliseconds;
    final answers = [...state.answers, a];
    state = state.copyWith(answers: answers);
    unawaited(_savePending(answers, submitted: false));
    _armIdle();
  }

  /// Any input resets the idle guard.
  void onActivity() => _armIdle();

  void _armIdle() {
    _idle?.cancel();
    if (state.phase != WakePhase.play) return;
    final after = ref.read(environmentConfigProvider).constants.idleRering;
    _idle = Timer(after, () {
      if (state.phase != WakePhase.play) return;
      state = state.copyWith(idle: true);
      unawaited(
        ref
            .read(alarmRepositoryProvider)
            .ringNow(
              RingReason.idle,
              message: 'Still with us?',
            ),
      );
    });
  }

  /// Dismisses the "Still with us?" overlay.
  Future<void> continueAfterIdle() async {
    state = state.copyWith(idle: false);
    await ref.read(alarmRepositoryProvider).stop(StopReason.started);
    _armIdle();
  }

  /// Called by the mode when the last card is answered.
  Future<void> onDone() async {
    _idle?.cancel();
    await _submit(offlineFallback: false);
  }

  /// Called by the offline arcade when finished.
  Future<void> onFallbackDone() async {
    _wakeMs ??= _ringAgeMs;
    await _submit(offlineFallback: true);
  }

  Future<void> _submit({required bool offlineFallback}) async {
    final r = await ref
        .read(roundRepositoryProvider)
        .submitResult(
          _key.saffId,
          _key.occurrenceId,
          _uid,
          answers: state.answers,
          wakeMs: _wakeMs ?? _ringAgeMs,
          snoozed: _snoozed,
          offlineFallback: offlineFallback,
        );
    await _savePending(state.answers, submitted: true);
    state = state.copyWith(
      phase: state.reveal != null ? WakePhase.reveal : WakePhase.waiting,
      failure: r is Err<void> ? r.failure : null,
      clearFailure: r is Ok<void>,
    );
  }

  // ----- waiting -----

  /// Rings [uid] again.
  Future<void> nudge(String uid) async {
    final r = await ref
        .read(roundRepositoryProvider)
        .nudge(_key.saffId, _key.occurrenceId, uid);
    state = r is Err<int>
        ? state.copyWith(failure: r.failure)
        : state.copyWith(clearFailure: true);
  }

  /// Opens the card review.
  void openReview() => state = state.copyWith(phase: WakePhase.review);

  /// Back to the reveal from the review.
  void closeReview() => state = state.copyWith(phase: WakePhase.reveal);

  // ----- local persistence (answers survive an app kill) -----

  Future<({List<CardAnswer> answers, int? wakeMs, bool submitted})?>
  _loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return (
      answers: [
        for (final a in (m['answers'] as List).cast<Map<String, dynamic>>())
          CardAnswer(
            cardId: a['cardId'] as String,
            msToAnswer: a['msToAnswer'] as int,
            answer: a['answer'] as String?,
            choiceIndex: a['choiceIndex'] as int?,
            selfGrade: a['selfGrade'] as bool?,
          ),
      ],
      wakeMs: m['wakeMs'] as int?,
      submitted: (m['submitted'] as bool?) ?? false,
    );
  }

  Future<void> _savePending(
    List<CardAnswer> answers, {
    required bool submitted,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingKey,
      jsonEncode({
        'answers': answers.map((a) => a.toMap()).toList(),
        'wakeMs': _wakeMs,
        'submitted': submitted,
      }),
    );
  }
}

/// Provider of the wake flow for one morning.
final NotifierProviderFamily<WakeFlowViewModel, WakeFlowState, MorningKey>
wakeFlowProvider = NotifierProvider.autoDispose
    .family<WakeFlowViewModel, WakeFlowState, MorningKey>(
      WakeFlowViewModel.new,
    );
