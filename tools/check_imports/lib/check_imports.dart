/// Enforces the import boundaries of `docs/REPOSITORY.md` section 4.
library;

import 'dart:io';

/// What each package may depend on (`docs/ARCHITECTURE.md` section 4.1).
const allowedPackageDependencies = <String, Set<String>>{
  'saff_core': {},
  'saff_domain': {'saff_core'},
  'saff_ui': {'saff_core'},
  'saff_alarm': {'saff_core'},
  'saff_modes': {'saff_core', 'saff_domain', 'saff_ui'},
  'mode_card_duel': {'saff_modes', 'saff_ui'},
  'mode_word': {'saff_modes', 'saff_ui'},
  'mode_arcade': {'saff_modes', 'saff_ui'},
  'mode_selfie': {'saff_modes', 'saff_ui'},
};

/// Workspace packages that features may not be imported across.
const _workspacePackages = {
  'saff_app',
  'saff_core',
  'saff_domain',
  'saff_ui',
  'saff_alarm',
  'saff_modes',
  'mode_card_duel',
  'mode_word',
  'mode_arcade',
  'mode_selfie',
};

/// Imports a view must never contain (the whole path or package prefix).
const _forbiddenInViews = [
  'package:cloud_firestore/',
  'package:firebase_',
  'package:cloud_functions/',
  'package:drift/',
  'package:drift_flutter/',
  'package:saff_alarm/',
];

final _importPattern = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// One broken rule.
class Violation {
  /// Creates a violation of [rule] in [file].
  const Violation(this.file, this.rule, this.message);

  /// The offending file, relative to the repo root.
  final String file;

  /// Short rule name.
  final String rule;

  /// What is wrong and what to do.
  final String message;

  @override
  String toString() => '$file: [$rule] $message';
}

/// Checks the repository at [root] and returns every violation.
List<Violation> checkRepo(String root) {
  final violations = <Violation>[];
  final packagesDir = Directory('$root/packages');
  if (packagesDir.existsSync()) {
    for (final dir in packagesDir.listSync().whereType<Directory>()) {
      final name = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      violations.addAll(_checkPackage(root, dir, name));
    }
  }
  final features = Directory('$root/app/lib/features');
  if (features.existsSync()) {
    violations
      ..addAll(_checkFeatures(root, features))
      ..addAll(_checkViews(root, features));
  }
  return violations..sort((a, b) => a.toString().compareTo(b.toString()));
}

Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _rel(String root, File f) =>
    f.path.substring(root.length).replaceFirst(RegExp('^/'), '');

List<String> _imports(File f) => [
  for (final m in _importPattern.allMatches(f.readAsStringSync())) m.group(1)!,
];

List<Violation> _checkPackage(String root, Directory dir, String name) {
  final allowed = allowedPackageDependencies[name];
  final out = <Violation>[];
  if (allowed == null) {
    return [
      Violation(
        'packages/$name',
        'unknown-package',
        'Package is not in the allow-list of docs/ARCHITECTURE.md §4.1.',
      ),
    ];
  }
  for (final dirName in ['lib', 'test']) {
    final sub = Directory('${dir.path}/$dirName');
    if (!sub.existsSync()) continue;
    for (final file in _dartFiles(sub)) {
      for (final uri in _imports(file)) {
        if (!uri.startsWith('package:')) continue;
        final target = uri.substring(8).split('/').first;
        if (target == name) continue;
        final rest = uri.substring(8 + target.length + 1);
        if (_workspacePackages.contains(target)) {
          if (target == 'saff_app') {
            out.add(
              Violation(
                _rel(root, file),
                'package-imports-app',
                'Packages never import the app ($uri).',
              ),
            );
          } else if (!allowed.contains(target)) {
            out.add(
              Violation(
                _rel(root, file),
                'package-dependency',
                '$name may not depend on $target ($uri); see '
                    'docs/ARCHITECTURE.md §4.1.',
              ),
            );
          } else if (rest.startsWith('src/')) {
            out.add(
              Violation(
                _rel(root, file),
                'src-reach-in',
                'Import the public library of $target, not its src/ ($uri).',
              ),
            );
          }
        }
      }
    }
  }
  return out;
}

List<Violation> _checkFeatures(String root, Directory features) {
  final out = <Violation>[];
  for (final featureDir in features.listSync().whereType<Directory>()) {
    final feature = featureDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    for (final file in _dartFiles(featureDir)) {
      for (final uri in _imports(file)) {
        final match = RegExp(
          '^package:saff_app/features/([^/]+)/',
        ).firstMatch(uri);
        if (match != null && match.group(1) != feature) {
          out.add(
            Violation(
              _rel(root, file),
              'feature-imports-feature',
              'Feature $feature imports feature ${match.group(1)} ($uri). '
                  'Move the shared part to a package or a repository.',
            ),
          );
        }
      }
    }
  }
  return out;
}

List<Violation> _checkViews(String root, Directory features) {
  final out = <Violation>[];
  for (final file in _dartFiles(features)) {
    final rel = _rel(root, file);
    if (!rel.contains('/views/')) continue;
    for (final uri in _imports(file)) {
      if (uri.startsWith('package:saff_app/data/services/') ||
          _forbiddenInViews.any(uri.startsWith)) {
        out.add(
          Violation(
            rel,
            'view-imports-data',
            'Views talk to view models only; $uri is off limits.',
          ),
        );
      }
    }
  }
  return out;
}
