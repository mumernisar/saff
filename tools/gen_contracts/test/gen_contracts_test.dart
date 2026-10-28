import 'dart:convert';

import 'package:gen_contracts/gen_contracts.dart';
import 'package:test/test.dart';

void main() {
  final errors = {
    'SKIP_TOO_LATE': {
      'kind': 'domain',
      'severity': 'info',
      'retryable': false,
      'httpsCode': 'failed-precondition',
      'messageKey': 'errorSkipTooLate',
      'description': 'd',
      'message': 'Too late.',
    },
  };
  final constants = {
    'NUDGE_INTERVAL': {'value': 120000, 'unit': 'ms', 'description': 'd'},
    'CARDS_PER_ROUND': {'value': 8, 'unit': 'count', 'description': 'd'},
  };

  test('camel converts UPPER_SNAKE', () {
    expect(camel('MAX_SAFF_SIZE_FREE'), 'maxSaffSizeFree');
  });

  test('generates the expected files', () {
    final files = generate(
      errors: errors,
      constants: constants,
      demo: {'NUDGE_INTERVAL': 20000},
      existingArb: '',
    );
    expect(files.keys, hasLength(5));
    expect(
      files['functions/src/contracts/constants.generated.ts'],
      contains('nudgeIntervalMs: 20000,'),
    );
    expect(
      files['packages/saff_domain/lib/src/constants/saff_constants.g.dart'],
      contains('Duration(milliseconds: 20000)'),
    );
  });

  test('a demo override of an unknown constant fails', () {
    expect(
      () => generate(
        errors: errors,
        constants: constants,
        demo: {'NOPE': 1},
        existingArb: '',
      ),
      throwsStateError,
    );
  });

  test('the ARB keeps hand-written keys and replaces error keys', () {
    final files = generate(
      errors: errors,
      constants: constants,
      demo: {},
      existingArb: jsonEncode({
        '@@locale': 'en',
        'appTitle': 'Saff',
        'errorStale': 'old',
      }),
    );
    final arb = jsonDecode(files['app/lib/l10n/app_en.arb']!) as Map;
    expect(arb['appTitle'], 'Saff');
    expect(arb['errorSkipTooLate'], 'Too late.');
    expect(arb.containsKey('errorStale'), isFalse);
  });
}
