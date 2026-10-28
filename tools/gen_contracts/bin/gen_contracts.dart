import 'dart:io';

import 'package:gen_contracts/gen_contracts.dart';

/// Usage: `dart run tools/gen_contracts/bin/gen_contracts.dart <repoRoot>`.
void main(List<String> args) {
  final root = args.isEmpty ? '.' : args.first;
  final files = generateFromRepo(root);
  for (final entry in files.entries) {
    File('$root/${entry.key}')
      ..createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }
  stdout.writeln('Generated ${files.length} files.');
}
