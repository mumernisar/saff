/// Source of time and delays, injectable so tests never wait.
abstract interface class Clock {
  /// The current instant.
  DateTime now();

  /// Completes after [duration].
  Future<void> delay(Duration duration);
}

/// The real clock.
final class SystemClock implements Clock {
  /// Creates the real clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Future<void> delay(Duration duration) => Future<void>.delayed(duration);
}

/// A clock for tests: time moves only when [delay] or [advance] is called.
final class FakeClock implements Clock {
  /// Starts the clock at [start].
  FakeClock(DateTime start) : _now = start;

  DateTime _now;

  /// Every duration passed to [delay], in order.
  final List<Duration> delays = [];

  @override
  DateTime now() => _now;

  /// Moves time forward.
  void advance(Duration duration) => _now = _now.add(duration);

  @override
  Future<void> delay(Duration duration) async {
    delays.add(duration);
    advance(duration);
  }
}
