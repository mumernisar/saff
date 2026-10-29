import 'package:saff_modes/src/game_mode.dart';

/// Looks the [GameMode] for a round up by id.
class ModeRegistry {
  /// Creates a registry from [modes].
  ModeRegistry(Iterable<GameMode> modes)
    : _modes = {for (final m in modes) m.id: m};

  final Map<String, GameMode> _modes;

  /// The mode for [id], or null when this build does not know it.
  GameMode? create(String id) => _modes[id];
}
