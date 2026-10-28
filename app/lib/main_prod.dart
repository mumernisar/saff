import 'package:saff_app/bootstrap.dart';
import 'package:saff_app/config/environment_config.dart';
import 'package:saff_app/config/firebase_options_prod.dart';

Future<void> main() => bootstrap(
  config: EnvironmentConfig.fromDefines(Flavor.prod),
  firebaseOptions: DefaultFirebaseOptions.currentPlatform,
);
