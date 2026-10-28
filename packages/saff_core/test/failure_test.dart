import 'dart:io';

import 'package:saff_core/saff_core.dart';
import 'package:test/test.dart';

void main() {
  test('fromCode builds the subtype for every failure kind', () {
    expect(AppFailure.fromCode(FailureCode.saffFull), isA<DomainFailure>());
    expect(
      AppFailure.fromCode(FailureCode.networkOffline),
      isA<NetworkFailure>(),
    );
    expect(
      AppFailure.fromCode(FailureCode.serverInternal),
      isA<BackendFailure>(),
    );
    expect(AppFailure.fromCode(FailureCode.dataMalformed), isA<DataFailure>());
    expect(AppFailure.fromCode(FailureCode.unknown), isA<UnknownFailure>());
  });

  test('a device failure carries its fix, defaulting to app settings', () {
    final withFix = AppFailure.fromCode(
      FailureCode.alarmPermissionMissing,
      fix: DeviceFix.alarmPermission,
    );
    expect((withFix as DeviceFailure).fix, DeviceFix.alarmPermission);
    final without = AppFailure.fromCode(FailureCode.storageFull);
    expect((without as DeviceFailure).fix, DeviceFix.appSettings);
  });

  test('exposes catalog data and a safe toString', () {
    const f = DomainFailure(code: FailureCode.skipTooLate);
    expect(f.retryable, isFalse);
    expect(f.severity, FailureSeverity.info);
    expect(f.messageKey, 'errorSkipTooLate');
    expect(f.toString(), 'AppFailure(SKIP_TOO_LATE)');
    expect(const HttpStatusException(500).toString(), isNot(contains('body')));
  });

  test('HttpException is treated as a network failure', () {
    const mapper = FailureMapper([NetworkExceptionMapper()]);
    final f = mapper.map(const HttpException('x'), StackTrace.current);
    expect(f.code, FailureCode.networkOffline);
  });

  test('the system clock reports now and waits', () async {
    const clock = SystemClock();
    final before = DateTime.now();
    await clock.delay(const Duration(milliseconds: 1));
    expect(clock.now().isBefore(before), isFalse);
  });
}
