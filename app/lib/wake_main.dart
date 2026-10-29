import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/config/environment_config.dart';
import 'package:saff_app/config/firebase_options_dev.dart' as dev;
import 'package:saff_app/config/firebase_options_prod.dart' as prod;
import 'package:saff_app/data/services/firebase_init.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/wake/views/ringing_view.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_ui/saff_ui.dart';

/// Entrypoint of the wake engine, started by the native alarm activity
/// (`docs/ARCHITECTURE.md` §7). Minimal providers; no Firebase until the
/// wake flow needs the locked round.
@pragma('vm:entry-point')
Future<void> wakeMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = EnvironmentConfig.fromBuildFlavor();
  // Firebase is needed for the round and live statuses; the ring itself never
  // waits for it (the sound already started natively).
  await initFirebase(
    config,
    config.isDev
        ? dev.DefaultFirebaseOptions.currentPlatform
        : prod.DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ProviderScope(
      overrides: [
        environmentConfigProvider.overrideWithValue(
          config,
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
        theme: SaffTheme.dark(),
        home: const RingingView(),
      ),
    ),
  );
}
