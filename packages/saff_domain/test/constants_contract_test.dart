import 'dart:convert';
import 'dart:io';

import 'package:saff_domain/saff_domain.dart';
import 'package:test/test.dart';

Map<String, dynamic> _read(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

void main() {
  const constantsPath = '../../contracts/constants.json';
  final constants = _read(constantsPath);
  const demoPath = '../../contracts/constants.demo.json';
  final demo = _read(demoPath);
  int value(String name) =>
      (constants[name]! as Map<String, dynamic>)['value']! as int;

  test('production constants match contracts/constants.json', () {
    const c = SaffConstants.production;
    expect(c.maxSaffSizeFree, value('MAX_SAFF_SIZE_FREE'));
    expect(
      c.maxSaffsPerUserPlus,
      value('MAX_SAFFS_PER_USER_PLUS'),
    );
    expect(
      c.nightLockLead.inMilliseconds,
      value('NIGHT_LOCK_LEAD'),
    );
    expect(c.importMaxFile, value('IMPORT_MAX_FILE'));
  });

  test('demo constants apply exactly the demo overlay', () {
    expect(
      SaffConstants.demo.nightLockLead.inMilliseconds,
      demo['NIGHT_LOCK_LEAD']! as int,
    );
    expect(
      SaffConstants.demo.nudgeInterval.inMilliseconds,
      demo['NUDGE_INTERVAL']! as int,
    );
    expect(
      SaffConstants.demo.cardsPerRound,
      SaffConstants.production.cardsPerRound,
    );
  });

  test('prod ignores a demo request (60 / 30 / 2 / 2 min)', () {
    final c = SaffConstants.resolve(allowDemo: false, demoRequested: true);
    expect(c, same(SaffConstants.production));
    expect(c.nightLockLead, const Duration(minutes: 60));
    expect(c.revealDeadline, const Duration(minutes: 30));
    expect(c.nudgeInterval, const Duration(minutes: 2));
    expect(c.offlineCheckDelay, const Duration(minutes: 2));
    expect(c.alarmConflictWindow, const Duration(minutes: 30));
    expect(c.skipMinNotice, const Duration(hours: 8));
    expect(c.snoozeDuration, const Duration(minutes: 5));
    expect(c.alarmPickerStep, const Duration(minutes: 5));
  });

  test('demo applies only when allowed and requested', () {
    expect(
      SaffConstants.resolve(allowDemo: true, demoRequested: true),
      same(SaffConstants.demo),
    );
    expect(
      SaffConstants.resolve(allowDemo: true, demoRequested: false),
      same(SaffConstants.production),
    );
  });
}
