import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:saff_modes/saff_modes.dart';
import 'package:saff_ui/saff_ui.dart';

/// Texts supplied by the app.
class SelfieStrings {
  /// Creates the strings.
  const SelfieStrings({
    required this.title,
    required this.hint,
    required this.capture,
    required this.sending,
  });

  /// Heading.
  final String title;

  /// Instruction.
  final String hint;

  /// Shutter label.
  final String capture;

  /// Shown while the photo uploads.
  final String sending;
}

/// Selfie (`docs/PRODUCT.md` §7): everyone takes a selfie with the front
/// camera (no gallery); selfies stay hidden until the reveal; unranked.
///
/// When the camera is unavailable or denied, [fallback] builds an arcade game
/// instead; the member counts as woke but unranked.
class SelfieMode implements GameMode {
  /// Creates the mode.
  const SelfieMode({required this.strings, required this.fallback});

  /// App-supplied texts.
  final SelfieStrings strings;

  /// The arcade game used when the camera cannot be used.
  final Widget Function(BuildContext, Round, ModeCallbacks) fallback;

  @override
  String get id => 'selfie';

  @override
  Widget build(
    BuildContext context,
    Round round,
    List<CardAnswer> answered,
    ModeCallbacks callbacks,
  ) => SelfieCapture(
    strings: strings,
    callbacks: callbacks,
    fallback: (c) => fallback(c, round, callbacks),
  );
}

/// The capture surface.
class SelfieCapture extends StatefulWidget {
  /// Creates the surface.
  const SelfieCapture({
    required this.strings,
    required this.callbacks,
    required this.fallback,
    super.key,
  });

  /// Texts.
  final SelfieStrings strings;

  /// Host callbacks.
  final ModeCallbacks callbacks;

  /// Builds the arcade fallback.
  final Widget Function(BuildContext) fallback;

  @override
  State<SelfieCapture> createState() => _SelfieCaptureState();
}

class _SelfieCaptureState extends State<SelfieCapture> {
  CameraController? _controller;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final c = CameraController(front, ResolutionPreset.medium);
      await c.initialize();
      if (!mounted) return;
      setState(() => _controller = c);
    } on Object catch (_) {
      // Permission denied or no camera: fall back to an arcade game.
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _shoot() async {
    final c = _controller;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    widget.callbacks.onActivity();
    final file = await c.takePicture();
    widget.callbacks.onFile?.call(file.path);
    widget.callbacks.onDone();
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback(context);
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(c)),
        Positioned(
          top: SaffSpacing.xl,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              widget.strings.hint,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: SaffSpacing.xxl,
          left: 0,
          right: 0,
          child: Center(
            child: _busy
                ? Text(
                    widget.strings.sending,
                    style: const TextStyle(color: Colors.white),
                  )
                : GestureDetector(
                    onTap: _shoot,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.saff.accent,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
