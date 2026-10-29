import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:saff_modes/saff_modes.dart';
import 'package:saff_ui/saff_ui.dart';

/// Texts supplied by the app.
class ClimberStrings {
  /// Creates the strings.
  const ClimberStrings({
    required this.hint,
    required this.reached,
    required this.locked,
    required this.continueLabel,
  });

  /// "Hold left or right to steer".
  final String hint;

  /// "You reached {m} m".
  final String Function(int metres) reached;

  /// "Your height is locked in".
  final String locked;

  /// Button label.
  final String continueLabel;
}

/// Climber (`docs/PRODUCT.md` §7): auto-bounce upward, hold the left or right
/// half of the screen to steer (touch steering per mockup frame 2d); the same
/// seed gives the same platforms on every phone.
class ClimberMode implements GameMode {
  /// Creates the mode.
  const ClimberMode(this.strings);

  /// App-supplied texts.
  final ClimberStrings strings;

  @override
  String get id => 'climber';

  @override
  Widget build(
    BuildContext context,
    Round round,
    List<CardAnswer> answered,
    ModeCallbacks callbacks,
  ) => ClimberGame(seed: round.seed, callbacks: callbacks, strings: strings);
}

/// Deterministic platform layout: the same on every device for one seed.
class PlatformField {
  /// Creates a field.
  PlatformField(int seed) : _rnd = math.Random(seed);

  final math.Random _rnd;

  /// Platforms so far: x in 0..1, y in world units.
  final List<({double x, double y})> platforms = [];
  double _top = 0;

  /// Ensures platforms exist up to world height [y] (world units, up is +).
  void fill(double y, double gapGrowth) {
    while (_top < y) {
      final gap = 70 + math.min(90, gapGrowth) + _rnd.nextDouble() * 30;
      _top += gap;
      platforms.add((x: _rnd.nextDouble(), y: _top));
    }
  }
}

/// The playable surface.
class ClimberGame extends StatefulWidget {
  /// Creates the game.
  const ClimberGame({
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
  final ClimberStrings strings;

  @override
  State<ClimberGame> createState() => _ClimberGameState();
}

class _ClimberGameState extends State<ClimberGame>
    with SingleTickerProviderStateMixin {
  static const _w = 60.0; // platform width
  late final Ticker _ticker;
  late final PlatformField _field = PlatformField(widget.seed);
  Duration _last = Duration.zero;
  double _px = 0.5; // 0..1
  double _py = 40;
  double _vy = 520;
  double _best = 0;
  double _elapsed = 0;
  int _steer = 0;
  bool _over = false;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _field.platforms.add((x: 0.5, y: 0));
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration t) {
    if (_over || _size == Size.zero) return;
    final dt = ((t - _last).inMicroseconds / 1e6).clamp(0.0, 0.033);
    _last = t;
    _elapsed += dt;
    final ramp = (_elapsed / 10).floor() * 12.0; // harder every 10 s
    _px = (_px + _steer * 0.9 * dt) % 1;
    if (_px < 0) _px += 1;
    final prevY = _py;
    _vy -= 1100 * dt;
    _py += _vy * dt;
    _field.fill(_py + _size.height, ramp);
    if (_vy < 0) {
      for (final p in _field.platforms) {
        final cx = p.x * _size.width;
        final x = _px * _size.width;
        if (prevY >= p.y && _py <= p.y && (x - cx).abs() < _w / 2 + 12) {
          _vy = 620;
          break;
        }
      }
    }
    _best = math.max(_best, _py);
    if (_py < _best - _size.height * 0.9) {
      _over = true;
      widget.callbacks.onScore?.call(_metres);
    }
    setState(() {});
  }

  int get _metres => (_best / 10).floor();

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
        return Listener(
          onPointerDown: (e) {
            widget.callbacks.onActivity();
            _steer = e.localPosition.dx < _size.width / 2 ? -1 : 1;
          },
          onPointerMove: (e) =>
              _steer = e.localPosition.dx < _size.width / 2 ? -1 : 1,
          onPointerUp: (_) => _steer = 0,
          onPointerCancel: (_) => _steer = 0,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ClimberPainter(
                    platforms: _field.platforms,
                    px: _px,
                    py: _py,
                    best: _best,
                    sky: Color.lerp(
                      const Color(0xFF0F1524),
                      const Color(0xFFF6D27A),
                      (_best / 6000).clamp(0.0, 1.0),
                    )!,
                    accent: c.accent,
                  ),
                ),
              ),
              Positioned(
                top: SaffSpacing.lg,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '$_metres m',
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
                              widget.strings.reached(_metres),
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

class _ClimberPainter extends CustomPainter {
  _ClimberPainter({
    required this.platforms,
    required this.px,
    required this.py,
    required this.best,
    required this.sky,
    required this.accent,
  });

  final List<({double x, double y})> platforms;
  final double px;
  final double py;
  final double best;
  final Color sky;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = sky);
    final base = best - size.height * 0.35; // world y at the bottom edge
    double sy(double y) => size.height - (y - base);
    final plat = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final p in platforms) {
      final y = sy(p.y);
      if (y < -10 || y > size.height + 10) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(p.x * size.width, y),
            width: 60,
            height: 10,
          ),
          const Radius.circular(5),
        ),
        plat,
      );
    }
    canvas.drawCircle(
      Offset(px * size.width, sy(py) - 12),
      12,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(_ClimberPainter old) => true;
}
