import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:saff_modes/saff_modes.dart';
import 'package:saff_ui/saff_ui.dart';

/// Texts supplied by the app.
class RapidRollStrings {
  /// Creates the strings.
  const RapidRollStrings({
    required this.hint,
    required this.reached,
    required this.locked,
    required this.continueLabel,
  });

  /// "Drag to steer".
  final String hint;

  /// "You went {m} m deep".
  final String Function(int metres) reached;

  /// "Your depth is locked in".
  final String locked;

  /// Button label.
  final String continueLabel;
}

/// Rapid Roll (`docs/PRODUCT.md` §7): drag to steer a ball through gaps in
/// rising platforms; the same seed gives the same gaps everywhere; the score
/// is depth. One life, one attempt.
class RapidRollMode implements GameMode {
  /// Creates the mode.
  const RapidRollMode(this.strings);

  /// App-supplied texts.
  final RapidRollStrings strings;

  @override
  String get id => 'rapidRoll';

  @override
  Widget build(
    BuildContext context,
    Round round,
    List<CardAnswer> answered,
    ModeCallbacks callbacks,
  ) => RapidRollGame(seed: round.seed, callbacks: callbacks, strings: strings);
}

/// The playable surface.
class RapidRollGame extends StatefulWidget {
  /// Creates the game.
  const RapidRollGame({
    required this.seed,
    required this.callbacks,
    required this.strings,
    super.key,
  });

  /// Round seed.
  final int seed;

  /// Host callbacks.
  final ModeCallbacks callbacks;

  /// Texts.
  final RapidRollStrings strings;

  @override
  State<RapidRollGame> createState() => _RapidRollGameState();
}

class _RapidRollGameState extends State<RapidRollGame>
    with SingleTickerProviderStateMixin {
  static const _spacing = 120.0;
  static const _r = 12.0;
  late final Ticker _ticker;
  final _gaps = <double>[]; // gap centre per row, 0..1
  late final math.Random _rnd = math.Random(widget.seed);
  Duration _last = Duration.zero;
  double _scroll = 0;
  double _elapsed = 0;
  double _x = 0.5;
  double _y = 80;
  double _vy = 0;
  bool _over = false;
  Size _size = Size.zero;

  double _gapAt(int i) {
    while (_gaps.length <= i) {
      _gaps.add(0.15 + _rnd.nextDouble() * 0.7);
    }
    return _gaps[i];
  }

  double get _gapWidth => math.max(70, 130 - _elapsed * 1.2);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration t) {
    if (_over || _size == Size.zero) return;
    final dt = ((t - _last).inMicroseconds / 1e6).clamp(0.0, 0.033);
    _last = t;
    _elapsed += dt;
    final speed = 70 + math.min(150, _elapsed * 3);
    _scroll += speed * dt;
    _vy += 700 * dt;
    final prevBottom = _y + _r;
    _y += _vy * dt - 0; // free fall unless landed below
    // Rows rise; find the row the ball may be standing on.
    final px = _x * _size.width;
    final first = ((_scroll + 0) / _spacing).floor();
    for (
      var i = first;
      i <= first + (_size.height / _spacing).ceil() + 1;
      i++
    ) {
      final rowY = (i + 1) * _spacing - _scroll;
      final gapC = _gapAt(i) * _size.width;
      final inGap = (px - gapC).abs() < _gapWidth / 2 - _r / 2;
      final ballBottom = _y + _r;
      final landed =
          !inGap &&
          prevBottom <= rowY + speed * dt + 1 &&
          ballBottom >= rowY &&
          _vy >= 0;
      if (landed) {
        _y = rowY - _r;
        _vy = 0;
        break;
      }
    }
    if (_y + _r > _size.height) {
      _y = _size.height - _r;
      _vy = 0;
    }
    if (_y - _r < 0) {
      _over = true;
      widget.callbacks.onScore?.call(_depth);
    }
    setState(() {});
  }

  int get _depth => (_scroll / 10).floor();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.saff;
    return LayoutBuilder(
      builder: (context, box) {
        _size = Size(box.maxWidth, box.maxHeight);
        return GestureDetector(
          onPanStart: (_) => widget.callbacks.onActivity(),
          onPanUpdate: (d) => _x = (d.localPosition.dx / _size.width).clamp(
            0.03,
            0.97,
          ),
          onTapDown: (d) {
            widget.callbacks.onActivity();
            _x = (d.localPosition.dx / _size.width).clamp(0.03, 0.97);
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RollPainter(
                    scroll: _scroll,
                    x: _x,
                    y: _y,
                    gapWidth: _gapWidth,
                    gapAt: _gapAt,
                    accent: c.accent,
                    sky: Color.lerp(
                      const Color(0xFF0F1524),
                      const Color(0xFF23325C),
                      (_scroll / 8000).clamp(0.0, 1.0),
                    )!,
                  ),
                ),
              ),
              Positioned(
                top: SaffSpacing.lg,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '$_depth m',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (_elapsed < 4 && !_over)
                Positioned(
                  bottom: SaffSpacing.xl,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      widget.strings.hint,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              if (_over)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(SaffSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.strings.reached(_depth),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              widget.strings.locked,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: SaffSpacing.xl),
                            PrimaryButton(
                              label: widget.strings.continueLabel,
                              onPressed: widget.callbacks.onDone,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RollPainter extends CustomPainter {
  _RollPainter({
    required this.scroll,
    required this.x,
    required this.y,
    required this.gapWidth,
    required this.gapAt,
    required this.accent,
    required this.sky,
  });

  final double scroll;
  final double x;
  final double y;
  final double gapWidth;
  final double Function(int) gapAt;
  final Color accent;
  final Color sky;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = sky);
    final bar = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final first = (scroll / 120).floor();
    for (var i = first; i <= first + (size.height / 120).ceil() + 1; i++) {
      final rowY = (i + 1) * 120 - scroll;
      final g = gapAt(i) * size.width;
      final left = g - gapWidth / 2;
      final right = g + gapWidth / 2;
      canvas
        ..drawRect(Rect.fromLTRB(0, rowY - 5, left, rowY + 5), bar)
        ..drawRect(Rect.fromLTRB(right, rowY - 5, size.width, rowY + 5), bar);
    }
    canvas.drawCircle(Offset(x * size.width, y), 12, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_RollPainter old) => true;
}
