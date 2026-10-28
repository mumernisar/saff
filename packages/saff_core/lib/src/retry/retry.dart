import 'dart:math';

import 'package:saff_core/src/result/result.dart';
import 'package:saff_core/src/time/clock.dart';

/// Backoff settings (`docs/ERRORS.md` §6).
final class RetryPolicy {
  /// Creates a policy.
  const RetryPolicy({
    required this.maxAttempts,
    this.base = const Duration(milliseconds: 500),
    this.factor = 2,
    this.cap = const Duration(seconds: 30),
  });

  /// Up to 4 attempts, for user-initiated reads.
  static const userRead = RetryPolicy(maxAttempts: 4);

  /// Up to 6 attempts, for background sync.
  static const backgroundSync = RetryPolicy(maxAttempts: 6);

  /// Total attempts including the first.
  final int maxAttempts;

  /// Delay ceiling of the first retry.
  final Duration base;

  /// Growth of the ceiling per retry.
  final int factor;

  /// Largest ceiling.
  final Duration cap;

  /// The ceiling for the delay before retry number [retry] (1-based).
  Duration ceiling(int retry) {
    final micros = base.inMicroseconds * pow(factor, retry - 1);
    return micros >= cap.inMicroseconds
        ? cap
        : Duration(microseconds: micros.toInt());
  }
}

/// Runs [operation], retrying only failures marked retryable, with full
/// jitter: each wait is a random value between zero and the ceiling.
///
/// Writes must be idempotent before they are retried (`docs/ERRORS.md` §6).
Future<Result<T>> retryResult<T>(
  Future<Result<T>> Function() operation, {
  required Clock clock,
  RetryPolicy policy = RetryPolicy.userRead,
  Random? random,
}) async {
  final rng = random ?? Random();
  var result = await operation();
  for (var retry = 1; retry < policy.maxAttempts; retry++) {
    if (result case Err(:final failure) when failure.retryable) {
      final ceiling = policy.ceiling(retry);
      await clock.delay(
        Duration(
          microseconds: (ceiling.inMicroseconds * rng.nextDouble()).round(),
        ),
      );
      result = await operation();
    } else {
      break;
    }
  }
  return result;
}
