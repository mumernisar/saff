import 'package:saff_alarm/saff_alarm.dart';
import 'package:saff_core/saff_core.dart';

/// The mapper chain registered once in DI (`docs/ERRORS.md` §4).
///
/// The Firebase, Platform and Drift mappers join this chain in
/// `app/lib/data/errors/` as the services that need them arrive.
FailureMapper buildFailureMapper() => const FailureMapper([
  AppFailureMapper(),
  AlarmFailureMapper(),
  NetworkExceptionMapper(),
  HttpStatusMapper(),
  FormatExceptionMapper(),
]);
