import 'dart:io';

import 'package:check_imports/check_imports.dart';

/// Usage: `dart run tools/check_imports/bin/check_imports.dart [repoRoot]`.
void main(List<String> args) {
  final root = args.isEmpty ? '.' : args.first;
  final violations = checkRepo(root);
  if (violations.isEmpty) {
    stdout.writeln('Import boundaries OK.');
    return;
  }
  violations.forEach(stderr.writeln);
  stderr.writeln('${violations.length} import boundary violation(s).');
  exitCode = 1;
}
