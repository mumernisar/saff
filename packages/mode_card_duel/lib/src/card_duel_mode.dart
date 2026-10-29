import 'dart:async';

import 'package:flutter/material.dart';
import 'package:saff_modes/saff_modes.dart';
import 'package:saff_ui/saff_ui.dart';

/// Texts the app supplies (the package has no localisation of its own).
class CardDuelStrings {
  /// Creates the strings.
  const CardDuelStrings({
    required this.cardOf,
    required this.sendAnswer,
    required this.typeAnswer,
    required this.iKnewIt,
    required this.iDidNot,
    required this.showAnswer,
    required this.timeUp,
    required this.yourAnswerSaved,
  });

  /// "1 of 8".
  final String Function(int index, int total) cardOf;

  /// Send button.
  final String sendAnswer;

  /// Typed-answer hint.
  final String typeAnswer;

  /// Self-grade yes.
  final String iKnewIt;

  /// Self-grade no.
  final String iDidNot;

  /// Reveal button of a self card.
  final String showAnswer;

  /// Shown when the timer ends.
  final String timeUp;

  /// Shown after the last card.
  final String yourAnswerSaved;
}

/// Card Duel (`docs/PRODUCT.md` §7): cards one at a time, a timer each.
class CardDuelMode implements GameMode {
  /// Creates the mode.
  const CardDuelMode({required this.strings, required this.cardTime});

  /// App-supplied texts.
  final CardDuelStrings strings;

  /// Time per card (`CARD_SECONDS`).
  final Duration cardTime;

  @override
  String get id => 'cardDuel';

  @override
  Widget build(
    BuildContext context,
    Round round,
    List<CardAnswer> answered,
    ModeCallbacks callbacks,
  ) => CardDuelPlay(
    cards: round.cards,
    answered: answered,
    callbacks: callbacks,
    strings: strings,
    cardTime: cardTime,
  );
}

/// The play surface of [CardDuelMode].
class CardDuelPlay extends StatefulWidget {
  /// Creates the surface.
  const CardDuelPlay({
    required this.cards,
    required this.answered,
    required this.callbacks,
    required this.strings,
    required this.cardTime,
    super.key,
  });

  /// Scored cards.
  final List<RoundCard> cards;

  /// Answers already given.
  final List<CardAnswer> answered;

  /// Host callbacks.
  final ModeCallbacks callbacks;

  /// Texts.
  final CardDuelStrings strings;

  /// Time per card.
  final Duration cardTime;

  @override
  State<CardDuelPlay> createState() => _CardDuelPlayState();
}

class _CardDuelPlayState extends State<CardDuelPlay> {
  late int _index = widget.answered.length.clamp(0, widget.cards.length);
  final _typed = TextEditingController();
  final _clock = Stopwatch();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  int? _picked;
  bool _revealedSelf = false;
  bool _finished = false;

  RoundCard? get _card =>
      _index < widget.cards.length ? widget.cards[_index] : null;

  @override
  void initState() {
    super.initState();
    if (_card == null) {
      _finish();
    } else {
      _startCard();
    }
  }

  void _startCard() {
    _typed.clear();
    _picked = null;
    _revealedSelf = false;
    _clock
      ..reset()
      ..start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _clock.elapsed);
      if (_clock.elapsed >= widget.cardTime) _submit(timeout: true);
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    widget.callbacks.onDone();
  }

  void _submit({bool timeout = false, bool? self}) {
    final card = _card;
    if (card == null || _finished) return;
    final ms = _clock.elapsedMilliseconds.clamp(
      0,
      widget.cardTime.inMilliseconds,
    );
    widget.callbacks.onAnswer(
      CardAnswer(
        cardId: card.id,
        msToAnswer: timeout ? widget.cardTime.inMilliseconds : ms,
        answer:
            card.type == 'typed' && !timeout && _typed.text.trim().isNotEmpty
            ? _typed.text.trim()
            : null,
        choiceIndex: card.type == 'choice' ? _picked : null,
        selfGrade: card.type == 'self' ? (self ?? false) : null,
      ),
    );
    setState(() => _index++);
    if (_card == null) {
      _finish();
    } else {
      _startCard();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.saff;
    final card = _card;
    if (card == null) {
      return Center(
        child: Text(
          widget.strings.yourAnswerSaved,
          style: TextStyle(fontSize: 20, color: c.muted),
        ),
      );
    }
    final left = 1 - _elapsed.inMilliseconds / widget.cardTime.inMilliseconds;
    final urgent = left < 0.24;
    return Listener(
      onPointerDown: (_) => widget.callbacks.onActivity(),
      child: Padding(
        padding: const EdgeInsets.all(SaffSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  widget.strings.cardOf(_index + 1, widget.cards.length),
                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  card.category.toUpperCase(),
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: SaffSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: left.clamp(0.0, 1.0),
                minHeight: 8,
                color: urgent ? c.error : c.accent,
                backgroundColor: c.line,
              ),
            ),
            const SizedBox(height: SaffSpacing.xl),
            Text(
              card.question,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            if (card.source != null) ...[
              const SizedBox(height: SaffSpacing.sm),
              Text(
                card.source!,
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: SaffSpacing.xl),
            Expanded(child: SingleChildScrollView(child: _answerArea(card))),
          ],
        ),
      ),
    );
  }

  Widget _answerArea(RoundCard card) {
    final c = context.saff;
    switch (card.type) {
      case 'choice':
        return Column(
          children: [
            for (var i = 0; i < card.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: SaffSpacing.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(SaffRadii.md),
                  onTap: () {
                    setState(() => _picked = i);
                    _submit();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(SaffSpacing.lg),
                    decoration: BoxDecoration(
                      color: _picked == i ? c.soft : c.surface,
                      borderRadius: BorderRadius.circular(SaffRadii.md),
                      border: Border.all(
                        color: _picked == i ? c.accent : c.line,
                      ),
                    ),
                    child: Text(
                      card.options[i],
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),
              ),
          ],
        );
      case 'typed':
        return Column(
          children: [
            TextField(
              key: const ValueKey('typed-answer'),
              controller: _typed,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(hintText: widget.strings.typeAnswer),
            ),
            const SizedBox(height: SaffSpacing.lg),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.strings.sendAnswer),
            ),
          ],
        );
      default:
        return _revealedSelf
            ? Column(
                children: [
                  Text(
                    card.answer,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SaffSpacing.lg),
                  FilledButton(
                    onPressed: () => _submit(self: true),
                    child: Text(widget.strings.iKnewIt),
                  ),
                  const SizedBox(height: SaffSpacing.sm),
                  OutlinedButton(
                    onPressed: () => _submit(self: false),
                    child: Text(widget.strings.iDidNot),
                  ),
                ],
              )
            : FilledButton(
                onPressed: () => setState(() => _revealedSelf = true),
                child: Text(widget.strings.showAnswer),
              );
    }
  }
}
