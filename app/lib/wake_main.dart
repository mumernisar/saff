import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/config/environment_config.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/wake/views/ringing_view.dart';
import 'package:saff_app/l10n/app_localizations.dart';

/// Entrypoint of the wake engine, started by the native alarm activity
/// (`docs/ARCHITECTURE.md` §7). Minimal providers; no Firebase until the
/// wake flow needs the locked round.
@pragma('vm:entry-point')
Future<void> wakeMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        environmentConfigProvider.overrideWithValue(
          EnvironmentConfig.fromBuildFlavor(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(useMaterial3: true),
        home: const RingingView(),
      ),
    ),
  );
}
