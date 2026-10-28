import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/router.dart';
import 'package:saff_ui/saff_ui.dart';

/// The root widget.
class SaffApp extends StatefulWidget {
  /// Creates the app. [router] defaults to the real one; tests inject theirs.
  const SaffApp({super.key, this.router});

  /// Overrides the router.
  final GoRouter? router;

  @override
  State<SaffApp> createState() => _SaffAppState();
}

class _SaffAppState extends State<SaffApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    routerConfig: _router,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: SaffTheme.light(),
    darkTheme: SaffTheme.dark(),
  );
}
