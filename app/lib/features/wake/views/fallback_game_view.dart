import 'dart:async';

import 'package:flutter/material.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_ui/saff_ui.dart';

/// Offline fallback (`docs/PRODUCT.md` §6.6): a tiny local game for a phone
/// that never received the locked round. The member still counts as woke but
/// is unranked. A full arcade game replaces this in the modes stage.
class FallbackGameView extends StatefulWidget {
  /// Creates the view.
  const FallbackGameView({required this.onDone, super.key});

  /// Called once the game is finished.
  final Future<void> Function() onDone;

  @override
  State<FallbackGameView> createState() => _FallbackGameViewState();
}

class _FallbackGameViewState extends State<FallbackGameView> {
  static const _target = 12;
  int _taps = 0;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SaffSpacing.xl),
          child: Column(
            children: [
              Text(
                l10n.offlineFallbackTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: SaffSpacing.sm),
              Text(l10n.offlineFallbackBody, style: TextStyle(color: c.muted)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (_done) return;
                  setState(() => _taps++);
                  if (_taps >= _target) {
                    _done = true;
                    unawaited(widget.onDone());
                  }
                },
                child: AnimatedContainer(
                  duration: SaffMotion.fast,
                  width: 120 + _taps * 10.0,
                  height: 120 + _taps * 10.0,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wb_sunny, size: 56),
                ),
              ),
              const Spacer(),
              Text(
                '$_taps / $_target',
                style: TextStyle(color: c.muted, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
