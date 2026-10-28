import 'dart:io';

import 'package:check_imports/check_imports.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('check_imports_'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String path, String content) => File('${root.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  List<String> rules() => checkRepo(root.path).map((v) => v.rule).toList();

  test('a clean tree has no violations', () {
    write(
      'packages/saff_domain/lib/a.dart',
      "import 'package:saff_core/saff_core.dart';",
    );
    write(
      'app/lib/features/today/views/today_view.dart',
      "import 'package:saff_ui/saff_ui.dart';",
    );
    expect(checkRepo(root.path), isEmpty);
  });

  test('flags a package depending on a package it may not', () {
    write(
      'packages/saff_core/lib/a.dart',
      "import 'package:saff_domain/saff_domain.dart';",
    );
    expect(rules(), ['package-dependency']);
  });

  test('flags a package importing the app', () {
    write(
      'packages/saff_ui/lib/a.dart',
      "import 'package:saff_app/main.dart';",
    );
    expect(rules(), ['package-imports-app']);
  });

  test('flags a src/ reach-in to another package', () {
    write(
      'packages/saff_domain/lib/a.dart',
      "import 'package:saff_core/src/x.dart';",
    );
    expect(rules(), ['src-reach-in']);
  });

  test('flags an unknown package', () {
    write('packages/mystery/lib/a.dart', '');
    expect(rules(), ['unknown-package']);
  });

  test('flags feature to feature imports', () {
    write(
      'app/lib/features/chat/view_models/c.dart',
      "import 'package:saff_app/features/today/widgets/w.dart';",
    );
    expect(rules(), ['feature-imports-feature']);
  });

  test('flags a view importing Firebase, Drift, services or saff_alarm', () {
    write(
      'app/lib/features/today/views/a.dart',
      "import 'package:cloud_firestore/cloud_firestore.dart';",
    );
    write(
      'app/lib/features/today/views/b.dart',
      "import 'package:drift/drift.dart';",
    );
    write(
      'app/lib/features/today/views/c.dart',
      "import 'package:saff_app/data/services/x.dart';",
    );
    write(
      'app/lib/features/today/views/d.dart',
      "import 'package:saff_alarm/saff_alarm.dart';",
    );
    write(
      'app/lib/features/today/views/e.dart',
      "import 'package:firebase_auth/firebase_auth.dart';",
    );
    expect(rules(), everyElement('view-imports-data'));
    expect(rules(), hasLength(5));
  });

  test('view models may import data layers', () {
    write(
      'app/lib/features/today/view_models/a.dart',
      "import 'package:cloud_firestore/cloud_firestore.dart';",
    );
    expect(checkRepo(root.path), isEmpty);
  });

  test('the real repository is clean', () {
    expect(checkRepo('../..'), isEmpty);
  });
}
