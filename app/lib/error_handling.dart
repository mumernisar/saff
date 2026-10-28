import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:saff_app/data/services/crash_reporter.dart';

/// Installs the global handlers for bugs and the unexpected
/// (`docs/ERRORS.md` §8).
///
/// [releaseWidgets] swaps the red error screen for a calm one, as in release
/// builds.
void installGlobalErrorHandlers(
  CrashReporter reporter, {
  bool releaseWidgets = kReleaseMode,
}) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.fatal(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.fatal(error, stack);
    return true;
  };
  if (releaseWidgets) {
    ErrorWidget.builder = (details) => const BrokenScreen();
  }
}

/// Shown instead of a widget that failed to build, in release.
class BrokenScreen extends StatelessWidget {
  /// Creates the screen.
  const BrokenScreen({super.key});

  @override
  Widget build(BuildContext context) => const Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: Text('Something broke on this screen.')),
  );
}
