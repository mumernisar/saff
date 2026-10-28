import 'package:saff_core/saff_core.dart';
import 'package:test/test.dart';

void main() {
  test('redact hides personal keys and keeps ids', () {
    final out = redact({
      'saffId': 's1',
      'email': 'a@b.c',
      'phone': '123',
      'text': 'hello',
      'requestId': 'r1',
    });
    expect(out['saffId'], 's1');
    expect(out['requestId'], 'r1');
    expect(out['email'], '[redacted]');
    expect(out['phone'], '[redacted]');
    expect(out['text'], '[redacted]');
  });

  test('NoopLog accepts every call', () {
    const log = NoopLog();
    log
      ..debug('a')
      ..info('b')
      ..warn('c')
      ..error(const UnknownFailure(code: FailureCode.unknown));
  });

  test('FakeClock advances only on demand', () {
    final clock = FakeClock(DateTime(2026))..advance(const Duration(hours: 1));
    expect(clock.now(), DateTime(2026, 1, 1, 1));
  });
}
