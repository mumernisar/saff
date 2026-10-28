import 'package:saff_app/bootstrap.dart';
import 'package:saff_app/config/environment_config.dart';
import 'package:saff_app/config/firebase_options_dev.dart';
// The wake engine starts this library by name, so it must be part of the app.
// ignore: unused_import
import 'package:saff_app/wake_main.dart';

Future<void> main() => bootstrap(
  config: EnvironmentConfig.fromDefines(Flavor.dev),
  firebaseOptions: DefaultFirebaseOptions.currentPlatform,
);
