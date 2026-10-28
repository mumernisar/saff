import 'package:saff_core/saff_core.dart';
import 'package:test/test.dart';

void main() {
  const mapper = FailureMapper([FormatExceptionMapper()]);
  const failure = DomainFailure(code: FailureCode.saffFull);

  test('map, flatMap, fold and getOrNull on Ok', () {
    const r = Result<int>.ok(2);
    expect(r.map((v) => v * 2).getOrNull(), 4);
    expect(r.flatMap((v) => Result<int>.ok(v + 1)).getOrNull(), 3);
    expect(r.fold(ok: (v) => 'ok$v', err: (f) => 'err'), 'ok2');
  });

  test('map, flatMap, fold and getOrNull on Err', () {
    const r = Result<int>.err(failure);
    expect(r.map((v) => v * 2), isA<Err<int>>());
    expect(r.flatMap(Result<int>.ok), isA<Err<int>>());
    expect(r.getOrNull(), isNull);
    expect(r.fold(ok: (v) => 'ok', err: (f) => f.code.wire), 'SAFF_FULL');
  });

  group('guard', () {
    test('returns Ok with the value', () async {
      final r = await Result.guard(() async => 7, mapper);
      expect(r.getOrNull(), 7);
    });

    test('maps an Exception and passes the context', () async {
      final r = await Result.guard<int>(
        () async => throw const FormatException('x'),
        mapper,
        context: {'op': 'parse'},
      );
      final f = (r as Err<int>).failure;
      expect(f.code, FailureCode.dataMalformed);
      expect(f.context['op'], 'parse');
    });

    test('lets an Error (a bug) escape', () {
      expect(
        Result.guard<int>(() async => throw StateError('bug'), mapper),
        throwsStateError,
      );
    });
  });
}
