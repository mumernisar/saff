import 'dart:convert';
import 'dart:io';

import 'package:saff_core/saff_core.dart';
import 'package:test/test.dart';

void main() {
  final catalog = (jsonDecode(
    File('../../contracts/errors.json').readAsStringSync(),
  ) as Map).cast<String, Map<String, dynamic>>();

  test('FailureCode has exactly the codes of contracts/errors.json', () {
    expect(
      FailureCode.values.map((c) => c.wire).toList(),
      catalog.keys.toList(),
    );
  });

  test('every code carries the catalog fields', () {
    for (final code in FailureCode.values) {
      final e = catalog[code.wire]!;
      expect(code.kind.name, e['kind'], reason: code.wire);
      expect(code.severity.name, e['severity'], reason: code.wire);
      expect(code.retryable, e['retryable'], reason: code.wire);
      expect(code.httpsCode, e['httpsCode'], reason: code.wire);
      expect(code.messageKey, e['messageKey'], reason: code.wire);
    }
  });

  test('fromWire finds codes and rejects unknown ones', () {
    expect(FailureCode.fromWire('SKIP_TOO_LATE'), FailureCode.skipTooLate);
    expect(FailureCode.fromWire('NOPE'), isNull);
  });

  test('every message key is unique and starts with error', () {
    final keys = FailureCode.values.map((c) => c.messageKey).toList();
    expect(keys.toSet().length, keys.length);
    expect(keys.every((k) => k.startsWith('error')), isTrue);
  });
}
