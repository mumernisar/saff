import 'dart:math';

import 'package:saff_core/saff_core.dart';
import 'package:test/test.dart';

void main() {
  const retryable = NetworkFailure(code: FailureCode.networkOffline);
  const permanent = DomainFailure(code: FailureCode.saffFull);

  test('ceiling doubles from 500 ms and caps at 30 s', () {
    const p = RetryPolicy.userRead;
    expect(p.ceiling(1), const Duration(milliseconds: 500));
    expect(p.ceiling(2), const Duration(seconds: 1));
    expect(p.ceiling(3), const Duration(seconds: 2));
    expect(p.ceiling(10), const Duration(seconds: 30));
  });

  test('the attempt counts follow the policy', () {
    expect(RetryPolicy.userRead.maxAttempts, 4);
    expect(RetryPolicy.backgroundSync.maxAttempts, 6);
  });

  test(
    'retries a retryable failure until success, without real waiting',
    () async {
      final clock = FakeClock(DateTime(2026));
      var calls = 0;
      final r = await retryResult(
        () async =>
            ++calls < 3 ? const Result<int>.err(retryable) : const Result.ok(1),
        clock: clock,
        random: Random(1),
      );
      expect(r.getOrNull(), 1);
      expect(calls, 3);
      expect(clock.delays, hasLength(2));
    },
  );

  test('stops at maxAttempts and returns the last failure', () async {
    final clock = FakeClock(DateTime(2026));
    var calls = 0;
    final r = await retryResult<int>(
      () async {
        calls++;
        return const Result.err(retryable);
      },
      clock: clock,
    );
    expect(r, isA<Err<int>>());
    expect(calls, 4);
  });

  test('never retries a non-retryable failure', () async {
    final clock = FakeClock(DateTime(2026));
    var calls = 0;
    await retryResult<int>(
      () async {
        calls++;
        return const Result.err(permanent);
      },
      clock: clock,
    );
    expect(calls, 1);
    expect(clock.delays, isEmpty);
  });

  test('full jitter keeps every wait within its ceiling', () async {
    final clock = FakeClock(DateTime(2026));
    await retryResult<int>(
      () async => const Result.err(retryable),
      clock: clock,
      policy: RetryPolicy.backgroundSync,
      random: Random(7),
    );
    for (var i = 0; i < clock.delays.length; i++) {
      expect(
        clock.delays[i],
        lessThanOrEqualTo(RetryPolicy.backgroundSync.ceiling(i + 1)),
      );
    }
    expect(clock.delays, hasLength(5));
  });
}
