import 'package:flutter/widgets.dart';
import 'package:saff_domain/saff_domain.dart';

/// What a mode reports while it is played.
class ModeCallbacks {
  /// Creates the callbacks.
  const ModeCallbacks({
    required this.onAnswer,
    required this.onDone,
    required this.onActivity,
  });

  /// One answer was given (saved locally by the host).
  final void Function(CardAnswer answer) onAnswer;

  /// The round is finished; called exactly once.
  final VoidCallback onDone;

  /// Any user input happened (feeds the idle guard).
  final VoidCallback onActivity;
}

/// The contract between the wake flow and a game (`docs/ARCHITECTURE.md` §4.3).
///
/// The host never knows which mode runs; reveal, stats and scheduling work on
/// results only.
abstract interface class GameMode {
  /// The mode id as stored in the round (`cardDuel`, `word`, ...).
  String get id;

  /// Builds the play UI for [round]. [answered] holds answers already saved
  /// (so a restart resumes). Must not do I/O.
  Widget build(
    BuildContext context,
    Round round,
    List<CardAnswer> answered,
    ModeCallbacks callbacks,
  );
}
