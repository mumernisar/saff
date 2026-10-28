import 'package:flutter/material.dart';
import 'package:saff_domain/saff_domain.dart';

/// A button that fires [onCompleted] after being held for `HOLD_TO_START`.
class HoldToStartButton extends StatefulWidget {
  /// Creates the button.
  const HoldToStartButton({
    required this.label,
    required this.onCompleted,
    super.key,
  });

  /// The label.
  final String label;

  /// Called once the hold completes.
  final VoidCallback onCompleted;

  @override
  State<HoldToStartButton> createState() => _HoldToStartButtonState();
}

class _HoldToStartButtonState extends State<HoldToStartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SaffConstants.production.holdToStart,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) widget.onCompleted();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _c.forward(),
    onPointerUp: (_) => _c.reverse(),
    onPointerCancel: (_) => _c.reverse(),
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(36),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _c.value,
                child: const ColoredBox(color: Color(0xFFF2B33D)),
              ),
            ),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
