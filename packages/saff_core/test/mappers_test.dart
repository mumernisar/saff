import 'dart:async';
import 'dart:io';

import 'package:saff_core/saff_core.dart';
import 'package:test/test.dart';

void main() {
  const mapper = FailureMapper([
    AppFailureMapper(),
    NetworkExceptionMapper(),
    HttpStatusMapper(),
    FormatExceptionMapper(),
  ]);
  final st = StackTrace.current;

  test('SocketException becomes NetworkFailure(NETWORK_OFFLINE)', () {
    final f = mapper.map(const SocketException('no route'), st);
    expect(f, isA<NetworkFailure>());
    expect(f.code, FailureCode.networkOffline);
    expect(f.retryable, isTrue);
  });

  test('HandshakeException becomes NETWORK_OFFLINE', () {
    final f = mapper.map(const HandshakeException('tls'), st);
    expect(f.code, FailureCode.networkOffline);
  });

  test('TimeoutException becomes NETWORK_TIMEOUT', () {
    final f = mapper.map(TimeoutException('slow'), st);
    expect(f, isA<NetworkFailure>());
    expect(f.code, FailureCode.networkTimeout);
  });

  test('a deliberate AppFailure passes through unchanged', () {
    const original = DomainFailure(code: FailureCode.skipTooLate);
    expect(identical(mapper.map(original, st), original), isTrue);
  });

  test('FormatException becomes DataFailure(DATA_MALFORMED)', () {
    final f = mapper.map(const FormatException('bad'), st);
    expect(f, isA<DataFailure>());
    expect(f.code, FailureCode.dataMalformed);
  });

  group('HttpStatusMapper', () {
    AppFailure map(int status) =>
        mapper.map(HttpStatusException(status, 'body'), st);

    test('maps statuses to codes', () {
      expect(map(401).code, FailureCode.unauthenticated);
      expect(map(403).code, FailureCode.permissionDenied);
      expect(map(404).code, FailureCode.notFound);
      expect(map(429).code, FailureCode.rateLimited);
      expect(map(400).code, FailureCode.dataMalformed);
    });

    test('5xx is a retryable BackendFailure', () {
      final f = map(503);
      expect(f, isA<BackendFailure>());
      expect(f.retryable, isTrue);
    });

    test('records the status in the context, not the body', () {
      final f = map(500);
      expect(f.context['httpStatus'], 500);
      expect(f.context.values, isNot(contains('body')));
    });
  });

  test('an unrecognised exception becomes UnknownFailure(UNKNOWN)', () {
    final f = mapper.map(Exception('mystery'), st, context: {'op': 'x'});
    expect(f, isA<UnknownFailure>());
    expect(f.code, FailureCode.unknown);
    expect(f.context['op'], 'x');
  });

  test('fromCode builds the subtype matching the code kind', () {
    expect(
      AppFailure.fromCode(FailureCode.serverInternal),
      isA<BackendFailure>(),
    );
  });
}
