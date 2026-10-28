import 'package:flutter/services.dart';
import 'package:saff_core/saff_core.dart';

/// Maps alarm-plugin [PlatformException]s to catalog failures (`docs/ERRORS.md` §4).
final class AlarmFailureMapper implements ExceptionMapper {
  /// Creates the mapper.
  const AlarmFailureMapper();

  @override
  AppFailure? tryMap(Object e, StackTrace st, Map<String, Object?> context) {
    if (e is! PlatformException) return null;
    final (code, fix) = switch (e.code) {
      'ALARM_PERMISSION_MISSING' => (
        FailureCode.alarmPermissionMissing,
        DeviceFix.alarmPermission,
      ),
      'FULL_SCREEN_DENIED' => (
        FailureCode.fullScreenDenied,
        DeviceFix.fullScreenIntent,
      ),
      _ => (null, null),
    };
    if (code == null) return null;
    return AppFailure.fromCode(
      code,
      cause: e,
      stackTrace: st,
      context: context,
      fix: fix,
    );
  }
}
